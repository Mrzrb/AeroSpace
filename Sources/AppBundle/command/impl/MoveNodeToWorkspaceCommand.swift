import Common
import Foundation

struct MoveNodeToWorkspaceCommand: Command {
    let args: MoveNodeToWorkspaceCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let window = target.windowOrNil else { return io.err(noWindowIsFocused) }
        let subjectWs = window.nodeWorkspace
        let targetWorkspace: Workspace
        switch args.target.val {
            case .relative(let nextPrev):
                guard let subjectWs else { return io.err("Window \(window.windowId) doesn't belong to any workspace") }
                let ws = getNextPrevWorkspace(
                    current: subjectWs,
                    isNext: nextPrev == .next,
                    wrapAround: args.wrapAround,
                    stdin: args.useStdin ? io.readStdin() : nil,
                    target: target,
                )
                guard let ws else { return io.err("Can't resolve next or prev workspace") }
                targetWorkspace = ws
            case .direct(let name):
                targetWorkspace = Workspace.get(byName: name.raw)
        }
        return moveWindowToWorkspace(window, targetWorkspace, io, focusFollowsWindow: args.focusFollowsWindow, failIfNoop: args.failIfNoop)
    }
}

@MainActor
func moveWindowToWorkspace(_ window: Window, _ targetWorkspace: Workspace, _ io: CmdIo, focusFollowsWindow: Bool, failIfNoop: Bool, index: Int = INDEX_BIND_LAST) -> Bool {
    if window.nodeWorkspace == targetWorkspace {
        if !failIfNoop {
            io.err("Window '\(window.windowId)' already belongs to workspace '\(targetWorkspace.name)'. Tip: use --fail-if-noop to exit with non-zero code")
        }
        return !failIfNoop
    }

    let sourceWorkspace = window.nodeWorkspace
    let targetContainer: NonLeafTreeNodeObject = window.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer

    // Check if animation is needed and possible
    let needsAnimation = config.animation.enabled && config.animation.workspaceTransitionAnimationEnabled
    let sourceVisible = sourceWorkspace?.isVisible == true
    let targetVisible = targetWorkspace.isVisible == true

    // In test environment, disable animations to avoid timing issues
    let isTestEnvironment = NSClassFromString("XCTest") != nil

    // Only use async animation for visible workspace transitions and not in test environment
    if needsAnimation && (sourceVisible || targetVisible) && !isTestEnvironment {
        Task {
            do {
                // If moving from visible workspace to hidden workspace, fade out
                if sourceVisible && !targetVisible {
                    try await WindowAnimationEngine.shared.animateWindowFadeOut(window)
                    window.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: index)
                }
                // If moving from hidden workspace to visible workspace, fade in
                else if !sourceVisible && targetVisible {
                    window.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: index)
                    try await WindowAnimationEngine.shared.animateWindowFadeIn(window)
                }
                // If both workspaces are visible (different monitors), use position transition
                else if sourceVisible && targetVisible {
                    // Save original binding data
                    let originalBinding = window.unbindFromParent()

                    // Temporarily bind to target to get target position
                    window.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: index)

                    // Get the new target rect after binding
                    if let targetRect = try await window.getAxRect() {
                        // Restore original binding to animate from original position
                        window.unbindFromParent()
                        window.bind(to: originalBinding.parent, adaptiveWeight: originalBinding.adaptiveWeight, index: originalBinding.index)

                        // Animate to target position, then rebind to final target
                        try await WindowAnimationEngine.shared.animateWorkspaceTransition(window, to: targetRect)
                        window.unbindFromParent()
                        window.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: index)
                    } else {
                        // Fallback to immediate binding if we can't get target rect
                        // Already bound to target, so no need to rebind
                    }
                } else {
                    // This case shouldn't happen, but handle it
                    window.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: index)
                }
            } catch {
                // Fallback to immediate binding if animation fails
                window.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: index)
            }
        }
    } else {
        // No animation needed or animations disabled - bind immediately
        window.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: index)
    }

    return focusFollowsWindow ? window.focusWindow() : true
}
