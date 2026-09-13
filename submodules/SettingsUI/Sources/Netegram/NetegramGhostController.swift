import Foundation
import UIKit
import CoreLocation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class NetegramGhostArguments {
    let updateFlag: (String, Bool) -> Void
    let updateDelaySeconds: (Int32) -> Void
    let updateDeviceName: (String) -> Void
    let updateSystemVersion: (String) -> Void
    let updateLangCode: (String) -> Void
    let pickLocation: () -> Void
    let resetLocation: () -> Void
    let openPrimaryPeerList: () -> Void
    let openSecondaryPeerList: () -> Void
    let updateScheduleStart: (NetegramGhostScheduleSlot, String) -> Void
    let updateScheduleEnd: (NetegramGhostScheduleSlot, String) -> Void

    init(updateFlag: @escaping (String, Bool) -> Void, updateDelaySeconds: @escaping (Int32) -> Void, updateDeviceName: @escaping (String) -> Void, updateSystemVersion: @escaping (String) -> Void, updateLangCode: @escaping (String) -> Void, pickLocation: @escaping () -> Void, resetLocation: @escaping () -> Void, openPrimaryPeerList: @escaping () -> Void, openSecondaryPeerList: @escaping () -> Void, updateScheduleStart: @escaping (NetegramGhostScheduleSlot, String) -> Void, updateScheduleEnd: @escaping (NetegramGhostScheduleSlot, String) -> Void) {
        self.updateFlag = updateFlag
        self.updateDelaySeconds = updateDelaySeconds
        self.updateDeviceName = updateDeviceName
        self.updateSystemVersion = updateSystemVersion
        self.updateLangCode = updateLangCode
        self.pickLocation = pickLocation
        self.resetLocation = resetLocation
        self.openPrimaryPeerList = openPrimaryPeerList
        self.openSecondaryPeerList = openSecondaryPeerList
        self.updateScheduleStart = updateScheduleStart
        self.updateScheduleEnd = updateScheduleEnd
    }
}

/// Every switch gets its own section, so it is drawn as its own rounded block with the
/// explanation underneath it rather than crowded together with unrelated settings.
///
/// Sections for the plain toggle rows are numbered from the row's position within the current
/// category (`netegramGhostEntries` filters `netegramGhostRows` down to one category before
/// building entries); the extras that follow take fixed numbers above them. A category screen
/// only ever shows the extras relevant to it, so the unused slots below cost nothing.
private enum NetegramGhostSection {
    static let extraBase: Int32 = 1000
}

public enum NetegramGhostPeerListSlot: Equatable {
    case primary
    case secondary
}

public enum NetegramGhostScheduleSlot: Equatable {
    case alwaysOnline
    case hideOnline
}

private enum NetegramGhostEntry: ItemListNodeEntry {
    /// index (local to the current category), key, title, value, enabled
    case toggle(Int32, String, String, Bool, Bool)
    /// index, footer text
    case toggleFooter(Int32, String)

    case delaySeconds(Int32, Bool)
    case locationPick(String)
    case locationReset
    case deviceName(String)
    case deviceNameFooter
    case systemVersion(String)
    case systemVersionFooter
    case langCode(String)
    case langCodeFooter

    case peerListPick(NetegramGhostPeerListSlot, String, Int)
    case peerListFooter(NetegramGhostPeerListSlot, String)

    case scheduleToggle(NetegramGhostScheduleSlot, String, Bool)
    case scheduleFooter(NetegramGhostScheduleSlot, String)
    case scheduleStart(NetegramGhostScheduleSlot, String)
    case scheduleEnd(NetegramGhostScheduleSlot, String)

