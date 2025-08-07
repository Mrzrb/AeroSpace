@testable import AppBundle
import AppKit
import Common

class TestTilingContainer: TilingContainer {
    @MainActor
    init(orientation: Orientation) {
        // Create a dummy workspace as parent
        let workspace = Workspace.get(byName: "test")
        super.init(parent: workspace, adaptiveWeight: 1.0, orientation, .tiles, index: 0)
    }
}

final class TestWindow: Window, CustomStringConvertible {
    private var _rect: Rect?
    var shouldFailGetAxRect: Bool = false
    var testRect: Rect? {
        get { _rect }
        set { _rect = newValue }
    }

    @MainActor
    private init(_ id: UInt32, _ parent: NonLeafTreeNodeObject, _ adaptiveWeight: CGFloat, _ rect: Rect?) {
        _rect = rect
        super.init(id: id, TestApp.shared, lastFloatingSize: nil, parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
    }
    
    @MainActor
    init(id: UInt32, app: any AbstractApp, lastFloatingSize: CGSize?, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        _rect = nil
        super.init(id: id, app, lastFloatingSize: lastFloatingSize, parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @discardableResult
    @MainActor
    static func new(id: UInt32, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat = 1, rect: Rect? = nil) -> TestWindow {
        let wi = TestWindow(id, parent, adaptiveWeight, rect)
        TestApp.shared._windows.append(wi)
        return wi
    }

    nonisolated var description: String { "TestWindow(\(windowId))" }

    @MainActor
    override func nativeFocus() {
        appForTests = TestApp.shared
        TestApp.shared.focusedWindow = self
    }

    override func closeAxWindow() {
        unbindFromParent()
    }

    override var title: String { description }

    @MainActor override func getAxRect() async throws -> Rect? { // todo change to not Optional
        if shouldFailGetAxRect {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test failure"])
        }
        return _rect
    }
    
    @MainActor override func getAxSize() async throws -> CGSize? {
        if shouldFailGetAxRect {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test failure"])
        }
        return _rect?.size
    }
    
    @MainActor override func getAxTopLeftCorner() async throws -> CGPoint? {
        if shouldFailGetAxRect {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test failure"])
        }
        return _rect?.topLeftCorner
    }
    
    override func setAxTopLeftCorner(_ point: CGPoint) {
        if let currentRect = _rect {
            _rect = Rect(topLeftX: point.x, topLeftY: point.y, width: currentRect.width, height: currentRect.height)
        } else {
            _rect = Rect(topLeftX: point.x, topLeftY: point.y, width: 400, height: 300)
        }
    }
    
    override func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) {
        let currentRect = _rect ?? Rect(topLeftX: 0, topLeftY: 0, width: 400, height: 300)
        let newTopLeft = topLeft ?? currentRect.topLeftCorner
        let newSize = size ?? currentRect.size
        _rect = Rect(topLeftX: newTopLeft.x, topLeftY: newTopLeft.y, width: newSize.width, height: newSize.height)
    }
    
    @MainActor
    override func setAxFrameBlocking(_ topLeft: CGPoint?, _ size: CGSize?) async throws {
        setAxFrame(topLeft, size)
    }
    
    override func setSizeAsync(_ size: CGSize) {
        if let currentRect = _rect {
            _rect = Rect(topLeftX: currentRect.topLeftX, topLeftY: currentRect.topLeftY, width: size.width, height: size.height)
        } else {
            _rect = Rect(topLeftX: 0, topLeftY: 0, width: size.width, height: size.height)
        }
    }
    
    // Animation bypass methods for immediate updates
    @MainActor
    override func setAxTopLeftCornerImmediate(_ point: CGPoint) {
        setAxTopLeftCorner(point)
    }
    
    @MainActor
    override func setAxFrameImmediate(_ topLeft: CGPoint?, _ size: CGSize?) {
        setAxFrame(topLeft, size)
    }
    
    @MainActor
    override func setSizeAsyncImmediate(_ size: CGSize) {
        setSizeAsync(size)
    }
    
    @MainActor
    func setTestRect(_ rect: Rect) {
        _rect = rect
    }
    

}
