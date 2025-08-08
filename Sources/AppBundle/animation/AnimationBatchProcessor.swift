import Foundation
@preconcurrency import Metal
import CoreGraphics
import Common

/// Batch processor for optimizing multiple simultaneous animations
@MainActor
class AnimationBatchProcessor {

    // MARK: - Batch Data Structures

    /// Represents a batch of animations to be processed together
    struct AnimationBatch {
        let id: UUID = UUID()
        let animations: [BatchedAnimation]
        let processingMode: ProcessingMode
        let timestamp: Date = Date()

        var count: Int { animations.count }
        var isEmpty: Bool { animations.isEmpty }
    }

    /// Individual animation within a batch
    struct BatchedAnimation {
        let windowId: UInt32
        let sourceRect: Rect
        let targetRect: Rect
        let progress: Double
        let easingType: EasingType

        /// Convert AnimationEasing to simplified EasingType for batch processing
        init(windowId: UInt32, sourceRect: Rect, targetRect: Rect, progress: Double, easing: AnimationEasing) {
            self.windowId = windowId
            self.sourceRect = sourceRect
            self.targetRect = targetRect
            self.progress = progress

            // Convert complex easing to simplified types for batch processing
            switch easing {
                case .linear:
                    self.easingType = .linear
                case .easeIn:
                    self.easingType = .easeIn
                case .easeOut:
                    self.easingType = .easeOut
                case .easeInOut:
                    self.easingType = .easeInOut
                case .custom, .spring, .bounce, .elastic:
                    // Complex easing functions fall back to individual processing
                    self.easingType = .easeOut // Default fallback
            }
        }
    }

    /// Simplified easing types for batch processing
    enum EasingType: Int, CaseIterable {
        case linear = 0
        case easeIn = 1
        case easeOut = 2
        case easeInOut = 3
    }

    /// Processing mode for animation batches
    enum ProcessingMode {
        case gpu(device: MTLDevice, pipeline: MTLComputePipelineState)
        case cpu
        case hybrid(gpuCount: Int, cpuCount: Int)
    }

    // MARK: - Properties

    private let hardwareAcceleration: HardwareAcceleration.Type
    private var pendingBatches: [AnimationBatch] = []
    private var processingQueue: DispatchQueue
    private var isProcessing: Bool = false

    // GPU resources
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var computePipeline: MTLComputePipelineState?

    // CPU processing resources
    private var cpuProcessingQueue: DispatchQueue

    // Performance tracking
    private var batchProcessingTimes: [TimeInterval] = []
    private var gpuProcessingTimes: [TimeInterval] = []
    private var cpuProcessingTimes: [TimeInterval] = []
    private let maxPerformanceHistorySize = 100

    // MARK: - Initialization

    init(hardwareAcceleration: HardwareAcceleration.Type = HardwareAcceleration.self) {
        self.hardwareAcceleration = hardwareAcceleration
        self.processingQueue = DispatchQueue(label: "com.aerospace.animation.batch", qos: .userInteractive)
        self.cpuProcessingQueue = DispatchQueue(label: "com.aerospace.animation.cpu", qos: .userInteractive, attributes: .concurrent)

        setupGPUResources()
    }

    deinit {
        // Note: Cleanup will be handled by the system when the object is deallocated
        // We cannot safely call async methods in deinit
    }

    // MARK: - GPU Setup

    private func setupGPUResources() {
        guard case .available = hardwareAcceleration.detectCapabilities() else {
            print("GPU resources not available for batch processing")
            return
        }

        metalDevice = hardwareAcceleration.metalDevice
        commandQueue = hardwareAcceleration.commandQueue
        computePipeline = hardwareAcceleration.interpolationPipeline

        if metalDevice != nil && commandQueue != nil && computePipeline != nil {
            print("GPU batch processing resources initialized")
        } else {
            print("Failed to initialize GPU batch processing resources")
        }
    }

    // MARK: - Batch Processing Interface

