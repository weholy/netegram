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
import PromptUI

public enum NetegramLocalStrings {
    public static let localFeatures = "Локальные функции"
    public static let localPremiumTitle = "Локальный премиум"
    public static let localPremiumFooter = "Премиум, виден только тебе."
    public static let localStars = "Локальные звёзды"
    public static let premiumEmojiTitle = "Премиум эмодзи в ботах"
    public static let premiumEmojiFooter = "Для разработчиков, делает локальные премиум эмодзи в ботах."
    public static let premiumEmojiRequiresPremium = "Сначала включите «Локальный премиум»."
    public static let starsHeader = "Звёзды Telegram"
    public static let changeStarBalance = "Изменить баланс звёзд"
    public static let starsAmount = "Количество звёзд"
    public static let starsCustomValue = "Своё значение"
}

private let localPremiumKey = "netegram.local.premium"
/// Mirrored in TelegramCore's PeerUtils, which cannot import this module.
private let localPremiumPeerIdKey = "netegram.local.premiumPeerId"
private let premiumEmojiInBotsKey = "netegram.local.premiumEmojiInBots"
private let localStarsEnabledKey = "netegram.local.starsEnabled"
private let localStarsAmountKey = "netegram.local.starsAmount"

/// Upper bound of the star amount slider.
public let netegramMaxLocalStars = 1_000_000

/// State of the local-feature toggles.
///
/// A struct, not a tuple: ValuePromise requires Equatable and tuples never conform.
public struct NetegramLocalFeatureSettings: Equatable {
    public let premium: Bool
    public let premiumEmojiInBots: Bool
    public let starsEnabled: Bool
    public let starsAmount: Int

    public init(premium: Bool, premiumEmojiInBots: Bool, starsEnabled: Bool, starsAmount: Int) {
        self.premium = premium
        self.premiumEmojiInBots = premiumEmojiInBots
        self.starsEnabled = starsEnabled
        self.starsAmount = starsAmount
    }
}

/// Device-local overrides that change only what this client draws.
///
/// Nothing here is sent to the server: the server remains the source of truth for the real
/// premium subscription and the real star balance, so these values cannot be spent and are
/// invisible to everyone else.
public final class NetegramLocalFeatures {
    public static let shared = NetegramLocalFeatures()

    private let promise: ValuePromise<NetegramLocalFeatureSettings>

    private init() {
        self.promise = ValuePromise(NetegramLocalFeatures.current(), ignoreRepeated: true)
    }

    public static func current() -> NetegramLocalFeatureSettings {
        let defaults = UserDefaults.standard
        return NetegramLocalFeatureSettings(
            premium: defaults.bool(forKey: localPremiumKey),
            premiumEmojiInBots: defaults.bool(forKey: premiumEmojiInBotsKey),
            starsEnabled: defaults.bool(forKey: localStarsEnabledKey),
            starsAmount: defaults.integer(forKey: localStarsAmountKey)
        )
    }

    public var signal: Signal<NetegramLocalFeatureSettings, NoError> {
        return self.promise.get()
    }

    /// True when this client should present the account as premium.
    public var isLocalPremium: Bool {
        return UserDefaults.standard.bool(forKey: localPremiumKey)
    }

    /// Premium custom emoji from bots render only while local premium is on, so the
    /// dependent toggle can never take effect on its own.
    public var rendersPremiumEmojiInBots: Bool {
        return self.isLocalPremium && UserDefaults.standard.bool(forKey: premiumEmojiInBotsKey)
    }

    /// Star balance to display, or nil to use the real one from the server.
    public var displayedStarBalance: Int? {
        guard UserDefaults.standard.bool(forKey: localStarsEnabledKey) else {
            return nil
        }
        return UserDefaults.standard.integer(forKey: localStarsAmountKey)
    }

    /// `ownPeerId` scopes the override to the signed-in account: PeerUtils compares against
    /// it so only this user is painted premium, not everyone in the contact list.
    public func setPremium(_ value: Bool, ownPeerId: Int64) {
        UserDefaults.standard.set(value, forKey: localPremiumKey)
        UserDefaults.standard.set(NSNumber(value: ownPeerId), forKey: localPremiumPeerIdKey)
        // Leaving the dependent toggle on while its prerequisite is off would show an
        // enabled switch that does nothing.
        if !value {
            UserDefaults.standard.set(false, forKey: premiumEmojiInBotsKey)
        }
        self.push()
    }

    public func setPremiumEmojiInBots(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: premiumEmojiInBotsKey)
        self.push()
    }

    public func setStarsEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: localStarsEnabledKey)
        self.push()
    }

    public func setStarsAmount(_ value: Int) {
        UserDefaults.standard.set(max(0, min(netegramMaxLocalStars, value)), forKey: localStarsAmountKey)
        self.push()
    }

    private func push() {
        self.promise.set(NetegramLocalFeatures.current())
    }
}

// MARK: - Local features screen

private final class NetegramLocalFeaturesArguments {
    let updatePremium: (Bool) -> Void
    let updatePremiumEmoji: (Bool) -> Void
    let openStars: () -> Void
    let premiumRequired: () -> Void

    init(updatePremium: @escaping (Bool) -> Void, updatePremiumEmoji: @escaping (Bool) -> Void, openStars: @escaping () -> Void, premiumRequired: @escaping () -> Void) {
        self.updatePremium = updatePremium
        self.updatePremiumEmoji = updatePremiumEmoji
        self.openStars = openStars
        self.premiumRequired = premiumRequired
    }
}

private enum NetegramLocalFeaturesSection: Int32 {
    case premium
    case stars
    case premiumEmoji
}

