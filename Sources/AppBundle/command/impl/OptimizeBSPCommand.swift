import AppKit
import Common

struct OptimizeBSPCommand: Command {
    let args: OptimizeBSPCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let workspace: Workspace
        
        if let workspaceName = args.workspaceName {
            workspace = Workspace.get(byName: workspaceName.raw)
        } else if let windowId = args.windowId {
            guard let window = Window.get(byId: windowId) else {
                return io.err("Window with ID \(windowId) not found")
            }
            guard let windowWorkspace = window.nodeWorkspace else {
                return io.err("Window is not in any workspace")
            }
            workspace = windowWorkspace
        } else {
            // Use focused workspace
            workspace = focus.workspace
        }
        
        let rootContainer = workspace.rootTilingContainer
        
        // Check if the workspace uses BSP layout
        guard rootContainer.layout == .bsp else {
            return io.err("Workspace '\(workspace.name)' is not using BSP layout")
        }
        
        // Perform comprehensive BSP optimization
        rootContainer.handleRootContainerChange()
        
        // Also optimize all child containers
        optimizeAllBSPContainers(in: rootContainer)
        
        return true
    }
}

/// Recursively optimizes all BSP containers in the tree
@MainActor private func optimizeAllBSPContainers(in container: TilingContainer) {
    if container.layout == .bsp {
        container.handleRootContainerChange()
    }
    
    for child in container.children {
        if let childContainer = child as? TilingContainer {
            optimizeAllBSPContainers(in: childContainer)
        }
    }
}