    var section: ItemListSectionId {
        switch self {
        case let .toggle(index, _, _, _, _), let .toggleFooter(index, _):
            return ItemListSectionId(index)
        case .delaySeconds:
            return ItemListSectionId(NetegramGhostSection.extraBase)
        case .locationPick, .locationReset:
            return ItemListSectionId(NetegramGhostSection.extraBase + 1)
        case .deviceName, .deviceNameFooter:
            return ItemListSectionId(NetegramGhostSection.extraBase + 2)
        case .systemVersion, .systemVersionFooter:
            return ItemListSectionId(NetegramGhostSection.extraBase + 3)
        case .langCode, .langCodeFooter:
            return ItemListSectionId(NetegramGhostSection.extraBase + 4)
        case .peerListPick(.primary, _, _), .peerListFooter(.primary, _):
            return ItemListSectionId(NetegramGhostSection.extraBase + 5)
        case .peerListPick(.secondary, _, _), .peerListFooter(.secondary, _):
            return ItemListSectionId(NetegramGhostSection.extraBase + 6)
        case .scheduleToggle(.alwaysOnline, _, _), .scheduleFooter(.alwaysOnline, _), .scheduleStart(.alwaysOnline, _), .scheduleEnd(.alwaysOnline, _):
            return ItemListSectionId(NetegramGhostSection.extraBase + 7)
        case .scheduleToggle(.hideOnline, _, _), .scheduleFooter(.hideOnline, _), .scheduleStart(.hideOnline, _), .scheduleEnd(.hideOnline, _):
            return ItemListSectionId(NetegramGhostSection.extraBase + 8)
        }
    }

    var stableId: Int32 {
        switch self {
        // Two slots per row: the switch and the text under it.
        case let .toggle(index, _, _, _, _):
            return index * 2
        case let .toggleFooter(index, _):
            return index * 2 + 1
        case .delaySeconds:
            return NetegramGhostSection.extraBase
        case .locationPick:
            return NetegramGhostSection.extraBase + 1
        case .locationReset:
            return NetegramGhostSection.extraBase + 2
        case .deviceName:
            return NetegramGhostSection.extraBase + 3
        case .deviceNameFooter:
            return NetegramGhostSection.extraBase + 4
        case .systemVersion:
            return NetegramGhostSection.extraBase + 5
        case .systemVersionFooter:
            return NetegramGhostSection.extraBase + 6
        case .langCode:
            return NetegramGhostSection.extraBase + 7
        case .langCodeFooter:
            return NetegramGhostSection.extraBase + 8
        case .peerListPick(.primary, _, _):
            return NetegramGhostSection.extraBase + 9
        case .peerListFooter(.primary, _):
            return NetegramGhostSection.extraBase + 10
        case .peerListPick(.secondary, _, _):
            return NetegramGhostSection.extraBase + 11
        case .peerListFooter(.secondary, _):
            return NetegramGhostSection.extraBase + 12
        case .scheduleToggle(.alwaysOnline, _, _):
            return NetegramGhostSection.extraBase + 13
        case .scheduleFooter(.alwaysOnline, _):
            return NetegramGhostSection.extraBase + 14
        case .scheduleStart(.alwaysOnline, _):
            return NetegramGhostSection.extraBase + 15
        case .scheduleEnd(.alwaysOnline, _):
            return NetegramGhostSection.extraBase + 16
        case .scheduleToggle(.hideOnline, _, _):
            return NetegramGhostSection.extraBase + 17
        case .scheduleFooter(.hideOnline, _):
            return NetegramGhostSection.extraBase + 18
        case .scheduleStart(.hideOnline, _):
            return NetegramGhostSection.extraBase + 19
        case .scheduleEnd(.hideOnline, _):
            return NetegramGhostSection.extraBase + 20
        }
    }

