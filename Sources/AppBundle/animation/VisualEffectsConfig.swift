import Foundation
import CoreGraphics

/// Configuration for visual effects system
struct VisualEffectsConfig {

    // MARK: - General Settings

    var enabled: Bool = true
    var adaptiveQuality: Bool = true
    var performanceThreshold: Double = 16.67 // ~60fps in milliseconds

    // MARK: - Motion Blur Settings

    var motionBlurEnabled: Bool = true
    var motionBlurVelocityThreshold: Double = 100.0 // pixels per second
    var maxMotionBlurSpeed: Double = 1000.0 // pixels per second
    var maxMotionBlurIntensity: Double = 0.8
    var automaticMotionEffects: Bool = true

    // MARK: - Afterimage Settings

    var afterimageEnabled: Bool = true
    var afterimageTrailLength: Int = 5
    var afterimageOpacityDecay: Double = 0.7
    var afterimageUpdateInterval: TimeInterval = 1.0 / 30.0 // 30fps for afterimages

    // MARK: - Particle Effects Settings

    var particleEffectsEnabled: Bool = true
    var particleCount: Int = 20
    var particleSize: CGSize = CGSize(width: 4.0, height: 4.0)
    var particleEffectDuration: TimeInterval = 1.0
    var particleSpread: Double = 50.0 // pixels
    var particleVelocity: Double = 100.0 // pixels per second

    // MARK: - Ripple Effects Settings

    var rippleEffectsEnabled: Bool = true
    var rippleSpeed: Double = 300.0 // pixels per second
    var rippleMaxRadius: Double = 200.0 // pixels
    var rippleDuration: TimeInterval = 0.8
    var rippleIntensity: Double = 0.6

    // MARK: - Particle Types

    var availableParticleTypes: [ParticleType] = [.spark, .bubble, .star, .geometric]
    var defaultParticleType: ParticleType = .spark

    // MARK: - Performance Settings

    var maxConcurrentEffects: Int = 10
    var effectQualityLevel: EffectQualityLevel = .high
    var enableGPUAcceleration: Bool = true

    // MARK: - Validation

    func validate() -> [String] {
        var errors: [String] = []

        // Motion blur validation
        if motionBlurVelocityThreshold < 0 || motionBlurVelocityThreshold > 2000 {
            errors.append("Motion blur velocity threshold must be between 0 and 2000 pixels/second")
        }

        if maxMotionBlurSpeed < motionBlurVelocityThreshold {
            errors.append("Max motion blur speed must be greater than velocity threshold")
        }

        if maxMotionBlurIntensity < 0.0 || maxMotionBlurIntensity > 1.0 {
            errors.append("Max motion blur intensity must be between 0.0 and 1.0")
        }

        // Afterimage validation
        if afterimageTrailLength < 1 || afterimageTrailLength > 20 {
            errors.append("Afterimage trail length must be between 1 and 20")
        }

        if afterimageOpacityDecay < 0.1 || afterimageOpacityDecay > 1.0 {
            errors.append("Afterimage opacity decay must be between 0.1 and 1.0")
        }

        // Particle effects validation
        if particleCount < 1 || particleCount > 100 {
            errors.append("Particle count must be between 1 and 100")
        }

        if particleSize.width < 1.0 || particleSize.width > 20.0 ||
            particleSize.height < 1.0 || particleSize.height > 20.0
        {
            errors.append("Particle size must be between 1.0 and 20.0 pixels")
        }

        if particleEffectDuration < 0.1 || particleEffectDuration > 5.0 {
            errors.append("Particle effect duration must be between 0.1 and 5.0 seconds")
        }

        // Ripple effects validation
        if rippleSpeed < 50.0 || rippleSpeed > 1000.0 {
            errors.append("Ripple speed must be between 50.0 and 1000.0 pixels/second")
        }

        if rippleMaxRadius < 50.0 || rippleMaxRadius > 500.0 {
            errors.append("Ripple max radius must be between 50.0 and 500.0 pixels")
        }

        if rippleDuration < 0.2 || rippleDuration > 3.0 {
            errors.append("Ripple duration must be between 0.2 and 3.0 seconds")
        }

        // Performance validation
        if maxConcurrentEffects < 1 || maxConcurrentEffects > 50 {
            errors.append("Max concurrent effects must be between 1 and 50")
        }

        if performanceThreshold < 8.33 || performanceThreshold > 33.33 {
            errors.append("Performance threshold must be between 8.33ms (120fps) and 33.33ms (30fps)")
        }

        return errors
    }

    static let `default` = VisualEffectsConfig()
}

// MARK: - Supporting Enums

/// Available particle types for effects
enum ParticleType: String, CaseIterable {
    case spark = "spark"
    case bubble = "bubble"
    case star = "star"
    case geometric = "geometric"

    var description: String {
        switch self {
            case .spark:
                return "Spark particles with trailing effect"
            case .bubble:
                return "Bubble particles with floating motion"
            case .star:
                return "Star-shaped particles with twinkling effect"
            case .geometric:
                return "Geometric shapes with rotation"
        }
    }
}

/// Particle effect types for different operations
enum ParticleEffectType: String, CaseIterable {
    case windowMove = "window_move"
    case windowResize = "window_resize"
    case multiWindowOperation = "multi_window"
    case ripple = "ripple"
    case explosion = "explosion"

    var description: String {
        switch self {
            case .windowMove:
                return "Particles for single window movement"
            case .windowResize:
                return "Particles for window resizing"
            case .multiWindowOperation:
                return "Particles for multi-window operations"
            case .ripple:
                return "Ripple effect particles"
            case .explosion:
                return "Explosion effect particles"
        }
    }
}

/// Quality levels for visual effects
enum EffectQualityLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case ultra = "ultra"

    var description: String {
        switch self {
            case .low:
                return "Low quality - minimal effects for performance"
            case .medium:
                return "Medium quality - balanced effects and performance"
            case .high:
                return "High quality - full effects with good performance"
            case .ultra:
                return "Ultra quality - maximum effects (may impact performance)"
        }
    }

    var particleMultiplier: Double {
        switch self {
            case .low: return 0.5
            case .medium: return 0.75
            case .high: return 1.0
            case .ultra: return 1.5
        }
    }

    var blurIntensityMultiplier: Double {
        switch self {
            case .low: return 0.3
            case .medium: return 0.6
            case .high: return 1.0
            case .ultra: return 1.2
        }
    }
}
