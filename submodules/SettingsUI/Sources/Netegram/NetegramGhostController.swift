import Foundation
import UIKit
import CoreLocation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class NetegramGhostArguments {
    let updateEnabled: (Bool) -> Void
    let updateFlag: (String, Bool) -> Void
    let updateDelaySeconds: (Int32) -> Void
    let updateDeviceName: (String) -> Void
    let pickLocation: () -> Void
    let resetLocation: () -> Void

    init(updateEnabled: @escaping (Bool) -> Void, updateFlag: @escaping (String, Bool) -> Void, updateDelaySeconds: @escaping (Int32) -> Void, updateDeviceName: @escaping (String) -> Void, pickLocation: @escaping () -> Void, resetLocation: @escaping () -> Void) {
        self.updateEnabled = updateEnabled
        self.updateFlag = updateFlag
        self.updateDelaySeconds = updateDelaySeconds
        self.updateDeviceName = updateDeviceName
        self.pickLocation = pickLocation
        self.resetLocation = resetLocation
    }
}

private enum NetegramGhostSection: Int32 {
    case master
    case presence
    case actions
    case receipts
    case extras
    case delay
    case location
    case keep
    case device
}

private enum NetegramGhostEntry: ItemListNodeEntry {
    case master(Bool)
    case masterFooter

    case alwaysOnline(Bool, Bool)
    case alwaysOnlineFooter
    case hideOnline(Bool, Bool)
    case hideOnlineFooter

    case actionsHeader
    /// Index keeps the ordering stable without one case per switch — sixteen near-identical
    /// cases would be sixteen places to keep in sync.
    case action(Int32, String, String, Bool, Bool)
    case actionsFooter

    case receiptsHeader
    case readReceipts(Bool, Bool)
    case readReceiptsFooter
    case readOnAction(Bool, Bool)
    case readOnActionFooter
    case storyViews(Bool, Bool)
    case storyViewsFooter
    case viewOnce(Bool, Bool)
    case viewOnceFooter
    case screenshots(Bool, Bool)
    case screenshotsFooter

    case delayedSend(Bool, Bool)
    case delaySeconds(Int32, Bool)
    case delayedSendFooter

    case locationHeader
    case locationEnabled(Bool, Bool)
    case locationPick(String)
    case locationReset
    case locationFooter

    case keepHeader
    case antiRevoke(Bool)
    case antiRevokeFooter
    case antiEdit(Bool)
    case antiEditFooter
    case antiAutoDelete(Bool)
    case antiAutoDeleteFooter

    case noAds(Bool)
    case noAdsFooter

    case deviceName(String)
    case deviceNameFooter

