import Foundation
import UIKit
import NetegramStore

/// Netegram: the character styles a message can be typed in.
///
/// Telegram's block-level formatting — quotes and code blocks — is deliberately not here.
/// Those carry a paragraph attribute with a payload rather than a plain on/off flag, they
/// change the shape of the bubble rather than the letters, and a whole conversation written
/// inside a quote block is not what "always type in bold" means.
public enum NetegramTextStyle: String, CaseIterable {
    case bold
    case italic
    case underline
    case strikethrough
    case monospace
    case spoiler

    /// The composer attribute this style writes. All six are plain flags, which is what lets
    /// them be unioned into the typing attributes without knowing anything about the text.
    public var inputAttribute: NSAttributedString.Key {
        switch self {
        case .bold:
            return ChatTextInputAttributes.bold
        case .italic:
            return ChatTextInputAttributes.italic
        case .underline:
            return ChatTextInputAttributes.underline
        case .strikethrough:
            return ChatTextInputAttributes.strikethrough
        case .monospace:
            return ChatTextInputAttributes.monospace
        case .spoiler:
            return ChatTextInputAttributes.spoiler
        }
    }

    public var title: String {
        switch self {
        case .bold:
            return "Жирный"
        case .italic:
            return "Курсив"
        case .underline:
            return "Подчёркнутый"
        case .strikethrough:
            return "Зачёркнутый"
        case .monospace:
            return "Моноширинный"
        case .spoiler:
            return "Спойлер"
        }
    }
}

/// Netegram: the style every message is typed in until told otherwise.
///
/// Applied to the composer's typing attributes rather than to the text on send, so what is on
/// screen while writing is what arrives — and so formatting a range by hand still wins, since
/// that range already carries its own attributes.
///
/// Cached in memory: the typing attributes are rebuilt on every keystroke and on every
/// selection change, which is far too often to reach the store.
public enum NetegramAutoFormat {
    private static let storageKey = "netegram.autoFormat.styles"

    private static let lock = NSLock()
    private static var cache: [NetegramTextStyle]?

    private static let observer: NSObjectProtocol = NotificationCenter.default.addObserver(forName: NGStore.didChangeNotification, object: nil, queue: nil, using: { _ in
        NetegramAutoFormat.lock.lock()
        NetegramAutoFormat.cache = nil
        NetegramAutoFormat.lock.unlock()
    })

    /// The styles currently switched on, in the order they are listed on the settings screen.
    public static var styles: [NetegramTextStyle] {
        NetegramAutoFormat.lock.lock()
        defer { NetegramAutoFormat.lock.unlock() }

        if let cache = NetegramAutoFormat.cache {
            return cache
        }
        _ = NetegramAutoFormat.observer

        let stored = Set(NGStore.stringArray(forKey: NetegramAutoFormat.storageKey) ?? [])
        let resolved = NetegramTextStyle.allCases.filter { stored.contains($0.rawValue) }
        NetegramAutoFormat.cache = resolved
        return resolved
    }

    public static func isEnabled(_ style: NetegramTextStyle) -> Bool {
        return NetegramAutoFormat.styles.contains(style)
    }

    public static func setEnabled(_ enabled: Bool, style: NetegramTextStyle) {
        var current = Set(NetegramAutoFormat.styles.map { $0.rawValue })
        if enabled {
            current.insert(style.rawValue)
        } else {
            current.remove(style.rawValue)
        }
        // Written in the enum's own order so the stored array reads the same way the screen
        // does, which makes an exported settings file legible.
        let ordered = NetegramTextStyle.allCases.filter { current.contains($0.rawValue) }.map { $0.rawValue }
        NGStore.setObject(ordered, forKey: NetegramAutoFormat.storageKey)

        NetegramAutoFormat.lock.lock()
        NetegramAutoFormat.cache = nil
        NetegramAutoFormat.lock.unlock()
    }

    /// Unions the enabled styles into a set of typing attributes.
    ///
    /// Unconditional rather than "only when nothing was inherited": the point of the setting
    /// is that everything typed comes out in this style, so continuing after a range the user
    /// had un-formatted goes back to it. Attributes already inherited from the character
    /// before the cursor are left alone, so a manual style is never overwritten — the two
    /// simply combine, exactly as they would if both had been applied by hand.
    public static func applyToTypingAttributes(_ attributes: inout [NSAttributedString.Key: Any]) {
        for style in NetegramAutoFormat.styles {
            let key = style.inputAttribute
            if attributes[key] == nil {
                attributes[key] = true as NSNumber
            }
        }
    }
}
