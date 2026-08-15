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
    let openHideButtons: () -> Void
    let openNavBar: () -> Void
    let openAppearance: () -> Void
    let openLiquidGlass: () -> Void
    let openGhost: () -> Void
    let openLocalFeatures: () -> Void
    let openBackground: () -> Void
    let openTransfer: () -> Void
    let openAnnouncement: () -> Void

    init(openSearch: @escaping () -> Void, openLook: @escaping () -> Void, openHideButtons: @escaping () -> Void, openNavBar: @escaping () -> Void, openAppearance: @escaping () -> Void, openLiquidGlass: @escaping () -> Void, openGhost: @escaping () -> Void, openLocalFeatures: @escaping () -> Void, openBackground: @escaping () -> Void, openTransfer: @escaping () -> Void, openAnnouncement: @escaping () -> Void) {
        self.openSearch = openSearch
        self.openLook = openLook
        self.openHideButtons = openHideButtons
        self.openNavBar = openNavBar
        self.openAppearance = openAppearance
        self.openLiquidGlass = openLiquidGlass
        self.openGhost = openGhost
        self.openLocalFeatures = openLocalFeatures
        self.openBackground = openBackground
        self.openTransfer = openTransfer
        self.openAnnouncement = openAnnouncement
    }
}


/// Netegram: the tile at the left of each row — a white glyph on a coloured square.
///
/// Colour is what makes the rows tell each other apart: a column of identical grey symbols
/// reads as one block of text, and the eye has to fall back to reading every label. Each
/// section keeps its own hue so a row can be found by colour before it is read.
///
/// Drawn into a fixed box, because a row sizes itself to the tallest thing in it and the
/// symbols vary in height — a constant tile keeps every row the same height. Rendered flat,
/// with the colour baked in, since the row hands the image straight to a node that draws its
/// pixels and ignores any tint applied on top.
private func netegramRowIcon(_ systemName: String, _ background: UIColor) -> UIImage? {
    let tileSize = CGSize(width: 29.0, height: 29.0)
    let configuration = UIImage.SymbolConfiguration(pointSize: 15.0, weight: .semibold)
    let symbol = UIImage(systemName: systemName, withConfiguration: configuration)

    return UIGraphicsImageRenderer(size: tileSize).image { context in
        let tile = UIBezierPath(
            roundedRect: CGRect(origin: CGPoint(), size: tileSize),
            cornerRadius: 7.0
        )
        background.setFill()
        tile.fill()

        guard let symbol else {
            return
        }
        let drawSize = symbol.size
        let rect = CGRect(
            x: (tileSize.width - drawSize.width) / 2.0,
            y: (tileSize.height - drawSize.height) / 2.0,
            width: drawSize.width,
            height: drawSize.height
        )
        // The symbol contributes its shape; the white fill below contributes the colour.
        symbol.withRenderingMode(.alwaysTemplate).draw(in: rect)
        context.cgContext.setBlendMode(.sourceAtop)
        UIColor.white.setFill()
        context.cgContext.fill(rect)
    }
}

/// One hue per section, spread far enough apart to stay distinct at tile size.
private enum NetegramRowColor {
    static let search = UIColor(rgb: 0x8E8E93)
    static let look = UIColor(rgb: 0x0079FF)
    static let appearance = UIColor(rgb: 0x5856D6)
    static let ghost = UIColor(rgb: 0x1C1C1E)
    static let liquidGlass = UIColor(rgb: 0x32ADE6)
    static let hideButtons = UIColor(rgb: 0xFF9500)
    static let navBar = UIColor(rgb: 0x30B0C7)
    static let localFeatures = UIColor(rgb: 0xFFCC00)
    static let background = UIColor(rgb: 0x34C759)
    static let transfer = UIColor(rgb: 0xAF52DE)
    static let announcement = UIColor(rgb: 0xFF3B30)
}

// One section per row: rows sharing a section are drawn inside a single rounded block, so
// each entry needs its own to stand apart.
private enum NetegramSettingsSection: Int32 {
    case logoHeader
    case header
    case search
    case look
    case hideButtons
    case navBar
    case appearance
    case liquidGlass
    case ghost
    case localFeatures
    case background
    case transfer
    case announcement
}

