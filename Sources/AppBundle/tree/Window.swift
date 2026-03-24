import AppKit
import Common

open class Window: TreeNode, Hashable {
    let windowId: UInt32
    let app: any AbstractApp
    var lastFloatingSize: CGSize?
    var isFullscreen: Bool = false
    var noOuterGapsInFullscreen: Bool = false
    var layoutReason: LayoutReason = .standard

    @MainActor
    init(id: UInt32, _ app: any AbstractApp, lastFloatingSize: CGSize?, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        self.windowId = id
        self.app = app
        self.lastFloatingSize = lastFloatingSize
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor static func get(byId windowId: UInt32) -> Window? { // todo make non optional
        isUnitTest
            ? Workspace.all.flatMap { $0.allLeafWindowsRecursive }.first(where: { $0.windowId == windowId })
            : MacWindow.allWindowsMap[windowId]
    }

    @MainActor
    func closeAxWindow() { die("Not implemented") }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }

    @MainActor // todo swift is stupid
    func getAxSize() async throws -> CGSize? { die("Not implemented") }
    @MainActor // todo swift is stupid
    var title: String { get async throws { die("Not implemented") } }
    @MainActor // todo swift is stupid
    var isMacosFullscreen: Bool { get async throws { false } }
    @MainActor // todo swift is stupid
    var isMacosMinimized: Bool { get async throws { false } }
    var isHiddenInCorner: Bool { die("Not implemented") }
    @MainActor
    func nativeFocus() { die("Not implemented") }
    @MainActor // todo can be dropped in future Swift versions
    func getAxRect() async throws -> Rect? { die("Not implemented") }
    @MainActor // todo can be dropped in future Swift versions
    func getCenter() async throws -> CGPoint? { try await getAxRect()?.center }
    @MainActor // todo can be dropped in future Swift versions
    func getAxTopLeftCorner() async throws -> CGPoint? { try await getAxRect()?.topLeftCorner }

    @MainActor func setAxTopLeftCorner(_ point: CGPoint) { die("Not implemented") }
    @MainActor func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) { die("Not implemented") }
    func setAxFrameBlocking(_ topLeft: CGPoint?, _ size: CGSize?) async throws { die("Not implemented") }
    @MainActor func setSizeAsync(_ size: CGSize) { die("Not implemented") }

    @MainActor func setAxTopLeftCornerImmediate(_ point: CGPoint) { die("Not implemented") }
    @MainActor func setAxFrameImmediate(_ topLeft: CGPoint?, _ size: CGSize?) { die("Not implemented") }
    @MainActor func setSizeAsyncImmediate(_ size: CGSize) { die("Not implemented") }
    @MainActor func setAxAlphaImmediate(_ alpha: Double) { die("Not implemented") }
}

enum LayoutReason: Equatable {
    case standard
    case macos(prevParentKind: NonLeafTreeNodeKind)
}

extension Window {
    var isFloating: Bool { parent is Workspace }

    @discardableResult
    @MainActor
    func bindAsFloatingWindow(to workspace: Workspace) -> BindingData? {
        bind(to: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    func asMacWindow() -> MacWindow { self as! MacWindow }
}
