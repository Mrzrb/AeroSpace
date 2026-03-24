import AppKit
import Common
import Foundation

private func appendToLog(_ message: String) {
    let timestamp = DateFormatter().string(from: Date())
    let logMessage = "[\(timestamp)] \(message)\n"
    
    if let data = logMessage.data(using: .utf8) {
        let url = URL(fileURLWithPath: "/tmp/aerospace.log")
        
        if FileManager.default.fileExists(atPath: url.path) {
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: url)
        }
    }
}

struct ResizeCommand: Command { // todo cover with tests
    let args: ResizeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    @MainActor
    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        // Log resize command start
        let logMessage = "ResizeCommand: Starting resize with dimension=\(args.dimension.val), units=\(args.units.val)"
        appendToLog(logMessage)
        
        guard let target = args.resolveTargetOrReportError(env, io) else { 
            appendToLog("ResizeCommand: Failed to resolve target")
            return false 
        }

        let candidates = target.windowOrNil?.parentsWithSelf
            .filter {
                let layout = ($0.parent as? TilingContainer)?.layout
                return layout == .tiles || layout == .bsp
            }
            ?? []
        
        appendToLog("ResizeCommand: Found \(candidates.count) candidates")

        // First, we need to determine the basic resize parameters to calculate diff
        let preliminaryResult = findPreliminaryResizeTarget(candidates: candidates, dimension: args.dimension.val)
        guard let preliminaryNode = preliminaryResult.node,
              let preliminaryParent = preliminaryResult.parent,
              let preliminaryOrientation = preliminaryResult.orientation else {
            appendToLog("ResizeCommand: No preliminary target found")
            return io.err("No suitable resize target found")
        }

        let currentWeight = preliminaryNode.getWeight(preliminaryOrientation)
        // Interpret resize values as percentages for consistent behavior across all weight values
        // e.g., resize +5 means "increase by 5%", resize -5 means "decrease by 5%"
        let diff: CGFloat = switch args.units.val {
            case .set(let unit): CGFloat(unit) - currentWeight  // Absolute set remains unchanged
            case .add(let unit): currentWeight * CGFloat(unit) / 100.0      // Percentage increase
            case .subtract(let unit): -currentWeight * CGFloat(unit) / 100.0 // Percentage decrease
        }

        // Now find the optimal resize target with the calculated diff
        let orientation: Orientation?
        let parent: TilingContainer?
        let node: TreeNode?
        switch args.dimension.val {
            case .width:
                orientation = .h
                let result = findBestResizeTarget(candidates: candidates, targetOrientation: .h, diff: diff)
                node = result.node
                parent = result.parent
            case .height:
                orientation = .v
                let result = findBestResizeTarget(candidates: candidates, targetOrientation: .v, diff: diff)
                node = result.node
                parent = result.parent
            case .smart:
                let result = findSmartResizeTarget(candidates: candidates, diff: diff)
                node = result.node
                parent = result.parent
                orientation = result.orientation
            case .smartOpposite:
                let result = findSmartOppositeResizeTarget(candidates: candidates, diff: diff)
                node = result.node
                parent = result.parent
                orientation = result.orientation
        }
        guard let parent else { 
            appendToLog("ResizeCommand: No parent found - floating window?")
            return io.err("resize command doesn't support floating windows yet https://github.com/nikitabobko/AeroSpace/issues/9") 
        }
        guard let orientation else { 
            appendToLog("ResizeCommand: No orientation found")
            return false 
        }
        guard let node else { 
            appendToLog("ResizeCommand: No node found")
            return false 
        }
        
        appendToLog("ResizeCommand: Found parent layout=\(parent.layout), orientation=\(orientation), children=\(parent.children.count)")
        
        // Additional diagnostics
        if let window = target.windowOrNil {
            appendToLog("ResizeCommand: Target window ID=\(window.windowId)")
            if let workspace = window.nodeWorkspace {
                appendToLog("ResizeCommand: Workspace=\(workspace.name), root layout=\(workspace.rootTilingContainer.layout)")
            }
        }
        
        appendToLog("ResizeCommand: Current weight=\(currentWeight), diff=\(diff)")

