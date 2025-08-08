import Foundation
@preconcurrency import Metal
import CoreGraphics
import IOKit.ps
import Common

/// Hardware acceleration capabilities and detection
enum HardwareAcceleration {

    // MARK: - GPU Detection

    /// Detected GPU information
    struct GPUInfo {
        let name: String
        let isDiscrete: Bool
        let supportsMetalPerformanceShaders: Bool
        let maxThreadsPerGroup: Int
        let recommendedMaxWorkingSetSize: Int
        let hasUnifiedMemory: Bool
        let supportsNonUniformThreadgroups: Bool
        let registryID: UInt64
    }

    /// GPU acceleration availability status
    enum AccelerationStatus {
        case available(GPUInfo)
        case unavailable(reason: String)
        case disabled(reason: String)
    }

    /// Current GPU acceleration status
    @MainActor private(set) static var status: AccelerationStatus = .unavailable(reason: "Not initialized")

    /// Available Metal device
    @MainActor private(set) static var metalDevice: MTLDevice?

    /// Metal command queue for animation operations
    @MainActor private(set) static var commandQueue: MTLCommandQueue?

    /// Metal compute pipeline for interpolation
    @MainActor private(set) static var interpolationPipeline: MTLComputePipelineState?

    // MARK: - Detection Methods

    /// Detect GPU acceleration capabilities
    @MainActor static func detectCapabilities() -> AccelerationStatus {
        // Check if Metal is available
        guard let device = MTLCreateSystemDefaultDevice() else {
            let status = AccelerationStatus.unavailable(reason: "Metal framework not available")
            self.status = status
            return status
        }

        metalDevice = device

        // Create command queue
        guard let queue = device.makeCommandQueue() else {
            let status = AccelerationStatus.unavailable(reason: "Failed to create Metal command queue")
            self.status = status
            return status
        }

        commandQueue = queue

        // Gather GPU information
        let gpuInfo = GPUInfo(
            name: device.name,
            isDiscrete: !device.hasUnifiedMemory,
            supportsMetalPerformanceShaders: device.supportsFamily(.common3),
            maxThreadsPerGroup: device.maxThreadsPerThreadgroup.width,
            recommendedMaxWorkingSetSize: Int(device.recommendedMaxWorkingSetSize),
            hasUnifiedMemory: device.hasUnifiedMemory,
            supportsNonUniformThreadgroups: device.supportsFamily(.common3),
            registryID: device.registryID,
        )

        // Try to create interpolation compute pipeline
        do {
            interpolationPipeline = try createInterpolationPipeline(device: device)
        } catch {
            let status = AccelerationStatus.unavailable(reason: "Failed to create compute pipeline: \(error.localizedDescription)")
            self.status = status
            return status
        }

        let status = AccelerationStatus.available(gpuInfo)
        self.status = status

        print("GPU acceleration available: \(gpuInfo.name)")
        print("  - Discrete GPU: \(gpuInfo.isDiscrete)")
        print("  - Unified Memory: \(gpuInfo.hasUnifiedMemory)")
        print("  - Max threads per group: \(gpuInfo.maxThreadsPerGroup)")
        print("  - Recommended working set: \(gpuInfo.recommendedMaxWorkingSetSize / 1024 / 1024) MB")

        return status
    }

    /// Create Metal compute pipeline for interpolation operations
    private static func createInterpolationPipeline(device: MTLDevice) throws -> MTLComputePipelineState {
        let library = try device.makeDefaultLibrary(bundle: Bundle.main)

        // Try to find the interpolation kernel function
        guard let function = library.makeFunction(name: "interpolate_rects") else {
            // If the function doesn't exist, create it programmatically
            return try createInterpolationPipelineFromSource(device: device)
        }

        return try device.makeComputePipelineState(function: function)
    }

    /// Create interpolation pipeline from Metal source code
    private static func createInterpolationPipelineFromSource(device: MTLDevice) throws -> MTLComputePipelineState {
        let metalSource = """
            #include <metal_stdlib>
            using namespace metal;

            struct Rect {
                float x;
                float y;
                float width;
                float height;
            };

            struct InterpolationParams {
                float progress;
                int easing_type; // 0=linear, 1=ease_in, 2=ease_out, 3=ease_in_out
            };

            // Easing functions
            float ease_in(float t) {
                return t * t;
            }

            float ease_out(float t) {
                return 1.0 - (1.0 - t) * (1.0 - t);
            }

            float ease_in_out(float t) {
                return t < 0.5 ? 2.0 * t * t : 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0;
            }

            float apply_easing(float t, int easing_type) {
                switch (easing_type) {
                    case 1: return ease_in(t);
                    case 2: return ease_out(t);
                    case 3: return ease_in_out(t);
                    default: return t; // linear
                }
            }

            kernel void interpolate_rects(
                device const Rect* source_rects [[buffer(0)]],
                device const Rect* target_rects [[buffer(1)]],
                device Rect* result_rects [[buffer(2)]],
                device const InterpolationParams& params [[buffer(3)]],
                uint index [[thread_position_in_grid]]
            ) {
                if (index >= 1024) return; // Safety check

                float eased_progress = apply_easing(params.progress, params.easing_type);

                Rect source = source_rects[index];
                Rect target = target_rects[index];

                result_rects[index] = {
                    source.x + (target.x - source.x) * eased_progress,
                    source.y + (target.y - source.y) * eased_progress,
                    source.width + (target.width - source.width) * eased_progress,
                    source.height + (target.height - source.height) * eased_progress
                };
            }
            """

        let library = try device.makeLibrary(source: metalSource, options: nil)
        let function = library.makeFunction(name: "interpolate_rects")!

        return try device.makeComputePipelineState(function: function)
    }

