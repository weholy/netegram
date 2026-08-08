import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import UndoUI

public enum NetegramUnlockStrings {
    public static let title = "Ссылки доступа"
    public static let subtitle = "Открыть функции другим"
    public static let word = "Своё слово"
    public static let wordPlaceholder = "например friends"
    public static let wordFooter = "Попадёт в ссылку, чтобы её было легко узнать. Только буквы и цифры."
    public static let count = "Сколько ссылок"
    public static let countFooter = "Ссылки выдаются по одной на человека. Каждая срабатывает на устройстве один раз — второй раз та же ссылка ничего не откроет."
    public static let create = "Создать"
    public static let created = "Созданные ссылки"
    public static let createdFooter = "Нажмите, чтобы скопировать. Кто получил ссылку — увидит все вкладки Netegram.\n\nСколько людей уже воспользовалось, здесь не видно: считать активации без сервера негде, об использовании знает только то устройство, где ссылку открыли."
    public static let copied = "Ссылка скопирована"
    public static let clear = "Очистить список"
}

private let netegramUnlockWordKey = "netegram.unlock.lastWord"
private let netegramUnlockCountKey = "netegram.unlock.lastCount"
private let netegramUnlockCreatedKey = "netegram.unlock.created"

/// Links the owner has minted, kept so the screen still shows them after it is closed.
///
/// Only a record of what was handed out — it says nothing about who used what, because that
/// is not knowable from here.
private enum NetegramUnlockLog {
    static func load() -> [String] {
        return UserDefaults.standard.stringArray(forKey: netegramUnlockCreatedKey) ?? []
    }

    static func save(_ links: [String]) {
        UserDefaults.standard.set(links, forKey: netegramUnlockCreatedKey)
    }
}

private final class NetegramUnlockArguments {
    let updateWord: (String) -> Void
    let updateCount: (Int) -> Void
    let create: () -> Void
    let copy: (String) -> Void
    let clear: () -> Void

    init(updateWord: @escaping (String) -> Void, updateCount: @escaping (Int) -> Void, create: @escaping () -> Void, copy: @escaping (String) -> Void, clear: @escaping () -> Void) {
        self.updateWord = updateWord
        self.updateCount = updateCount
        self.create = create
        self.copy = copy
        self.clear = clear
    }
}

private enum NetegramUnlockEntry: ItemListNodeEntry {
    case word(String)
    case wordFooter
    case count(Int)
    case countFooter
    case create
    case createdHeader
    case link(Int, String)
    case createdFooter
    case clear

    var section: ItemListSectionId {
        switch self {
        case .word, .wordFooter:
            return 0
        case .count, .countFooter:
            return 1
        case .create:
            return 2
        // Every link shares one block: they are a list of the same thing, not separate
        // settings, so splitting them apart would only add noise.
        case .createdHeader, .link, .createdFooter:
            return 3
        case .clear:
            return 4
        }
    }

    var stableId: Int32 {
        switch self {
        case .word: return 0
        case .wordFooter: return 1
        case .count: return 2
        case .countFooter: return 3
        case .create: return 4
        case .createdHeader: return 5
        case let .link(index, _): return 10 + Int32(index)
        case .createdFooter: return 5000
        case .clear: return 5001
        }
    }

    static func <(lhs: NetegramUnlockEntry, rhs: NetegramUnlockEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramUnlockArguments
        switch self {
        case let .word(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: NetegramUnlockStrings.word, textColor: presentationData.theme.list.itemPrimaryTextColor), text: value, placeholder: NetegramUnlockStrings.wordPlaceholder, type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updateWord(value)
            }, action: {})
        case .wordFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramUnlockStrings.wordFooter), sectionId: self.section)
        case let .count(value):
            return NetegramStarsSliderItem(theme: presentationData.theme, title: "\(NetegramUnlockStrings.count): \(value)", value: value - 1, maxValue: 49, enabled: true, sectionId: self.section, updated: { updated in
                arguments.updateCount(updated + 1)
            })
        case .countFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramUnlockStrings.countFooter), sectionId: self.section)
        case .create:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: NetegramUnlockStrings.create, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.create()
            })
        case .createdHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: NetegramUnlockStrings.created, sectionId: self.section)
        case let .link(_, link):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: link, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.copy(link)
            })
        case .createdFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramUnlockStrings.createdFooter), sectionId: self.section)
        case .clear:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: NetegramUnlockStrings.clear, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clear()
            })
        }
    }
}

/// A named type rather than a tuple: ValuePromise compares what it is given, and tuples do not
/// conform to Equatable no matter what they contain.
private struct NetegramUnlockState: Equatable {
    var word: String
    var count: Int
    var links: [String]
}

public func netegramUnlockController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise<NetegramUnlockState>(
        NetegramUnlockState(
            word: UserDefaults.standard.string(forKey: netegramUnlockWordKey) ?? "",
            count: max(1, UserDefaults.standard.object(forKey: netegramUnlockCountKey) as? Int ?? 1),
            links: NetegramUnlockLog.load()
        ),
        ignoreRepeated: false
    )
    var currentWord = UserDefaults.standard.string(forKey: netegramUnlockWordKey) ?? ""
    var currentCount = max(1, UserDefaults.standard.object(forKey: netegramUnlockCountKey) as? Int ?? 1)
    var currentLinks = NetegramUnlockLog.load()

    var presentCopiedImpl: (() -> Void)?

    let push: () -> Void = {
        statePromise.set(NetegramUnlockState(word: currentWord, count: currentCount, links: currentLinks))
    }

    let arguments = NetegramUnlockArguments(updateWord: { value in
        currentWord = value
        UserDefaults.standard.set(value, forKey: netegramUnlockWordKey)
    }, updateCount: { value in
        currentCount = value
        UserDefaults.standard.set(value, forKey: netegramUnlockCountKey)
        push()
    }, create: {
        // Numbered from what already exists, so creating a second batch with the same word
        // does not hand out links that are already spent.
        let start = currentLinks.count
        var links = currentLinks
        for index in 0 ..< currentCount {
            links.append(NetegramUnlock.makeLink(word: currentWord, index: start + index))
        }
        currentLinks = links
        NetegramUnlockLog.save(links)
        push()
    }, copy: { link in
        UIPasteboard.general.string = link
        presentCopiedImpl?()
    }, clear: {
        currentLinks = []
        NetegramUnlockLog.save([])
        push()
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [NetegramUnlockEntry] = [
            .word(state.word),
            .wordFooter,
            .count(state.count),
            .countFooter,
            .create
        ]
        if !state.links.isEmpty {
            entries.append(.createdHeader)
            for (index, link) in state.links.enumerated() {
                entries.append(.link(index, link))
            }
            entries.append(.createdFooter)
            entries.append(.clear)
        }

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramUnlockStrings.title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentCopiedImpl = { [weak controller] in
        guard let controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(
            UndoOverlayController(presentationData: presentationData, content: .copy(text: NetegramUnlockStrings.copied), elevatedLayout: false, action: { _ in return false }),
            in: .current
        )
    }
    return controller
}
