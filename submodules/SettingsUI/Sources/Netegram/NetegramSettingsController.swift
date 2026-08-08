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
    let openSearch: () -> Void
    let openLook: () -> Void
    let openUnlock: () -> Void
    let openHideButtons: () -> Void
    let openNavBar: () -> Void
    let openAppearance: () -> Void
    let openLiquidGlass: () -> Void
    let openGhost: () -> Void
    let openLocalFeatures: () -> Void
    let openBackground: () -> Void
    let openAnnouncement: () -> Void

    init(openSearch: @escaping () -> Void, openLook: @escaping () -> Void, openUnlock: @escaping () -> Void, openHideButtons: @escaping () -> Void, openNavBar: @escaping () -> Void, openAppearance: @escaping () -> Void, openLiquidGlass: @escaping () -> Void, openGhost: @escaping () -> Void, openLocalFeatures: @escaping () -> Void, openBackground: @escaping () -> Void, openAnnouncement: @escaping () -> Void) {
        self.openSearch = openSearch
        self.openLook = openLook
        self.openUnlock = openUnlock
        self.openHideButtons = openHideButtons
        self.openNavBar = openNavBar
        self.openAppearance = openAppearance
        self.openLiquidGlass = openLiquidGlass
        self.openGhost = openGhost
        self.openLocalFeatures = openLocalFeatures
        self.openBackground = openBackground
        self.openAnnouncement = openAnnouncement
    }
}


/// Netegram: the small symbol at the left of each row on the Netegram screen.
///
/// SF Symbols rather than drawn artwork: the set already covers every idea on this screen, it
/// follows the system weight, and there is nothing to redraw when a row is renamed or added.
///
/// Drawn into a fixed box rather than handed over at its natural size. A row sizes itself to
/// the tallest thing in it, so a symbol that happens to be tall — and they vary — would make
/// its row taller than its neighbours. A constant box keeps every row the height it had
/// before the icons arrived.
///
/// Rendered as `.alwaysOriginal` because the row does not tint the image it is handed, so the
/// colour has to be baked in here.
private func netegramRowIcon(_ systemName: String, _ color: UIColor) -> UIImage? {
    let boxSize = CGSize(width: 24.0, height: 24.0)
    let configuration = UIImage.SymbolConfiguration(pointSize: 17.0, weight: .regular)
    guard let symbol = UIImage(systemName: systemName, withConfiguration: configuration)?.withTintColor(color, renderingMode: .alwaysOriginal) else {
        return nil
    }
    return UIGraphicsImageRenderer(size: boxSize).image { _ in
        let drawSize = symbol.size
        symbol.draw(in: CGRect(
            x: (boxSize.width - drawSize.width) / 2.0,
            y: (boxSize.height - drawSize.height) / 2.0,
            width: drawSize.width,
            height: drawSize.height
        ))
    }
}

// One section per row: rows sharing a section are drawn inside a single rounded block, so
// each entry needs its own to stand apart.
private enum NetegramSettingsSection: Int32 {
    case logoHeader
    case header
    case search
    case look
    case unlock
    case hideButtons
    case navBar
    case appearance
    case liquidGlass
    case ghost
    case localFeatures
    case background
    case announcement
}

private enum NetegramSettingsEntry: ItemListNodeEntry {
    case logoHeader(Bool)
    case search
    case look
    case unlock
    case hideButtons
    case navBar
    case appearance
    case liquidGlass
    case ghost
    case localFeatures
    case background
    case announcement
    case appearanceFooter

    var section: ItemListSectionId {
        switch self {
        case .logoHeader:
            return NetegramSettingsSection.logoHeader.rawValue
        case .search:
            return NetegramSettingsSection.search.rawValue
        case .look:
            return NetegramSettingsSection.look.rawValue
        case .unlock:
            return NetegramSettingsSection.unlock.rawValue
        case .hideButtons:
            return NetegramSettingsSection.hideButtons.rawValue
        case .navBar:
            return NetegramSettingsSection.navBar.rawValue
        case .appearance, .appearanceFooter:
            return NetegramSettingsSection.appearance.rawValue
        case .liquidGlass:
            return NetegramSettingsSection.liquidGlass.rawValue
        case .ghost:
            return NetegramSettingsSection.ghost.rawValue
        case .localFeatures:
            return NetegramSettingsSection.localFeatures.rawValue
        case .background:
            return NetegramSettingsSection.background.rawValue
        case .announcement:
            return NetegramSettingsSection.announcement.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .logoHeader:
            return -1
        case .search:
            return 0
        case .look:
            return 1
        case .appearance:
            return 2
        case .liquidGlass:
            return 3
        case .ghost:
            return 4
        case .hideButtons:
            return 5
        case .navBar:
            return 6
        case .localFeatures:
            return 7
        case .background:
            return 8
        case .announcement:
            return 9
        case .unlock:
            return 10
        case .appearanceFooter:
            return 11
        }
    }

