import Foundation
import NetegramStore
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
    let openDiagnostics: () -> Void
    let openHideButtons: () -> Void
    let openNavBar: () -> Void
    let openLiquidGlass: () -> Void
    let openGhostCategory: (NetegramGhostCategory) -> Void
    let openLocalFeatures: () -> Void
    let openAutoFormat: () -> Void
    let openFakeActivity: () -> Void
    let openTransfer: () -> Void

    init(openDiagnostics: @escaping () -> Void, openHideButtons: @escaping () -> Void, openNavBar: @escaping () -> Void, openLiquidGlass: @escaping () -> Void, openGhostCategory: @escaping (NetegramGhostCategory) -> Void, openLocalFeatures: @escaping () -> Void, openAutoFormat: @escaping () -> Void, openFakeActivity: @escaping () -> Void, openTransfer: @escaping () -> Void) {
        self.openDiagnostics = openDiagnostics
        self.openHideButtons = openHideButtons
        self.openNavBar = openNavBar
        self.openLiquidGlass = openLiquidGlass
        self.openGhostCategory = openGhostCategory
        self.openLocalFeatures = openLocalFeatures
        self.openAutoFormat = openAutoFormat
        self.openFakeActivity = openFakeActivity
        self.openTransfer = openTransfer
    }
}

// One section per row: rows sharing a section are drawn inside a single rounded block, so
// each entry needs its own to stand apart.
private enum NetegramSettingsSection: Int32 {
    case logoHeader
    case diagnostics
    case hideButtons
    case navBar
    case liquidGlass
    case ghost
    case localFeatures
    case autoFormat
    case fakeActivity
    case transfer
}

private enum NetegramSettingsEntry: ItemListNodeEntry {
    case logoHeader(Bool)
    case diagnostics
    case hideButtons
    case navBar
    case liquidGlass
    case ghostHeader
    case ghostCategory(NetegramGhostCategory, Int)
    case localFeatures
    case autoFormat
    case fakeActivity
    case transfer

    var section: ItemListSectionId {
        switch self {
        case .logoHeader:
            return NetegramSettingsSection.logoHeader.rawValue
        case .diagnostics:
            return NetegramSettingsSection.diagnostics.rawValue
        case .hideButtons:
            return NetegramSettingsSection.hideButtons.rawValue
        case .navBar:
            return NetegramSettingsSection.navBar.rawValue
        case .liquidGlass:
            return NetegramSettingsSection.liquidGlass.rawValue
        case .ghostHeader, .ghostCategory:
            return NetegramSettingsSection.ghost.rawValue
        case .localFeatures:
            return NetegramSettingsSection.localFeatures.rawValue
        case .autoFormat:
            return NetegramSettingsSection.autoFormat.rawValue
        case .fakeActivity:
            return NetegramSettingsSection.fakeActivity.rawValue
        case .transfer:
            return NetegramSettingsSection.transfer.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .logoHeader:
            return -1
        case .diagnostics:
            return 1
        case .fakeActivity:
            return 2
        case .ghostHeader:
            return 3
        case let .ghostCategory(category, _):
            return 4 + Int32(NetegramGhostCategory.allCases.firstIndex(of: category) ?? 0)
        case .liquidGlass:
            return 11
        case .hideButtons:
            return 12
        case .navBar:
            return 13
        case .localFeatures:
            return 14
        case .autoFormat:
            return 15
        case .transfer:
            return 16
        }
    }

    static func <(lhs: NetegramSettingsEntry, rhs: NetegramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramSettingsControllerArguments
        switch self {
        case let .logoHeader(showsRevision):
            return NetegramHeaderItem(theme: presentationData.theme, showsRevision: showsRevision, sectionId: self.section)
        case .diagnostics:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramDiagnosticsStrings.title, label: "", additionalDetailLabel: NetegramDiagnosticsStrings.subtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openDiagnostics()
            })
        case .hideButtons:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramLookStrings.hideButtonsTitle, label: "", additionalDetailLabel: NetegramLookStrings.hideButtonsSubtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openHideButtons()
            })
        // On this screen the description belongs inside the cell, under the title. The
        // screens these rows lead to keep their descriptions under the block instead.
        case .liquidGlass:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramStrings.liquidGlass, label: "", additionalDetailLabel: "Жидкое стекло в интерфейсе", sectionId: self.section, style: .blocks, action: {
                arguments.openLiquidGlass()
            })
        case .navBar:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramLookStrings.navBarTitle, label: "", additionalDetailLabel: NetegramLookStrings.navBarSubtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openNavBar()
            })
        case .ghostHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: NetegramGhostStrings.title.uppercased(), sectionId: self.section)
        case let .ghostCategory(category, activeCount):
            let label = activeCount == 0 ? "Выключено" : "Включено: \(activeCount)"
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: category.title, label: "", additionalDetailLabel: label, sectionId: self.section, style: .blocks, action: {
                arguments.openGhostCategory(category)
            })
        case .localFeatures:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramLocalStrings.localFeatures, label: "", additionalDetailLabel: "Премиум, звёзды, значки", sectionId: self.section, style: .blocks, action: {
                arguments.openLocalFeatures()
            })
        case .autoFormat:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramAutoFormatStrings.title, label: "", additionalDetailLabel: NetegramAutoFormatStrings.subtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openAutoFormat()
            })
        case .fakeActivity:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramFakeStrings.title, label: "", additionalDetailLabel: NetegramFakeStrings.subtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openFakeActivity()
            })
        case .transfer:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramTransferStrings.title, label: "", additionalDetailLabel: NetegramTransferStrings.subtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openTransfer()
            })
        }
    }
}

