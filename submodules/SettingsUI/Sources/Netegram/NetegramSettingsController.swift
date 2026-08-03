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

private final class NetegramSettingsControllerArguments {
    let openAppearance: () -> Void
    let openLiquidGlass: () -> Void

    init(openAppearance: @escaping () -> Void, openLiquidGlass: @escaping () -> Void) {
        self.openAppearance = openAppearance
        self.openLiquidGlass = openLiquidGlass
    }
}

private enum NetegramSettingsSection: Int32 {
    case appearance
}

private enum NetegramSettingsEntry: ItemListNodeEntry {
    case appearance
    case liquidGlass
    case appearanceFooter

    var section: ItemListSectionId {
        return NetegramSettingsSection.appearance.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .appearance:
            return 0
        case .liquidGlass:
            return 1
        case .appearanceFooter:
            return 2
        }
    }

    static func <(lhs: NetegramSettingsEntry, rhs: NetegramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramSettingsControllerArguments
        switch self {
        case .appearance:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramStrings.appearance, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openAppearance()
            })
        case .liquidGlass:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramStrings.liquidGlass, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openLiquidGlass()
            })
        case .appearanceFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramStrings.appearanceFooter), sectionId: self.section)
        }
    }
}

public func netegramSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = NetegramSettingsControllerArguments(openAppearance: {
        pushControllerImpl?(netegramAppearanceController(context: context))
    }, openLiquidGlass: {
        pushControllerImpl?(netegramLiquidGlassController(context: context))
    })

    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramStrings.netegram),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: [.appearance, .liquidGlass, .appearanceFooter] as [NetegramSettingsEntry],
            style: .blocks,
            animateChanges: false
        )

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
