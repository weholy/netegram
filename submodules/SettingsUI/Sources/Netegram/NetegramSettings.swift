import Foundation
import SwiftSignalKit

/// User-facing copy for the Netegram-specific screens.
///
/// These features do not exist in Telegram's server-delivered language packs, so the text
/// lives here instead of in Localizable.strings — otherwise every locale except English
/// would fall back to a missing key.
public enum NetegramStrings {
    public static let netegram = "Netegram"
    public static let liquidGlass = "Liquid Glass"
    public static let liquidGlassMessagesTitle = "Liquid Glass на сообщения"
    public static let liquidGlassMessagesFooter = "Делает пузырьки сообщений прозрачными."
    public static let liquidGlassEverywhereTitle = "Liquid Glass повсюду"
    public static let liquidGlassEverywhereFooter = "Панели, шапки, кнопки и блоки по всему приложению."
}

/// State of the Liquid Glass toggles.
///
/// A struct rather than a tuple: ValuePromise requires Equatable, and Swift tuples do not
/// conform to it however simple their elements are.
public struct NetegramLiquidGlassSettings: Equatable {
    public let messages: Bool
    public let everywhere: Bool

    public init(messages: Bool, everywhere: Bool) {
        self.messages = messages
        self.everywhere = everywhere
    }
}

/// The app icon baked into the bundle as the primary icon (Netegram artwork). There is no
/// switch back to Telegram's own branding — Netegram's blue icon is the only one shipped.
public let netegramDefaultAppIconName = "NetegramIcon"

private let liquidGlassMessagesKey = "netegram.liquidGlass.messages"
/// Mirrored in GlassBackgroundComponent, which resolves .panel to .clear when this is set.
private let liquidGlassEverywhereKey = "netegram.liquidGlass.everywhere"

/// Local, device-only Liquid Glass preferences.
///
/// Backed by UserDefaults rather than Postbox shared data: the value never syncs between
/// devices and is read during presentation, so the simpler store avoids threading a new
/// preferences key through the account schema.
public final class NetegramSettings {
    public static let shared = NetegramSettings()

    private let liquidGlassPromise: ValuePromise<NetegramLiquidGlassSettings>

    private init() {
        self.liquidGlassPromise = ValuePromise(NetegramSettings.currentLiquidGlass(), ignoreRepeated: true)
    }

    public var liquidGlassMessages: Bool {
        return UserDefaults.standard.bool(forKey: liquidGlassMessagesKey)
    }

    public var liquidGlassEverywhere: Bool {
        return UserDefaults.standard.bool(forKey: liquidGlassEverywhereKey)
    }

    public var liquidGlassSignal: Signal<NetegramLiquidGlassSettings, NoError> {
        return self.liquidGlassPromise.get()
    }

    public func setLiquidGlassMessages(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: liquidGlassMessagesKey)
        UserDefaults.standard.synchronize()
        self.pushLiquidGlass()
    }

    public func setLiquidGlassEverywhere(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: liquidGlassEverywhereKey)
        UserDefaults.standard.synchronize()
        self.pushLiquidGlass()
    }

    private func pushLiquidGlass() {
        self.liquidGlassPromise.set(NetegramSettings.currentLiquidGlass())
    }

    private static func currentLiquidGlass() -> NetegramLiquidGlassSettings {
        let defaults = UserDefaults.standard
        return NetegramLiquidGlassSettings(
            messages: defaults.bool(forKey: liquidGlassMessagesKey),
            everywhere: defaults.bool(forKey: liquidGlassEverywhereKey)
        )
    }
}
