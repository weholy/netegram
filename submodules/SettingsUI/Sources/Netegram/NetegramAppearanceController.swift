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

private final class NetegramAppearanceControllerArguments {
    let updateUseOriginalLogo: (Bool) -> Void
    let updateCustomIcons: (Bool) -> Void
    let updateContextRedesign: (Bool) -> Void

    init(updateUseOriginalLogo: @escaping (Bool) -> Void, updateCustomIcons: @escaping (Bool) -> Void, updateContextRedesign: @escaping (Bool) -> Void) {
        self.updateUseOriginalLogo = updateUseOriginalLogo
        self.updateCustomIcons = updateCustomIcons
        self.updateContextRedesign = updateContextRedesign
    }
}

private enum NetegramAppearanceSection: Int32 {
    case logo
    case customIcons
    case contextRedesign
}

private enum NetegramAppearanceEntry: ItemListNodeEntry {
    case replaceLogo(Bool)
    case replaceLogoFooter
    case customIcons(Bool)
    case customIconsFooter
    case contextRedesign(Bool)
    case contextRedesignFooter

    var section: ItemListSectionId {
        switch self {
        case .replaceLogo, .replaceLogoFooter:
            return NetegramAppearanceSection.logo.rawValue
        case .customIcons, .customIconsFooter:
            return NetegramAppearanceSection.customIcons.rawValue
        case .contextRedesign, .contextRedesignFooter:
            return NetegramAppearanceSection.contextRedesign.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .replaceLogo:
            return 0
        case .replaceLogoFooter:
            return 1
        case .customIcons:
            return 2
        case .customIconsFooter:
            return 3
        case .contextRedesign:
            return 4
        case .contextRedesignFooter:
            return 5
        }
    }

    static func <(lhs: NetegramAppearanceEntry, rhs: NetegramAppearanceEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramAppearanceControllerArguments
        switch self {
        case let .replaceLogo(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramStrings.replaceLogoTitle, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateUseOriginalLogo(value)
            })
        case .replaceLogoFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramStrings.replaceLogoFooter), sectionId: self.section)
        case let .customIcons(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramStrings.customIconsTitle, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateCustomIcons(value)
            })
        case .customIconsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramStrings.customIconsFooter), sectionId: self.section)
        case let .contextRedesign(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramLookStrings.contextRedesignTitle, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateContextRedesign(value)
            })
        case .contextRedesignFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramLookStrings.contextRedesignFooter), sectionId: self.section)
        }
    }
}

private func netegramAppearanceControllerEntries(useOriginalLogo: Bool, customIcons: Bool, contextRedesign: Bool) -> [NetegramAppearanceEntry] {
    return [
        .replaceLogo(useOriginalLogo),
        .replaceLogoFooter,
        .customIcons(customIcons),
        .customIconsFooter,
        .contextRedesign(contextRedesign),
        .contextRedesignFooter
    ]
}

public func netegramAppearanceController(context: AccountContext) -> ViewController {
    var presentRestartImpl: (() -> Void)?

    let arguments = NetegramAppearanceControllerArguments(updateUseOriginalLogo: { value in
        NetegramSettings.shared.setUseOriginalTelegramLogo(value)

        // Netegram's artwork is the bundle's primary icon, so restoring it means clearing
        // the alternate icon rather than naming one. iOS shows its own confirmation alert
        // on every change; that is unavoidable with this API.
        let iconName: String? = value ? netegramOriginalAppIconName : nil
        context.sharedContext.applicationBindings.requestSetAlternateIconName(iconName, { _ in
        })
    }, updateCustomIcons: { value in
        NetegramSettings.shared.setCustomSettingsIcons(value)
        // The rendered icons are memoised, so the cache has to be dropped for the settings
        // list to pick up the other set.
        netegramInvalidateSettingsIconCache()
    }, updateContextRedesign: { value in
        NetegramLookPreferences.shared.setContextRedesign(value)
        presentRestartImpl?()
    })

    // Mirrored from the "Внешний вид" screen: both write the same preference, so the switch
    // reads the same way wherever it is shown.
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        NetegramSettings.shared.useOriginalTelegramLogoSignal,
        NetegramSettings.shared.customSettingsIconsSignal,
        NetegramLookPreferences.shared.signal
    )
    |> deliverOnMainQueue
    |> map { presentationData, useOriginalLogo, customIcons, lookSettings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramStrings.appearance),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: netegramAppearanceControllerEntries(useOriginalLogo: useOriginalLogo, customIcons: customIcons, contextRedesign: lookSettings.contextRedesign),
            style: .blocks,
            animateChanges: false
        )

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentRestartImpl = { [weak controller] in
        netegramPresentRestartToast(context: context, controller: controller, text: NetegramRestartStrings.contextMenu)
    }
    return controller
}
