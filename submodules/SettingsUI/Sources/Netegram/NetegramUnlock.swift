import Foundation
import CryptoKit
import SwiftSignalKit

/// Netegram: the deep links that open the rest of the settings screen.
///
/// A fresh install shows three rows; the others appear only after a link is used. There is no
/// server, so the check has to be answerable by the app alone: the link carries a signature
/// made with a secret built into the binary, and the app verifies it offline.
///
/// The honest limit of that: anyone who takes the binary apart can pull the secret out and mint
/// their own links. This stops a link being guessed or typed at random, not a determined person
/// with the app in hand. Without something to ask over the network, nothing does better.
public enum NetegramUnlock {
    /// Shared between minting and checking. Changing it invalidates every link already handed
    /// out, which is the only revocation available without a server.
    private static let secret = "netegram.unlock.v1.4f2b9c7e"
    private static let unlockedKey = "netegram.unlock.enabled"
    private static let previewKey = "netegram.unlock.previewAsUser"
    private static let usedCodesKey = "netegram.unlock.usedCodes"

    public static let scheme = "netegram"
    public static let host = "unlock"

    /// Not ignoring repeats: the preview switch pushes the same unlocked value on purpose, just
    /// to make the screen redraw, and a promise that swallowed it would leave the list stale.
    private static let promise = ValuePromise<Bool>(NetegramUnlock.isUnlocked, ignoreRepeated: false)

    public static var isUnlocked: Bool {
        return UserDefaults.standard.bool(forKey: NetegramUnlock.unlockedKey)
    }

    public static var signal: Signal<Bool, NoError> {
        return NetegramUnlock.promise.get()
    }

    /// Netegram: draws the settings screen the way a stranger sees it.
    ///
    /// Everything the owner adds for other people — the shortened list, the missing header —
    /// is by definition invisible from the owner's own phone, and the only way to check it
    /// would be a second account. This lifts that: the check itself is untouched, only the
    /// screen pretends.
    public static var previewsAsRegularUser: Bool {
        return UserDefaults.standard.bool(forKey: NetegramUnlock.previewKey)
    }

    public static func setPreviewsAsRegularUser(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: NetegramUnlock.previewKey)
        // Pushed through the same promise the screen already listens to, so it redraws at once.
        NetegramUnlock.promise.set(NetegramUnlock.isUnlocked)
    }

    /// Short, readable and case-insensitive: these get typed by hand and read aloud.
    private static func signature(for nonce: String) -> String {
        let digest = SHA256.hash(data: Data((nonce.lowercased() + NetegramUnlock.secret).utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(8).lowercased()
    }

    /// Builds a link. `word` is whatever the owner typed; the signature is appended so the
    /// receiving app can tell it apart from something invented.
    public static func makeLink(word: String, index: Int) -> String {
        let cleaned = word.lowercased().filter { $0.isLetter || $0.isNumber }
        let base = cleaned.isEmpty ? "netegram" : cleaned
        let nonce = "\(base)\(index)"
        return "\(NetegramUnlock.scheme)://\(NetegramUnlock.host)/\(nonce)-\(NetegramUnlock.signature(for: nonce))"
    }

    /// Result of opening a link, so the caller can say something useful either way.
    public enum Redemption {
        case unlocked
        case alreadyUsed
        case invalid
    }

    /// Consumes a link. Each code works once per device: a second tap says so instead of
    /// pretending to unlock something that is already open.
    @discardableResult
    public static func redeem(code: String) -> Redemption {
        let parts = code.lowercased().split(separator: "-")
        guard parts.count == 2 else {
            return .invalid
        }
        let nonce = String(parts[0])
        guard NetegramUnlock.signature(for: nonce) == String(parts[1]) else {
            return .invalid
        }

        var used = UserDefaults.standard.stringArray(forKey: NetegramUnlock.usedCodesKey) ?? []
        if used.contains(nonce) {
            return .alreadyUsed
        }
        used.append(nonce)
        UserDefaults.standard.set(used, forKey: NetegramUnlock.usedCodesKey)
        UserDefaults.standard.set(true, forKey: NetegramUnlock.unlockedKey)
        NetegramUnlock.promise.set(true)
        return .unlocked
    }

    /// Parses a `netegram://unlock/<code>` URL. Returns nil for anything else, so the app can
    /// carry on handing unknown links to Telegram's own handling.
    public static func code(from url: URL) -> String? {
        guard url.scheme?.lowercased() == NetegramUnlock.scheme else {
            return nil
        }
        guard url.host?.lowercased() == NetegramUnlock.host else {
            return nil
        }
        let code = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return code.isEmpty ? nil : code
    }
}
