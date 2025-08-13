import AppKit
import Common

@MainActor
private var resizeWithMouseTask: Task<(), any Error>? = nil

func resizedObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    let notif = notif as String
    let windowId = ax.containingWindowId()
    Task { @MainActor in
        guard let token: RunSessionGuard = .isServerEnabled else { return }
        guard let windowId, let window = Window.get(byId: windowId), try await isManipulatedWithMouse(window) else {
            runRefreshSession(.ax(notif))
            return
        }
        resizeWithMouseTask?.cancel()
        resizeWithMouseTask = Task {
            try checkCancellation()
            try await runSession(.ax(notif), token) {
                try await resizeWithMouse(window)
            }
        }
    }
}

@MainActor
func resetManipulatedWithMouseIfPossible() async throws {
    if currentlyManipulatedWithMouseWindowId != nil {
        currentlyManipulatedWithMouseWindowId = nil
        for workspace in Workspace.all {
            workspace.resetResizeWeightBeforeResizeRecursive()
        }
        runRefreshSession(.resetManipulatedWithMouse, optimisticallyPreLayoutWorkspaces: true)
    }
}

private let adaptiveWeightBeforeResizeWithMouseKey = TreeNodeUserDataKey<CGFloat>(key: "adaptiveWeightBeforeResizeWithMouseKey")

@MainActor
private func resizeWithMouse(_ window: Window) async throws { // todo cover with tests
    resetClosedWindowsCache()
    guard let parent = window.parent else { return }
    switch parent.cases {
        case .workspace, .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
             .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
            return // Nothing to do for floating, or unconventional windows
        case .tilingContainer:
            guard let rect = try await window.getAxRect() else { return }
            guard let lastAppliedLayoutRect = window.lastAppliedLayoutPhysicalRect else { return }
            let (lParent, lOwnIndex) = window.closestParent(hasChildrenInDirection: .left, withLayout: nil) ?? (nil, nil)
            let (dParent, dOwnIndex) = window.closestParent(hasChildrenInDirection: .down, withLayout: nil) ?? (nil, nil)
            let (uParent, uOwnIndex) = window.closestParent(hasChildrenInDirection: .up, withLayout: nil) ?? (nil, nil)
            let (rParent, rOwnIndex) = window.closestParent(hasChildrenInDirection: .right, withLayout: nil) ?? (nil, nil)
            let table: [(CGFloat, TilingContainer?, Int?, Int?)] = [
                (lastAppliedLayoutRect.minX - rect.minX, lParent, 0,                        lOwnIndex),               // Horizontal, to the left of the window
                (rect.maxY - lastAppliedLayoutRect.maxY, dParent, dOwnIndex.map { $0 + 1 }, dParent?.children.count), // Vertical, to the down of the window
                (lastAppliedLayoutRect.minY - rect.minY, uParent, 0,                        uOwnIndex),               // Vertical, to the up of the window
                (rect.maxX - lastAppliedLayoutRect.maxX, rParent, rOwnIndex.map { $0 + 1 }, rParent?.children.count), // Horizontal, to the right of the window
            ]
            for (diff, parent, startIndex, pastTheEndIndex) in table {
                if let parent, let startIndex, let pastTheEndIndex, pastTheEndIndex - startIndex > 0 && abs(diff) > 5 { // 5 pixels should be enough to fight with accumulated floating precision error
                    let siblingDiff = diff.div(pastTheEndIndex - startIndex).orDie()
                    let orientation = parent.orientation

                    // Handle BSP layout differently from tiles layout
                    if parent.layout == .bsp {
                        // For BSP layout, we need to adjust weights proportionally
                        // because BSP uses proportional sizing (weight / totalWeight)
                        handleBSPMouseResize(window: window, parent: parent, diff: diff, orientation: orientation, startIndex: startIndex, pastTheEndIndex: pastTheEndIndex)
                    } else {
                        // Original logic for tiles layout
                        window.parentsWithSelf.lazy
                            .prefix(while: { $0 != parent })
                            .filter {
                                let parent = $0.parent as? TilingContainer
                                return parent?.orientation == orientation && parent?.layout == .tiles
                            }
                            .forEach { $0.setWeight(orientation, $0.getWeightBeforeResize(orientation) + diff) }
                        for sibling in parent.children[startIndex ..< pastTheEndIndex] {
                            sibling.setWeight(orientation, sibling.getWeightBeforeResize(orientation) - siblingDiff)
                        }
                    }
                }
            }
            currentlyManipulatedWithMouseWindowId = window.windowId
    }
}

@MainActor
private func handleBSPMouseResize(
    window: Window,
    parent: TilingContainer,
    diff: CGFloat,
    orientation: Orientation,
    startIndex: Int,
    pastTheEndIndex: Int
) {
    // For BSP layout, we need to handle proportional weight adjustments
    // Get the current container dimensions to calculate proportional changes
    guard let containerRect = parent.lastAppliedLayoutVirtualRect else { return }
    
    let containerSize = containerRect.getDimension(orientation)
    guard containerSize > 0 else { return }
    
    // Calculate the proportional change based on pixel difference
    let proportionalChange = diff / containerSize
    
    // Find the target window in the parent's children
    let targetWindows = window.parentsWithSelf.lazy
        .prefix(while: { $0 != parent })
        .filter {
            let parent = $0.parent as? TilingContainer
            return parent?.orientation == orientation && parent?.layout == .bsp
        }
    
    // Get current total weight for proportional calculations
    let currentTotalWeight = parent.children.sumOfDouble { $0.getWeightBeforeResize(orientation) }
    guard currentTotalWeight > 0 else { return }
    
    // Adjust weights proportionally
    for targetWindow in targetWindows {
        let currentWeight = targetWindow.getWeightBeforeResize(orientation)
        let currentProportion = currentWeight / currentTotalWeight
        
        // Calculate new weight based on proportional change
        let newProportion = currentProportion + proportionalChange
        let newWeight = max(0.1, newProportion * currentTotalWeight) // Ensure minimum weight
        
        targetWindow.setWeight(orientation, newWeight)
    }
    
    // Adjust sibling weights to compensate
    let siblingCount = pastTheEndIndex - startIndex
    if siblingCount > 0 {
        let siblingProportionalChange = -proportionalChange / CGFloat(siblingCount)
        
        for sibling in parent.children[startIndex ..< pastTheEndIndex] {
            let currentWeight = sibling.getWeightBeforeResize(orientation)
            let currentProportion = currentWeight / currentTotalWeight
            
            let newProportion = currentProportion + siblingProportionalChange
            let newWeight = max(0.1, newProportion * currentTotalWeight) // Ensure minimum weight
            
            sibling.setWeight(orientation, newWeight)
        }
    }
}

extension TreeNode {
    @MainActor
    fileprivate func getWeightBeforeResize(_ orientation: Orientation) -> CGFloat {
        let currentWeight = getWeight(orientation) // Check assertions
        return getUserData(key: adaptiveWeightBeforeResizeWithMouseKey)
            ?? (lastAppliedLayoutVirtualRect?.getDimension(orientation) ?? currentWeight)
            .also { putUserData(key: adaptiveWeightBeforeResizeWithMouseKey, data: $0) }
    }

    fileprivate func resetResizeWeightBeforeResizeRecursive() {
        cleanUserData(key: adaptiveWeightBeforeResizeWithMouseKey)
        for child in children {
            child.resetResizeWeightBeforeResizeRecursive()
        }
    }
}