    static func <(lhs: NetegramGhostEntry, rhs: NetegramGhostEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramGhostArguments
        switch self {
        case let .toggle(_, key, title, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(key, value)
            })
        case let .toggleFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .delaySeconds(value, enabled):
            return NetegramStarsSliderItem(theme: presentationData.theme, title: "\(NetegramGhostStrings.delayedSendSeconds): \(value) с", value: Int(value), maxValue: 60, enabled: enabled, sectionId: self.section, updated: { updated in
                arguments.updateDelaySeconds(Int32(max(1, updated)))
            })
        case let .locationPick(label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.locationPick, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.pickLocation()
            })
        case .locationReset:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: NetegramGhostStrings.locationReset, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.resetLocation()
            })
        case let .deviceName(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: NetegramGhostStrings.deviceName, textColor: presentationData.theme.list.itemPrimaryTextColor), text: value, placeholder: NetegramGhostStrings.deviceNamePlaceholder, type: .regular(capitalization: true, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updateDeviceName(value)
            }, action: {})
        case .deviceNameFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.deviceNameFooter), sectionId: self.section)
        case let .systemVersion(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: NetegramGhostStrings.systemVersionTitle, textColor: presentationData.theme.list.itemPrimaryTextColor), text: value, placeholder: NetegramGhostStrings.systemVersionPlaceholder, type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updateSystemVersion(value)
            }, action: {})
        case .systemVersionFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.systemVersionFooter), sectionId: self.section)
        case let .langCode(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: NetegramGhostStrings.langCodeTitle, textColor: presentationData.theme.list.itemPrimaryTextColor), text: value, placeholder: NetegramGhostStrings.langCodePlaceholder, type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updateLangCode(value)
            }, action: {})
        case .langCodeFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramGhostStrings.langCodeFooter), sectionId: self.section)
        case let .peerListPick(slot, title, count):
            let label = count == 0 ? NetegramGhostStrings.exceptionsCountEmpty : "\(count)"
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                switch slot {
                case .primary:
                    arguments.openPrimaryPeerList()
                case .secondary:
                    arguments.openSecondaryPeerList()
                }
            })
        case let .peerListFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .scheduleToggle(slot, title, value):
            let key: String
            switch slot {
            case .alwaysOnline:
                key = NetegramGhostKeys.scheduleAlwaysOnlineEnabled
            case .hideOnline:
                key = NetegramGhostKeys.scheduleHideOnlineEnabled
            }
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFlag(key, value)
            })
        case let .scheduleFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .scheduleStart(slot, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: NetegramGhostStrings.scheduleFrom, textColor: presentationData.theme.list.itemPrimaryTextColor), text: value, placeholder: "00:00", type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updateScheduleStart(slot, value)
            }, action: {})
        case let .scheduleEnd(slot, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: NetegramGhostStrings.scheduleTo, textColor: presentationData.theme.list.itemPrimaryTextColor), text: value, placeholder: "00:00", type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updateScheduleEnd(slot, value)
            }, action: {})
        }
    }
}

/// Formats minutes-since-midnight the way MTGhostIsWithinSchedule stores them, back into
/// "HH:MM" for display. Wraps defensively — a value outside 0..1439 cannot occur through this
/// screen's own editor, but a value written by hand into an imported settings file could.
private func netegramFormatTimeOfDay(_ minutes: Int32) -> String {
    let wrapped = ((minutes % 1440) + 1440) % 1440
    return String(format: "%02d:%02d", wrapped / 60, wrapped % 60)
}

/// The inverse of the formatter above. Returns nil on anything that is not a valid HH:MM, so a
/// bad keystroke leaves the stored value untouched instead of corrupting it.
private func netegramParseTimeOfDay(_ text: String) -> Int32? {
    let parts = text.split(separator: ":")
    guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]), hours >= 0, hours < 24, minutes >= 0, minutes < 60 else {
        return nil
    }
    return Int32(hours * 60 + minutes)
}

/// Opens Telegram's own chat picker and hands back what was chosen.
///
/// Channels and bots are excluded: a channel has no single person to be exempt for, and a bot
/// does not look at typing indicators or read marks. Contacts stay in, since those are exactly
/// who these lists exist for. Mirrors NetegramFakeActivityController's picker of the same shape.
private func netegramGhostPresentPeerPicker(context: AccountContext, selected: [Int64], title: String, parentController: ViewController, completion: @escaping ([Int64]) -> Void) {
    let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(
        context: context,
        mode: .chatSelection(ContactMultiselectionControllerMode.ChatSelection(
            title: title,
            searchPlaceholder: NetegramGhostStrings.choosePeersPlaceholder,
            selectedChats: Set(selected.map { PeerId($0) }),
            additionalCategories: ContactMultiselectionControllerAdditionalCategories(categories: [], selectedCategories: Set()),
            chatListFilters: nil,
            onlyUsers: false,
            disableChannels: true,
            disableBots: true,
            disableContacts: false
        ))
    ))

    let _ = (controller.result
    |> take(1)
    |> deliverOnMainQueue).start(next: { [weak controller] result in
        var peerIds: [ContactListPeerId] = []
        if case let .result(peerIdsValue, _) = result {
            peerIds = peerIdsValue
        }
        completion(peerIds.compactMap { entry -> Int64? in
            if case let .peer(value) = entry {
                return value.toInt64()
            }
            return nil
        })
        controller?.dismiss()
    })

    parentController.push(controller)
}

