import AppKit
import Common

@MainActor
private var activeRefreshTask: Task<(), any Error>? = nil

@MainActor
func runRefreshSession(
    _ event: RefreshSessionEvent,
    optimisticallyPreLayoutWorkspaces: Bool = false,
) {
    activeRefreshTask?.cancel()
    activeRefreshTask = Task { @MainActor in
        try checkCancellation()
        try await runRefreshSessionBlocking(event, optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces)
    }
}

@MainActor
func runRefreshSessionBlocking(
    _ event: RefreshSessionEvent,
    layoutWorkspaces shouldLayoutWorkspaces: Bool = true,
    optimisticallyPreLayoutWorkspaces: Bool = false,
) async throws {
    let state = signposter.beginInterval(#function, "event: \(event) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
    defer { signposter.endInterval(#function, state) }
    if !TrayMenuModel.shared.isEnabled { return }
    try await $refreshSessionEvent.withValue(event) {
        try await $_isStartup.withValue(event.isStartup) {
            let nativeFocused = try await getNativeFocusedWindow()
            if let nativeFocused { try await debugWindowsIfRecording(nativeFocused) }
            updateFocusCache(nativeFocused)

            if shouldLayoutWorkspaces && optimisticallyPreLayoutWorkspaces { try await layoutWorkspaces() }

            refreshModel()
            try await refresh()
            gcMonitors()

            updateTrayText()
            try await normalizeLayoutReason()
            if shouldLayoutWorkspaces { try await layoutWorkspaces() }
        }
    }
}

@MainActor
func runSession<T>(
    _ event: RefreshSessionEvent,
    _ token: RunSessionGuard,
    body: @MainActor () async throws -> T
) async throws -> T {
    let state = signposter.beginInterval(#function, "event: \(event) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
    defer { signposter.endInterval(#function, state) }
    activeRefreshTask?.cancel() // Give priority to runSession
    activeRefreshTask = nil
    return try await $refreshSessionEvent.withValue(event) {
        try await $_isStartup.withValue(event.isStartup) {
            let nativeFocused = try await getNativeFocusedWindow()
            if let nativeFocused { try await debugWindowsIfRecording(nativeFocused) }
            updateFocusCache(nativeFocused)
            let focusBefore = focus.windowOrNil

            refreshModel()
            let result = try await body()
            refreshModel()

            let focusAfter = focus.windowOrNil

            updateTrayText()
            try await layoutWorkspaces()
            if focusBefore != focusAfter {
                focusAfter?.nativeFocus() // syncFocusToMacOs
            }
            runRefreshSession(event)
            return result
        }
    }
}

struct RunSessionGuard: Sendable {
    @MainActor
    static var isServerEnabled: RunSessionGuard? { TrayMenuModel.shared.isEnabled ? forceRun : nil }
    @MainActor
    static func isServerEnabled(orIsEnableCommand command: (any Command)?) -> RunSessionGuard? {
        command is EnableCommand ? .forceRun : .isServerEnabled
    }
    @MainActor
    static var checkServerIsEnabledOrDie: RunSessionGuard { .isServerEnabled ?? dieT("server is disabled") }
    static let forceRun = RunSessionGuard()
    private init() {}
}

@MainActor
func refreshModel() {
    Workspace.garbageCollectUnusedWorkspaces()
    checkOnFocusChangedCallbacks()
    normalizeContainers()
}

@MainActor
private func refresh() async throws {
    // Garbage collect terminated apps and windows before working with all windows
    let mapping = try await MacApp.refreshAllAndGetAliveWindowIds(frontmostAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    let aliveWindowIds = mapping.values.flatMap { $0 }

    for window in MacWindow.allWindows {
        if !aliveWindowIds.contains(window.windowId) {
            window.garbageCollect(skipClosedWindowsCache: false)
        }
    }
    for (app, windowIds) in mapping {
        for windowId in windowIds {
            try await MacWindow.getOrRegister(windowId: windowId, macApp: app)
        }
    }

    // Garbage collect workspaces after apps, because workspaces contain apps.
    Workspace.garbageCollectUnusedWorkspaces()
}

func refreshObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    let notif = notif as String
    Task { @MainActor in
        if !TrayMenuModel.shared.isEnabled { return }
        runRefreshSession(.ax(notif))
    }
}

enum OptimalHideCorner {
    case bottomLeftCorner, bottomRightCorner
}

// Track previous visible workspaces for transition animation
@MainActor private var previousVisibleWorkspaces: Set<String> = []

@MainActor
private func layoutWorkspaces() async throws {
    if !TrayMenuModel.shared.isEnabled {
        for workspace in Workspace.all {
            workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideFromCorner() } // todo as!
            try await workspace.layoutWorkspace() // Unhide tiling windows from corner
        }
        return
    }
    let monitors = monitors
    var monitorToOptimalHideCorner: [CGPoint: OptimalHideCorner] = [:]
    for monitor in monitors {
        let xOff = monitor.width * 0.1
        let yOff = monitor.height * 0.1
        // brc = bottomRightCorner
        let brc1 = monitor.rect.bottomRightCorner + CGPoint(x: 2, y: -yOff)
        let brc2 = monitor.rect.bottomRightCorner + CGPoint(x: -xOff, y: 2)
        let brc3 = monitor.rect.bottomRightCorner + CGPoint(x: 2, y: 2)

        // blc = bottomLeftCorner
        let blc1 = monitor.rect.bottomLeftCorner + CGPoint(x: -2, y: -yOff)
        let blc2 = monitor.rect.bottomLeftCorner + CGPoint(x: xOff, y: 2)
        let blc3 = monitor.rect.bottomLeftCorner + CGPoint(x: -2, y: 2)

        let corner: OptimalHideCorner =
            monitors.contains(where: { m in m.rect.contains(brc1) || m.rect.contains(brc2) || m.rect.contains(brc3) }) &&
            monitors.allSatisfy { m in !m.rect.contains(blc1) && !m.rect.contains(blc2) && !m.rect.contains(blc3) }
            ? .bottomLeftCorner
            : .bottomRightCorner
        monitorToOptimalHideCorner[monitor.rect.topLeftCorner] = corner
    }

    // Detect workspace changes for transition animation
    let currentVisibleWorkspaces = Set(monitors.map { $0.activeWorkspace.name })
    let newlyVisibleWorkspaces = currentVisibleWorkspaces.subtracting(previousVisibleWorkspaces)
    let newlyHiddenWorkspaces = previousVisibleWorkspaces.subtracting(currentVisibleWorkspaces)
    let isWorkspaceSwitch = !newlyVisibleWorkspaces.isEmpty || !newlyHiddenWorkspaces.isEmpty
    
    // Update tracking
    previousVisibleWorkspaces = currentVisibleWorkspaces

    // Workspace transition animation
    if isWorkspaceSwitch && config.animation.enabled && config.animation.workspaceTransitionAnimationEnabled {
        // Step 1: Animate out windows from newly hidden workspaces
        for workspaceName in newlyHiddenWorkspaces {
            if let workspace = Workspace.all.first(where: { $0.name == workspaceName }) {
                for window in workspace.allLeafWindowsRecursive {
                    if let macWindow = window as? MacWindow {
                        try? await WindowAnimationEngine.shared.animateWindowFadeOut(macWindow)
                    }
                }
            }
        }
        
        // Step 2: Position newly visible windows at their target locations (hidden)
        for monitor in monitors {
            let workspace = monitor.activeWorkspace
            if newlyVisibleWorkspaces.contains(workspace.name) {
                // First, set windows to target position but invisible
                for window in workspace.allLeafWindowsRecursive {
                    (window as! MacWindow).unhideFromCorner()
                }
            }
        }
        
        // Step 3: Layout all visible workspaces
        for monitor in monitors {
            let workspace = monitor.activeWorkspace
            workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideFromCorner() }
            try await workspace.layoutWorkspace()
        }
        
        // Step 4: Animate in windows for newly visible workspaces
        for monitor in monitors {
            let workspace = monitor.activeWorkspace
            if newlyVisibleWorkspaces.contains(workspace.name) {
                for window in workspace.allLeafWindowsRecursive {
                    if let macWindow = window as? MacWindow {
                        try? await WindowAnimationEngine.shared.animateWindowFadeIn(macWindow)
                    }
                }
            }
        }
    } else {
        // Normal layout without workspace transition animation
        for monitor in monitors {
            let workspace = monitor.activeWorkspace
            workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideFromCorner() }
            try await workspace.layoutWorkspace()
        }
    }
    
    // Hide windows in invisible workspaces
    for workspace in Workspace.all where !workspace.isVisible {
        let corner = monitorToOptimalHideCorner[workspace.workspaceMonitor.rect.topLeftCorner] ?? .bottomRightCorner
        for window in workspace.allLeafWindowsRecursive {
            try await (window as! MacWindow).hideInCorner(corner)
        }
    }
}

@MainActor
private func normalizeContainers() {
    // Can't do it only for visible workspace because most of the commands support --window-id and --workspace flags
    for workspace in Workspace.all {
        workspace.normalizeContainers()
    }
}