    var section: ItemListSectionId {
        switch self {
        case .master, .masterFooter:
            return NetegramGhostSection.master.rawValue
        case .alwaysOnline, .alwaysOnlineFooter, .hideOnline, .hideOnlineFooter:
            return NetegramGhostSection.presence.rawValue
        case .actionsHeader, .action, .actionsFooter:
            return NetegramGhostSection.actions.rawValue
        case .receiptsHeader, .readReceipts, .readReceiptsFooter, .readOnAction, .readOnActionFooter,
             .storyViews, .storyViewsFooter, .viewOnce, .viewOnceFooter, .screenshots, .screenshotsFooter:
            return NetegramGhostSection.receipts.rawValue
        case .delayedSend, .delaySeconds, .delayedSendFooter:
            return NetegramGhostSection.delay.rawValue
        case .locationHeader, .locationEnabled, .locationPick, .locationReset, .locationFooter:
            return NetegramGhostSection.location.rawValue
        case .keepHeader, .antiRevoke, .antiRevokeFooter, .antiEdit, .antiEditFooter, .antiAutoDelete, .antiAutoDeleteFooter:
            return NetegramGhostSection.keep.rawValue
        case .noAds, .noAdsFooter:
            return NetegramGhostSection.extras.rawValue
        case .deviceName, .deviceNameFooter:
            return NetegramGhostSection.device.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .master: return 0
        case .masterFooter: return 1
        case .alwaysOnline: return 2
        case .alwaysOnlineFooter: return 3
        case .hideOnline: return 4
        case .hideOnlineFooter: return 5
        case .actionsHeader: return 6
        // Reserves 10…99 for the action rows so later blocks never collide with them.
        case let .action(index, _, _, _, _): return 10 + index
        case .actionsFooter: return 100
        case .receiptsHeader: return 101
        case .readReceipts: return 102
        case .readReceiptsFooter: return 103
        case .readOnAction: return 104
        case .readOnActionFooter: return 105
        case .storyViews: return 106
        case .storyViewsFooter: return 107
        case .viewOnce: return 108
        case .viewOnceFooter: return 109
        case .screenshots: return 110
        case .screenshotsFooter: return 111
        case .delayedSend: return 112
        case .delaySeconds: return 113
        case .delayedSendFooter: return 114
        case .locationHeader: return 115
        case .locationEnabled: return 116
        case .locationPick: return 117
        case .locationReset: return 118
        case .locationFooter: return 119
        case .keepHeader: return 120
        case .antiRevoke: return 121
        case .antiRevokeFooter: return 122
        case .antiEdit: return 123
        case .antiEditFooter: return 124
        case .antiAutoDelete: return 125
        case .antiAutoDeleteFooter: return 126
        case .noAds: return 127
        case .noAdsFooter: return 128
        case .deviceName: return 129
        case .deviceNameFooter: return 130
        }
    }

    static func <(lhs: NetegramGhostEntry, rhs: NetegramGhostEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramGhostArguments
        switch self {
        case let .master(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.enabled, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateEnabled(value)
            })
        case .masterFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.enabledFooter), sectionId: self.section)
        case let .alwaysOnline(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.alwaysOnline, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(NetegramGhostKeys.alwaysOnline, value)
            })
        case .alwaysOnlineFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.alwaysOnlineFooter), sectionId: self.section)
        case let .hideOnline(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.hideOnline, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(NetegramGhostKeys.hideOnline, value)
            })
        case .hideOnlineFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.hideOnlineFooter), sectionId: self.section)
        case .actionsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: NetegramGhostStrings.statuses, sectionId: self.section)
        case let .action(_, key, title, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(key, value)
            })
        case .actionsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.statusesFooter), sectionId: self.section)
        case .receiptsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: NetegramGhostStrings.receipts, sectionId: self.section)
        case let .readReceipts(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.readReceipts, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(NetegramGhostKeys.readReceipts, value)
            })
        case .readReceiptsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.readReceiptsFooter), sectionId: self.section)
        case let .readOnAction(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.readOnAction, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(NetegramGhostKeys.readOnAction, value)
            })
        case .readOnActionFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.readOnActionFooter), sectionId: self.section)
        case let .storyViews(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.storyViews, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(NetegramGhostKeys.storyViews, value)
            })
        case .storyViewsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.storyViewsFooter), sectionId: self.section)
        case let .viewOnce(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.viewOnce, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(NetegramGhostKeys.viewOnce, value)
            })
        case .viewOnceFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.viewOnceFooter), sectionId: self.section)
        case let .screenshots(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.screenshots, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(NetegramGhostKeys.screenshots, value)
            })
        case .screenshotsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.screenshotsFooter), sectionId: self.section)
        case let .delayedSend(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.delayedSend, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(NetegramGhostKeys.delayedSend, value)
            })
        case let .delaySeconds(value, enabled):
            return NetegramStarsSliderItem(theme: presentationData.theme, title: "\(NetegramGhostStrings.delayedSendSeconds): \(value) с", value: Int(value), maxValue: 60, enabled: enabled, sectionId: self.section, updated: { updated in
                arguments.updateDelaySeconds(Int32(max(1, updated)))
            })
        case .delayedSendFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.delayedSendFooter), sectionId: self.section)
        case .locationHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: NetegramGhostStrings.location, sectionId: self.section)
        case let .locationEnabled(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.locationEnabled, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(NetegramGhostKeys.locationEnabled, value)
            })
        case let .locationPick(label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.locationPick, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.pickLocation()
            })
        case .locationReset:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.locationReset, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.resetLocation()
            })
        case .locationFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.locationFooter), sectionId: self.section)
        case .keepHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: NetegramGhostStrings.keep, sectionId: self.section)
        case let .antiRevoke(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.antiRevoke, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(NetegramGhostKeys.antiRevoke, value)
            })
        case .antiRevokeFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.antiRevokeFooter), sectionId: self.section)
        case let .antiEdit(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.antiEdit, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(NetegramGhostKeys.antiEdit, value)
            })
        case .antiEditFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.antiEditFooter), sectionId: self.section)
        case let .antiAutoDelete(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.antiAutoDelete, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(NetegramGhostKeys.antiAutoDelete, value)
            })
        case .antiAutoDeleteFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.antiAutoDeleteFooter), sectionId: self.section)
        case let .noAds(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.noAds, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(NetegramGhostKeys.noAds, value)
            })
        case .noAdsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.noAdsFooter), sectionId: self.section)
        case let .deviceName(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: NetegramGhostStrings.deviceName, textColor: presentationData.theme.list.itemPrimaryTextColor), text: value, placeholder: NetegramGhostStrings.deviceNamePlaceholder, type: .regular(capitalization: true, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updateDeviceName(value)
            }, action: {})
        case .deviceNameFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.deviceNameFooter), sectionId: self.section)
        }
    }
}