/// Builds the rows for one category: the plain toggles that belong to it, plus whatever extras
/// that category carries (a slider, a map point, text fields, peer-list pickers, schedules).
/// Extras are recognised by the key of the row they follow, the same way the single unified
/// screen picked them out before categories existed.
private func netegramGhostEntries(settings: NetegramGhostSettings, category: NetegramGhostCategory) -> [NetegramGhostEntry] {
    var entries: [NetegramGhostEntry] = []
    let rows = netegramGhostRows.filter { $0.category == category }

    for (index, row) in rows.enumerated() {
        // "Читать при действиях" refines the switch above it and means nothing on its own.
        let enabled: Bool
        if row.key == NetegramGhostKeys.readOnAction {
            enabled = settings.flag(NetegramGhostKeys.readReceipts)
        } else {
            enabled = true
        }
        entries.append(.toggle(Int32(index), row.key, row.title, settings.flag(row.key), enabled))

        // The controls a switch owns sit right after it, ahead of the explanation, so it is
        // obvious which switch they belong to.
        if row.key == NetegramGhostKeys.delayedSend {
            entries.append(.delaySeconds(settings.delayedSendSeconds, settings.flag(NetegramGhostKeys.delayedSend)))
        } else if row.key == NetegramGhostKeys.locationEnabled {
            entries.append(.locationPick(settings.hasLocation ? String(format: "%.4f, %.4f", settings.latitude, settings.longitude) : NetegramGhostStrings.locationNotSet))
            if settings.hasLocation {
                entries.append(.locationReset)
            }
        }

        entries.append(.toggleFooter(Int32(index), row.footer))
    }

    if category == .identitySpoof {
        entries.append(.deviceName(settings.deviceName))
        entries.append(.deviceNameFooter)
        entries.append(.systemVersion(settings.systemVersion))
        entries.append(.systemVersionFooter)
        entries.append(.langCode(settings.langCode))
        entries.append(.langCodeFooter)
    }

    if let primary = netegramPeerListRow(forCategory: category) {
        entries.append(.peerListPick(.primary, primary.title, settings.peerList(primary.key).count))
        entries.append(.peerListFooter(.primary, primary.footer))
    }
    if let secondary = netegramSecondaryPeerListRow(forCategory: category) {
        entries.append(.peerListPick(.secondary, secondary.title, settings.peerList(secondary.key).count))
        entries.append(.peerListFooter(.secondary, secondary.footer))
    }

    if category == .presence {
        entries.append(.scheduleToggle(.alwaysOnline, NetegramGhostStrings.scheduleAlwaysOnlineTitle, settings.flags[NetegramGhostKeys.scheduleAlwaysOnlineEnabled] ?? false))
        entries.append(.scheduleFooter(.alwaysOnline, NetegramGhostStrings.scheduleAlwaysOnlineFooter))
        entries.append(.scheduleStart(.alwaysOnline, netegramFormatTimeOfDay(settings.scheduleAlwaysOnlineStart)))
        entries.append(.scheduleEnd(.alwaysOnline, netegramFormatTimeOfDay(settings.scheduleAlwaysOnlineEnd)))

        entries.append(.scheduleToggle(.hideOnline, NetegramGhostStrings.scheduleHideOnlineTitle, settings.flags[NetegramGhostKeys.scheduleHideOnlineEnabled] ?? false))
        entries.append(.scheduleFooter(.hideOnline, NetegramGhostStrings.scheduleHideOnlineFooter))
        entries.append(.scheduleStart(.hideOnline, netegramFormatTimeOfDay(settings.scheduleHideOnlineStart)))
        entries.append(.scheduleEnd(.hideOnline, netegramFormatTimeOfDay(settings.scheduleHideOnlineEnd)))
    }

    return entries
}

