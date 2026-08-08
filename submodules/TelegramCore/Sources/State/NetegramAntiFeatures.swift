import Foundation
import Postbox

/// Netegram: the switches that make the client ignore instructions to destroy history.
///
/// Keys are mirrored in NetegramGhost (SettingsUI). They live in UserDefaults because the
/// decision is taken deep inside update processing, long before any account preference is
/// reachable, and because it describes this device rather than the account.
enum NetegramAnti {
    static var revoke: Bool {
        return UserDefaults.standard.bool(forKey: "netegram.anti.revoke")
    }

    static var edit: Bool {
        return UserDefaults.standard.bool(forKey: "netegram.anti.edit")
    }

    static var autoDelete: Bool {
        return UserDefaults.standard.bool(forKey: "netegram.anti.autoDelete")
    }
}

/// Netegram: true while the client ignores a chat's ban on saving and forwarding.
///
/// The restriction is advisory — the server sends the content either way and only asks the
/// client to hide the buttons, which is why lifting it needs nothing but this check.
public func netegramAllowSavingProtectedContent() -> Bool {
    return UserDefaults.standard.bool(forKey: "netegram.ghost.allowSaving")
}

/// Netegram: true while the stories bar is hidden everywhere.
public func netegramHideStories() -> Bool {
    return UserDefaults.standard.bool(forKey: "netegram.ghost.hideStories")
}

/// Netegram: true while a call has to be confirmed before it is placed.
public func netegramConfirmCalls() -> Bool {
    return UserDefaults.standard.bool(forKey: "netegram.ghost.confirmCalls")
}

/// Netegram: true while picked audio files are sent as voice messages.
public func netegramSendAudioAsVoice() -> Bool {
    return UserDefaults.standard.bool(forKey: "netegram.ghost.sendAsVoice")
}

/// Netegram: how much bigger to make download chunks. Nil while the boost is off.
///
/// A larger part means fewer round trips, which is where the speed comes from. The cost is
/// that the server starts answering with FLOOD_WAIT sooner, so this is opt-in.
public func netegramDownloadBoost() -> (partSize: Int64, parallelParts: Int)? {
    guard UserDefaults.standard.bool(forKey: "netegram.ghost.fastDownload") else {
        return nil
    }
    // 1 MB is the largest part the file API accepts, and 1 MB has to stay divisible by it.
    return (1024 * 1024, 12)
}

/// Netegram: messages someone tried to take back, kept and flagged instead of removed.
///
/// An id list rather than a change to the message itself: rewriting the text to carry a marker
/// meant editing every kept message in the database, and the marker then lived inside the
/// bubble, where it reads as part of what was written. The chat asks this list while laying a
/// message out and draws the mark beside the bubble instead.
///
/// Held in memory and mirrored to disk. It is consulted on every bubble layout, which is far
/// too often to touch the store, and it has to survive a restart or yesterday's kept messages
/// would quietly lose their mark.
public enum NetegramDeletedMessages {
    private static let storageKey = "netegram.deletedMessages"
    private static let maximumTracked = 2000

    private static var cache: Set<String>?
    private static let lock = NSLock()

    private static func key(_ id: MessageId) -> String {
        return "\(id.peerId.toInt64()):\(id.namespace):\(id.id)"
    }

    private static func loaded() -> Set<String> {
        if let cache = NetegramDeletedMessages.cache {
            return cache
        }
        let stored = Set(UserDefaults.standard.stringArray(forKey: NetegramDeletedMessages.storageKey) ?? [])
        NetegramDeletedMessages.cache = stored
        return stored
    }

    public static func insert(_ ids: [MessageId]) {
        guard !ids.isEmpty else {
            return
        }
        NetegramDeletedMessages.lock.lock()
        var stored = NetegramDeletedMessages.loaded()
        for id in ids {
            stored.insert(NetegramDeletedMessages.key(id))
        }
        // Oldest entries are not knowable here, so an overflowing list is simply dropped: the
        // marks are a convenience, and an unbounded list would grow for the life of the install.
        if stored.count > NetegramDeletedMessages.maximumTracked {
            stored = []
        }
        NetegramDeletedMessages.cache = stored
        UserDefaults.standard.set(Array(stored), forKey: NetegramDeletedMessages.storageKey)
        NetegramDeletedMessages.lock.unlock()
    }

    public static func contains(_ id: MessageId) -> Bool {
        NetegramDeletedMessages.lock.lock()
        defer { NetegramDeletedMessages.lock.unlock() }
        return NetegramDeletedMessages.loaded().contains(NetegramDeletedMessages.key(id))
    }
}

/// Keeps the messages and records them as deleted, instead of removing them.
func netegramMarkMessagesDeleted(transaction: Transaction, ids: [MessageId]) {
    NetegramDeletedMessages.insert(ids)
}

func netegramMarkMessagesDeleted(transaction: Transaction, globalIds: [Int32]) {
    netegramMarkMessagesDeleted(transaction: transaction, ids: transaction.messageIdsForGlobalIds(globalIds))
}

/// True when an edit should be discarded so the text you already read stays put.
///
/// Only incoming messages are protected: refusing your own edits would mean typing a
/// correction, watching it succeed on the server, and never seeing it apply locally.
func netegramShouldIgnoreEdit(transaction: Transaction, id: MessageId) -> Bool {
    guard NetegramAnti.edit else {
        return false
    }
    guard let message = transaction.getMessage(id) else {
        return false
    }
    return message.flags.contains(.Incoming)
}

/// Netegram: descriptions replaced with your own text, on this device only.
///
/// Nothing is sent anywhere — the person keeps whatever they wrote, and only you see the
/// replacement. Useful when someone's "about" says nothing and you need a reminder of who
/// they are.
///
/// Kept in memory and mirrored to disk for the same reason as the deleted list: it is read
/// while the profile is laid out, and it has to outlive a restart.
public enum NetegramLocalBio {
    private static let storageKey = "netegram.localBio"

    private static var cache: [String: String]?
    private static let lock = NSLock()

    private static func loaded() -> [String: String] {
        if let cache = NetegramLocalBio.cache {
            return cache
        }
        let stored = (UserDefaults.standard.dictionary(forKey: NetegramLocalBio.storageKey) as? [String: String]) ?? [:]
        NetegramLocalBio.cache = stored
        return stored
    }

    private static func store(_ value: [String: String]) {
        NetegramLocalBio.cache = value
        UserDefaults.standard.set(value, forKey: NetegramLocalBio.storageKey)
    }

    public static func set(peerId: PeerId, text: String) {
        NetegramLocalBio.lock.lock()
        var stored = NetegramLocalBio.loaded()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // An empty replacement is a removal, not a blank description: leaving it would hide the
        // real text behind nothing with no way to tell the two apart.
        if trimmed.isEmpty {
            stored.removeValue(forKey: "\(peerId.toInt64())")
        } else {
            stored["\(peerId.toInt64())"] = trimmed
        }
        NetegramLocalBio.store(stored)
        NetegramLocalBio.lock.unlock()
    }

    public static func clear(peerId: PeerId) {
        NetegramLocalBio.set(peerId: peerId, text: "")
    }

    public static func value(peerId: PeerId) -> String? {
        NetegramLocalBio.lock.lock()
        defer { NetegramLocalBio.lock.unlock() }
        return NetegramLocalBio.loaded()["\(peerId.toInt64())"]
    }
}

/// The description to show: your replacement when there is one, otherwise what the server sent.
public func netegramDisplayBio(peerId: PeerId, about: String?) -> String? {
    return NetegramLocalBio.value(peerId: peerId) ?? about
}
