import AppKit

extension Workspace {
    @MainActor // todo can be dropped in future Swift versions?
    func layoutWorkspace() async throws {
        if isEffectivelyEmpty { return }
        let rect = workspaceMonitor.visibleRectPaddedByOuterGaps
        // If monitors are aligned vertically and the monitor below has smaller width, then macOS may not allow the
        // window on the upper monitor to take full width. rect.height - 1 resolves this problem
        // But I also faced this problem in monitors horizontal configuration. ¯\_(ツ)_/¯
        try await layoutRecursive(rect.topLeftCorner, width: rect.width, height: rect.height - 1, virtual: rect, LayoutContext(self))
    }
}

extension TreeNode {
    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutRecursive(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        let physicalRect = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: height)
        switch nodeCases {
            case .workspace(let workspace):
                lastAppliedLayoutPhysicalRect = physicalRect
                lastAppliedLayoutVirtualRect = virtual
                try await workspace.rootTilingContainer.layoutRecursive(point, width: width, height: height, virtual: virtual, context)
                for window in workspace.children.filterIsInstance(of: Window.self) {
                    window.lastAppliedLayoutPhysicalRect = nil
                    window.lastAppliedLayoutVirtualRect = nil
                    try await window.layoutFloatingWindow(context)
                }
            case .window(let window):
                if window.windowId != currentlyManipulatedWithMouseWindowId {
                    lastAppliedLayoutVirtualRect = virtual
                    if window.isFullscreen && window == context.workspace.rootTilingContainer.mostRecentWindowRecursive {
                        lastAppliedLayoutPhysicalRect = nil
                        try await window.layoutFullscreen(context)
                    } else {
                        lastAppliedLayoutPhysicalRect = physicalRect
                        window.isFullscreen = false

                        // Use animation for layout changes if enabled
                        if config.animation.enabled && config.animation.layoutChangeAnimationEnabled {
                            do {
                                let targetRect = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: height)
                                try await WindowAnimationEngine.shared.animateWindow(window, to: targetRect)
                            } catch {
                                // Fallback to immediate positioning if animation fails
                                window.setAxFrameImmediate(point, CGSize(width: width, height: height))
                            }
                        } else {
                            window.setAxFrame(point, CGSize(width: width, height: height))
                        }
                    }
                }
            case .tilingContainer(let container):
                lastAppliedLayoutPhysicalRect = physicalRect
                lastAppliedLayoutVirtualRect = virtual
                switch container.layout {
                    case .tiles:
                        try await container.layoutTiles(point, width: width, height: height, virtual: virtual, context)
                    case .accordion:
                        try await container.layoutAccordion(point, width: width, height: height, virtual: virtual, context)
                    case .bsp:
                        try await container.layoutBSP(point, width: width, height: height, virtual: virtual, context)
                }
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
                 .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
                return // Nothing to do for weirdos
        }
    }
}

private struct LayoutContext {
    let workspace: Workspace
    let resolvedGaps: ResolvedGaps

    @MainActor
    init(_ workspace: Workspace) {
        self.workspace = workspace
        self.resolvedGaps = ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitor)
    }
}

extension Window {
    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutFloatingWindow(_ context: LayoutContext) async throws {
        let workspace = context.workspace
        let currentMonitor = try await getCenter()?.monitorApproximation // Probably not idempotent
        if let currentMonitor, let windowTopLeftCorner = try await getAxTopLeftCorner(), workspace != currentMonitor.activeWorkspace {
            let xProportion = (windowTopLeftCorner.x - currentMonitor.visibleRect.topLeftX) / currentMonitor.visibleRect.width
            let yProportion = (windowTopLeftCorner.y - currentMonitor.visibleRect.topLeftY) / currentMonitor.visibleRect.height

            let moveTo = workspace.workspaceMonitor
            let newPosition = CGPoint(
                x: moveTo.visibleRect.topLeftX + xProportion * moveTo.visibleRect.width,
                y: moveTo.visibleRect.topLeftY + yProportion * moveTo.visibleRect.height,
            )

            // Use animation for floating window movement if enabled
            if config.animation.enabled && config.animation.workspaceTransitionAnimationEnabled {
                do {
                    try await WindowAnimationEngine.shared.animateWindowPosition(self, to: newPosition)
                } catch {
                    // Fallback to immediate positioning if animation fails
                    setAxTopLeftCornerImmediate(newPosition)
                }
            } else {
                setAxTopLeftCorner(newPosition)
            }
        }
        if isFullscreen {
            try await layoutFullscreen(context)
            isFullscreen = false
        }
    }

    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutFullscreen(_ context: LayoutContext) async throws {
        let monitorRect = noOuterGapsInFullscreen
            ? context.workspace.workspaceMonitor.visibleRect
            : context.workspace.workspaceMonitor.visibleRectPaddedByOuterGaps

        // Use animation for fullscreen layout if enabled
        if config.animation.enabled && config.animation.layoutChangeAnimationEnabled {
            do {
                let targetRect = Rect(topLeftX: monitorRect.topLeftX, topLeftY: monitorRect.topLeftY,
                                      width: monitorRect.width, height: monitorRect.height)
                try await WindowAnimationEngine.shared.animateWindow(self, to: targetRect)
            } catch {
                // Fallback to immediate positioning if animation fails
                setAxFrameImmediate(monitorRect.topLeftCorner, CGSize(width: monitorRect.width, height: monitorRect.height))
            }
        } else {
            setAxFrame(monitorRect.topLeftCorner, CGSize(width: monitorRect.width, height: monitorRect.height))
        }
    }
}