    /// Process a batch of animations
    func processBatch(_ animations: [BatchedAnimation]) async -> [Rect] {
        guard !animations.isEmpty else { return [] }

        let startTime = Date()
        let processingMode = determineOptimalProcessingMode(for: animations)
        let batch = AnimationBatch(animations: animations, processingMode: processingMode)

        let results: [Rect] = switch processingMode {
            case .gpu(let device, let pipeline):
                await processGPUBatch(batch, device: device, pipeline: pipeline)
            case .cpu:
                await processCPUBatch(batch)
            case .hybrid(let gpuCount, let cpuCount):
                await processHybridBatch(batch, gpuCount: gpuCount, cpuCount: cpuCount)
        }

        // Track performance
        let processingTime = Date().timeIntervalSince(startTime)
        recordBatchProcessingTime(processingTime, mode: processingMode)

        return results
    }

    /// Determine the optimal processing mode for a batch
    private func determineOptimalProcessingMode(for animations: [BatchedAnimation]) -> ProcessingMode {
        let batchSize = animations.count

        // Check if GPU acceleration is available and recommended
        guard hardwareAcceleration.shouldUseAcceleration,
              let device = metalDevice,
              let pipeline = computePipeline
        else {
            return .cpu
        }

        // For small batches, CPU might be faster due to GPU setup overhead
        if batchSize < 4 {
            return .cpu
        }

        // Check if all animations use simple easing (suitable for GPU)
        let hasComplexEasing = animations.contains { animation in
            // Complex easing types that require individual processing
            return false // All BatchedAnimation easing types are simple
        }

        if hasComplexEasing {
            // Use hybrid processing for mixed easing types
            let gpuCount = animations.count / 2
            let cpuCount = animations.count - gpuCount
            return .hybrid(gpuCount: gpuCount, cpuCount: cpuCount)
        }

        // Check system resources
        guard let resourceInfo = hardwareAcceleration.getResourceInfo() else {
            return .cpu
        }

        // Don't use GPU if thermal state is concerning
        if resourceInfo.thermalState == .serious || resourceInfo.thermalState == .critical {
            return .cpu
        }

        // Don't use GPU if utilization is already high
        if resourceInfo.gpuUtilization > 0.8 {
            return .cpu
        }

        // Use GPU for larger batches with good system conditions
        return .gpu(device: device, pipeline: pipeline)
    }

    // MARK: - GPU Batch Processing

    private func processGPUBatch(_ batch: AnimationBatch, device: MTLDevice, pipeline: MTLComputePipelineState) async -> [Rect] {
        let startTime = Date()

        guard let commandQueue else {
            print("GPU command queue not available, falling back to CPU")
            return await processCPUBatch(batch)
        }

        do {
            let results = try await performGPUInterpolation(batch.animations, device: device, pipeline: pipeline, commandQueue: commandQueue)

            let processingTime = Date().timeIntervalSince(startTime)
            recordGPUProcessingTime(processingTime)

            return results
        } catch {
            print("GPU batch processing failed: \(error), falling back to CPU")
            return await processCPUBatch(batch)
        }
    }

