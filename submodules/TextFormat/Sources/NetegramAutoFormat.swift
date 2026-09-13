import Foundation
import UIKit
import TelegramCore
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

    /// The composer attribute this style writes. All six are plain flags.
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

    /// The entity the same style becomes in a sent message.
    public var entityType: MessageTextEntityType {
        switch self {
        case .bold:
            return .Bold
        case .italic:
            return .Italic
        case .underline:
            return .Underline
        case .strikethrough:
            return .Strikethrough
        case .monospace:
            return .Code
        case .spoiler:
            return .Spoiler
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

/// Netegram: the one style every message goes out in.
///
/// One style, not a set. Choosing a second switches the first off, which is what the screen
/// promises and what keeps the result predictable: bold-plus-strikethrough-plus-spoiler reads
/// as a mistake, not a preference.
///
/// Applied in two places, because neither alone is enough. The composer shows it — every
/// refresh of the input puts the whole text in the style, so what you see while writing is
/// what arrives. And sending enforces it — the composer has more than one backend and text
/// can arrive by paste, autocorrect or a draft, so the outgoing message is styled again on
/// the way out regardless of how its text got there.
///
/// Cached in memory: the composer reads this on every keystroke.
public enum NetegramAutoFormat {
    private static let storageKey = "netegram.autoFormat.style"
    /// The multi-select version stored an array here. Read once so an update keeps the
    /// first style the user had picked instead of silently switching the feature off.
    private static let legacyStorageKey = "netegram.autoFormat.styles"

    private static let lock = NSLock()
    /// `.none` means not loaded yet; `.some(nil)` means loaded and switched off.
    private static var cache: NetegramTextStyle??

    private static let observer: NSObjectProtocol = NotificationCenter.default.addObserver(forName: NGStore.didChangeNotification, object: nil, queue: nil, using: { _ in
        NetegramAutoFormat.lock.lock()
        NetegramAutoFormat.cache = nil
        NetegramAutoFormat.lock.unlock()
    })

    /// The style currently chosen, or nil while auto-format is off.
    public static var style: NetegramTextStyle? {
        NetegramAutoFormat.lock.lock()
        defer { NetegramAutoFormat.lock.unlock() }

        if let cached = NetegramAutoFormat.cache {
            return cached
        }
        _ = NetegramAutoFormat.observer

        let resolved: NetegramTextStyle?
        if let stored = NGStore.string(forKey: NetegramAutoFormat.storageKey) {
            // An empty string is a deliberate "off", distinct from never having chosen.
            resolved = NetegramTextStyle(rawValue: stored)
        } else if let legacy = NGStore.stringArray(forKey: NetegramAutoFormat.legacyStorageKey) {
            resolved = NetegramTextStyle.allCases.first(where: { legacy.contains($0.rawValue) })
        } else {
            resolved = nil
        }
        NetegramAutoFormat.cache = .some(resolved)
        return resolved
    }

    public static func setStyle(_ style: NetegramTextStyle?) {
        NGStore.setObject(style?.rawValue ?? "", forKey: NetegramAutoFormat.storageKey)
        NGStore.removeObject(forKey: NetegramAutoFormat.legacyStorageKey)

        NetegramAutoFormat.lock.lock()
        NetegramAutoFormat.cache = nil
        NetegramAutoFormat.lock.unlock()

        // One style for the whole message and a different one per character are two answers to
        // the same question; picking a single style while combo fonts was on would leave it
        // unclear which one actually applies.
        if style != nil {
            NetegramComboFonts.setEnabled(false)
        }
    }

    /// Captions and the other fields that only rebuild typing attributes.
    ///
    /// Combo fonts has nothing to do here: a typing attribute is what the *next* keystroke
    /// inherits, the same value for as long as it is set, which cannot express "a different
    /// style for each character." `applyToStateText` covers combo fonts in the one place that
    /// rebuilds from the actual text instead of describing what comes next.
    public static func applyToTypingAttributes(_ attributes: inout [NSAttributedString.Key: Any]) {
        guard let style = NetegramAutoFormat.style else {
            return
        }
        if attributes[style.inputAttribute] == nil {
            attributes[style.inputAttribute] = true as NSNumber
        }
    }

    /// The chat composer: the whole text in the chosen style, not only what is typed next.
    ///
    /// Typing attributes alone miss everything that is not a keystroke — a paste, an
    /// autocorrect replacement, a restored draft — which is why the style used to show up
    /// only some of the time.
    public static func applyToStateText(_ text: NSMutableAttributedString) {
        guard text.length > 0 else {
            return
        }
        if let choices = NetegramComboFonts.activeStyles {
            NetegramComboFonts.applyToStateText(text, choices: choices)
            return
        }
        guard let style = NetegramAutoFormat.style else {
            return
        }
        var excluded: [Range<Int>] = []
        if style == .monospace {
            // Monospace cannot hold a custom emoji or a link: the server strips them from a code
            // span. Those stretches are left out so the emoji and links survive.
            for key in [ChatTextInputAttributes.customEmoji, ChatTextInputAttributes.textMention, ChatTextInputAttributes.textUrl, ChatTextInputAttributes.date] {
                text.enumerateAttribute(key, in: NSRange(location: 0, length: text.length), options: [], using: { value, range, _ in
                    if value != nil {
                        excluded.append(range.location ..< range.location + range.length)
                    }
                })
            }
        }
        for range in netegramRanges(length: text.length, excluding: excluded) {
            text.addAttribute(style.inputAttribute, value: true as NSNumber, range: NSRange(location: range.lowerBound, length: range.count))
        }
    }
}

/// Netegram: each character in a random style from a chosen set of 1–6, instead of one style
/// for the whole message.
///
/// Mutually exclusive with NetegramAutoFormat's single style, the same way NetegramGhost's
/// alwaysOnline/hideOnline switches are: the two describe incompatible answers to "what style is
/// this text," so choosing one clears the other rather than leaving it ambiguous which applies.
///
/// "Random" here means a deterministic pick from each character's position, not a fresh coin
/// flip on every read. `applyToStateText` runs on every keystroke against the *entire* current
/// text (see refreshChatTextInputAttributes), so a genuinely random per-call pick would make
/// already-typed characters change style on every subsequent keystroke — visibly flickering
/// text rather than a stable combo look. A position-keyed pick gives the same character the same
/// style across repeated refreshes, and only text typed after a style is added or removed can
/// ever change.
public enum NetegramComboFonts {
    private static let enabledKey = "netegram.comboFonts.enabled"
    private static let stylesKey = "netegram.comboFonts.styles"

    private static let lock = NSLock()
    private static var cache: [NetegramTextStyle]??

    private static let observer: NSObjectProtocol = NotificationCenter.default.addObserver(forName: NGStore.didChangeNotification, object: nil, queue: nil, using: { _ in
        NetegramComboFonts.lock.lock()
        NetegramComboFonts.cache = nil
        NetegramComboFonts.lock.unlock()
    })

    /// The chosen styles when combo mode is genuinely in effect — enabled, with at least one
    /// style actually chosen. Nil otherwise, so every call site has exactly one question to ask
    /// ("is this nil") instead of needing to separately check `isEnabled` and an empty list.
    public static var activeStyles: [NetegramTextStyle]? {
        NetegramComboFonts.lock.lock()
        defer { NetegramComboFonts.lock.unlock() }

        if let cached = NetegramComboFonts.cache {
            return cached
        }
        _ = NetegramComboFonts.observer

        let resolved: [NetegramTextStyle]?
        if NGStore.bool(forKey: NetegramComboFonts.enabledKey) {
            let styles = NetegramComboFonts.storedStyles()
            resolved = styles.isEmpty ? nil : styles
        } else {
            resolved = nil
        }
        NetegramComboFonts.cache = .some(resolved)
        return resolved
    }

    public static var isEnabled: Bool {
        return NGStore.bool(forKey: NetegramComboFonts.enabledKey)
    }

    /// What is checked on the settings screen, independent of whether the master switch is on —
    /// unlike `activeStyles`, this does not fold the enabled flag in, since the screen needs to
    /// show which boxes are ticked even while the feature itself is off.
    public static var chosenStyles: [NetegramTextStyle] {
        return NetegramComboFonts.storedStyles()
    }

    private static func storedStyles() -> [NetegramTextStyle] {
        return (NGStore.stringArray(forKey: NetegramComboFonts.stylesKey) ?? []).compactMap(NetegramTextStyle.init(rawValue:))
    }

    public static func setEnabled(_ value: Bool) {
        NGStore.setObject(value, forKey: NetegramComboFonts.enabledKey)
        if value {
            NetegramAutoFormat.setStyle(nil)
        }
        NetegramComboFonts.invalidate()
    }

    public static func setStyleChosen(_ style: NetegramTextStyle, chosen: Bool) {
        var styles = NetegramComboFonts.storedStyles()
        if chosen {
            if !styles.contains(style) {
                styles.append(style)
            }
        } else {
            styles.removeAll(where: { $0 == style })
        }
        NGStore.setObject(styles.map { $0.rawValue }, forKey: NetegramComboFonts.stylesKey)
        NetegramComboFonts.invalidate()
    }

    private static func invalidate() {
        NetegramComboFonts.lock.lock()
        NetegramComboFonts.cache = nil
        NetegramComboFonts.lock.unlock()
    }

    /// A stable pick per character position. Not cryptographic and not meant to be — Knuth's
    /// multiplicative hash constant, folded down to however many styles are on offer.
    public static func style(forIndex index: Int, choices: [NetegramTextStyle]) -> NetegramTextStyle {
        guard !choices.isEmpty else {
            return .bold
        }
        let hashed = UInt64(bitPattern: Int64(index)) &* 2654435761
        let bucket = Int(hashed % UInt64(choices.count))
        return choices[bucket]
    }

    /// Character by character rather than merged into runs: this only ever feeds a live,
    /// in-memory text view, so the simplicity of one attribute call per character outweighs the
    /// small saving from merging adjacent same-style runs. `netegramComboStyleEntities` below
    /// does merge, because there the runs become actual message entities.
    fileprivate static func applyToStateText(_ text: NSMutableAttributedString, choices: [NetegramTextStyle]) {
        var excluded: [Range<Int>] = []
        if choices.contains(.monospace) {
            for key in [ChatTextInputAttributes.customEmoji, ChatTextInputAttributes.textMention, ChatTextInputAttributes.textUrl, ChatTextInputAttributes.date] {
                text.enumerateAttribute(key, in: NSRange(location: 0, length: text.length), options: [], using: { value, range, _ in
                    if value != nil {
                        excluded.append(range.location ..< range.location + range.length)
                    }
                })
            }
        }
        for range in netegramRanges(length: text.length, excluding: excluded) {
            for index in range {
                let style = NetegramComboFonts.style(forIndex: index, choices: choices)
                text.addAttribute(style.inputAttribute, value: true as NSNumber, range: NSRange(location: index, length: 1))
            }
        }
    }
}

/// Netegram: puts outgoing text in the auto-format style.
///
/// The composer already shows the style, so for a message typed normally this changes
/// nothing. It is here for everything that reaches sending without passing through that
/// display: pasted text, the native editor, captions, drafts. Any existing entity of the same
/// kind is replaced by one covering the whole text, so the result never carries overlapping
/// duplicates.
///
/// Rich messages — headings, lists, tables — carry their formatting inside the page they
/// describe rather than as entities, and are left exactly as they are.
public func netegramApplyAutoFormat(messages: [EnqueueMessage]) -> [EnqueueMessage] {
    let comboChoices = NetegramComboFonts.activeStyles
    let singleStyle = comboChoices == nil ? NetegramAutoFormat.style : nil
    guard comboChoices != nil || singleStyle != nil else {
        return messages
    }
    return messages.map { message -> EnqueueMessage in
        guard case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets) = message else {
            return message
        }
        let length = (text as NSString).length
        guard length > 0 else {
            return message
        }
        if attributes.contains(where: { $0 is RichTextMessageAttribute }) {
            return message
        }

        var existing: [MessageTextEntity] = []
        // The engine alias rather than Postbox's own name: TextFormat does not import Postbox,
        // and TelegramCore does not re-export it.
        var otherAttributes: [EngineMessage.Attribute] = []
        for attribute in attributes {
            if let attribute = attribute as? TextEntitiesMessageAttribute {
                existing.append(contentsOf: attribute.entities)
            } else {
                otherAttributes.append(attribute)
            }
        }

        let entities: [MessageTextEntity]
        if let comboChoices {
            entities = netegramComboStyleEntities(length: length, existing: existing, choices: comboChoices)
        } else if let singleStyle {
            entities = netegramSingleStyleEntities(length: length, existing: existing, style: singleStyle)
        } else {
            entities = existing
        }
        otherAttributes.append(TextEntitiesMessageAttribute(entities: entities))

        return .message(
            text: text,
            attributes: otherAttributes,
            inlineStickers: inlineStickers,
            mediaReference: mediaReference,
            threadId: threadId,
            replyToMessageId: replyToMessageId,
            replyToStoryId: replyToStoryId,
            localGroupingKey: localGroupingKey,
            correlationId: correlationId,
            bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets
        )
    }
}

/// The stretches of an entity type the fork's monospace handling has always protected — the
/// server strips these from inside a code span, so whichever style is being applied skips them
/// when that style is monospace. Shared between the single-style and combo paths below.
private func netegramMonospaceExclusions(existing: [MessageTextEntity]) -> [Range<Int>] {
    var excluded: [Range<Int>] = []
    for entity in existing {
        switch entity.type {
        case .CustomEmoji, .TextMention, .TextUrl, .Mention, .Url, .Email, .PhoneNumber, .Hashtag, .BotCommand, .BankCard, .FormattedDate, .Pre:
            excluded.append(entity.range)
        default:
            break
        }
    }
    return excluded
}

private func netegramSingleStyleEntities(length: Int, existing: [MessageTextEntity], style: NetegramTextStyle) -> [MessageTextEntity] {
    let excluded = style == .monospace ? netegramMonospaceExclusions(existing: existing) : []
    var entities = existing.filter { $0.type != style.entityType }
    for range in netegramRanges(length: length, excluding: excluded) {
        entities.append(MessageTextEntity(range: range, type: style.entityType))
    }
    return entities
}

/// One entity per contiguous run of characters that resolve to the same style, rather than one
/// per character — a "combo" message otherwise carries as many entities as it has letters, for
/// no benefit over merging the runs a random-looking sequence still happens to repeat.
private func netegramComboStyleEntities(length: Int, existing: [MessageTextEntity], choices: [NetegramTextStyle]) -> [MessageTextEntity] {
    // A plain array rather than a Set: MessageTextEntityType is Equatable but not Hashable, and
    // there are at most six of these, so a linear check costs nothing.
    let strippedTypes = choices.map { $0.entityType }
    let excluded = choices.contains(.monospace) ? netegramMonospaceExclusions(existing: existing) : []
    let kept = existing.filter { !strippedTypes.contains($0.type) }
    return kept + netegramComboRunEntities(length: length, excluding: excluded, choices: choices)
}

private func netegramComboRunEntities(length: Int, excluding excluded: [Range<Int>], choices: [NetegramTextStyle]) -> [MessageTextEntity] {
    var entities: [MessageTextEntity] = []
    var runStart: Int?
    var runStyle: NetegramTextStyle?

    func flush(at end: Int) {
        if let start = runStart, let style = runStyle, end > start {
            entities.append(MessageTextEntity(range: start ..< end, type: style.entityType))
        }
        runStart = nil
        runStyle = nil
    }

    for range in netegramRanges(length: length, excluding: excluded) {
        for index in range {
            let style = NetegramComboFonts.style(forIndex: index, choices: choices)
            if style == runStyle {
                continue
            }
            flush(at: index)
            runStart = index
            runStyle = style
        }
        flush(at: range.upperBound)
    }
    return entities
}

/// `0 ..< length` with the excluded stretches cut out. Empty pieces are dropped.
private func netegramRanges(length: Int, excluding excluded: [Range<Int>]) -> [Range<Int>] {
    guard length > 0 else {
        return []
    }
    let sorted = excluded
        .map { max(0, $0.lowerBound) ..< min(length, $0.upperBound) }
        .filter { !$0.isEmpty }
        .sorted(by: { $0.lowerBound < $1.lowerBound })

    var result: [Range<Int>] = []
    var cursor = 0
    for range in sorted {
        if range.lowerBound > cursor {
            result.append(cursor ..< range.lowerBound)
        }
        cursor = max(cursor, range.upperBound)
    }
    if cursor < length {
        result.append(cursor ..< length)
    }
    return result
}
