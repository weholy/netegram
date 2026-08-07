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
