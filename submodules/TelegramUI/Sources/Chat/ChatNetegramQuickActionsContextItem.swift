import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ContextUI

/// One button of the top row: an icon above a caption.
struct ChatNetegramQuickAction {
    let title: String
    let iconName: String
    let isDestructive: Bool
    let action: (ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void
}

/// The horizontal "Select / Copy / Delete" row that opens the redesigned message menu.
///
/// Inserted at the top of the action list the same way Telegram inserts its own custom
/// nodes — `actions.insert(.custom(item, false), at: 0)`.
final class ChatNetegramQuickActionsContextItem: ContextMenuCustomItem {
    private let actions: [ChatNetegramQuickAction]

    init(actions: [ChatNetegramQuickAction]) {
        self.actions = actions
    }

    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return ChatNetegramQuickActionsContextItemNode(
            presentationData: presentationData,
            actions: self.actions,
            getController: getController,
            actionSelected: actionSelected
        )
    }
}

private final class ChatNetegramQuickActionsColumnNode: ASDisplayNode {
    let action: ChatNetegramQuickAction
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let highlightNode: ASDisplayNode
    private var theme: PresentationTheme

    var pressed: (() -> Void)?

    init(presentationData: PresentationData, action: ChatNetegramQuickAction) {
        self.action = action
        self.theme = presentationData.theme

        self.highlightNode = ASDisplayNode()
        self.highlightNode.isLayerBacked = true
        self.highlightNode.alpha = 0.0

        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.contentMode = .center

        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.textAlignment = .center

        super.init()

        self.addSubnode(self.highlightNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)

        self.applyTheme(presentationData: presentationData)
    }

    override func didLoad() {
        super.didLoad()
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }

    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.pressed?()
        }
    }

    func applyTheme(presentationData: PresentationData) {
        self.theme = presentationData.theme
        let color = self.action.isDestructive ? presentationData.theme.contextMenu.destructiveColor : presentationData.theme.contextMenu.primaryColor
        self.highlightNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: self.action.iconName), color: color)
        self.titleNode.attributedText = NSAttributedString(
            string: self.action.title,
            font: Font.regular(12.0),
            textColor: color
        )
    }

    func updateIsHighlighted(_ isHighlighted: Bool) {
        self.highlightNode.alpha = isHighlighted ? 1.0 : 0.0
    }

    /// Lays the icon above a single caption line inside the given column width.
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.highlightNode, frame: CGRect(origin: CGPoint(), size: size))

        let iconSize = self.iconNode.image?.size ?? CGSize(width: 24.0, height: 24.0)
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - 8.0, height: 20.0))

        let contentHeight = iconSize.height + 6.0 + titleSize.height
        var contentTop = floorToScreenPixels((size.height - contentHeight) / 2.0)
        if contentTop < 0.0 {
            contentTop = 0.0
        }

        transition.updateFrame(node: self.iconNode, frame: CGRect(
            origin: CGPoint(x: floorToScreenPixels((size.width - iconSize.width) / 2.0), y: contentTop),
            size: iconSize
        ))
        transition.updateFrame(node: self.titleNode, frame: CGRect(
            origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: contentTop + iconSize.height + 6.0),
            size: titleSize
        ))
    }
}

private final class ChatNetegramQuickActionsContextItemNode: ASDisplayNode, ContextMenuCustomNode {
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void

    private var columnNodes: [ChatNetegramQuickActionsColumnNode] = []
    private var separatorNodes: [ASDisplayNode] = []

    init(presentationData: PresentationData, actions: [ChatNetegramQuickAction], getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.getController = getController
        self.actionSelected = actionSelected

        super.init()

        for action in actions {
            let columnNode = ChatNetegramQuickActionsColumnNode(presentationData: presentationData, action: action)
            columnNode.pressed = { [weak self] in
                guard let self else {
                    return
                }
                action.action(self.getController(), self.actionSelected)
            }
            self.columnNodes.append(columnNode)
            self.addSubnode(columnNode)
        }

        // Thin dividers between columns, one fewer than the number of buttons.
        for _ in 0 ..< max(0, actions.count - 1) {
            let separatorNode = ASDisplayNode()
            separatorNode.isLayerBacked = true
            separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
            self.separatorNodes.append(separatorNode)
            self.addSubnode(separatorNode)
        }
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let height: CGFloat = 68.0
        let size = CGSize(width: constrainedWidth, height: height)

        return (size, { [weak self] size, transition in
            guard let self, !self.columnNodes.isEmpty else {
                return
            }
            let columnWidth = size.width / CGFloat(self.columnNodes.count)
            for (index, columnNode) in self.columnNodes.enumerated() {
                let columnFrame = CGRect(
                    origin: CGPoint(x: columnWidth * CGFloat(index), y: 0.0),
                    size: CGSize(width: columnWidth, height: size.height)
                )
                transition.updateFrame(node: columnNode, frame: columnFrame)
                columnNode.updateLayout(size: columnFrame.size, transition: transition)

                if index < self.separatorNodes.count {
                    transition.updateFrame(node: self.separatorNodes[index], frame: CGRect(
                        origin: CGPoint(x: columnFrame.maxX - UIScreenPixel, y: 8.0),
                        size: CGSize(width: UIScreenPixel, height: size.height - 16.0)
                    ))
                }
            }
        })
    }

    func updateTheme(presentationData: PresentationData) {
        for columnNode in self.columnNodes {
            columnNode.applyTheme(presentationData: presentationData)
        }
        for separatorNode in self.separatorNodes {
            separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
        }
    }

    // Highlighting is handled per column by the tap gesture, not by the menu as a whole.
    func canBeHighlighted() -> Bool {
        return false
    }

    func updateIsHighlighted(isHighlighted: Bool) {
    }

    func performAction() {
    }
}
