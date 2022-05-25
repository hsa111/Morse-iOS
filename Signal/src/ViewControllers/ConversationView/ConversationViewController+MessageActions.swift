//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

extension ConversationViewController {

    func presentMessageActions(_ messageActions: [MessageAction],
                               withFocusedCell cell: UICollectionViewCell,
                               itemViewModel: CVItemViewModelImpl) {
        guard let window = view.window,
              let navigationController = navigationController else {
            owsFailDebug("Missing window or navigationController.")
            return
        }
        if FeatureFlags.contextMenus {
            let keyboardActive = inputToolbar?.isInputViewFirstResponder() ?? false
            let interaction = ChatHistoryContextMenuInteraction(delegate: self, itemViewModel: itemViewModel, thread: thread, messageActions: messageActions, initiatingGestureRecognizer: collectionViewContextMenuGestureRecognizer, keyboardWasActive: keyboardActive)
            collectionViewActiveContextMenuInteraction = interaction
            cell.addInteraction(interaction)
            let cellCenterPoint = cell.frame.center
            let screenPoint = self.collectionView .convert(cellCenterPoint, from: cell)
            var presentImmediately = false
            if let secondaryClickRecognizer = collectionViewContextMenuSecondaryClickRecognizer, secondaryClickRecognizer.state == .ended {
                presentImmediately = true
            }
            interaction.initiateContextMenuGesture(locationInView: screenPoint, presentImmediately: presentImmediately)
        } else {
            let messageActionsViewController = MessageActionsViewController(itemViewModel: itemViewModel,
                                                                            focusedView: cell,
                                                                            actions: messageActions)
            messageActionsViewController.delegate = self

            self.messageActionsViewController = messageActionsViewController

            setupMessageActionsState(forCell: cell)

            messageActionsViewController.present(on: window,
                                                 prepareConstraints: {
                                                    // In order to ensure the bottom bar remains above the keyboard, we pin it
                                                    // to our bottom bar which follows the inputAccessoryView
                                                    messageActionsViewController.bottomBar.autoPinEdge(.bottom,
                                                                                                       to: .bottom,
                                                                                                       of: self.bottomBar)

                                                    // We only want the message actions to show up over the detail view, in
                                                    // the case where we are expanded. So match its edges to our nav controller.
                                                    messageActionsViewController.view.autoPinEdges(toEdgesOf: navigationController.view)
                                                 },
                                                 animateAlongside: {
                                                    self.bottomBar.alpha = 0
                                                 },
                                                 completion: nil)
        }
    }

    func updateMessageActionsState(forCell cell: UIView) {
        // While presenting message actions, cache the original content offset.
        // This allows us to restore the user to their original scroll position
        // when they dismiss the menu.
        self.messageActionsOriginalContentOffset = self.collectionView.contentOffset
        self.messageActionsOriginalFocusY = self.view.convert(cell.frame.origin, from: self.collectionView).y
    }

    func setupMessageActionsState(forCell cell: UIView) {
        guard let navigationController = navigationController else {
            owsFailDebug("Missing navigationController.")
            return
        }
        updateMessageActionsState(forCell: cell)

        // While the menu actions are presented, temporarily use extra content
        // inset padding so that interactions near the top or bottom of the
        // collection view can be scrolled anywhere within the viewport.
        // This allows us to keep the message position constant even when
        // messages dissappear above / below the focused message to the point
        // that we have less than one screen worth of content.
        let navControllerSize = navigationController.view.frame.size
        self.messageActionsExtraContentInsetPadding = max(navControllerSize.width, navControllerSize.height)

        var contentInset = self.collectionView.contentInset
        contentInset.top += self.messageActionsExtraContentInsetPadding
        contentInset.bottom += self.messageActionsExtraContentInsetPadding
        self.collectionView.contentInset = contentInset
    }

    func clearMessageActionsState() {
        self.bottomBar.alpha = 1

        var contentInset = self.collectionView.contentInset
        contentInset.top -= self.messageActionsExtraContentInsetPadding
        contentInset.bottom -= self.messageActionsExtraContentInsetPadding
        self.collectionView.contentInset = contentInset

        // TODO: This isn't safe. We should capture a token that represents scroll state.
        self.collectionView.contentOffset = self.messageActionsOriginalContentOffset
        self.messageActionsOriginalContentOffset = .zero
        self.messageActionsExtraContentInsetPadding = 0
        self.messageActionsViewController = nil
    }