    private func performGPUInterpolation(_ animations: [BatchedAnimation], device: MTLDevice, pipeline: MTLComputePipelineState, commandQueue: MTLCommandQueue) async throws -> [Rect] {

        let animationCount = animations.count
        let bufferSize = animationCount * MemoryLayout<MetalRect>.stride

        // Create Metal buffers
        guard let sourceBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared),
              let targetBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared),
              let resultBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared),
              let paramsBuffer = device.makeBuffer(length: MemoryLayout<InterpolationParams>.stride, options: .storageModeShared)
        else {
            throw BatchProcessingError.bufferCreationFailed
        }

        // Fill source and target buffers
        let sourcePointer = sourceBuffer.contents().bindMemory(to: MetalRect.self, capacity: animationCount)
        let targetPointer = targetBuffer.contents().bindMemory(to: MetalRect.self, capacity: animationCount)

        for (index, animation) in animations.enumerated() {
            sourcePointer[index] = MetalRect(from: animation.sourceRect)
            targetPointer[index] = MetalRect(from: animation.targetRect)
        }

        // Set up interpolation parameters (using first animation's progress and easing)
        let paramsPointer = paramsBuffer.contents().bindMemory(to: InterpolationParams.self, capacity: 1)
        paramsPointer[0] = InterpolationParams(
            progress: Float(animations.first?.progress ?? 0.0),
            easingType: Int32(animations.first?.easingType.rawValue ?? 0),
        )

        // Create command buffer and encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            throw BatchProcessingError.commandCreationFailed
        }

        // Set up compute pipeline
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(targetBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(resultBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 3)

        // Calculate thread group sizes
        let threadsPerGroup = MTLSize(width: min(pipeline.threadExecutionWidth, animationCount), height: 1, depth: 1)
        let threadGroups = MTLSize(width: (animationCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)

        // Dispatch compute kernel
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()

        // Execute and wait
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw BatchProcessingError.gpuExecutionFailed(error)
        }

        // Read results
        let resultPointer = resultBuffer.contents().bindMemory(to: MetalRect.self, capacity: animationCount)
        var results: [Rect] = []

        for i in 0 ..< animationCount {
            results.append(resultPointer[i].toRect())
        }

        return results
    }

    // MARK: - CPU Batch Processing

    private func processCPUBatch(_ batch: AnimationBatch) async -> [Rect] {
        let startTime = Date()

        return await withTaskGroup(of: (Int, Rect).self, returning: [Rect].self) { group in
            // Process animations in parallel on CPU
            for (index, animation) in batch.animations.enumerated() {
                group.addTask {
                    let interpolatedRect = self.interpolateRectCPU(
                        from: animation.sourceRect,
                        to: animation.targetRect,
                        progress: animation.progress,
                        easing: animation.easingType,
                    )
                    return (index, interpolatedRect)
                }
            }

            // Collect results in order
            var results = Array<Rect?>(repeating: nil, count: batch.animations.count)
            for await (index, rect) in group {
                results[index] = rect
            }

            let processingTime = Date().timeIntervalSince(startTime)
            self.recordCPUProcessingTime(processingTime)

            return results.compactMap { $0 }
        }
    }

    private nonisolated func interpolateRectCPU(from source: Rect, to target: Rect, progress: Double, easing: EasingType) -> Rect {
        let easedProgress = applyCPUEasing(progress, type: easing)

        return Rect(
            topLeftX: source.topLeftX + (target.topLeftX - source.topLeftX) * easedProgress,
            topLeftY: source.topLeftY + (target.topLeftY - source.topLeftY) * easedProgress,
            width: source.width + (target.width - source.width) * easedProgress,
            height: source.height + (target.height - source.height) * easedProgress,
        )
    }

    private nonisolated func applyCPUEasing(_ progress: Double, type: EasingType) -> Double {
        switch type {
            case .linear:
                return progress
            case .easeIn:
                return progress * progress
            case .easeOut:
                return 1.0 - (1.0 - progress) * (1.0 - progress)
            case .easeInOut:
                return progress < 0.5 ? 2.0 * progress * progress : 1.0 - pow(-2.0 * progress + 2.0, 2.0) / 2.0
        }
    }

    // MARK: - Hybrid Batch Processing

    private func processHybridBatch(_ batch: AnimationBatch, gpuCount: Int, cpuCount: Int) async -> [Rect] {
        let animations = batch.animations
        let gpuAnimations = Array(animations.prefix(gpuCount))
        let cpuAnimations = Array(animations.suffix(cpuCount))

        // Safely check for GPU resources
        guard let device = metalDevice,
              let pipeline = computePipeline
        else {
            // If GPU resources aren't available, fall back to CPU processing
            print("GPU resources not available for hybrid processing, falling back to CPU")
            return await processCPUBatch(batch)
        }

        async let gpuResults = processGPUBatch(
            AnimationBatch(animations: gpuAnimations, processingMode: .gpu(device: device, pipeline: pipeline)),
            device: device,
            pipeline: pipeline,
        )

        async let cpuResults = processCPUBatch(
            AnimationBatch(animations: cpuAnimations, processingMode: .cpu),
        )

        let (gpu, cpu) = await (gpuResults, cpuResults)
        return gpu + cpu
    }

    // MARK: - Performance Tracking

    private func recordBatchProcessingTime(_ time: TimeInterval, mode: ProcessingMode) {
        batchProcessingTimes.append(time)
        if batchProcessingTimes.count > maxPerformanceHistorySize {
            batchProcessingTimes.removeFirst()
        }

        let modeDescription: String = switch mode {
            case .gpu:
                "GPU"
            case .cpu:
                "CPU"
            case .hybrid(let gpuCount, let cpuCount):
                "Hybrid(GPU:\(gpuCount), CPU:\(cpuCount))"
        }

        print("Batch processing (\(modeDescription)): \(time * 1000)ms")
    }

    private func recordGPUProcessingTime(_ time: TimeInterval) {
        gpuProcessingTimes.append(time)
        if gpuProcessingTimes.count > maxPerformanceHistorySize {
            gpuProcessingTimes.removeFirst()
        }
    }

    private func recordCPUProcessingTime(_ time: TimeInterval) {
        cpuProcessingTimes.append(time)
        if cpuProcessingTimes.count > maxPerformanceHistorySize {
            cpuProcessingTimes.removeFirst()
        }
    }

    // MARK: - Performance Metrics

    struct BatchPerformanceMetrics {
        let averageBatchTime: TimeInterval
        let averageGPUTime: TimeInterval
        let averageCPUTime: TimeInterval
        let totalBatchesProcessed: Int
        let gpuBatchesProcessed: Int
        let cpuBatchesProcessed: Int
        let gpuSpeedupFactor: Double // How much faster GPU is compared to CPU
    }

    func getPerformanceMetrics() -> BatchPerformanceMetrics {
        let avgBatchTime = batchProcessingTimes.isEmpty ? 0 : batchProcessingTimes.reduce(0, +) / Double(batchProcessingTimes.count)
        let avgGPUTime = gpuProcessingTimes.isEmpty ? 0 : gpuProcessingTimes.reduce(0, +) / Double(gpuProcessingTimes.count)
        let avgCPUTime = cpuProcessingTimes.isEmpty ? 0 : cpuProcessingTimes.reduce(0, +) / Double(cpuProcessingTimes.count)

        let speedupFactor = (avgCPUTime > 0 && avgGPUTime > 0) ? avgCPUTime / avgGPUTime : 1.0

        return BatchPerformanceMetrics(
            averageBatchTime: avgBatchTime,
            averageGPUTime: avgGPUTime,
            averageCPUTime: avgCPUTime,
            totalBatchesProcessed: batchProcessingTimes.count,
            gpuBatchesProcessed: gpuProcessingTimes.count,
            cpuBatchesProcessed: cpuProcessingTimes.count,
            gpuSpeedupFactor: speedupFactor,
        )
    }

    // MARK: - Cleanup

    func cleanup() {
        pendingBatches.removeAll()
        batchProcessingTimes.removeAll()
        gpuProcessingTimes.removeAll()
        cpuProcessingTimes.removeAll()

        metalDevice = nil
        commandQueue = nil
        computePipeline = nil
    }
}

