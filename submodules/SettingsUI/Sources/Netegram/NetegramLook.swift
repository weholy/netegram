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

public enum NetegramLookStrings {
    public static let title = "Внешний вид"
    public static let subtitle = "Меню и эффекты"
    public static let contextRedesignTitle = "Редизайн при зажатии сообщения"
    public static let contextRedesignFooter = "Новый невышедший дизайн Telegram: «Выбрать», «Скопировать» и «Удалить» отдельным рядом сверху, остальные действия списком под ним."
}

/// Read by the chat context menu assembly, which cannot import SettingsUI.
public let netegramContextRedesignKey = "netegram.look.contextRedesign"

public struct NetegramLookSettings: Equatable {
    public let contextRedesign: Bool

    public init(contextRedesign: Bool) {
        self.contextRedesign = contextRedesign
    }
}

public final class NetegramLookPreferences {
    public static let shared = NetegramLookPreferences()

    private let promise: ValuePromise<NetegramLookSettings>

    private init() {
        self.promise = ValuePromise(NetegramLookPreferences.current(), ignoreRepeated: true)
    }

    public static func current() -> NetegramLookSettings {
        return NetegramLookSettings(contextRedesign: UserDefaults.standard.bool(forKey: netegramContextRedesignKey))
    }

    public var signal: Signal<NetegramLookSettings, NoError> {
        return self.promise.get()
    }

    public func setContextRedesign(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: netegramContextRedesignKey)
        self.promise.set(NetegramLookPreferences.current())
    }
}

private final class NetegramLookArguments {
    let updateContextRedesign: (Bool) -> Void

    init(updateContextRedesign: @escaping (Bool) -> Void) {
        self.updateContextRedesign = updateContextRedesign
    }
}

private enum NetegramLookSection: Int32 {
    case contextRedesign
}

private enum NetegramLookEntry: ItemListNodeEntry {
    case contextRedesign(Bool)
    case contextRedesignFooter

    var section: ItemListSectionId {
        return NetegramLookSection.contextRedesign.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .contextRedesign:
            return 0
        case .contextRedesignFooter:
            return 1
        }
    }

    static func <(lhs: NetegramLookEntry, rhs: NetegramLookEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramLookArguments
        switch self {
        case let .contextRedesign(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramLookStrings.contextRedesignTitle, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateContextRedesign(value)
            })
        case .contextRedesignFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramLookStrings.contextRedesignFooter), sectionId: self.section)
        }
    }
}

public func netegramLookController(context: AccountContext) -> ViewController {
    let arguments = NetegramLookArguments(updateContextRedesign: { value in
        NetegramLookPreferences.shared.setContextRedesign(value)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        NetegramLookPreferences.shared.signal
    )
    |> deliverOnMainQueue
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries: [NetegramLookEntry] = [
            .contextRedesign(settings.contextRedesign),
            .contextRedesignFooter
        ]

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramLookStrings.title),
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

    return ItemListController(context: context, state: signal)
}