    public var isPresentingMessageActions: Bool {
        self.messageActionsViewController != nil
    }

    public var isPresentingContextMenu: Bool {
        if let interaction = viewState.collectionViewActiveContextMenuInteraction, interaction.contextMenuVisible {
            return true
        }

        return false
    }

    @objc
    public func dismissMessageContextMenu(animated: Bool) {
        if let collectionViewActiveContextMenuInteraction = self.collectionViewActiveContextMenuInteraction {
            collectionViewActiveContextMenuInteraction.dismissMenu(animated: animated, completion: { })
        }
    }

    @objc
    public func dismissMessageActions(animated: Bool) {
        dismissMessageActions(animated: animated, completion: nil)
    }

    public typealias MessageActionsCompletion = () -> Void

    public func dismissMessageActions(animated: Bool, completion: MessageActionsCompletion?) {
        Logger.verbose("")

        guard let messageActionsViewController = messageActionsViewController else {
            return
        }

        if animated {
            messageActionsViewController.dismiss(animateAlongside: {
                self.bottomBar.alpha = 1
            }, completion: {
                self.clearMessageActionsState()
                completion?()
            })
        } else {
            messageActionsViewController.dismissWithoutAnimating()
            clearMessageActionsState()
            completion?()
        }
    }

    func dismissMessageActionsIfNecessary() {
        if shouldDismissMessageActions {
            dismissMessageActions(animated: true)
        }
    }

    func dismissMessageContextMenuIfNecessary() {
        if shouldDismissMessageContextMenu {
            dismissMessageContextMenu(animated: true)
        }
    }

    var shouldDismissMessageActions: Bool {
        guard let messageActionsViewController = messageActionsViewController else {
            return false
        }
        let messageActionInteractionId = messageActionsViewController.focusedInteraction.uniqueId
        // Check whether there is still a view item for this interaction.
        return self.indexPath(forInteractionUniqueId: messageActionInteractionId) == nil
    }

    var shouldDismissMessageContextMenu: Bool {
        guard let collectionViewActiveContextMenuInteraction = self.collectionViewActiveContextMenuInteraction else {
            return false
        }

        let messageActionInteractionId = collectionViewActiveContextMenuInteraction.itemViewModel.interaction.uniqueId
        // Check whether there is still a view item for this interaction.
        return self.indexPath(forInteractionUniqueId: messageActionInteractionId) == nil
    }

    public func reloadReactionsDetailSheet(transaction: SDSAnyReadTransaction) {
        AssertIsOnMainThread()

        guard let reactionsDetailSheet = self.reactionsDetailSheet else {
            return
        }

        let messageId = reactionsDetailSheet.messageId

        guard let indexPath = self.indexPath(forInteractionUniqueId: messageId),
              let renderItem = self.renderItem(forIndex: indexPath.row) else {
            // The message no longer exists, dismiss the sheet.
            dismissReactionsDetailSheet(animated: true)
            return
        }
        guard let reactionState = renderItem.reactionState,
              reactionState.hasReactions else {
            // There are no longer reactions on this message, dismiss the sheet.
            dismissReactionsDetailSheet(animated: true)
            return
        }

        // Update the detail sheet with the latest reaction
        // state, in case the reactions have changed.
        reactionsDetailSheet.setReactionState(reactionState, transaction: transaction)
    }

    public func dismissReactionsDetailSheet(animated: Bool) {
        AssertIsOnMainThread()

        guard let reactionsDetailSheet = self.reactionsDetailSheet else {
            return
        }

        reactionsDetailSheet.dismiss(animated: animated) {
            self.reactionsDetailSheet = nil
        }
    }
}

extension ConversationViewController: ContextMenuInteractionDelegate {