// MARK: - Supporting Types

/// Metal-compatible rectangle structure
private struct MetalRect {
    let x: Float
    let y: Float
    let width: Float
    let height: Float

    init(from rect: Rect) {
        self.x = Float(rect.topLeftX)
        self.y = Float(rect.topLeftY)
        self.width = Float(rect.width)
        self.height = Float(rect.height)
    }

    func toRect() -> Rect {
        return Rect(
            topLeftX: Double(x),
            topLeftY: Double(y),
            width: Double(width),
            height: Double(height),
        )
    }
}

/// Metal-compatible interpolation parameters
private struct InterpolationParams {
    let progress: Float
    let easingType: Int32
}

/// Batch processing errors
enum BatchProcessingError: Error, LocalizedError {
    case bufferCreationFailed
    case commandCreationFailed
    case gpuExecutionFailed(Error)
    case invalidBatchSize

    var errorDescription: String? {
        switch self {
            case .bufferCreationFailed:
                return "Failed to create Metal buffers for batch processing"
            case .commandCreationFailed:
                return "Failed to create Metal command buffer or encoder"
            case .gpuExecutionFailed(let error):
                return "GPU execution failed: \(error.localizedDescription)"
            case .invalidBatchSize:
                return "Invalid batch size for processing"
        }
    }
}
