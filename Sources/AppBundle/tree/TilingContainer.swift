import AppKit
import Common

class TilingContainer: TreeNode, NonLeafTreeNodeObject { // todo consider renaming to GenericContainer
    fileprivate var _orientation: Orientation
    var orientation: Orientation { _orientation }
    var layout: Layout

    @MainActor
    init(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, _ orientation: Orientation, _ layout: Layout, index: Int) {
        self._orientation = orientation
        self.layout = layout
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor
    static func newHTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) -> TilingContainer {
        TilingContainer(parent: parent, adaptiveWeight: adaptiveWeight, .h, .tiles, index: index)
    }

    @MainActor
    static func newVTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) -> TilingContainer {
        TilingContainer(parent: parent, adaptiveWeight: adaptiveWeight, .v, .tiles, index: index)
    }
}

extension TilingContainer {
    var isRootContainer: Bool { parent is Workspace }

    @MainActor
    func changeOrientation(_ targetOrientation: Orientation) {
        if orientation == targetOrientation {
            return
        }
        if config.enableNormalizationOppositeOrientationForNestedContainers {
            var orientation = targetOrientation
            parentsWithSelf
                .filterIsInstance(of: TilingContainer.self)
                .forEach {
                    $0._orientation = orientation
                    orientation = orientation.opposite
                }
        } else {
            _orientation = targetOrientation
        }
    }

    func normalizeOppositeOrientationForNestedContainers() {
        if orientation == (parent as? TilingContainer)?.orientation {
            _orientation = orientation.opposite
        }
        for child in children {
            (child as? TilingContainer)?.normalizeOppositeOrientationForNestedContainers()
        }
    }

    // MARK: - BSP Layout Support

    /// Chooses the optimal split direction for BSP layout based on container dimensions and configuration
    /// - Parameters:
    ///   - width: The width of the container
    ///   - height: The height of the container
    /// - Returns: The optimal orientation for splitting (.h for horizontal, .v for vertical)

    // MARK: - BSP Weight Conversion Utilities



    /// Validates and clamps weight values for BSP layout
    private static func validateBSPWeight(_ weight: CGFloat) -> CGFloat {
        let minWeight: CGFloat = 0.1  // 10% minimum
        let maxWeight: CGFloat = 0.9  // 90% maximum
        return max(minWeight, min(maxWeight, weight))
    }

    @MainActor
    func chooseBSPSplitDirection(width: CGFloat, height: CGFloat) -> Orientation {
        let bspConfig = config.bsp

        // If user has a preferred split direction, use it
        if let preferredDirection = bspConfig.preferredSplitDirection {
            return preferredDirection
        }

        // Calculate aspect ratio
        let aspectRatio = width / height
        let threshold = bspConfig.autoSplitThreshold

        // If width is significantly larger than height, split vertically (creating horizontal strips)
        if aspectRatio > threshold {
            return .v
        }
        // If height is significantly larger than width, split horizontally (creating vertical strips)
        else if aspectRatio < (1.0 / threshold) {
            return .h
        }
        // For roughly square containers, alternate based on current orientation
        else {
            return orientation.opposite
        }
    }

    /// Inserts a new window into the BSP layout by splitting an existing window or container
    /// - Parameters:
    ///   - newWindow: The window to insert
    ///   - targetWindow: The window to split (if nil, uses most recent window)
    /// - Returns: The binding data for the new window
    @MainActor
    func insertWindowBSP(_ newWindow: Window, relativeTo targetWindow: Window?) -> BindingData {
        // Try to use the safe split method with error handling
        do {
            let containerRect = lastAppliedLayoutVirtualRect
            return try safeBSPSplit(newWindow, relativeTo: targetWindow, containerRect: containerRect)
        } catch let error as BSPError {
            // Log the error for debugging
            Self.logBSPError(error)

            // Attempt to recover from the error
            if handleBSPError(error) {
                // Retry the split after recovery
                do {
                    let containerRect = lastAppliedLayoutVirtualRect
                    return try safeBSPSplit(newWindow, relativeTo: targetWindow, containerRect: containerRect)
                } catch {
                    // If retry fails, fall back to simple insertion
                    return fallbackBSPInsertion(newWindow, relativeTo: targetWindow)
                }
            } else {
                // If recovery fails, fall back to simple insertion
                return fallbackBSPInsertion(newWindow, relativeTo: targetWindow)
            }
        } catch {
            // Handle unexpected errors
            print("Unexpected error during BSP split: \(error)")
            return fallbackBSPInsertion(newWindow, relativeTo: targetWindow)
        }
    }

