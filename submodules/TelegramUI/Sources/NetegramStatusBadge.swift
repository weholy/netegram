import Foundation
import UIKit
import AppBundle

/// Netegram: the branded pill drawn over the Dynamic Island.
///
/// iOS gives no API for the island's frame, but the safe-area inset is a reliable proxy: the
/// island sits 48pt above the bottom of the inset on every device that has one (59pt inset on
/// iPhone 14/15 Pro puts it at y=11, 62pt on iPhone 16 Pro at y=14). Devices without an island
/// report a smaller inset, so the same check doubles as the feature gate.
private let islandSize = CGSize(width: 126.0, height: 37.33)
private let islandTopFromSafeAreaBottom: CGFloat = 48.0
private let minimumDynamicIslandSafeAreaInset: CGFloat = 55.0
/// Grown slightly past the island so antialiased black edges never peek out around the pill.
private let badgeOutset: CGFloat = 0.66

public final class NetegramStatusBadgeView: UIView {
    private let badgeView: UIImageView

    public override init(frame: CGRect) {
        self.badgeView = UIImageView(image: UIImage(bundleImageName: "Netegram Icons/StatusBadge"))

        super.init(frame: frame)

        self.badgeView.contentMode = .scaleToFill
        self.badgeView.clipsToBounds = true
        self.badgeView.layer.cornerCurve = .continuous

        self.isUserInteractionEnabled = false
        // Keeps the pill above every view the app later adds to the window, without having to
        // re-insert it whenever a controller is presented.
        self.layer.zPosition = 10000.0
        self.addSubview(self.badgeView)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    /// Adds the badge to the window and keeps it sized to it. Safe to call more than once.
    public static func install(in window: UIWindow) {
        for subview in window.subviews {
            if subview is NetegramStatusBadgeView {
                return
            }
        }
        let view = NetegramStatusBadgeView(frame: window.bounds)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(view)
    }

    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()

        // The insets arrive after the view is already in the window, and nothing else asks for
        // another layout pass — without this the badge stays where the first, empty inset put
        // it, which is off the top of the screen.
        self.setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        // Read from the window rather than from self: a plain subview reports zero insets
        // until the window has propagated them, and a zero inset reads here as "this device
        // has no Dynamic Island" — which hides the badge for good.
        let safeAreaTop = self.window?.safeAreaInsets.top ?? self.safeAreaInsets.top
        // Landscape moves the island off the top edge, so there is nothing to cover there.
        let isPortrait = self.bounds.height >= self.bounds.width
        guard isPortrait, safeAreaTop >= minimumDynamicIslandSafeAreaInset else {
            self.badgeView.isHidden = true
            return
        }
        self.badgeView.isHidden = false

        let size = CGSize(width: islandSize.width + badgeOutset * 2.0, height: islandSize.height + badgeOutset * 2.0)
        let origin = CGPoint(
            x: floor((self.bounds.width - size.width) / 2.0),
            y: safeAreaTop - islandTopFromSafeAreaBottom - badgeOutset
        )
        self.badgeView.frame = CGRect(origin: origin, size: size)
        self.badgeView.layer.cornerRadius = size.height / 2.0
    }
}