    // MARK: - Resource Monitoring

    /// GPU resource availability information
    struct ResourceInfo {
        let availableMemory: Int // bytes
        let usedMemory: Int // bytes
        let gpuUtilization: Double // 0.0 to 1.0
        let thermalState: ThermalState
        let powerState: PowerState
    }

    enum ThermalState {
        case nominal
        case fair
        case serious
        case critical
        case unknown
    }

    enum PowerState {
        case highPerformance
        case balanced
        case powerSaver
        case unknown
    }

    /// Monitor GPU resource availability
    @MainActor static func getResourceInfo() -> ResourceInfo? {
        // Only return resource info if GPU acceleration is available
        guard isAvailable, let device = metalDevice else { return nil }

        // Get memory information
        let availableMemory = Int(device.recommendedMaxWorkingSetSize)
        let usedMemory = getCurrentMemoryUsage()

        // Get thermal and power state from system
        let thermalState = getCurrentThermalState()
        let powerState = getCurrentPowerState()

        // Estimate GPU utilization (simplified)
        let gpuUtilization = estimateGPUUtilization()

        return ResourceInfo(
            availableMemory: availableMemory,
            usedMemory: usedMemory,
            gpuUtilization: gpuUtilization,
            thermalState: thermalState,
            powerState: powerState,
        )
    }

    /// Get current GPU memory usage (estimated)
    @MainActor private static func getCurrentMemoryUsage() -> Int {
        guard let device = metalDevice else { return 0 }

        // This is a simplified estimation
        // In a real implementation, you would track allocated buffers
        return Int(device.currentAllocatedSize)
    }

    /// Get current thermal state from system
    private static func getCurrentThermalState() -> ThermalState {
        // Use ProcessInfo to get thermal state
        let thermalState = ProcessInfo.processInfo.thermalState

        switch thermalState {
            case .nominal:
                return .nominal
            case .fair:
                return .fair
            case .serious:
                return .serious
            case .critical:
                return .critical
            @unknown default:
                return .unknown
        }
    }

    /// Get current power state (simplified)
    private static func getCurrentPowerState() -> PowerState {
        // Check if we're on battery power
        let powerSourceInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let powerSources = IOPSCopyPowerSourcesList(powerSourceInfo)?.takeRetainedValue() as? [CFTypeRef]

        var onBattery = false
        if let sources = powerSources {
            for source in sources {
                if let sourceDict = IOPSGetPowerSourceDescription(powerSourceInfo, source)?.takeUnretainedValue() as? [String: Any] {
                    if let powerSource = sourceDict[kIOPSPowerSourceStateKey as String] as? String {
                        if powerSource == kIOPSBatteryPowerValue as String {
                            onBattery = true
                            break
                        }
                    }
                }
            }
        }

        // Simple heuristic based on power source
        return onBattery ? .powerSaver : .highPerformance
    }

    /// Estimate GPU utilization (simplified)
    @MainActor private static func estimateGPUUtilization() -> Double {
        // This is a simplified estimation
        // In a real implementation, you would use performance counters

        // For now, base it on active animations and system load
        let activeAnimations = WindowAnimationEngine.shared.activeAnimationCount
        let maxAnimations = WindowAnimationEngine.shared.currentConfiguration.maxConcurrentAnimations

        return min(1.0, Double(activeAnimations) / Double(maxAnimations))
    }

    // MARK: - Capability Checks

    /// Check if GPU acceleration is available and recommended
    @MainActor static var isAvailable: Bool {
        switch status {
            case .available:
                return true
            default:
                return false
        }
    }

    /// Check if GPU acceleration should be used based on current conditions
    @MainActor static var shouldUseAcceleration: Bool {
        guard isAvailable else { return false }

        // Check resource constraints
        guard let resourceInfo = getResourceInfo() else { return false }

        // Don't use GPU acceleration if thermal state is critical
        if resourceInfo.thermalState == .critical {
            return false
        }

        // Don't use GPU acceleration if GPU utilization is already very high
        if resourceInfo.gpuUtilization > 0.9 {
            return false
        }

        // Don't use GPU acceleration if available memory is very low
        let memoryUsageRatio = Double(resourceInfo.usedMemory) / Double(resourceInfo.availableMemory)
        if memoryUsageRatio > 0.9 {
            return false
        }

        return true
    }

    /// Get recommended batch size for GPU operations
    @MainActor static var recommendedBatchSize: Int {
        guard let resourceInfo = getResourceInfo() else { return 1 }

        // Base batch size on available memory and GPU capabilities
        let baseSize = 32

        // Adjust based on thermal state
        let thermalMultiplier: Double = switch resourceInfo.thermalState {
            case .nominal:
                1.0
            case .fair:
                0.8
            case .serious:
                0.5
            case .critical:
                0.2
            case .unknown:
                0.7
        }

        // Adjust based on power state
        let powerMultiplier: Double = switch resourceInfo.powerState {
            case .highPerformance:
                1.0
            case .balanced:
                0.8
            case .powerSaver:
                0.5
            case .unknown:
                0.7
        }

        let adjustedSize = Int(Double(baseSize) * thermalMultiplier * powerMultiplier)
        return max(1, min(adjustedSize, 128)) // Clamp between 1 and 128
    }

    // MARK: - Cleanup

    /// Cleanup GPU resources
    @MainActor static func cleanup() {
        commandQueue = nil
        interpolationPipeline = nil
        metalDevice = nil
        status = .unavailable(reason: "Cleaned up")
    }
}