/// The sixteen action switches, in the order they appear. Ordered by how often they matter
/// rather than alphabetically: typing and voice come first because those are the ones people
/// notice.
private let netegramGhostActions: [(key: String, title: String)] = [
    (NetegramGhostKeys.typing, NetegramGhostStrings.typing),
    (NetegramGhostKeys.recordVoice, NetegramGhostStrings.recordVoice),
    (NetegramGhostKeys.uploadVoice, NetegramGhostStrings.uploadVoice),
    (NetegramGhostKeys.recordRound, NetegramGhostStrings.recordRound),
    (NetegramGhostKeys.uploadRound, NetegramGhostStrings.uploadRound),
    (NetegramGhostKeys.recordVideo, NetegramGhostStrings.recordVideo),
    (NetegramGhostKeys.uploadVideo, NetegramGhostStrings.uploadVideo),
    (NetegramGhostKeys.uploadPhoto, NetegramGhostStrings.uploadPhoto),
    (NetegramGhostKeys.uploadFile, NetegramGhostStrings.uploadFile),
    (NetegramGhostKeys.chooseSticker, NetegramGhostStrings.chooseSticker),
    (NetegramGhostKeys.chooseLocation, NetegramGhostStrings.chooseLocation),
    (NetegramGhostKeys.chooseContact, NetegramGhostStrings.chooseContact),
    (NetegramGhostKeys.playGame, NetegramGhostStrings.playGame),
    (NetegramGhostKeys.speaking, NetegramGhostStrings.speaking),
    (NetegramGhostKeys.emojiInteraction, NetegramGhostStrings.emojiInteraction),
    (NetegramGhostKeys.emojiSeen, NetegramGhostStrings.emojiSeen)
]