    static func <(lhs: NetegramSettingsEntry, rhs: NetegramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramSettingsControllerArguments
        switch self {
        case .search:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("magnifyingglass", presentationData.theme.list.itemPrimaryTextColor), title: NetegramSearchStrings.title, label: "", additionalDetailLabel: "Найти функцию Netegram", sectionId: self.section, style: .blocks, action: {
                arguments.openSearch()
            })
        case let .logoHeader(showsRevision):
            return NetegramHeaderItem(theme: presentationData.theme, showsRevision: showsRevision, sectionId: self.section)
        case .look:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("paintbrush", presentationData.theme.list.itemPrimaryTextColor), title: NetegramLookStrings.title, label: "", additionalDetailLabel: NetegramLookStrings.subtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openLook()
            })
        case .hideButtons:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("person.crop.circle.badge.minus", presentationData.theme.list.itemPrimaryTextColor), title: NetegramLookStrings.hideButtonsTitle, label: "", additionalDetailLabel: NetegramLookStrings.hideButtonsSubtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openHideButtons()
            })
        // On this screen the description belongs inside the cell, under the title. The
        // screens these rows lead to keep their descriptions under the block instead.
        case .appearance:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("paintpalette", presentationData.theme.list.itemPrimaryTextColor), title: NetegramStrings.appearance, label: "", additionalDetailLabel: "Логотип, иконки", sectionId: self.section, style: .blocks, action: {
                arguments.openAppearance()
            })
        case .liquidGlass:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("drop", presentationData.theme.list.itemPrimaryTextColor), title: NetegramStrings.liquidGlass, label: "", additionalDetailLabel: "Жидкое стекло в интерфейсе", sectionId: self.section, style: .blocks, action: {
                arguments.openLiquidGlass()
            })
        case .navBar:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("square.grid.2x2", presentationData.theme.list.itemPrimaryTextColor), title: NetegramLookStrings.navBarTitle, label: "", additionalDetailLabel: NetegramLookStrings.navBarSubtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openNavBar()
            })
        case .ghost:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("eye.slash", presentationData.theme.list.itemPrimaryTextColor), title: NetegramGhostStrings.title, label: "", additionalDetailLabel: NetegramGhostStrings.subtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openGhost()
            })
        case .localFeatures:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("sparkles", presentationData.theme.list.itemPrimaryTextColor), title: NetegramLocalStrings.localFeatures, label: "", additionalDetailLabel: "Премиум, звёзды, эмодзи", sectionId: self.section, style: .blocks, action: {
                arguments.openLocalFeatures()
            })
        case .background:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("photo", presentationData.theme.list.itemPrimaryTextColor), title: NetegramBackgroundStrings.title, label: "", additionalDetailLabel: "Видео или фото позади экранов", sectionId: self.section, style: .blocks, action: {
                arguments.openBackground()
            })
        case .unlock:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("link", presentationData.theme.list.itemPrimaryTextColor), title: NetegramUnlockStrings.title, label: "", additionalDetailLabel: NetegramUnlockStrings.subtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openUnlock()
            })
        case .announcement:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("megaphone", presentationData.theme.list.itemPrimaryTextColor), title: NetegramAnnouncementStrings.title, label: "", additionalDetailLabel: "Плашка в списке чатов", sectionId: self.section, style: .blocks, action: {
                arguments.openAnnouncement()
            })
        case .appearanceFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramStrings.appearanceFooter), sectionId: self.section)
        }
    }
}

/// Rows offered to everyone. The rest of the screen is build-owner only — those features are
/// either unfinished or specific to how this build is put together.
/// What a fresh install shows. The header is left out: the logo and version belong to whoever
/// builds this, and a first-time user has nothing to do with them.
private let netegramPublicEntries: [NetegramSettingsEntry] = [.look, .ghost, .localFeatures]

/// Everything an unlock link adds, in the same order the owner sees them.
private let netegramUnlockedEntries: [NetegramSettingsEntry] = [.look, .liquidGlass, .ghost, .hideButtons, .navBar, .localFeatures]

private func netegramSettingsEntries(isOwner: Bool, isUnlocked: Bool) -> [NetegramSettingsEntry] {
    // The preview makes the owner take the stranger's branch, so what other people get can be
    // checked without a second account.
    guard isOwner, !NetegramUnlock.previewsAsRegularUser else {
        return isUnlocked ? netegramUnlockedEntries : netegramPublicEntries
    }
    return [.logoHeader(true), .search, .look, .appearance, .liquidGlass, .ghost, .hideButtons, .navBar, .localFeatures, .background, .unlock, .announcement]
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

public func netegramSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = NetegramSettingsControllerArguments(openSearch: {
        pushControllerImpl?(netegramSearchController(context: context))
    }, openLook: {
        pushControllerImpl?(netegramLookController(context: context))
    }, openUnlock: {
        pushControllerImpl?(netegramUnlockController(context: context))
    }, openHideButtons: {
        pushControllerImpl?(netegramHideProfileButtonsController(context: context))
    }, openNavBar: {
        pushControllerImpl?(netegramNavBarController(context: context))
    }, openAppearance: {
        pushControllerImpl?(netegramAppearanceController(context: context))
    }, openLiquidGlass: {
        pushControllerImpl?(netegramLiquidGlassController(context: context))
    }, openGhost: {
        pushControllerImpl?(netegramGhostController(context: context))
    }, openLocalFeatures: {
        pushControllerImpl?(netegramLocalFeaturesController(context: context))
    }, openBackground: {
        pushControllerImpl?(netegramBackgroundController(context: context))
    }, openAnnouncement: {
        pushControllerImpl?(netegramAnnouncementController(context: context))
    })

    let unlockSignal = NetegramUnlock.signal

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
        unlockSignal
    )
    |> deliverOnMainQueue
    |> map { presentationData, isOwner, isUnlocked -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramStrings.netegram),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: netegramSettingsEntries(isOwner: isOwner, isUnlocked: isUnlocked),
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