public func netegramGhostController(context: AccountContext, category: NetegramGhostCategory) -> ViewController {
    var presentPeerPickerImpl: ((String, [Int64], @escaping ([Int64]) -> Void) -> Void)?

    let arguments = NetegramGhostArguments(updateFlag: { key, value in
        NetegramGhostPreferences.shared.setFlag(key, value: value)
    }, updateDelaySeconds: { value in
        NetegramGhostPreferences.shared.setDelayedSendSeconds(value)
    }, updateDeviceName: { value in
        NetegramGhostPreferences.shared.setDeviceName(value)
    }, updateSystemVersion: { value in
        NetegramGhostPreferences.shared.setSystemVersion(value)
    }, updateLangCode: { value in
        NetegramGhostPreferences.shared.setLangCode(value)
    }, pickLocation: {
        let current = NetegramGhostPreferences.current()
        let initial = current.hasLocation ? CLLocationCoordinate2D(latitude: current.latitude, longitude: current.longitude) : nil
        netegramPresentLocationPicker(window: context.sharedContext.mainWindow, initial: initial, completion: { coordinate in
            NetegramGhostPreferences.shared.setLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        })
    }, resetLocation: {
        NetegramGhostPreferences.shared.resetLocation()
    }, openPrimaryPeerList: {
        guard let row = netegramPeerListRow(forCategory: category) else { return }
        presentPeerPickerImpl?(row.title, NetegramGhostPreferences.current().peerList(row.key), { peerIds in
            NetegramGhostPreferences.shared.setPeerList(row.key, peerIds: peerIds)
        })
    }, openSecondaryPeerList: {
        guard let row = netegramSecondaryPeerListRow(forCategory: category) else { return }
        presentPeerPickerImpl?(row.title, NetegramGhostPreferences.current().peerList(row.key), { peerIds in
            NetegramGhostPreferences.shared.setPeerList(row.key, peerIds: peerIds)
        })
    }, updateScheduleStart: { slot, text in
        guard let minutes = netegramParseTimeOfDay(text) else { return }
        let current = NetegramGhostPreferences.current()
        switch slot {
        case .alwaysOnline:
            NetegramGhostPreferences.shared.setScheduleWindow(startKey: NetegramGhostKeys.scheduleAlwaysOnlineStart, endKey: NetegramGhostKeys.scheduleAlwaysOnlineEnd, startMinutes: minutes, endMinutes: current.scheduleAlwaysOnlineEnd)
        case .hideOnline:
            NetegramGhostPreferences.shared.setScheduleWindow(startKey: NetegramGhostKeys.scheduleHideOnlineStart, endKey: NetegramGhostKeys.scheduleHideOnlineEnd, startMinutes: minutes, endMinutes: current.scheduleHideOnlineEnd)
        }
    }, updateScheduleEnd: { slot, text in
        guard let minutes = netegramParseTimeOfDay(text) else { return }
        let current = NetegramGhostPreferences.current()
        switch slot {
        case .alwaysOnline:
            NetegramGhostPreferences.shared.setScheduleWindow(startKey: NetegramGhostKeys.scheduleAlwaysOnlineStart, endKey: NetegramGhostKeys.scheduleAlwaysOnlineEnd, startMinutes: current.scheduleAlwaysOnlineStart, endMinutes: minutes)
        case .hideOnline:
            NetegramGhostPreferences.shared.setScheduleWindow(startKey: NetegramGhostKeys.scheduleHideOnlineStart, endKey: NetegramGhostKeys.scheduleHideOnlineEnd, startMinutes: current.scheduleHideOnlineStart, endMinutes: minutes)
        }
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        NetegramGhostPreferences.shared.signal
    )
    |> deliverOnMainQueue
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(category.title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: netegramGhostEntries(settings: settings, category: category),
            style: .blocks,
            animateChanges: false
        )

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentPeerPickerImpl = { [weak controller] title, selected, completion in
        guard let controller else {
            return
        }
        netegramGhostPresentPeerPicker(context: context, selected: selected, title: title, parentController: controller, completion: completion)
    }
    return controller
}
