import Foundation
import Postbox

/// Netegram: previous versions of edited messages, remembered by this client.
///
/// Telegram's API has no notion of edit history — the server sends the new text and a flag
/// saying the message was edited, and nothing else. The only way to know what a message used
/// to say is to have seen it before the edit arrived. So this records the old text at the
/// moment an edit is applied, and can only ever show edits this device was running for.
public struct NetegramEditVersion: Codable, Equatable {
    public let text: String
    /// When this version stopped being current, i.e. when the edit replacing it arrived.
    public let replacedAt: Int32

    public init(text: String, replacedAt: Int32) {
        self.text = text
        self.replacedAt = replacedAt
    }
}

private let editHistoryKey = "netegram.editHistory"
/// Kept small on purpose. This is a convenience for reading back a message someone just
/// reworded, not an archive — an unbounded store would grow for the life of the install.
private let maximumTrackedMessages = 300
private let maximumVersionsPerMessage = 10

public enum NetegramEditHistory {
    /// Stable across launches, unlike the message's own stable id.
    private static func storageKey(_ id: MessageId) -> String {
        return "\(id.peerId.toInt64()):\(id.namespace):\(id.id)"
    }

    private static func load() -> [String: [NetegramEditVersion]] {
        guard let data = UserDefaults.standard.data(forKey: editHistoryKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: [NetegramEditVersion]].self, from: data)) ?? [:]
    }

    private static func save(_ value: [String: [NetegramEditVersion]]) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }
        UserDefaults.standard.set(data, forKey: editHistoryKey)
    }

    /// Records the text a message had before the edit that is about to be applied.
    ///
    /// Does nothing when the text is unchanged: an edit can also arrive for a reaction, a pin
    /// or a media change, and recording those would fill the history with identical entries.
    public static func record(id: MessageId, previousText: String, newText: String, timestamp: Int32) {
        guard previousText != newText, !previousText.isEmpty else {
            return
        }

        var storage = self.load()
        let key = self.storageKey(id)

        var versions = storage[key] ?? []
        // The first edit also has to record the original, which is the text being replaced.
        versions.append(NetegramEditVersion(text: previousText, replacedAt: timestamp))
        if versions.count > maximumVersionsPerMessage {
            versions.removeFirst(versions.count - maximumVersionsPerMessage)
        }
        storage[key] = versions

        if storage.count > maximumTrackedMessages {
            // Drop whichever entries were touched longest ago. Sorting by the newest version
            // in each entry keeps the messages still being edited, which are the ones worth
            // being able to look back at.
            let ordered = storage.sorted(by: { lhs, rhs in
                (lhs.value.last?.replacedAt ?? 0) > (rhs.value.last?.replacedAt ?? 0)
            })
            storage = Dictionary(uniqueKeysWithValues: ordered.prefix(maximumTrackedMessages).map { ($0.key, $0.value) })
        }

        self.save(storage)
    }

    /// Oldest first. Empty when this device never saw the message change.
    public static func versions(id: MessageId) -> [NetegramEditVersion] {
        return self.load()[self.storageKey(id)] ?? []
    }
}
