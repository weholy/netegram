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
    public static let liquidGlassInlineButtonsTitle = "Liquid Glass на кнопки ботов"
    public static let liquidGlassInlineButtonsFooter = "Кнопки под сообщениями ботов становятся стеклянными вместо размытых."
    public static let liquidGlassInputPanelTitle = "Liquid Glass на поле ввода"
    public static let liquidGlassInputPanelFooter = "Поле ввода сообщения и кнопки рядом с ним становятся стеклянными."
    public static let liquidGlassHeaderTitle = "Liquid Glass на список чатов"
    public static let liquidGlassHeaderFooter = "Кнопки в шапке списка чатов становятся стеклянными."
    public static let liquidGlassTabBarTitle = "Liquid Glass на нижнюю панель"
    public static let liquidGlassTabBarFooter = "Панель вкладок внизу экрана становится стеклянной."
    public static let liquidGlassEverywhereTitle = "Liquid Glass повсюду"
    public static let liquidGlassEverywhereFooter = "Панели, шапки, кнопки и блоки по всему приложению — включает в себя все переключатели выше."
}

/// State of the Liquid Glass toggles.
///
/// A struct rather than a tuple: ValuePromise requires Equatable, and Swift tuples do not
/// conform to it however simple their elements are.
public struct NetegramLiquidGlassSettings: Equatable {
    public let messages: Bool
    public let inlineButtons: Bool
    public let inputPanel: Bool
    public let header: Bool
    public let tabBar: Bool
    public let everywhere: Bool

    public init(messages: Bool, inlineButtons: Bool, inputPanel: Bool, header: Bool, tabBar: Bool, everywhere: Bool) {
        self.messages = messages
        self.inlineButtons = inlineButtons
        self.inputPanel = inputPanel
        self.header = header
        self.tabBar = tabBar
        self.everywhere = everywhere
    }
}

/// The app icon baked into the bundle as the primary icon (Netegram artwork). There is no
/// switch back to Telegram's own branding — Netegram's blue icon is the only one shipped.
public let netegramDefaultAppIconName = "NetegramIcon"

private let liquidGlassMessagesKey = "netegram.liquidGlass.messages"
/// Mirrored in ChatMessageActionButtonsNode, which cannot import this module (SettingsUI
/// depends on it, not the other way round) and so reads the key directly.
private let liquidGlassInlineButtonsKey = "netegram.liquidGlass.inlineButtons"
/// Mirrored in ChatTextInputPanelNode.
private let liquidGlassInputPanelKey = "netegram.liquidGlass.inputPanel"
/// Mirrored in ChatListHeaderComponent.
private let liquidGlassHeaderKey = "netegram.liquidGlass.header"
/// Mirrored in TabBarComponent.
private let liquidGlassTabBarKey = "netegram.liquidGlass.tabBar"
/// Mirrored in GlassBackgroundComponent, which resolves .panel to .clear when this is set.
private let liquidGlassEverywhereKey = "netegram.liquidGlass.everywhere"

/// Local, device-only Liquid Glass preferences.
///
/// Backed by UserDefaults rather than Postbox shared data: the value never syncs between
/// devices and is read during presentation, so the simpler store avoids threading a new
/// preferences key through the account schema.
///
/// "Everywhere" and the five specific toggles are independent switches that happen to reach
/// the same end state on the surfaces they overlap: each surface resolves its tint from
/// either its own key or the blanket one, whichever says clear. Turning "everywhere" off
/// again does not silently disable a surface that has its own toggle still on.
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

    public func setLiquidGlassInlineButtons(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: liquidGlassInlineButtonsKey)
        UserDefaults.standard.synchronize()
        self.pushLiquidGlass()
    }

    public func setLiquidGlassInputPanel(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: liquidGlassInputPanelKey)
        UserDefaults.standard.synchronize()
        self.pushLiquidGlass()
    }

    public func setLiquidGlassHeader(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: liquidGlassHeaderKey)
        UserDefaults.standard.synchronize()
        self.pushLiquidGlass()
    }

    public func setLiquidGlassTabBar(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: liquidGlassTabBarKey)
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
            inlineButtons: defaults.bool(forKey: liquidGlassInlineButtonsKey),
            inputPanel: defaults.bool(forKey: liquidGlassInputPanelKey),
            header: defaults.bool(forKey: liquidGlassHeaderKey),
            tabBar: defaults.bool(forKey: liquidGlassTabBarKey),
            everywhere: defaults.bool(forKey: liquidGlassEverywhereKey)
        )
    }
}
