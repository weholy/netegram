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
    let openLocalFeatures: () -> Void
    let openBackground: () -> Void
    let openAnnouncement: () -> Void

    init(openAppearance: @escaping () -> Void, openLiquidGlass: @escaping () -> Void, openLocalFeatures: @escaping () -> Void, openBackground: @escaping () -> Void, openAnnouncement: @escaping () -> Void) {
        self.openAppearance = openAppearance
        self.openLiquidGlass = openLiquidGlass
        self.openLocalFeatures = openLocalFeatures
        self.openBackground = openBackground
        self.openAnnouncement = openAnnouncement
    }
}

private enum NetegramSettingsSection: Int32 {
    case appearance
}

private enum NetegramSettingsEntry: ItemListNodeEntry {
    case appearance
    case liquidGlass
    case localFeatures
    case background
    case announcement
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
        case .localFeatures:
            return 2
        case .background:
            return 3
        case .announcement:
            return 4
        case .appearanceFooter:
            return 5
        }
    }

    static func <(lhs: NetegramSettingsEntry, rhs: NetegramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramSettingsControllerArguments
        switch self {
        // On this screen the description belongs inside the cell, under the title. The
        // screens these rows lead to keep their descriptions under the block instead.
        case .appearance:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramStrings.appearance, label: "", additionalDetailLabel: "Логотип, иконки", sectionId: self.section, style: .blocks, action: {
                arguments.openAppearance()
            })
        case .liquidGlass:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramStrings.liquidGlass, label: "", additionalDetailLabel: "Жидкое стекло в интерфейсе", sectionId: self.section, style: .blocks, action: {
                arguments.openLiquidGlass()
            })
        case .localFeatures:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramLocalStrings.localFeatures, label: "", additionalDetailLabel: "Премиум, звёзды, эмодзи", sectionId: self.section, style: .blocks, action: {
                arguments.openLocalFeatures()
            })
        case .background:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramBackgroundStrings.title, label: "", additionalDetailLabel: "Видео или фото позади экранов", sectionId: self.section, style: .blocks, action: {
                arguments.openBackground()
            })
        case .announcement:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramAnnouncementStrings.title, label: "", additionalDetailLabel: "Плашка в списке чатов", sectionId: self.section, style: .blocks, action: {
                arguments.openAnnouncement()
            })
        case .appearanceFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramStrings.appearanceFooter), sectionId: self.section)
        }
    }
}

private func netegramSettingsEntries(isAnnouncementOwner: Bool) -> [NetegramSettingsEntry] {
    var entries: [NetegramSettingsEntry] = [.appearance, .liquidGlass, .localFeatures, .background]
    if isAnnouncementOwner {
        entries.append(.announcement)
    }
    return entries
}

public func netegramSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = NetegramSettingsControllerArguments(openAppearance: {
        pushControllerImpl?(netegramAppearanceController(context: context))
    }, openLiquidGlass: {
        pushControllerImpl?(netegramLiquidGlassController(context: context))
    }, openLocalFeatures: {
        pushControllerImpl?(netegramLocalFeaturesController(context: context))
    }, openBackground: {
        pushControllerImpl?(netegramBackgroundController(context: context))
    }, openAnnouncement: {
        pushControllerImpl?(netegramAnnouncementController(context: context))
    })

    // The announcement editor is only offered to the build owner.
    let isAnnouncementOwner = context.account.peerId.id._internalGetInt64Value() == netegramAnnouncementOwnerId

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
            entries: netegramSettingsEntries(isAnnouncementOwner: isAnnouncementOwner),
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
