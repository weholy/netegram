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

public enum NetegramSearchStrings {
    public static let title = "Поиск"
    public static let placeholder = "Поиск настроек..."
    public static let nothingFound = "Ничего не найдено"
}

/// One searchable Netegram feature.
///
/// `alternate` holds words a person might type instead of the exact title, so "стекло"
/// finds Liquid Glass and "звёзды" finds the balance override.
struct NetegramSearchEntryDescriptor {
    let title: String
    let breadcrumb: String
    let alternate: [String]
    let open: (AccountContext, (ViewController) -> Void) -> Void

    func matches(_ query: String) -> Bool {
        let needle = query.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        if needle.isEmpty {
            return true
        }
        let haystack = ([self.title, self.breadcrumb] + self.alternate)
            .map { $0.folding(options: .diacriticInsensitive, locale: .current).lowercased() }
        return haystack.contains(where: { $0.contains(needle) })
    }
}

/// Every Netegram feature reachable from the settings tree.
///
/// Keep this in step with the screens: a feature missing here simply cannot be found.
func netegramSearchEntries() -> [NetegramSearchEntryDescriptor] {
    return [
        NetegramSearchEntryDescriptor(
            title: NetegramStrings.replaceLogoTitle,
            breadcrumb: "Оформление",
            alternate: ["логотип", "logo", "telegram", "значок"],
            open: { context, push in push(netegramAppearanceController(context: context)) }
        ),
        NetegramSearchEntryDescriptor(
            title: NetegramStrings.customIconsTitle,
            breadcrumb: "Оформление",
            alternate: ["иконки", "icons", "настройки", "значки"],
            open: { context, push in push(netegramAppearanceController(context: context)) }
        ),
        NetegramSearchEntryDescriptor(
            title: NetegramStrings.liquidGlassMessagesTitle,
            breadcrumb: "Liquid Glass",
            alternate: ["стекло", "glass", "пузырьки", "сообщения", "прозрачность"],
            open: { context, push in push(netegramLiquidGlassController(context: context)) }
        ),
        NetegramSearchEntryDescriptor(
            title: NetegramStrings.liquidGlassEverywhereTitle,
            breadcrumb: "Liquid Glass",
            alternate: ["стекло", "везде", "повсюду", "glass", "панели", "меню"],
            open: { context, push in push(netegramLiquidGlassController(context: context)) }
        ),
        NetegramSearchEntryDescriptor(
            title: NetegramLocalStrings.localPremiumTitle,
            breadcrumb: "Локальные функции",
            alternate: ["премиум", "premium", "локальный"],
            open: { context, push in push(netegramLocalFeaturesController(context: context)) }
        ),
        NetegramSearchEntryDescriptor(
            title: NetegramLocalStrings.localStars,
            breadcrumb: "Локальные функции",
            alternate: ["звёзды", "звезды", "stars", "баланс"],
            open: { context, push in push(netegramLocalStarsController(context: context)) }
        ),
        NetegramSearchEntryDescriptor(
            title: NetegramBackgroundStrings.videoTitle,
            breadcrumb: "Фон приложения",
            alternate: ["видео", "video", "фон", "обои"],
            open: { context, push in push(netegramBackgroundController(context: context)) }
        ),
        NetegramSearchEntryDescriptor(
            title: NetegramBackgroundStrings.photoTitle,
            breadcrumb: "Фон приложения",
            alternate: ["фото", "photo", "фон", "картинка", "обои"],
            open: { context, push in push(netegramBackgroundController(context: context)) }
        ),
        NetegramSearchEntryDescriptor(
            title: NetegramAnnouncementStrings.title,
            breadcrumb: "Netegram",
            alternate: ["объявление", "плашка", "баннер", "announcement"],
            open: { context, push in push(netegramAnnouncementController(context: context)) }
        )
    ]
}

private final class NetegramSearchArguments {
    let context: AccountContext
    let select: (Int) -> Void
    let updateQuery: (String) -> Void

    init(context: AccountContext, select: @escaping (Int) -> Void, updateQuery: @escaping (String) -> Void) {
        self.context = context
        self.select = select
        self.updateQuery = updateQuery
    }
}

// Results first, the input below them — the field belongs at the bottom, within thumb reach.
private enum NetegramSearchSection: Int32 {
    case results
    case query
}

private enum NetegramSearchEntry: ItemListNodeEntry {
    case query(String)
    case result(index: Int, order: Int, title: String, breadcrumb: String)
    case empty

    var section: ItemListSectionId {
        switch self {
        case .query:
            return NetegramSearchSection.query.rawValue
        case .result, .empty:
            return NetegramSearchSection.results.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .empty:
            return 0
        case let .result(_, order, _, _):
            return Int32(100 + order)
        // Sorted last so the field sits under the results rather than above them.
        case .query:
            return 10000
        }
    }

    static func <(lhs: NetegramSearchEntry, rhs: NetegramSearchEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramSearchArguments
        switch self {
        case let .query(value):
            return ItemListSingleLineInputItem(
                context: arguments.context,
                presentationData: presentationData,
                systemStyle: .glass,
                title: NSAttributedString(string: ""),
                text: value,
                placeholder: NetegramSearchStrings.placeholder,
                clearType: .always,
                sectionId: self.section,
                textUpdated: { value in
                    arguments.updateQuery(value)
                },
                action: {},
                cleared: {
                    arguments.updateQuery("")
                }
            )
        case let .result(index, _, title, breadcrumb):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: "", additionalDetailLabel: breadcrumb, sectionId: self.section, style: .blocks, action: {
                arguments.select(index)
            })
        case .empty:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramSearchStrings.nothingFound), sectionId: self.section)
        }
    }
}

public func netegramSearchController(context: AccountContext) -> ViewController {
    let queryPromise = ValuePromise<String>("", ignoreRepeated: true)
    var currentQuery = ""
    var pushControllerImpl: ((ViewController) -> Void)?

    let allEntries = netegramSearchEntries()

    let arguments = NetegramSearchArguments(context: context, select: { index in
        guard index >= 0 && index < allEntries.count else {
            return
        }
        allEntries[index].open(context, { controller in
            pushControllerImpl?(controller)
        })
    }, updateQuery: { value in
        currentQuery = value
        queryPromise.set(value)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        queryPromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, query -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [NetegramSearchEntry] = [.query(query)]

        var order = 0
        for (index, descriptor) in allEntries.enumerated() where descriptor.matches(query) {
            entries.append(.result(index: index, order: order, title: descriptor.title, breadcrumb: descriptor.breadcrumb))
            order += 1
        }
        if order == 0 {
            entries.append(.empty)
        }

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramSearchStrings.title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: true
        )

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    let _ = currentQuery
    return controller
}