private enum NetegramSettingsEntry: ItemListNodeEntry {
    case logoHeader(Bool)
    case search
    case look
    case hideButtons
    case navBar
    case appearance
    case liquidGlass
    case ghost
    case localFeatures
    case background
    case transfer
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
        case .transfer:
            return NetegramSettingsSection.transfer.rawValue
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
        case .ghost:
            return 3
        case .liquidGlass:
            return 4
        case .hideButtons:
            return 5
        case .navBar:
            return 6
        case .localFeatures:
            return 7
        case .background:
            return 8
        case .transfer:
            return 9
        case .announcement:
            return 10
        case .appearanceFooter:
            return 12
        }
    }

    static func <(lhs: NetegramSettingsEntry, rhs: NetegramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramSettingsControllerArguments
        switch self {
        case .search:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("magnifyingglass", NetegramRowColor.search), title: NetegramSearchStrings.title, label: "", additionalDetailLabel: "Найти функцию Netegram", sectionId: self.section, style: .blocks, action: {
                arguments.openSearch()
            })
        case let .logoHeader(showsRevision):
            return NetegramHeaderItem(theme: presentationData.theme, showsRevision: showsRevision, sectionId: self.section)
        case .look:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("paintbrush", NetegramRowColor.look), title: NetegramLookStrings.title, label: "", additionalDetailLabel: NetegramLookStrings.subtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openLook()
            })
        case .hideButtons:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("person.crop.circle.badge.minus", NetegramRowColor.hideButtons), title: NetegramLookStrings.hideButtonsTitle, label: "", additionalDetailLabel: NetegramLookStrings.hideButtonsSubtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openHideButtons()
            })
        // On this screen the description belongs inside the cell, under the title. The
        // screens these rows lead to keep their descriptions under the block instead.
        case .appearance:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("paintpalette", NetegramRowColor.appearance), title: NetegramStrings.appearance, label: "", additionalDetailLabel: "Логотип, иконки", sectionId: self.section, style: .blocks, action: {
                arguments.openAppearance()
            })
        case .liquidGlass:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("drop", NetegramRowColor.liquidGlass), title: NetegramStrings.liquidGlass, label: "", additionalDetailLabel: "Жидкое стекло в интерфейсе", sectionId: self.section, style: .blocks, action: {
                arguments.openLiquidGlass()
            })
        case .navBar:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("square.grid.2x2", NetegramRowColor.navBar), title: NetegramLookStrings.navBarTitle, label: "", additionalDetailLabel: NetegramLookStrings.navBarSubtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openNavBar()
            })
        case .ghost:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("eye.slash", NetegramRowColor.ghost), title: NetegramGhostStrings.title, label: "", additionalDetailLabel: NetegramGhostStrings.subtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openGhost()
            })
        case .localFeatures:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("sparkles", NetegramRowColor.localFeatures), title: NetegramLocalStrings.localFeatures, label: "", additionalDetailLabel: "Премиум, звёзды, эмодзи", sectionId: self.section, style: .blocks, action: {
                arguments.openLocalFeatures()
            })
        case .background:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("photo", NetegramRowColor.background), title: NetegramBackgroundStrings.title, label: "", additionalDetailLabel: "Видео или фото позади экранов", sectionId: self.section, style: .blocks, action: {
                arguments.openBackground()
            })
        case .transfer:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("arrow.up.arrow.down", NetegramRowColor.transfer), title: NetegramTransferStrings.title, label: "", additionalDetailLabel: NetegramTransferStrings.subtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openTransfer()
            })
        case .announcement:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: netegramRowIcon("megaphone", NetegramRowColor.announcement), title: NetegramAnnouncementStrings.title, label: "", additionalDetailLabel: "Плашка в списке чатов", sectionId: self.section, style: .blocks, action: {
                arguments.openAnnouncement()
            })
        case .appearanceFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramStrings.appearanceFooter), sectionId: self.section)
        }
    }
}

/// Rows offered to everyone. The rest of the screen is build-owner only — those features are
/// either unfinished or specific to how this build is put together.
/// What everyone but the owner sees. The header is left out: the logo and version belong to
/// whoever builds this, and say nothing to anyone else.
private let netegramPublicEntries: [NetegramSettingsEntry] = [.ghost, .liquidGlass, .navBar]

private func netegramSettingsEntries(isOwner: Bool) -> [NetegramSettingsEntry] {
    guard isOwner else {
        return netegramPublicEntries
    }
    return [.logoHeader(true), .search, .look, .appearance, .ghost, .liquidGlass, .hideButtons, .navBar, .localFeatures, .background, .transfer, .announcement]
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
    }, openTransfer: {
        pushControllerImpl?(netegramTransferController(context: context))
    }, openAnnouncement: {
        pushControllerImpl?(netegramAnnouncementController(context: context))
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
        ownerSignal
    )
    |> deliverOnMainQueue
    |> map { presentationData, isOwner -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramStrings.netegram),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: netegramSettingsEntries(isOwner: isOwner),
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