        // Handle different layout modes - BSP and tiles now use the same logic
        switch parent.layout {
        case .bsp:
            appendToLog("ResizeCommand: Using unified resize handler for BSP")
            return handleUnifiedResize(parent: parent, node: node, diff: diff, orientation: orientation, io: io)
        case .tiles:
            appendToLog("ResizeCommand: Using unified resize handler for tiles")
            return handleUnifiedResize(parent: parent, node: node, diff: diff, orientation: orientation, io: io)
        default:
            appendToLog("ResizeCommand: Unsupported layout: \(parent.layout)")
            return io.err("resize command only supports tiles and bsp layouts")
        }
    }

    /// Result type for resize target selection
    private struct ResizeTarget {
        let node: TreeNode?
        let parent: TilingContainer?
        let orientation: Orientation?
    }

    /// Find preliminary resize target to calculate diff (simple selection without optimization)
    @MainActor
    private func findPreliminaryResizeTarget(candidates: [TreeNode], dimension: ResizeCmdArgs.Dimension) -> ResizeTarget {
        switch dimension {
            case .width:
                if let candidate = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == .h }),
                   let parent = candidate.parent as? TilingContainer {
                    return ResizeTarget(node: candidate, parent: parent, orientation: .h)
                }
            case .height:
                if let candidate = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == .v }),
                   let parent = candidate.parent as? TilingContainer {
                    return ResizeTarget(node: candidate, parent: parent, orientation: .v)
                }
            case .smart:
                if let candidate = candidates.first,
                   let parent = candidate.parent as? TilingContainer {
                    return ResizeTarget(node: candidate, parent: parent, orientation: parent.orientation)
                }
            case .smartOpposite:
                if let candidate = candidates.first,
                   let parent = candidate.parent as? TilingContainer {
                    let oppositeOrientation = parent.orientation.opposite
                    if let oppositeCandidate = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == oppositeOrientation }),
                       let oppositeParent = oppositeCandidate.parent as? TilingContainer {
                        return ResizeTarget(node: oppositeCandidate, parent: oppositeParent, orientation: oppositeOrientation)
                    }
                }
        }
        return ResizeTarget(node: nil, parent: nil, orientation: nil)
    }

    /// Find the best resize target for a specific orientation
    @MainActor
    private func findBestResizeTarget(candidates: [TreeNode], targetOrientation: Orientation, diff: CGFloat) -> ResizeTarget {
        appendToLog("ResizeCommand: Finding best target for orientation \(targetOrientation), diff=\(diff)")
        
        // Filter candidates that match the target orientation
        let matchingCandidates = candidates.compactMap { candidate -> (TreeNode, TilingContainer)? in
            guard let parent = candidate.parent as? TilingContainer,
                  parent.orientation == targetOrientation else { return nil }
            return (candidate, parent)
        }
        
        if matchingCandidates.isEmpty {
            appendToLog("ResizeCommand: No matching candidates for orientation \(targetOrientation)")
            return ResizeTarget(node: nil, parent: nil, orientation: nil)
        }
        
        // For nested containers, prefer the one that can accommodate the resize better
        let bestCandidate = matchingCandidates.max { (a, b) in
            let (nodeA, parentA) = a
            let (nodeB, parentB) = b
            
            // Calculate resize potential for each candidate
            let potentialA = calculateResizePotential(node: nodeA, parent: parentA, diff: diff, orientation: targetOrientation)
            let potentialB = calculateResizePotential(node: nodeB, parent: parentB, diff: diff, orientation: targetOrientation)
            
            return potentialA < potentialB
        }
        
        if let (node, parent) = bestCandidate {
            appendToLog("ResizeCommand: Selected best candidate with resize potential")
            return ResizeTarget(node: node, parent: parent, orientation: targetOrientation)
        }
        
        return ResizeTarget(node: nil, parent: nil, orientation: nil)
    }

    /// Find smart resize target (chooses best orientation automatically)
    @MainActor
    private func findSmartResizeTarget(candidates: [TreeNode], diff: CGFloat) -> ResizeTarget {
        appendToLog("ResizeCommand: Finding smart resize target, diff=\(diff)")
        
        // Try both orientations and pick the best one
        let horizontalResult = findBestResizeTarget(candidates: candidates, targetOrientation: .h, diff: diff)
        let verticalResult = findBestResizeTarget(candidates: candidates, targetOrientation: .v, diff: diff)
        
        // If only one orientation is available, use it
        if horizontalResult.node != nil && verticalResult.node == nil {
            appendToLog("ResizeCommand: Smart resize using horizontal orientation")
            return horizontalResult
        }
        if verticalResult.node != nil && horizontalResult.node == nil {
            appendToLog("ResizeCommand: Smart resize using vertical orientation")
            return verticalResult
        }
        
        // If both are available, choose based on resize potential
        if let hNode = horizontalResult.node, let hParent = horizontalResult.parent,
           let vNode = verticalResult.node, let vParent = verticalResult.parent {
            
            let hPotential = calculateResizePotential(node: hNode, parent: hParent, diff: diff, orientation: .h)
            let vPotential = calculateResizePotential(node: vNode, parent: vParent, diff: diff, orientation: .v)
            
            if hPotential >= vPotential {
                appendToLog("ResizeCommand: Smart resize chose horizontal (potential: \(hPotential) vs \(vPotential))")
                return horizontalResult
            } else {
                appendToLog("ResizeCommand: Smart resize chose vertical (potential: \(vPotential) vs \(hPotential))")
                return verticalResult
            }
        }
        
        // Fallback to first available candidate
        if let firstCandidate = candidates.first,
           let parent = firstCandidate.parent as? TilingContainer {
            appendToLog("ResizeCommand: Smart resize fallback to first candidate")
            return ResizeTarget(node: firstCandidate, parent: parent, orientation: parent.orientation)
        }
        
        return ResizeTarget(node: nil, parent: nil, orientation: nil)
    }

    /// Find smart opposite resize target
    @MainActor
    private func findSmartOppositeResizeTarget(candidates: [TreeNode], diff: CGFloat) -> ResizeTarget {
        appendToLog("ResizeCommand: Finding smart opposite resize target")
        
        // Get the orientation of the first candidate's parent
        guard let firstCandidate = candidates.first,
              let firstParent = firstCandidate.parent as? TilingContainer else {
            return ResizeTarget(node: nil, parent: nil, orientation: nil)
        }
        
        let oppositeOrientation = firstParent.orientation.opposite
        return findBestResizeTarget(candidates: candidates, targetOrientation: oppositeOrientation, diff: diff)
    }

    /// Calculate how well a container can accommodate a resize operation
    @MainActor
    private func calculateResizePotential(node: TreeNode, parent: TilingContainer, diff: CGFloat, orientation: Orientation) -> CGFloat {
        let currentWeight = node.getWeight(orientation)
        let siblingCount = parent.children.count - 1
        
        guard siblingCount > 0 else { return 0 }
        
        let childDiff = diff / CGFloat(siblingCount)
        
        // Calculate how much space is available for this resize
        var availableSpace: CGFloat = 0
        
        if diff > 0 {
            // Growing: check how much siblings can shrink
            for sibling in parent.children where sibling !== node {
                let siblingWeight = sibling.getWeight(orientation)
                let canShrink = max(0, siblingWeight - 0.1) // Minimum weight is 0.1
                availableSpace += canShrink
            }
        } else {
            // Shrinking: check how much this node can shrink
            availableSpace = max(0, currentWeight - 0.1)
        }
        
        // Prefer containers where the resize can be fully accommodated
        let requestedSpace = abs(diff)
        let accommodationRatio = min(1.0, availableSpace / requestedSpace)
        
        // Consider the depth, but prefer containers that can better accommodate the resize
        let depth = calculateContainerDepth(parent)
        let depthPenalty = CGFloat(depth) * 0.05 // Reduced penalty to allow deeper containers when they're better
        
        // Bonus for containers where the resize can be fully accommodated
        let accommodationBonus = accommodationRatio >= 1.0 ? 0.2 : 0.0
        
        let potential = accommodationRatio + accommodationBonus - depthPenalty
        
        appendToLog("ResizeCommand: Container potential=\(potential) (accommodation=\(accommodationRatio), depth=\(depth))")
        return potential
    }

    /// Calculate the depth of a container in the tree
    @MainActor
    private func calculateContainerDepth(_ container: TilingContainer) -> Int {
        var depth = 0
        var current: TreeNode? = container
        
        while let node = current, node.parent != nil {
            depth += 1
            current = node.parent as? TreeNode
        }
        
        return depth
    }

    /// Handle resize operation for both BSP and tiles layouts using unified logic
    @MainActor
    private func handleUnifiedResize(parent: TilingContainer, node: TreeNode, diff: CGFloat, orientation: Orientation, io: CmdIo) -> Bool {
        appendToLog("UnifiedResize: Starting with \(parent.children.count) children, diff=\(diff), orientation=\(orientation), layout=\(parent.layout)")
        
        guard parent.children.count > 1 else { 
            appendToLog("UnifiedResize: Single window - cannot resize")
            if parent.layout == .bsp {
                return io.err("Cannot resize single window in BSP container")
            }
            return false // Single window cannot be resized
        }

        // Calculate weight distribution - same logic for both BSP and tiles
        guard let childDiff = diff.div(parent.children.count - 1) else { 
            appendToLog("UnifiedResize: Invalid weight distribution calculation")
            return false 
        }
        
        appendToLog("UnifiedResize: childDiff=\(childDiff)")

        // Log initial weights
        let initialWeights = parent.children.map { $0.getWeight(orientation) }
        appendToLog("UnifiedResize: Initial weights: \(initialWeights)")

        // For BSP, set resize in progress flag to prevent intelligent rebalancing
        if parent.layout == .bsp {
            parent.setResizeInProgress(true)
        }

        // Apply weight changes - same logic for both layouts
        parent.children.lazy
            .filter { $0 != node }
            .forEach { child in
                let oldWeight = child.getWeight(orientation)
                let newWeight = max(0.1, oldWeight - childDiff) // Ensure minimum weight
                child.setWeight(orientation, newWeight)
                appendToLog("UnifiedResize: Child weight \(oldWeight) -> \(newWeight)")
            }

        let oldNodeWeight = node.getWeight(orientation)
        let newNodeWeight = max(0.1, oldNodeWeight + diff) // Ensure minimum weight
        node.setWeight(orientation, newNodeWeight)
        appendToLog("UnifiedResize: Target node weight \(oldNodeWeight) -> \(newNodeWeight)")

        // Log final weights
        let finalWeights = parent.children.map { $0.getWeight(orientation) }
        appendToLog("UnifiedResize: Final weights: \(finalWeights)")
        
        // Clear BSP resize in progress flag
        if parent.layout == .bsp {
            parent.setResizeInProgress(false)
        }
        
        appendToLog("UnifiedResize: Completed successfully")
        return true
    }
}
