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

/// Local, device-only branding preferences.
///
/// Backed by UserDefaults rather than Postbox shared data: the value never syncs between
/// devices and is read during presentation, so the simpler store avoids threading a new
/// preferences key through the account schema.
public final class NetegramSettings {
    public static let shared = NetegramSettings()

    private let valuePromise: ValuePromise<Bool>
    private let customIconsPromise: ValuePromise<Bool>

    private init() {
        self.valuePromise = ValuePromise(UserDefaults.standard.bool(forKey: useOriginalTelegramLogoKey), ignoreRepeated: true)
        self.customIconsPromise = ValuePromise(UserDefaults.standard.bool(forKey: customSettingsIconsKey), ignoreRepeated: true)
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

    /// Bundle image name for the logo shown inside the app, following the toggle.
    public var logoImageName: String {
        return self.useOriginalTelegramLogo ? "Netegram/OriginalLogo" : "Netegram/Logo"
    }
}