/// "Владелец" used to unlock four more screens — Внешний вид, Фон приложения and Объявление —
/// which are gone: their settings entry was the sole way to reach or change them, so removing
/// it retires the feature rather than merely hiding it.
///
/// Режим призрака stays available either way: it is a per-device privacy setting, not an
/// owner-only extra, so it sits directly inside "Netegram" for every build — one screen tap
/// away, not nested under its own landing page.
private func netegramGhostSettingsEntries(_ ghostSettings: NetegramGhostSettings) -> [NetegramSettingsEntry] {
    return [.ghostHeader] + NetegramGhostCategory.allCases.map { category in
        .ghostCategory(category, NetegramGhostPreferences.activeCount(in: category, settings: ghostSettings))
    }
}

private func netegramSettingsEntries(isOwner: Bool, ghostSettings: NetegramGhostSettings) -> [NetegramSettingsEntry] {
    let ghostEntries = netegramGhostSettingsEntries(ghostSettings)
    guard isOwner else {
        return [.diagnostics] + ghostEntries + [.liquidGlass, .navBar]
    }
    return [.logoHeader(true), .diagnostics, .fakeActivity] + ghostEntries + [.liquidGlass, .hideButtons, .navBar, .localFeatures, .autoFormat, .transfer]
}

/// Netegram: the account this build belongs to.
///
/// Three ways to match, because none of them is reliable on its own — the peer id is empty
/// until the account loads, the username can be changed, and the phone number is hidden on
/// some accounts. Any one hit is enough.
public func netegramIsBuildOwner(peer: EnginePeer?) -> Bool {
    guard let peer else {
        return false
    }
    if peer.id.id._internalGetInt64Value() == netegramAnnouncementOwnerId {
        return true
    }
    if let username = peer.addressName, username.lowercased() == netegramOwnerUsername {
        return true
    }
    if case let .user(user) = peer, let phone = user.phone {
        if phone.filter({ $0.isNumber }) == netegramOwnerPhone {
            return true
        }
    }
    return false
}

private let netegramOwnerUsername = "detarlo"
private let netegramOwnerPhone = "79809334541"

/// Retires the three removed screens' settings, one time, so nobody who had already turned one
/// on is left stuck with it permanently active and no menu path left to switch it back off.
private func netegramRetireRemovedScreens() {
    guard !NGStore.bool(forKey: "netegram.removedScreensRetired") else {
        return
    }
    NGStore.setObject(false, forKey: netegramContextRedesignKey)
    NGStore.setObject(false, forKey: netegramRoundProfileButtonsKey)
    NGStore.setObject(0, forKey: "netegram.background.mode")
    NGStore.setObject(true, forKey: "netegram.removedScreensRetired")
}

public func netegramSettingsController(context: AccountContext) -> ViewController {
    netegramRetireRemovedScreens()

    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = NetegramSettingsControllerArguments(openDiagnostics: {
        pushControllerImpl?(netegramDiagnosticsController(context: context))
    }, openHideButtons: {
        pushControllerImpl?(netegramHideProfileButtonsController(context: context))
    }, openNavBar: {
        pushControllerImpl?(netegramNavBarController(context: context))
    }, openLiquidGlass: {
        pushControllerImpl?(netegramLiquidGlassController(context: context))
    }, openGhostCategory: { category in
        pushControllerImpl?(netegramGhostController(context: context, category: category))
    }, openLocalFeatures: {
        pushControllerImpl?(netegramLocalFeaturesController(context: context))
    }, openAutoFormat: {
        pushControllerImpl?(netegramAutoFormatController(context: context))
    }, openFakeActivity: {
        pushControllerImpl?(netegramFakeActivityController(context: context))
    }, openTransfer: {
        pushControllerImpl?(netegramTransferController(context: context))
    })

    let ownerSignal = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
    )
    |> map { peer -> Bool in
        return netegramIsBuildOwner(peer: peer)
    }
    |> distinctUntilChanged

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        ownerSignal,
        NetegramGhostPreferences.shared.signal
    )
    |> deliverOnMainQueue
    |> map { presentationData, isOwner, ghostSettings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramStrings.netegram),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: netegramSettingsEntries(isOwner: isOwner, ghostSettings: ghostSettings),
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