private func netegramGhostEntries(settings: NetegramGhostSettings) -> [NetegramGhostEntry] {
    // Everything except ads and the device name hangs off the master switch: those two say
    // nothing about you to anyone, so hiding them behind "ghost mode" would be surprising.
    let on = settings.enabled

    var entries: [NetegramGhostEntry] = [
        .master(settings.enabled),
        .masterFooter,
        .alwaysOnline(settings.flag(NetegramGhostKeys.alwaysOnline), on),
        .alwaysOnlineFooter,
        .hideOnline(settings.flag(NetegramGhostKeys.hideOnline), on),
        .hideOnlineFooter,
        .actionsHeader
    ]
    for (index, action) in netegramGhostActions.enumerated() {
        entries.append(.action(Int32(index), action.key, action.title, settings.flag(action.key), on))
    }
    entries.append(.actionsFooter)

    entries.append(contentsOf: [
        .receiptsHeader,
        .readReceipts(settings.flag(NetegramGhostKeys.readReceipts), on),
        .readReceiptsFooter,
        .readOnAction(settings.flag(NetegramGhostKeys.readOnAction), on && settings.flag(NetegramGhostKeys.readReceipts)),
        .readOnActionFooter,
        .storyViews(settings.flag(NetegramGhostKeys.storyViews), on),
        .storyViewsFooter,
        .viewOnce(settings.flag(NetegramGhostKeys.viewOnce), on),
        .viewOnceFooter,
        .screenshots(settings.flag(NetegramGhostKeys.screenshots), on),
        .screenshotsFooter,
        .delayedSend(settings.flag(NetegramGhostKeys.delayedSend), on),
        .delaySeconds(settings.delayedSendSeconds, on && settings.flag(NetegramGhostKeys.delayedSend)),
        .delayedSendFooter,
        .locationHeader,
        .locationEnabled(settings.flag(NetegramGhostKeys.locationEnabled), settings.hasLocation),
        .locationPick(settings.hasLocation ? String(format: "%.4f, %.4f", settings.latitude, settings.longitude) : NetegramGhostStrings.locationNotSet),
        .locationReset,
        .locationFooter,
        .keepHeader,
        .antiRevoke(settings.flag(NetegramGhostKeys.antiRevoke)),
        .antiRevokeFooter,
        .antiEdit(settings.flag(NetegramGhostKeys.antiEdit)),
        .antiEditFooter,
        .antiAutoDelete(settings.flag(NetegramGhostKeys.antiAutoDelete)),
        .antiAutoDeleteFooter,
        .noAds(settings.flag(NetegramGhostKeys.noAds)),
        .noAdsFooter,
        .deviceName(settings.deviceName),
        .deviceNameFooter
    ])

    return entries
}

public func netegramGhostController(context: AccountContext) -> ViewController {
    var presentRestartImpl: ((String) -> Void)?

    let arguments = NetegramGhostArguments(updateEnabled: { value in
        NetegramGhostPreferences.shared.setEnabled(value)
    }, updateFlag: { key, value in
        NetegramGhostPreferences.shared.setFlag(key, value: value)
        if key == NetegramGhostKeys.noAds {
            presentRestartImpl?(NetegramRestartStrings.ads)
        }
    }, updateDelaySeconds: { value in
        NetegramGhostPreferences.shared.setDelayedSendSeconds(value)
    }, updateDeviceName: { value in
        NetegramGhostPreferences.shared.setDeviceName(value)
    }, pickLocation: {
        let current = NetegramGhostPreferences.current()
        let initial = current.hasLocation ? CLLocationCoordinate2D(latitude: current.latitude, longitude: current.longitude) : nil
        netegramPresentLocationPicker(window: context.sharedContext.mainWindow, initial: initial, completion: { coordinate in
            NetegramGhostPreferences.shared.setLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        })
    }, resetLocation: {
        NetegramGhostPreferences.shared.resetLocation()
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        NetegramGhostPreferences.shared.signal
    )
    |> deliverOnMainQueue
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramGhostStrings.title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: netegramGhostEntries(settings: settings),
            style: .blocks,
            animateChanges: false
        )

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentRestartImpl = { [weak controller] text in
        netegramPresentRestartToast(context: context, controller: controller, text: text)
    }
    return controller
}