    /// Fallback insertion method when BSP split fails
    /// - Parameters:
    ///   - newWindow: The window to insert
    ///   - targetWindow: The target window (may be ignored in fallback)
    /// - Returns: The binding data for the new window
    @MainActor
    private func fallbackBSPInsertion(_ newWindow: Window, relativeTo targetWindow: Window?) -> BindingData {
        // Simple fallback: add to the end of the current container
        return BindingData(parent: self, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    /// Finds the best insertion point for a new window in BSP layout
    /// - Parameter workspace: The workspace to search in
    /// - Returns: The binding data for the new window
    @MainActor
    static func getBSPInsertionPoint(in workspace: Workspace, for newWindow: Window?) -> BindingData {
        let rootContainer = workspace.rootTilingContainer

        // If root container is not BSP, use default insertion
        guard rootContainer.layout == .bsp else {
            return BindingData(parent: rootContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }

        // Find the most recently used window
        let mruWindow = workspace.mostRecentWindowRecursive

        guard let mruWindow else {
            // No windows exist, add to root container
            return BindingData(parent: rootContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }

        // Find the container that holds the MRU window
        var currentContainer = mruWindow.parent as? TilingContainer

        // Traverse up to find a BSP container
        while let container = currentContainer {
            if container.layout == .bsp {
                return container.insertWindowBSP(newWindow ?? mruWindow, relativeTo: mruWindow)
            }
            currentContainer = container.parent as? TilingContainer
        }

        // Fallback to root container
        return BindingData(parent: rootContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    // MARK: - BSP Tree Structure Optimization

    /// Optimizes the BSP tree structure by removing unnecessary containers and merging adjacent spaces
    /// This should be called after window removal or movement operations
    @MainActor
    func optimizeBSPTreeStructure() {
        guard layout == .bsp else { return }

        // First, recursively optimize all child containers
        for child in children {
            (child as? TilingContainer)?.optimizeBSPTreeStructure()
        }

        // Handle single child containers - merge them with parent if possible
        if let singleChild = children.singleOrNil() {
            optimizeSingleChildBSPContainer(child: singleChild)
            return
        }

        // Handle empty containers
        if children.isEmpty && !isRootContainer {
            // Empty non-root containers should be removed
            unbindFromParent()
            return
        }

        // Handle containers with only two children - check if they can be simplified
        if children.count == 2 {
            optimizeTwoChildBSPContainer()
        }
    }

    /// Optimizes a BSP container that has only one child
    /// - Parameter child: The single child node
    @MainActor
    private func optimizeSingleChildBSPContainer(child: TreeNode) {
        // If this container has only one child, we can potentially eliminate this container
        // and move the child up to our parent

        guard !isRootContainer else {
            // Root containers with single child are kept but may need layout adjustment
            if let childContainer = child as? TilingContainer, childContainer.layout == .bsp {
                // If the child is also a BSP container, we can flatten the structure
                if config.enableNormalizationFlattenContainers {
                    _ = child.unbindFromParent()
                    let ourBinding = unbindFromParent()
                    child.bind(to: ourBinding.parent, adaptiveWeight: ourBinding.adaptiveWeight, index: ourBinding.index)
                }
            }
            return
        }

        // For non-root containers, always try to eliminate unnecessary nesting
        _ = child.unbindFromParent()
        let ourBinding = unbindFromParent()

        // Move the child to our parent's position
        child.bind(to: ourBinding.parent, adaptiveWeight: ourBinding.adaptiveWeight, index: ourBinding.index)

        // If the child is a container, continue optimization
        (child as? TilingContainer)?.optimizeBSPTreeStructure()
    }

    /// Optimizes a BSP container that has exactly two children
    @MainActor
    private func optimizeTwoChildBSPContainer() {
        guard children.count == 2 else { return }

        let firstChild = children[0]
        let secondChild = children[1]

        // Check if both children are BSP containers with the same orientation as us
        if let firstContainer = firstChild as? TilingContainer,
           let secondContainer = secondChild as? TilingContainer,
           firstContainer.layout == .bsp,
           secondContainer.layout == .bsp,
           firstContainer.orientation == orientation,
           secondContainer.orientation == orientation
        {

            // We can potentially merge these containers to reduce nesting
            // This is an advanced optimization that should be done carefully
            attemptBSPContainerMerge(first: firstContainer, second: secondContainer)
        }
    }

    /// Attempts to merge two BSP containers with the same orientation
    /// - Parameters:
    ///   - first: The first BSP container
    ///   - second: The second BSP container
    @MainActor
    private func attemptBSPContainerMerge(first: TilingContainer, second: TilingContainer) {
        // Only merge if both containers have reasonable number of children
        // to avoid creating overly wide containers
        let totalChildren = first.children.count + second.children.count
        guard totalChildren <= 4 else { return } // Arbitrary limit to maintain usability

        // Calculate weight distribution for merged children
        let firstWeight = first.getWeight(orientation)
        let secondWeight = second.getWeight(orientation)
        _ = firstWeight + secondWeight

        // Unbind children from their current containers
        var childrenToMerge: [(TreeNode, CGFloat)] = []

        // Collect children from first container
        for child in first.children {
            let childWeight = child.getWeight(first.orientation)
            let adjustedWeight = (childWeight / first.children.map { $0.getWeight(first.orientation) }.reduce(0, +)) * firstWeight
            childrenToMerge.append((child, adjustedWeight))
        }

        // Collect children from second container
        for child in second.children {
            let childWeight = child.getWeight(second.orientation)
            let adjustedWeight = (childWeight / second.children.map { $0.getWeight(second.orientation) }.reduce(0, +)) * secondWeight
            childrenToMerge.append((child, adjustedWeight))
        }

        // Unbind the old containers
        first.unbindFromParent()
        second.unbindFromParent()

        // Bind all children directly to this container
        for (index, (child, weight)) in childrenToMerge.enumerated() {
            child.unbindFromParent()
            child.bind(to: self, adaptiveWeight: weight, index: index)
        }
    }

    /// Validates that the BSP tree structure is consistent and fixes any issues
    /// - Returns: True if the structure was valid or successfully fixed, false if unfixable issues were found
    @MainActor
    @discardableResult
    func validateBSPTreeStructure() -> Bool {
        guard layout == .bsp else { return true }

        var isValid = true

        // Validate all child containers recursively
        for child in children {
            if let childContainer = child as? TilingContainer {
                if !childContainer.validateBSPTreeStructure() {
                    isValid = false
                }
            }
        }

        // Check for common BSP tree issues

        // Issue 1: Empty containers (except root)
        if children.isEmpty && !isRootContainer {
            // This container should be removed
            unbindFromParent()
            return false
        }

        // Issue 2: Single child containers that can be flattened
        if children.singleOrNil() != nil, !isRootContainer {
            if config.enableNormalizationFlattenContainers {
                // This indicates the structure needs optimization
                isValid = false
            }
        }

        // Issue 3: Invalid weight distribution
        let totalWeight = children.map { $0.getWeight(orientation) }.reduce(0, +)
        if totalWeight <= 0 {
            // Fix by redistributing weights equally
            let equalWeight = 1.0 / CGFloat(max(1, children.count))
            for child in children {
                child.setWeight(orientation, equalWeight)
            }
        }

        return isValid
    }

    /// Checks if a BSP split would result in windows that are too small
    /// - Parameters:
    ///   - containerWidth: The width of the container to split
    ///   - containerHeight: The height of the container to split
    ///   - splitDirection: The direction of the proposed split
    /// - Returns: True if the split would create acceptable window sizes
    @MainActor
    func validateBSPSplitSize(containerWidth: CGFloat, containerHeight: CGFloat, splitDirection: Orientation) -> Bool {
        let minWindowSize: CGFloat = 100.0 // Minimum window dimension in points

        switch splitDirection {
            case .h:
                // Horizontal split creates vertically stacked windows
                let resultingHeight = containerHeight * config.bsp.splitRatio
                return resultingHeight >= minWindowSize && (containerHeight - resultingHeight) >= minWindowSize
            case .v:
                // Vertical split creates horizontally arranged windows
                let resultingWidth = containerWidth * config.bsp.splitRatio
                return resultingWidth >= minWindowSize && (containerWidth - resultingWidth) >= minWindowSize
        }
    }

    /// Automatically adjusts BSP split strategy when windows would become too small
    /// - Parameters:
    ///   - containerWidth: The width of the container
    ///   - containerHeight: The height of the container
    /// - Returns: The adjusted split direction, or nil if no split should be made
    @MainActor
    func adjustBSPSplitStrategy(containerWidth: CGFloat, containerHeight: CGFloat) -> Orientation? {
        // Try the preferred split direction first
        let preferredDirection = chooseBSPSplitDirection(width: containerWidth, height: containerHeight)

        if validateBSPSplitSize(containerWidth: containerWidth, containerHeight: containerHeight, splitDirection: preferredDirection) {
            return preferredDirection
        }

        // Try the opposite direction
        let alternateDirection = preferredDirection.opposite
        if validateBSPSplitSize(containerWidth: containerWidth, containerHeight: containerHeight, splitDirection: alternateDirection) {
            return alternateDirection
        }

        // If neither direction works, don't split
        return nil
    }

    // MARK: - BSP Error Handling

    /// Handles BSP-specific errors that may occur during layout operations
    enum BSPError: Error, LocalizedError {
        case splitFailed(reason: String)
        case windowTooSmall(minSize: CGFloat, actualSize: CGFloat)
        case layoutTransitionFailed(from: Layout, to: Layout, reason: String)
        case invalidTreeStructure(reason: String)
        case configurationError(reason: String)

        var errorDescription: String? {
            switch self {
                case .splitFailed(let reason):
                    return "BSP split failed: \(reason)"
                case .windowTooSmall(let minSize, let actualSize):
                    return "Window too small: minimum \(minSize)pt required, got \(actualSize)pt"
                case .layoutTransitionFailed(let from, let to, let reason):
                    return "Layout transition from \(from) to \(to) failed: \(reason)"
                case .invalidTreeStructure(let reason):
                    return "Invalid BSP tree structure: \(reason)"
                case .configurationError(let reason):
                    return "BSP configuration error: \(reason)"
            }
        }
    }



    /// Safely attempts to split a BSP container with comprehensive error handling
    /// - Parameters:
    ///   - newWindow: The window to insert
    ///   - targetWindow: The window to split (if nil, uses most recent window)
    ///   - containerRect: The current container dimensions
    /// - Returns: The binding data for the new window, or throws BSPError
    @MainActor
    func safeBSPSplit(_ newWindow: Window, relativeTo targetWindow: Window?, containerRect: Rect?) throws -> BindingData {
        // Validate that we can perform a split
        guard layout == .bsp else {
            throw BSPError.layoutTransitionFailed(from: layout, to: .bsp, reason: "Container is not in BSP layout mode")
        }

        // Find the target window to split
        let windowToSplit = targetWindow ?? mostRecentWindowRecursive

        guard let windowToSplit else {
            // If no windows exist, add to root container (this is safe)
            return BindingData(parent: self, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }

        // Get the parent container of the window to split
        guard let parentContainer = windowToSplit.parent as? TilingContainer else {
            throw BSPError.splitFailed(reason: "Target window is not in a tiling container")
        }

        // Validate container dimensions if available
        if let rect = containerRect ?? parentContainer.lastAppliedLayoutVirtualRect {
            // Check if the container is large enough for any split
            let minContainerSize: CGFloat = 200.0 // Minimum container size for splitting
            if rect.width < minContainerSize || rect.height < minContainerSize {
                throw BSPError.windowTooSmall(minSize: minContainerSize, actualSize: min(rect.width, rect.height))
            }

            // Try to find a valid split direction
            guard let splitDirection = parentContainer.adjustBSPSplitStrategy(containerWidth: rect.width, containerHeight: rect.height) else {
                throw BSPError.splitFailed(reason: "No valid split direction found - container too small")
            }

            // Perform the split with the validated direction
            return try performBSPSplit(newWindow, relativeTo: windowToSplit, direction: splitDirection, in: parentContainer)
        } else {
            // Fallback to basic split without size validation
            return try performBSPSplit(newWindow, relativeTo: windowToSplit, direction: nil, in: parentContainer)
        }
    }

    /// Performs the actual BSP split operation
    /// - Parameters:
    ///   - newWindow: The window to insert
    ///   - targetWindow: The window to split
    ///   - direction: The split direction (if nil, will be determined automatically)
    ///   - parentContainer: The container to split in
    /// - Returns: The binding data for the new window
    @MainActor
    private func performBSPSplit(_ newWindow: Window, relativeTo targetWindow: Window, direction: Orientation?, in parentContainer: TilingContainer) throws -> BindingData {
        let windowToSplitIndex = targetWindow.ownIndex ?? INDEX_BIND_LAST

        // Determine split direction
        let splitDirection: Orientation = if let direction {
            direction
        } else {
            // Fallback: alternate based on parent's orientation
            parentContainer.orientation.opposite
        }

        // Validate split ratio configuration
        let splitRatio = config.bsp.splitRatio
        guard splitRatio > 0.1 && splitRatio < 0.9 else {
            throw BSPError.configurationError(reason: "Invalid split ratio: \(splitRatio). Must be between 0.1 and 0.9")
        }

        // Create a new BSP container to hold both windows
        let newContainer = TilingContainer(
            parent: parentContainer,
            adaptiveWeight: targetWindow.getWeight(parentContainer.orientation),
            splitDirection,
            .bsp,
            index: windowToSplitIndex,
        )

        // Unbind the existing window from its parent
        _ = targetWindow.unbindFromParent()

        // Use BSP split ratio directly as weights
        let firstWeight = splitRatio
        let secondWeight = 1.0 - splitRatio

        // Validate weights
        guard firstWeight > 0 && secondWeight > 0 else {
            throw BSPError.configurationError(reason: "Invalid weight calculation from split ratio")
        }

        // Bind the existing window to the new container (first position)
        targetWindow.bind(to: newContainer, adaptiveWeight: firstWeight, index: 0)

        // Return binding data for the new window (second position)
        return BindingData(
            parent: newContainer,
            adaptiveWeight: secondWeight,
            index: 1,
        )
    }

    /// Safely transitions a container from one layout to BSP with error handling
    /// - Parameter targetLayout: The target BSP layout variant
    /// - Throws: BSPError if the transition fails
    @MainActor
    func safeTransitionToBSP(_ targetLayout: Layout) throws {
        guard targetLayout == .bsp else {
            throw BSPError.layoutTransitionFailed(from: layout, to: targetLayout, reason: "Target layout is not BSP")
        }

        let currentLayout = layout

        // Validate that transition is possible
        switch currentLayout {
            case .tiles, .accordion:
                // These transitions are generally safe
                break
            case .bsp:
                // Already BSP, no transition needed
                return
        }

        // Check if container has children that can be transitioned
        if !children.isEmpty {
            // Validate that all children are windows or containers that can be handled
            for child in children {
                if let childContainer = child as? TilingContainer {
                    // Nested containers should be compatible
                    if childContainer.layout == .bsp {
                        continue // Already BSP, good
                    }
                    // Other layouts can be transitioned
                } else if child is Window {
                    // Windows are always compatible
                    continue
                } else {
                    throw BSPError.layoutTransitionFailed(from: currentLayout, to: targetLayout, reason: "Unsupported child type: \(type(of: child))")
                }
            }
        }

        // Perform the transition
        layout = targetLayout

        // Validate the result
        if !validateBSPTreeStructure() {
            // Rollback on validation failure
            layout = currentLayout
            throw BSPError.layoutTransitionFailed(from: currentLayout, to: targetLayout, reason: "Tree structure validation failed after transition")
        }
    }

    /// Handles errors that occur during BSP operations by attempting recovery
    /// - Parameter error: The error that occurred
    /// - Returns: True if recovery was successful, false otherwise
    @MainActor
    func handleBSPError(_ error: BSPError) -> Bool {
        switch error {
            case .splitFailed:
                // For split failures, we can try to optimize the tree structure
                optimizeBSPTreeStructure()
                return validateBSPTreeStructure()

            case .windowTooSmall:
                // For size issues, we can try to rebalance weights
                return rebalanceBSPWeights()

            case .layoutTransitionFailed:
                // For transition failures, we can try to clean up the tree
                optimizeBSPTreeStructure()
                return validateBSPTreeStructure()

            case .invalidTreeStructure:
                // For structure issues, attempt to fix them
                optimizeBSPTreeStructure()
                return validateBSPTreeStructure()

            case .configurationError:
                // Configuration errors usually can't be recovered from automatically
                return false
        }
    }

    /// Rebalances BSP weights to ensure all windows have reasonable sizes
    /// - Returns: True if rebalancing was successful
    @MainActor
    private func rebalanceBSPWeights() -> Bool {
        guard layout == .bsp && !children.isEmpty else { return true }

        // Calculate equal weights for all children (normalized to sum to 1.0)
        let equalWeight = 1.0 / CGFloat(children.count)
        let validatedWeight = Self.validateBSPWeight(equalWeight)

        // Apply equal weights to all children
        for child in children {
            child.setWeight(orientation, validatedWeight)
        }

        // Verify the total weight is reasonable
        let totalWeight = children.map { $0.getWeight(orientation) }.reduce(0, +)
        return totalWeight > 0 && totalWeight <= 2.0 // Allow some tolerance
    }

    /// Logs BSP errors for debugging purposes
    /// - Parameter error: The error to log
    @MainActor
    static func logBSPError(_ error: BSPError) {
        // In a real implementation, this would use the app's logging system
        print("BSP Error: \(error.localizedDescription)")
    }
}

enum Layout: String {
    case tiles
    case accordion
    case bsp
}

extension String {
    func parseLayout() -> Layout? {
        if let parsed = Layout(rawValue: self) {
            return parsed
        } else if self == "list" {
            return .tiles
        } else {
            return nil
        }
    }
}