extension TilingContainer {
    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutTiles(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        var point = point
        var virtualPoint = virtual.topLeftCorner

        guard let delta = ((orientation == .h ? width : height) - CGFloat(children.sumOfDouble { $0.getWeight(orientation) }))
            .div(children.count) else { return }

        let lastIndex = children.indices.last
        for (i, child) in children.enumerated() {
            child.setWeight(orientation, child.getWeight(orientation) + delta)
            let rawGap = context.resolvedGaps.inner.get(orientation).toDouble()
            // Gaps. Consider 4 cases:
            // 1. Multiple children. Layout first child
            // 2. Multiple children. Layout last child
            // 3. Multiple children. Layout child in the middle
            // 4. Single child   let rawGap = gaps.inner.get(orientation).toDouble()
            let gap = rawGap - (i == 0 ? rawGap / 2 : 0) - (i == lastIndex ? rawGap / 2 : 0)
            try await child.layoutRecursive(
                i == 0 ? point : point.addingOffset(orientation, rawGap / 2),
                width: orientation == .h ? child.hWeight - gap : width,
                height: orientation == .v ? child.vWeight - gap : height,
                virtual: Rect(
                    topLeftX: virtualPoint.x,
                    topLeftY: virtualPoint.y,
                    width: orientation == .h ? child.hWeight : width,
                    height: orientation == .v ? child.vWeight : height,
                ),
                context,
            )
            virtualPoint = orientation == .h ? virtualPoint.addingXOffset(child.hWeight) : virtualPoint.addingYOffset(child.vWeight)
            point = orientation == .h ? point.addingXOffset(child.hWeight) : point.addingYOffset(child.vWeight)
        }
    }

    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutAccordion(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        guard let mruIndex: Int = mostRecentChild?.ownIndex else { return }
        for (index, child) in children.enumerated() {
            let padding = CGFloat(config.accordionPadding)
            let (lPadding, rPadding): (CGFloat, CGFloat) = switch index {
                case 0 where children.count == 1: (0, 0)
                case 0:                           (0, padding)
                case children.indices.last:       (padding, 0)
                case mruIndex - 1:                (0, 2 * padding)
                case mruIndex + 1:                (2 * padding, 0)
                default:                          (padding, padding)
            }
            switch orientation {
                case .h:
                    try await child.layoutRecursive(
                        point + CGPoint(x: lPadding, y: 0),
                        width: width - rPadding - lPadding,
                        height: height,
                        virtual: virtual,
                        context,
                    )
                case .v:
                    try await child.layoutRecursive(
                        point + CGPoint(x: 0, y: lPadding),
                        width: width,
                        height: height - lPadding - rPadding,
                        virtual: virtual,
                        context,
                    )
            }
        }
    }

    @MainActor // todo can be dropped in future Swift versions?
    fileprivate func layoutBSP(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        // BSP layout divides space recursively based on the container's orientation
        // Each child gets space proportional to its weight

        guard !children.isEmpty else { return }

        // For single child, give it all the space
        if children.count == 1 {
            try await children[0].layoutRecursive(point, width: width, height: height, virtual: virtual, context)
            return
        }

        // Calculate total weight for normalization
        let totalWeight = children.sumOfDouble { $0.getWeight(orientation) }
        guard totalWeight > 0 else { return }

        var currentPoint = point
        var currentVirtualPoint = virtual.topLeftCorner
        let gaps = context.resolvedGaps.inner.get(orientation).toDouble()

        // Layout each child based on its proportional weight
        for (index, child) in children.enumerated() {
            let childWeight = child.getWeight(orientation)
            let proportion = childWeight / totalWeight

            // Calculate child dimensions based on orientation
            let (childWidth, childHeight): (CGFloat, CGFloat)
            let (childVirtualWidth, childVirtualHeight): (CGFloat, CGFloat)

            switch orientation {
                case .h:
                    // Horizontal split: children are arranged side by side
                    childWidth = width * proportion
                    childHeight = height
                    childVirtualWidth = virtual.width * proportion
                    childVirtualHeight = virtual.height
                case .v:
                    // Vertical split: children are arranged top to bottom
                    childWidth = width
                    childHeight = height * proportion
                    childVirtualWidth = virtual.width
                    childVirtualHeight = virtual.height * proportion
            }

            // Apply gaps (except for the last child)
            let isLastChild = index == children.count - 1
            let gapAdjustment = isLastChild ? 0 : gaps / 2

            let adjustedChildWidth = orientation == .h ? max(0, childWidth - gapAdjustment) : childWidth
            let adjustedChildHeight = orientation == .v ? max(0, childHeight - gapAdjustment) : childHeight

            // Create virtual rect for this child
            let childVirtualRect = Rect(
                topLeftX: currentVirtualPoint.x,
                topLeftY: currentVirtualPoint.y,
                width: childVirtualWidth,
                height: childVirtualHeight,
            )

            // Layout the child recursively
            try await child.layoutRecursive(
                currentPoint,
                width: adjustedChildWidth,
                height: adjustedChildHeight,
                virtual: childVirtualRect,
                context,
            )

            // Move to next position
            switch orientation {
                case .h:
                    currentPoint.x += childWidth
                    currentVirtualPoint.x += childVirtualWidth
                case .v:
                    currentPoint.y += childHeight
                    currentVirtualPoint.y += childVirtualHeight
            }
        }
    }
}