private enum NetegramLocalFeaturesEntry: ItemListNodeEntry {
    case premium(Bool)
    case premiumFooter
    case stars
    case premiumEmoji(value: Bool, enabled: Bool)
    case premiumEmojiFooter

    var section: ItemListSectionId {
        switch self {
        case .premium, .premiumFooter:
            return NetegramLocalFeaturesSection.premium.rawValue
        case .stars:
            return NetegramLocalFeaturesSection.stars.rawValue
        case .premiumEmoji, .premiumEmojiFooter:
            return NetegramLocalFeaturesSection.premiumEmoji.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .premium:
            return 0
        case .premiumFooter:
            return 1
        case .stars:
            return 2
        case .premiumEmoji:
            return 3
        case .premiumEmojiFooter:
            return 4
        }
    }

    static func <(lhs: NetegramLocalFeaturesEntry, rhs: NetegramLocalFeaturesEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramLocalFeaturesArguments
        switch self {
        case let .premium(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramLocalStrings.localPremiumTitle, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updatePremium(value)
            })
        case .premiumFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramLocalStrings.localPremiumFooter), sectionId: self.section)
        case .stars:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramLocalStrings.localStars, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openStars()
            })
        case let .premiumEmoji(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramLocalStrings.premiumEmojiTitle, value: value, enableInteractiveChanges: enabled, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updatePremiumEmoji(value)
            }, activatedWhileDisabled: {
                arguments.premiumRequired()
            })
        case .premiumEmojiFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramLocalStrings.premiumEmojiFooter), sectionId: self.section)
        }
    }
}

public func netegramLocalFeaturesController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentWarningImpl: (() -> Void)?

    let arguments = NetegramLocalFeaturesArguments(updatePremium: { value in
        NetegramLocalFeatures.shared.setPremium(value, ownPeerId: context.account.peerId.toInt64())
    }, updatePremiumEmoji: { value in
        NetegramLocalFeatures.shared.setPremiumEmojiInBots(value)
    }, openStars: {
        pushControllerImpl?(netegramLocalStarsController(context: context))
    }, premiumRequired: {
        presentWarningImpl?()
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        NetegramLocalFeatures.shared.signal
    )
    |> deliverOnMainQueue
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries: [NetegramLocalFeaturesEntry] = [
            .premium(settings.premium),
            .premiumFooter,
            .stars,
            .premiumEmoji(value: settings.premiumEmojiInBots, enabled: settings.premium),
            .premiumEmojiFooter
        ]

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramLocalStrings.localFeatures),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: true
        )

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentWarningImpl = { [weak controller] in
        guard let controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(
            textAlertController(context: context, title: nil, text: NetegramLocalStrings.premiumEmojiRequiresPremium, actions: [
                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
            ]),
            in: .window(.root)
        )
    }
    return controller
}

// MARK: - Local stars screen

private final class NetegramLocalStarsArguments {
    let updateEnabled: (Bool) -> Void
    let updateAmount: (Int) -> Void

    init(updateEnabled: @escaping (Bool) -> Void, updateAmount: @escaping (Int) -> Void) {
        self.updateEnabled = updateEnabled
        self.updateAmount = updateAmount
    }
}

private enum NetegramLocalStarsSection: Int32 {
    case toggle
    case amount
}

private enum NetegramLocalStarsEntry: ItemListNodeEntry {
    case header
    case toggle(Bool)
    case amount(value: Int, enabled: Bool)

    var section: ItemListSectionId {
        switch self {
        case .header, .toggle:
            return NetegramLocalStarsSection.toggle.rawValue
        case .amount:
            return NetegramLocalStarsSection.amount.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .toggle:
            return 1
        case .amount:
            return 2
        }
    }

    static func <(lhs: NetegramLocalStarsEntry, rhs: NetegramLocalStarsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramLocalStarsArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: NetegramLocalStrings.starsHeader, sectionId: self.section)
        case let .toggle(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramLocalStrings.changeStarBalance, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateEnabled(value)
            })
        case let .amount(value, enabled):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramLocalStrings.starsAmount, enabled: enabled, label: "\(value)", sectionId: self.section, style: .blocks, action: {
                arguments.updateAmount(value)
            })
        }
    }
}

public func netegramLocalStarsController(context: AccountContext) -> ViewController {
    var presentAmountInputImpl: ((Int) -> Void)?

    let arguments = NetegramLocalStarsArguments(updateEnabled: { value in
        NetegramLocalFeatures.shared.setStarsEnabled(value)
    }, updateAmount: { current in
        presentAmountInputImpl?(current)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        NetegramLocalFeatures.shared.signal
    )
    |> deliverOnMainQueue
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries: [NetegramLocalStarsEntry] = [
            .header,
            .toggle(settings.starsEnabled),
            .amount(value: settings.starsAmount, enabled: settings.starsEnabled)
        ]

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramLocalStrings.localStars),
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

    let controller = ItemListController(context: context, state: signal)
    presentAmountInputImpl = { [weak controller] current in
        guard let controller else {
            return
        }
        // Named `inputController`, not `promptController`: a local of that name would
        // shadow the function being called.
        let inputController = promptController(
            context: context,
            text: NetegramLocalStrings.starsAmount,
            value: "\(current)",
            apply: { value in
                if let value, let amount = Int(value.trimmingCharacters(in: CharacterSet.whitespaces)) {
                    NetegramLocalFeatures.shared.setStarsAmount(amount)
                }
            }
        )
        controller.present(inputController, in: .window(.root))
    }
    return controller
}
