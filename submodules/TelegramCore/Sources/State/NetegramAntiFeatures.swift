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

/// Prefixed to a message the sender tried to take back.
///
/// A marker rather than silent retention: a chat where deleted messages simply stay looks like
/// a chat where nothing happened, and later there is no way to tell that the other side no
/// longer has what you are reading.
private let netegramDeletedMarker = "🗑 "

/// Keeps the message and marks it, instead of removing it.
///
/// Deletion updates arrive more than once — a resend, a difference fetch, a second device —
/// so the marker is applied only when it is not already there.
func netegramMarkMessagesDeleted(transaction: Transaction, ids: [MessageId]) {
    for id in ids {
        transaction.updateMessage(id, update: { currentMessage in
            if currentMessage.text.hasPrefix(netegramDeletedMarker) {
                return .skip
            }

            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(
                    authorId: forwardInfo.author?.id,
                    sourceId: forwardInfo.source?.id,
                    sourceMessageId: forwardInfo.sourceMessageId,
                    date: forwardInfo.date,
                    authorSignature: forwardInfo.authorSignature,
                    psaType: forwardInfo.psaType,
                    flags: forwardInfo.flags
                )
            }

            return .update(StoreMessage(
                id: currentMessage.id,
                globallyUniqueId: currentMessage.globallyUniqueId,
                groupingKey: currentMessage.groupingKey,
                threadId: currentMessage.threadId,
                timestamp: currentMessage.timestamp,
                flags: StoreMessageFlags(currentMessage.flags),
                tags: currentMessage.tags,
                globalTags: currentMessage.globalTags,
                localTags: currentMessage.localTags,
                forwardInfo: storeForwardInfo,
                authorId: currentMessage.author?.id,
                text: netegramDeletedMarker + currentMessage.text,
                attributes: currentMessage.attributes,
                media: currentMessage.media
            ))
        })
    }
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
