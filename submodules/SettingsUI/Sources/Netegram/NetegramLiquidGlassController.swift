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

private final class NetegramLiquidGlassControllerArguments {
    let updateMessages: (Bool) -> Void
    let updateInlineButtons: (Bool) -> Void
    let updateEverywhere: (Bool) -> Void

    init(updateMessages: @escaping (Bool) -> Void, updateInlineButtons: @escaping (Bool) -> Void, updateEverywhere: @escaping (Bool) -> Void) {
        self.updateMessages = updateMessages
        self.updateInlineButtons = updateInlineButtons
        self.updateEverywhere = updateEverywhere
    }
}

private enum NetegramLiquidGlassSection: Int32 {
    case messages
    case inlineButtons
    case everywhere
}

private enum NetegramLiquidGlassEntry: ItemListNodeEntry {
    case messages(Bool)
    case messagesFooter
    case inlineButtons(Bool)
    case inlineButtonsFooter
    case everywhere(Bool)
    case everywhereFooter

    var section: ItemListSectionId {
        switch self {
        case .messages, .messagesFooter:
            return NetegramLiquidGlassSection.messages.rawValue
        case .inlineButtons, .inlineButtonsFooter:
            return NetegramLiquidGlassSection.inlineButtons.rawValue
        case .everywhere, .everywhereFooter:
            return NetegramLiquidGlassSection.everywhere.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .messages:
            return 0
        case .messagesFooter:
            return 1
        case .inlineButtons:
            return 2
        case .inlineButtonsFooter:
            return 3
        case .everywhere:
            return 4
        case .everywhereFooter:
            return 5
        }
    }

    static func <(lhs: NetegramLiquidGlassEntry, rhs: NetegramLiquidGlassEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramLiquidGlassControllerArguments
        switch self {
        case let .messages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramStrings.liquidGlassMessagesTitle, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateMessages(value)
            })
        case .messagesFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramStrings.liquidGlassMessagesFooter), sectionId: self.section)
        case let .inlineButtons(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramStrings.liquidGlassInlineTitle, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateInlineButtons(value)
            })
        case .inlineButtonsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramStrings.liquidGlassInlineFooter), sectionId: self.section)
        case let .everywhere(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramStrings.liquidGlassEverywhereTitle, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateEverywhere(value)
            })
        case .everywhereFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramStrings.liquidGlassEverywhereFooter), sectionId: self.section)
        }
    }
}

public func netegramLiquidGlassController(context: AccountContext) -> ViewController {
    let arguments = NetegramLiquidGlassControllerArguments(updateMessages: { value in
        NetegramSettings.shared.setLiquidGlassMessages(value)
    }, updateInlineButtons: { value in
        NetegramSettings.shared.setLiquidGlassInlineButtons(value)
    }, updateEverywhere: { value in
        NetegramSettings.shared.setLiquidGlassEverywhere(value)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        NetegramSettings.shared.liquidGlassSignal
    )
    |> deliverOnMainQueue
    |> map { presentationData, glass -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries: [NetegramLiquidGlassEntry] = [
            .messages(glass.messages),
            .messagesFooter,
            .inlineButtons(glass.inlineButtons),
            .inlineButtonsFooter,
            .everywhere(glass.everywhere),
            .everywhereFooter
        ]

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramStrings.liquidGlass),
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
