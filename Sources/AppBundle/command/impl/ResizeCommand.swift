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
    /*conforms*/ var shouldResetClosedWindowsCache = true

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

        let orientation: Orientation?
        let parent: TilingContainer?
        let node: TreeNode?
        switch args.dimension.val {
            case .width:
                orientation = .h
                node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
                parent = node?.parent as? TilingContainer
            case .height:
                orientation = .v
                node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
                parent = node?.parent as? TilingContainer
            case .smart:
                node = candidates.first
                parent = node?.parent as? TilingContainer
                orientation = parent?.orientation
            case .smartOpposite:
                orientation = (candidates.first?.parent as? TilingContainer)?.orientation.opposite
                node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
                parent = node?.parent as? TilingContainer
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

        let currentWeight = node.getWeight(orientation)
        let diff: CGFloat = switch args.units.val {
            case .set(let unit): CGFloat(unit) - currentWeight
            case .add(let unit): CGFloat(unit)
            case .subtract(let unit): -CGFloat(unit)
        }
        
        appendToLog("ResizeCommand: Current weight=\(currentWeight), diff=\(diff)")

        // Handle different layout modes with specialized logic
        switch parent.layout {
        case .bsp:
            appendToLog("ResizeCommand: Using BSP resize handler")
            return await handleBSPResize(parent: parent, node: node, diff: diff, orientation: orientation, io: io)
        case .tiles:
            appendToLog("ResizeCommand: Using tiles resize handler")
            return handleTilesResize(parent: parent, node: node, diff: diff, orientation: orientation)
        default:
            appendToLog("ResizeCommand: Unsupported layout: \(parent.layout)")
            return io.err("resize command only supports tiles and bsp layouts")
        }
    }

    /// Handle resize operation for BSP layout
    @MainActor
    private func handleBSPResize(parent: TilingContainer, node: TreeNode, diff: CGFloat, orientation: Orientation, io: CmdIo) async -> Bool {
        appendToLog("BSPResize: Starting with \(parent.children.count) children, diff=\(diff), orientation=\(orientation)")
        
        // Set resize in progress flag to prevent intelligent rebalancing
        parent.setResizeInProgress(true)
        
        guard parent.children.count > 1 else { 
            appendToLog("BSPResize: Single window error")
            parent.setResizeInProgress(false)
            return io.err("Cannot resize single window in BSP container")
        }

        // Calculate weight distribution for BSP
        guard let childDiff = diff.div(parent.children.count - 1) else { 
            appendToLog("BSPResize: Invalid weight distribution calculation")
            parent.setResizeInProgress(false)
            return io.err("Invalid weight distribution calculation")
        }
        
        appendToLog("BSPResize: childDiff=\(childDiff)")

        // Log initial weights
        let initialWeights = parent.children.map { $0.getWeight(orientation) }
        appendToLog("BSPResize: Initial weights: \(initialWeights)")

        // Apply weight changes without normalization (BSP handles proportions at layout time)
        parent.children.lazy
            .filter { $0 != node }
            .forEach { child in
                let oldWeight = child.getWeight(orientation)
                let newWeight = oldWeight - childDiff
                child.setWeight(orientation, newWeight)
                appendToLog("BSPResize: Child weight \(oldWeight) -> \(newWeight)")
            }

        let oldNodeWeight = node.getWeight(orientation)
        let newNodeWeight = oldNodeWeight + diff
        node.setWeight(orientation, newNodeWeight)
        appendToLog("BSPResize: Target node weight \(oldNodeWeight) -> \(newNodeWeight)")

        // Log final weights before validation
        let beforeValidationWeights = parent.children.map { $0.getWeight(orientation) }
        appendToLog("BSPResize: Before validation weights: \(beforeValidationWeights)")

        // Validate and correct BSP weights
        let correctionsMade = parent.validateAndCorrectBSPWeights(orientation: orientation)
        appendToLog("BSPResize: Weight validation corrections made: \(correctionsMade)")
        
        // Log final weights after validation
        let finalWeights = parent.children.map { $0.getWeight(orientation) }
        appendToLog("BSPResize: Final weights: \(finalWeights)")
        
        // Skip immediate layout update to prevent weight reset
        appendToLog("BSPResize: Skipping immediate layout update to prevent weight reset")
        
        // Instead, let the system handle layout updates naturally
        // The weights are set correctly, and the layout system should pick them up
        
        // Check weights immediately
        let weightsImmediately = parent.children.map { $0.getWeight(orientation) }
        appendToLog("BSPResize: Weights immediately after: \(weightsImmediately)")
        
        // Skip refreshModel() call to prevent potential recursion during resize
        appendToLog("BSPResize: Skipping refreshModel() to prevent recursion during resize")
        
        // Clear resize in progress flag
        parent.setResizeInProgress(false)
        
        appendToLog("BSPResize: Completed successfully")
        return true
    }

    /// Handle resize operation for tiles layout
    @MainActor
    private func handleTilesResize(parent: TilingContainer, node: TreeNode, diff: CGFloat, orientation: Orientation) -> Bool {
        guard let childDiff = diff.div(parent.children.count - 1) else { return false }
        
        parent.children.lazy
            .filter { $0 != node }
            .forEach { $0.setWeight(orientation, $0.getWeight(orientation) - childDiff) }

        node.setWeight(orientation, node.getWeight(orientation) + diff)
        
        return true
    }
}
