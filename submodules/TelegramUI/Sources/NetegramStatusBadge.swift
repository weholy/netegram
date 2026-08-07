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
        self.badgeView.contentMode = .scaleToFill
        self.badgeView.clipsToBounds = true
        self.badgeView.layer.cornerCurve = .continuous

        super.init(frame: frame)

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

    public override func layoutSubviews() {
        super.layoutSubviews()

        let safeAreaTop = self.safeAreaInsets.top
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
