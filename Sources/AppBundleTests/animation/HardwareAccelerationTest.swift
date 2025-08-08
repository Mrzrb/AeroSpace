import XCTest
@testable import AppBundle
import Metal

class HardwareAccelerationTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clean up any previous state will be done in individual tests
    }
    
    override func tearDown() {
        // Cleanup will be done in individual tests
        super.tearDown()
    }
    
    // MARK: - Detection Tests
    
    @MainActor
    func testGPUDetection() {
        HardwareAcceleration.cleanup()
        let status = HardwareAcceleration.detectCapabilities()
        
        switch status {
        case .available(let gpuInfo):
            // Verify GPU info is populated correctly
            XCTAssertFalse(gpuInfo.name.isEmpty, "GPU name should not be empty")
            XCTAssertGreaterThan(gpuInfo.maxThreadsPerGroup, 0, "Max threads per group should be positive")
            XCTAssertGreaterThan(gpuInfo.recommendedMaxWorkingSetSize, 0, "Working set size should be positive")
            
            print("Detected GPU: \(gpuInfo.name)")
            print("  - Discrete: \(gpuInfo.isDiscrete)")
            print("  - Unified Memory: \(gpuInfo.hasUnifiedMemory)")
            print("  - Max Threads: \(gpuInfo.maxThreadsPerGroup)")
            
        case .unavailable(let reason):
            print("GPU acceleration unavailable: \(reason)")
            // This is acceptable on systems without Metal support
            
        case .disabled(let reason):
            XCTFail("GPU should not be disabled during detection: \(reason)")
        }
    }
    
    @MainActor
    func testMetalDeviceAvailability() {
        // Test if Metal device can be created
        let device = MTLCreateSystemDefaultDevice()
        
        if device != nil {
            let isAvailable = HardwareAcceleration.isAvailable
            let statusUnavailable = HardwareAcceleration.status.isUnavailable
            XCTAssertTrue(isAvailable || statusUnavailable,
                         "If Metal device exists, acceleration should be available or have a valid reason for being unavailable")
        } else {
            // On systems without Metal support, acceleration should be unavailable
            switch HardwareAcceleration.detectCapabilities() {
            case .unavailable:
                break // Expected
            default:
                XCTFail("Without Metal device, acceleration should be unavailable")
            }
        }
    }
    
    @MainActor
    func testGPUInfoAccuracy() {
        guard case .available(let gpuInfo) = HardwareAcceleration.detectCapabilities() else {
            // Skip test if GPU acceleration is not available
            return
        }
        
        // Verify GPU info matches Metal device properties
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal device should be available if GPU acceleration is available")
            return
        }
        
        XCTAssertEqual(gpuInfo.name, device.name, "GPU name should match Metal device name")
        XCTAssertEqual(gpuInfo.hasUnifiedMemory, device.hasUnifiedMemory, "Unified memory flag should match")
        XCTAssertEqual(gpuInfo.registryID, device.registryID, "Registry ID should match")
        XCTAssertEqual(gpuInfo.maxThreadsPerGroup, device.maxThreadsPerThreadgroup.width, "Max threads should match")
    }
    
    // MARK: - Resource Monitoring Tests
    
    @MainActor
    func testResourceInfoRetrieval() {
        // First ensure GPU acceleration is detected
        _ = HardwareAcceleration.detectCapabilities()
        
        let resourceInfo = HardwareAcceleration.getResourceInfo()
        
        if HardwareAcceleration.isAvailable {
            XCTAssertNotNil(resourceInfo, "Resource info should be available when GPU acceleration is available")
            
            if let info = resourceInfo {
                XCTAssertGreaterThan(info.availableMemory, 0, "Available memory should be positive")
                XCTAssertGreaterThanOrEqual(info.usedMemory, 0, "Used memory should be non-negative")
                XCTAssertGreaterThanOrEqual(info.gpuUtilization, 0.0, "GPU utilization should be non-negative")
                XCTAssertLessThanOrEqual(info.gpuUtilization, 1.0, "GPU utilization should not exceed 1.0")
                
                print("GPU Resource Info:")
                print("  - Available Memory: \(info.availableMemory / 1024 / 1024) MB")
                print("  - Used Memory: \(info.usedMemory / 1024 / 1024) MB")
                print("  - GPU Utilization: \(info.gpuUtilization * 100)%")
                print("  - Thermal State: \(info.thermalState)")
                print("  - Power State: \(info.powerState)")
            }
        } else {
            XCTAssertNil(resourceInfo, "Resource info should be nil when GPU acceleration is unavailable")
        }
    }
    
    @MainActor
    func testThermalStateDetection() {
        // Test thermal state detection
        let resourceInfo = HardwareAcceleration.getResourceInfo()
        
        if let info = resourceInfo {
            // Thermal state should be one of the valid values
            switch info.thermalState {
            case .nominal, .fair, .serious, .critical, .unknown:
                break // All valid states
            }
            
            // Thermal state should affect acceleration recommendation
            if info.thermalState == .critical {
                let shouldUse = HardwareAcceleration.shouldUseAcceleration
                XCTAssertFalse(shouldUse,
                              "GPU acceleration should not be recommended in critical thermal state")
            }
        }
    }
    
    @MainActor
    func testPowerStateDetection() {
        let resourceInfo = HardwareAcceleration.getResourceInfo()
        
        if let info = resourceInfo {
            // Power state should be one of the valid values
            switch info.powerState {
            case .highPerformance, .balanced, .powerSaver, .unknown:
                break // All valid states
            }
        }
    }
    
    // MARK: - Capability Tests
    
    @MainActor
    func testAccelerationRecommendation() {
        _ = HardwareAcceleration.detectCapabilities()
        
        let shouldUse = HardwareAcceleration.shouldUseAcceleration
        let isAvailable = HardwareAcceleration.isAvailable
        
        if !isAvailable {
            XCTAssertFalse(shouldUse, "Should not recommend acceleration when not available")
        }
        
        // Test with different resource conditions
        if let resourceInfo = HardwareAcceleration.getResourceInfo() {
            if resourceInfo.thermalState == .critical {
                XCTAssertFalse(shouldUse, "Should not recommend acceleration in critical thermal state")
            }
            
            if resourceInfo.gpuUtilization > 0.9 {
                XCTAssertFalse(shouldUse, "Should not recommend acceleration when GPU utilization is very high")
            }
        }
    }
    
    @MainActor
    func testBatchSizeRecommendation() {
        _ = HardwareAcceleration.detectCapabilities()
        
        let batchSize = HardwareAcceleration.recommendedBatchSize
        
        XCTAssertGreaterThan(batchSize, 0, "Batch size should be positive")
        XCTAssertLessThanOrEqual(batchSize, 128, "Batch size should not exceed maximum")
        
        print("Recommended batch size: \(batchSize)")
    }
    
    // MARK: - Configuration Integration Tests
    
    @MainActor
    func testAnimationConfigGPUSettings() {
        var config = AnimationConfig.default
        
        // Test default values
        XCTAssertTrue(config.gpuAccelerationEnabled, "GPU acceleration should be enabled by default")
        XCTAssertEqual(config.gpuAccelerationMode, .automatic, "GPU acceleration mode should be automatic by default")
        XCTAssertEqual(config.gpuBatchSize, 32, "Default GPU batch size should be 32")
        XCTAssertEqual(config.gpuFallbackThreshold, 0.8, "Default GPU fallback threshold should be 0.8")
        
        // Test validation
        config.gpuBatchSize = 0
        let errors = config.validate()
        XCTAssertTrue(errors.contains { $0.contains("GPU batch size") }, "Should validate GPU batch size")
        
        config.gpuBatchSize = 300
        let errors2 = config.validate()
        XCTAssertTrue(errors2.contains { $0.contains("GPU batch size") }, "Should validate GPU batch size upper bound")
        
        config.gpuBatchSize = 32
        config.gpuFallbackThreshold = -0.1
        let errors3 = config.validate()
        XCTAssertTrue(errors3.contains { $0.contains("GPU fallback threshold") }, "Should validate GPU fallback threshold")
        
        config.gpuFallbackThreshold = 1.1
        let errors4 = config.validate()
        XCTAssertTrue(errors4.contains { $0.contains("GPU fallback threshold") }, "Should validate GPU fallback threshold upper bound")
    }
    
    @MainActor
    func testGPUAccelerationModeDescriptions() {
        XCTAssertFalse(GPUAccelerationMode.disabled.description.isEmpty)
        XCTAssertFalse(GPUAccelerationMode.automatic.description.isEmpty)
        XCTAssertFalse(GPUAccelerationMode.forced.description.isEmpty)
        
        // Test all cases are covered
        let allModes: [GPUAccelerationMode] = [.disabled, .automatic, .forced]
        XCTAssertEqual(allModes.count, GPUAccelerationMode.allCases.count, "All GPU acceleration modes should be tested")
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testDetectionPerformance() {
        measure {
            _ = HardwareAcceleration.detectCapabilities()
        }
    }
    
    @MainActor
    func testResourceMonitoringPerformance() {
        _ = HardwareAcceleration.detectCapabilities()
        
        measure {
            _ = HardwareAcceleration.getResourceInfo()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
    func testCleanupHandling() {
        // Detect capabilities first
        _ = HardwareAcceleration.detectCapabilities()
        
        // Cleanup should not crash
        HardwareAcceleration.cleanup()
        
        // After cleanup, status should be unavailable
        let isAvailable = HardwareAcceleration.isAvailable
        XCTAssertFalse(isAvailable, "GPU acceleration should not be available after cleanup")
        
        // Should be able to detect again after cleanup
        let newStatus = HardwareAcceleration.detectCapabilities()
        switch newStatus {
        case .available, .unavailable:
            break // Both are valid after re-detection
        case .disabled:
            XCTFail("GPU should not be disabled after re-detection")
        }
    }
    
    @MainActor
    func testMultipleDetectionCalls() {
        // Multiple detection calls should be safe
        let status1 = HardwareAcceleration.detectCapabilities()
        let status2 = HardwareAcceleration.detectCapabilities()
        let status3 = HardwareAcceleration.detectCapabilities()
        
        // Results should be consistent
        switch (status1, status2, status3) {
        case (.available(let gpu1), .available(let gpu2), .available(let gpu3)):
            XCTAssertEqual(gpu1.name, gpu2.name, "GPU name should be consistent")
            XCTAssertEqual(gpu2.name, gpu3.name, "GPU name should be consistent")
            XCTAssertEqual(gpu1.registryID, gpu2.registryID, "GPU registry ID should be consistent")
            XCTAssertEqual(gpu2.registryID, gpu3.registryID, "GPU registry ID should be consistent")
            
        case (.unavailable, .unavailable, .unavailable):
            break // Consistent unavailability is fine
            
        default:
            XCTFail("Detection results should be consistent across multiple calls")
        }
    }
}

// MARK: - Helper Extensions

private extension HardwareAcceleration.AccelerationStatus {
    var isUnavailable: Bool {
        switch self {
        case .unavailable:
            return true
        default:
            return false
        }
    }
}