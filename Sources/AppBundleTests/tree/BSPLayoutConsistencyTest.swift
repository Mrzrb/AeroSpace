@testable import AppBundle
import XCTest

@MainActor
class BSPLayoutConsistencyTest: XCTestCase {
    
    override func setUp() async throws { setUpWorkspacesForTests() }
    
    // MARK: - enforceBSPLayoutConsistency Tests
    
    func testEnforceBSPLayoutConsistency_WithBSPContainer_ShouldConvertChildContainers() {
        // Given: A BSP container with child containers that have different layouts
        let workspace = Workspace.get(byName: "test")
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        let childContainer1 = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .h, .tiles, index: 0)
        let childContainer2 = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .v, .accordion, index: 1)
        
        // Verify initial state
        XCTAssertEqual(rootContainer.layout, .bsp)
        XCTAssertEqual(childContainer1.layout, .tiles)
        XCTAssertEqual(childContainer2.layout, .accordion)
        
        // When: Enforcing BSP layout consistency
        rootContainer.enforceBSPLayoutConsistency()
        
        // Then: All child containers should be converted to BSP
        XCTAssertEqual(rootContainer.layout, .bsp)
        XCTAssertEqual(childContainer1.layout, .bsp)
        XCTAssertEqual(childContainer2.layout, .bsp)
    }
    
    func testEnforceBSPLayoutConsistency_WithNestedContainers_ShouldConvertRecursively() {
        // Given: A nested structure with mixed layouts
        let workspace = Workspace.get(byName: "test")
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        let level1Container = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .h, .tiles, index: 0)
        let level2Container = TilingContainer(parent: level1Container, adaptiveWeight: 1.0, .v, .accordion, index: 0)
        let level3Container = TilingContainer(parent: level2Container, adaptiveWeight: 1.0, .h, .tiles, index: 0)
        
        // Verify initial state
        XCTAssertEqual(rootContainer.layout, .bsp)
        XCTAssertEqual(level1Container.layout, .tiles)
        XCTAssertEqual(level2Container.layout, .accordion)
        XCTAssertEqual(level3Container.layout, .tiles)
        
        // When: Enforcing BSP layout consistency
        rootContainer.enforceBSPLayoutConsistency()
        
        // Then: All nested containers should be converted to BSP
        XCTAssertEqual(rootContainer.layout, .bsp)
        XCTAssertEqual(level1Container.layout, .bsp)
        XCTAssertEqual(level2Container.layout, .bsp)
        XCTAssertEqual(level3Container.layout, .bsp)
    }
    
    func testEnforceBSPLayoutConsistency_WithNonBSPContainer_ShouldNotChangeAnything() {
        // Given: A non-BSP container with child containers
        let workspace = Workspace.get(byName: "test")
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .tiles
        
        let childContainer = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .h, .accordion, index: 0)
        
        // Verify initial state
        XCTAssertEqual(rootContainer.layout, .tiles)
        XCTAssertEqual(childContainer.layout, .accordion)
        
        // When: Enforcing BSP layout consistency
        rootContainer.enforceBSPLayoutConsistency()
        
        // Then: Layouts should remain unchanged
        XCTAssertEqual(rootContainer.layout, .tiles)
        XCTAssertEqual(childContainer.layout, .accordion)
    }
    
    func testEnforceBSPLayoutConsistency_WithMixedChildren_ShouldOnlyConvertContainers() {
        // Given: A BSP container with both window and container children
        let workspace = Workspace.get(byName: "test")
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        let window = TestWindow.new(id: 1, parent: rootContainer, adaptiveWeight: 1.0)
        let childContainer = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .h, .tiles, index: 1)
        
        // Verify initial state
        XCTAssertEqual(rootContainer.layout, .bsp)
        XCTAssertEqual(childContainer.layout, .tiles)
        
        // When: Enforcing BSP layout consistency
        rootContainer.enforceBSPLayoutConsistency()
        
        // Then: Container should be converted, window should remain unchanged
        XCTAssertEqual(rootContainer.layout, .bsp)
        XCTAssertEqual(childContainer.layout, .bsp)
        XCTAssertNotNil(window.parent) // Window should still be there
    }
    
    // MARK: - validateBSPLayoutConsistency Tests
    
    func testValidateBSPLayoutConsistency_WithConsistentLayout_ShouldReturnTrue() {
        // Given: A BSP container with all BSP child containers
        let workspace = Workspace.get(byName: "test")
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        let childContainer1 = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let childContainer2 = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .v, .bsp, index: 1)
        
        // When: Validating BSP layout consistency
        let isConsistent = rootContainer.validateBSPLayoutConsistency()
        
        // Then: Should return true
        XCTAssertTrue(isConsistent)
    }
    
    func testValidateBSPLayoutConsistency_WithInconsistentLayout_ShouldReturnFalse() {
        // Given: A BSP container with non-BSP child containers
        let workspace = Workspace.get(byName: "test")
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        let childContainer1 = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let childContainer2 = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .v, .tiles, index: 1)
        
        // When: Validating BSP layout consistency
        let isConsistent = rootContainer.validateBSPLayoutConsistency()
        
        // Then: Should return false
        XCTAssertFalse(isConsistent)
    }
    
    func testValidateBSPLayoutConsistency_WithNonBSPContainer_ShouldReturnTrue() {
        // Given: A non-BSP container
        let workspace = Workspace.get(byName: "test")
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .tiles
        
        // When: Validating BSP layout consistency
        let isConsistent = rootContainer.validateBSPLayoutConsistency()
        
        // Then: Should return true (consistency check only applies to BSP containers)
        XCTAssertTrue(isConsistent)
    }
    
    func testValidateBSPLayoutConsistency_WithNestedInconsistency_ShouldReturnFalse() {
        // Given: A nested structure with inconsistency at deeper level
        let workspace = Workspace.get(byName: "test")
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        let level1Container = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        let level2Container = TilingContainer(parent: level1Container, adaptiveWeight: 1.0, .v, .tiles, index: 0)
        
        // When: Validating BSP layout consistency
        let isConsistent = rootContainer.validateBSPLayoutConsistency()
        
        // Then: Should return false due to nested inconsistency
        XCTAssertFalse(isConsistent)
    }
    
    // MARK: - getBSPLayoutConsistencyReport Tests
    
    func testGetBSPLayoutConsistencyReport_WithInconsistencies_ShouldReturnIssues() {
        // Given: A BSP container with layout inconsistencies
        let workspace = Workspace.get(byName: "test")
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        let childContainer1 = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .h, .tiles, index: 0)
        let childContainer2 = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .v, .accordion, index: 1)
        
        // When: Getting consistency report
        let report = rootContainer.getBSPLayoutConsistencyReport()
        
        // Then: Should report the inconsistencies
        XCTAssertEqual(report.count, 2)
        
        // Check first issue
        if case .childContainerWrongLayout(let childIndex, let expectedLayout, let actualLayout) = report[0] {
            XCTAssertEqual(childIndex, 0)
            XCTAssertEqual(expectedLayout, .bsp)
            XCTAssertEqual(actualLayout, .tiles)
        } else {
            XCTFail("Expected childContainerWrongLayout issue")
        }
        
        // Check second issue
        if case .childContainerWrongLayout(let childIndex, let expectedLayout, let actualLayout) = report[1] {
            XCTAssertEqual(childIndex, 1)
            XCTAssertEqual(expectedLayout, .bsp)
            XCTAssertEqual(actualLayout, .accordion)
        } else {
            XCTFail("Expected childContainerWrongLayout issue")
        }
    }
    
    func testGetBSPLayoutConsistencyReport_WithConsistentLayout_ShouldReturnEmptyReport() {
        // Given: A BSP container with consistent layout
        let workspace = Workspace.get(byName: "test")
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .bsp
        
        let childContainer = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .h, .bsp, index: 0)
        
        // When: Getting consistency report
        let report = rootContainer.getBSPLayoutConsistencyReport()
        
        // Then: Should return empty report
        XCTAssertTrue(report.isEmpty)
    }
    
    func testGetBSPLayoutConsistencyReport_WithNonBSPContainer_ShouldReturnEmptyReport() {
        // Given: A non-BSP container
        let workspace = Workspace.get(byName: "test")
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = .tiles
        
        let childContainer = TilingContainer(parent: rootContainer, adaptiveWeight: 1.0, .h, .accordion, index: 0)
        
        // When: Getting consistency report
        let report = rootContainer.getBSPLayoutConsistencyReport()
        
        // Then: Should return empty report
        XCTAssertTrue(report.isEmpty)
    }
}