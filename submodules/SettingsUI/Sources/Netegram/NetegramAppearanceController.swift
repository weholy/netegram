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

    init(updateUseOriginalLogo: @escaping (Bool) -> Void, updateCustomIcons: @escaping (Bool) -> Void) {
        self.updateUseOriginalLogo = updateUseOriginalLogo
        self.updateCustomIcons = updateCustomIcons
    }
}

private enum NetegramAppearanceSection: Int32 {
    case logo
    case customIcons
}

private enum NetegramAppearanceEntry: ItemListNodeEntry {
    case replaceLogo(Bool)
    case replaceLogoFooter
    case customIcons(Bool)
    case customIconsFooter

    var section: ItemListSectionId {
        switch self {
        case .replaceLogo, .replaceLogoFooter:
            return NetegramAppearanceSection.logo.rawValue
        case .customIcons, .customIconsFooter:
            return NetegramAppearanceSection.customIcons.rawValue
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
        }
    }
}

private func netegramAppearanceControllerEntries(useOriginalLogo: Bool, customIcons: Bool) -> [NetegramAppearanceEntry] {
    return [
        .replaceLogo(useOriginalLogo),
        .replaceLogoFooter,
        .customIcons(customIcons),
        .customIconsFooter
    ]
}

public func netegramAppearanceController(context: AccountContext) -> ViewController {
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
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        NetegramSettings.shared.useOriginalTelegramLogoSignal,
        NetegramSettings.shared.customSettingsIconsSignal
    )
    |> deliverOnMainQueue
    |> map { presentationData, useOriginalLogo, customIcons -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramStrings.appearance),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: netegramAppearanceControllerEntries(useOriginalLogo: useOriginalLogo, customIcons: customIcons),
            style: .blocks,
            animateChanges: false
        )

        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