    public func contextMenuInteraction(
        _ interaction: ContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint) -> ContextMenuConfiguration? {

        return ContextMenuConfiguration(identifier: UUID() as NSCopying, actionProvider: { _ in

            var contextMenuActions: [ContextMenuAction] = []
            if let actions = self.collectionViewActiveContextMenuInteraction?.messageActions {
                let actionOrder: [MessageAction.MessageActionType] = [.reply, .forward, .copy, .share, .select, .info, .delete]
                for type in actionOrder {
                    let actionWithType = actions.first { $0.actionType == type }
                    if let messageAction = actionWithType {
                        let contextMenuAction = ContextMenuAction(title: messageAction.contextMenuTitle, image: messageAction.image, attributes: messageAction.contextMenuAttributes, handler: { _ in
                            messageAction.block(nil)
                        })

                        contextMenuActions.append(contextMenuAction)
                    }
                }
            }

            return ContextMenu(contextMenuActions)
        })
    }

    public func contextMenuInteraction(
        _ interaction: ContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration configuration: ContextMenuConfiguration) -> ContextMenuTargetedPreview? {

        guard let contextInteraction = interaction as? ChatHistoryContextMenuInteraction else {
            owsFailDebug("Expected ChatHistoryContextMenuInteraction.")
            return nil
        }

        guard let cell = contextInteraction.view as? CVCell else {
            owsFailDebug("Expected context interaction view to be of CVCell type")
            return nil
        }

        guard let componentView = cell.componentView else {
            owsFailDebug("Expected cell to have component view")
            return nil
        }

        var accessories = cell.rootComponent?.contextMenuAccessoryViews(componentView: componentView) ?? []

        // Add reaction bar if necessary
        if thread.canSendReactionToThread && shouldShowReactionPickerForInteraction(contextInteraction.itemViewModel.interaction) {
            let reactionBarAccessory = ContextMenuRectionBarAccessory(thread: self.thread, itemViewModel: contextInteraction.itemViewModel)
            reactionBarAccessory.didSelectReactionHandler = {(message: TSMessage, reaction: String, isRemoving: Bool) in
                self.databaseStorage.asyncWrite { transaction in
                    ReactionManager.localUserReacted(
                        to: message,
                        emoji: reaction,
                        isRemoving: isRemoving,
                        transaction: transaction
                    )
                }
            }
            accessories.append(reactionBarAccessory)
        }

        var alignment: ContextMenuTargetedPreview.Alignment = .center
        let interactionType = contextInteraction.itemViewModel.interaction.interactionType
        let isRTL = CurrentAppContext().isRTL
        if interactionType == .incomingMessage {
            alignment = isRTL ? .right : .left
        } else if interactionType == .outgoingMessage {
            alignment = isRTL ? .left : .right
        }

        if let componentView = cell.componentView, let contentView = componentView.contextMenuContentView?() {
            let preview = ContextMenuTargetedPreview(view: contentView, alignment: alignment, accessoryViews: accessories)
            preview.auxiliaryView = componentView.contextMenuAuxiliaryContentView?()
            return preview
        } else {
            return ContextMenuTargetedPreview(view: cell, alignment: alignment, accessoryViews: accessories)

        }
    }

    public func contextMenuInteraction(_ interaction: ContextMenuInteraction, willDisplayMenuForConfiguration: ContextMenuConfiguration) {
        // Reset scroll view pan gesture recognizer, so CV does not scroll behind context menu post presentation on user swipe
        collectionView.panGestureRecognizer.isEnabled = false
        collectionView.panGestureRecognizer.isEnabled = true

        if let contextInteraction = interaction as? ChatHistoryContextMenuInteraction, let cell = contextInteraction.view as? CVCell, let componentView = cell.componentView {
            componentView.contextMenuPresentationWillBegin?()
        }

        dismissKeyBoard()
    }

    public func contextMenuInteraction(_ interaction: ContextMenuInteraction, willEndForConfiguration: ContextMenuConfiguration) {

    }

    public func contextMenuInteraction(_ interaction: ContextMenuInteraction, didEndForConfiguration: ContextMenuConfiguration) {
        if let contextInteraction = interaction as? ChatHistoryContextMenuInteraction, let cell = contextInteraction.view as? CVCell, let componentView = cell.componentView {
            componentView.contextMenuPresentationDidEnd?()

            // Restore the keyboard unless the context menu item presented
            // a view controller.
            if contextInteraction.keyboardWasActive {
                if self.presentedViewController == nil {
                    popKeyBoard()
                } else {
                    // If we're not going to restore the keyboard, update
                    // chat history layout.
                    self.loadCoordinator.enqueueReload()
                }
            }
        }

        collectionViewActiveContextMenuInteraction = nil
    }

}
