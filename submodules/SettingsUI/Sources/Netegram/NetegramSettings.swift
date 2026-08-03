import Foundation
import SwiftSignalKit

/// User-facing copy for the Netegram-specific screens.
///
/// These features do not exist in Telegram's server-delivered language packs, so the text
/// lives here instead of in Localizable.strings — otherwise every locale except English
/// would fall back to a missing key.
public enum NetegramStrings {
    public static let netegram = "Netegram"
    public static let appearance = "Оформление"
    public static let appearanceFooter = "Внешний вид Netegram."
    public static let replaceLogoTitle = "Заменить логотип Telegram"
    public static let replaceLogoFooter = "Заменяет логотип на оригинальный Telegram."
    public static let customIconsTitle = "Кастомные иконки в настройках"
    public static let customIconsFooter = "Заменяет на кастомные иконки."
    public static let liquidGlass = "Liquid Glass"
    public static let liquidGlassMessagesTitle = "Liquid Glass на сообщения"
    public static let liquidGlassMessagesFooter = "Делает пузырьки сообщений прозрачными."
    public static let liquidGlassInlineTitle = "Liquid Glass на Inline-кнопки в ботах"
    public static let liquidGlassInlineFooter = "Делает кнопки под сообщениями ботов прозрачными."
    public static let liquidGlassEverywhereTitle = "Liquid Glass повсюду"
    public static let liquidGlassEverywhereFooter = "Панели, шапки, кнопки и блоки по всему приложению."
}

/// State of the three Liquid Glass toggles.
///
/// A struct rather than a tuple: ValuePromise requires Equatable, and Swift tuples do not
/// conform to it however simple their elements are.
public struct NetegramLiquidGlassSettings: Equatable {
    public let messages: Bool
    public let inlineButtons: Bool
    public let everywhere: Bool

    public init(messages: Bool, inlineButtons: Bool, everywhere: Bool) {
        self.messages = messages
        self.inlineButtons = inlineButtons
        self.everywhere = everywhere
    }
}

/// The app icon baked into the bundle as the primary icon (Netegram artwork).
public let netegramDefaultAppIconName = "NetegramIcon"
/// The alternate icon carrying the original Telegram artwork. This must match the key in
/// AlternateIcons.plist ("Blue"), not the image file name ("BlueIcon").
public let netegramOriginalAppIconName = "Blue"

private let useOriginalTelegramLogoKey = "netegram.useOriginalTelegramLogo"
/// Kept in sync with the key read by PresentationResourcesSettings, which cannot import
/// this module (SettingsUI already depends on TelegramPresentationData).
private let customSettingsIconsKey = "netegram.customSettingsIcons"
private let liquidGlassMessagesKey = "netegram.liquidGlass.messages"
private let liquidGlassInlineButtonsKey = "netegram.liquidGlass.inlineButtons"
/// Mirrored in GlassBackgroundComponent, which resolves .panel to .clear when this is set.
private let liquidGlassEverywhereKey = "netegram.liquidGlass.everywhere"

/// Local, device-only branding preferences.
///
/// Backed by UserDefaults rather than Postbox shared data: the value never syncs between
/// devices and is read during presentation, so the simpler store avoids threading a new
/// preferences key through the account schema.
public final class NetegramSettings {
    public static let shared = NetegramSettings()

    private let valuePromise: ValuePromise<Bool>
    private let customIconsPromise: ValuePromise<Bool>
    private let liquidGlassPromise: ValuePromise<NetegramLiquidGlassSettings>

    private init() {
        self.valuePromise = ValuePromise(UserDefaults.standard.bool(forKey: useOriginalTelegramLogoKey), ignoreRepeated: true)
        self.customIconsPromise = ValuePromise(UserDefaults.standard.bool(forKey: customSettingsIconsKey), ignoreRepeated: true)
        self.liquidGlassPromise = ValuePromise(NetegramSettings.currentLiquidGlass(), ignoreRepeated: true)
    }

    /// When enabled, the app presents Telegram's original branding instead of Netegram's.
    public var useOriginalTelegramLogo: Bool {
        return UserDefaults.standard.bool(forKey: useOriginalTelegramLogoKey)
    }

    public var useOriginalTelegramLogoSignal: Signal<Bool, NoError> {
        return self.valuePromise.get()
    }

    public func setUseOriginalTelegramLogo(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: useOriginalTelegramLogoKey)
        self.valuePromise.set(value)
    }

    /// When enabled, the settings list uses the bundled Netegram artwork instead of the
    /// icons rendered from monochrome templates. Off by default.
    public var customSettingsIcons: Bool {
        return UserDefaults.standard.bool(forKey: customSettingsIconsKey)
    }

    public var customSettingsIconsSignal: Signal<Bool, NoError> {
        return self.customIconsPromise.get()
    }

    public func setCustomSettingsIcons(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: customSettingsIconsKey)
        self.customIconsPromise.set(value)
    }

    public var liquidGlassMessages: Bool {
        return UserDefaults.standard.bool(forKey: liquidGlassMessagesKey)
    }

    public var liquidGlassInlineButtons: Bool {
        return UserDefaults.standard.bool(forKey: liquidGlassInlineButtonsKey)
    }

    public var liquidGlassEverywhere: Bool {
        return UserDefaults.standard.bool(forKey: liquidGlassEverywhereKey)
    }

    public var liquidGlassSignal: Signal<NetegramLiquidGlassSettings, NoError> {
        return self.liquidGlassPromise.get()
    }

    public func setLiquidGlassMessages(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: liquidGlassMessagesKey)
        self.pushLiquidGlass()
    }

    public func setLiquidGlassInlineButtons(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: liquidGlassInlineButtonsKey)
        self.pushLiquidGlass()
    }

    public func setLiquidGlassEverywhere(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: liquidGlassEverywhereKey)
        self.pushLiquidGlass()
    }

    private func pushLiquidGlass() {
        self.liquidGlassPromise.set(NetegramSettings.currentLiquidGlass())
    }

    private static func currentLiquidGlass() -> NetegramLiquidGlassSettings {
        let defaults = UserDefaults.standard
        return NetegramLiquidGlassSettings(
            messages: defaults.bool(forKey: liquidGlassMessagesKey),
            inlineButtons: defaults.bool(forKey: liquidGlassInlineButtonsKey),
            everywhere: defaults.bool(forKey: liquidGlassEverywhereKey)
        )
    }

    /// Bundle image name for the logo shown inside the app, following the toggle.
    public var logoImageName: String {
        return self.useOriginalTelegramLogo ? "Netegram/OriginalLogo" : "Netegram/Logo"
    }
}
