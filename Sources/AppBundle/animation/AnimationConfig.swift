import Foundation
import Common

struct AnimationConfig: ConvenienceCopyable {
    var enabled: Bool = true
    var defaultDuration: TimeInterval = 0.25
    var easingFunction: AnimationEasing = .easeOut
    var respectSystemPreferences: Bool = true

    // Per-operation settings
    var moveAnimationEnabled: Bool = true
    var resizeAnimationEnabled: Bool = true
    var layoutChangeAnimationEnabled: Bool = true
    var workspaceTransitionAnimationEnabled: Bool = true

    // Performance settings
    var maxConcurrentAnimations: Int = 10
    var adaptiveQuality: Bool = true
    var minFrameRate: Double = 30.0
    
    // Spring animation settings
    var springDamping: Float = 0.8
    var springVelocity: Float = 0.0
    
    // Bounce animation settings
    var bounceIntensity: Float = 1.0
    
    // Elastic animation settings
    var elasticAmplitude: Float = 0.5
    var elasticPeriod: Float = 0.3
    
    // GPU acceleration settings
    var gpuAccelerationEnabled: Bool = true
    var gpuAccelerationMode: GPUAccelerationMode = .automatic
    var gpuBatchSize: Int = 32
    var gpuFallbackThreshold: Double = 0.8

    // Validation
    func validate() -> [String] {
        var errors: [String] = []

        if defaultDuration < 0.01 || defaultDuration > 2.0 {
            errors.append("Animation duration must be between 0.01 and 2.0 seconds")
        }

        if maxConcurrentAnimations < 1 || maxConcurrentAnimations > 50 {
            errors.append("Max concurrent animations must be between 1 and 50")
        }

        if minFrameRate < 15.0 || minFrameRate > 120.0 {
            errors.append("Min frame rate must be between 15.0 and 120.0 fps")
        }
        
        if !AnimationEasing.validateSpringParameters(damping: springDamping, velocity: springVelocity) {
            errors.append("Spring parameters are invalid. Damping must be in [0, 2] range and velocity in [-10, 10] range.")
        }
        
        if !AnimationEasing.validateBounceParameters(intensity: bounceIntensity) {
            errors.append("Bounce parameters are invalid. Intensity must be in [0, 3] range.")
        }
        
        if !AnimationEasing.validateElasticParameters(amplitude: elasticAmplitude, period: elasticPeriod) {
            errors.append("Elastic parameters are invalid. Amplitude must be in [0, 2] range and period in (0, 1] range.")
        }
        
        // Validate GPU acceleration settings
        if gpuBatchSize < 1 || gpuBatchSize > 256 {
            errors.append("GPU batch size must be between 1 and 256")
        }
        
        if gpuFallbackThreshold < 0.0 || gpuFallbackThreshold > 1.0 {
            errors.append("GPU fallback threshold must be between 0.0 and 1.0")
        }

        // Validate easing function
        switch easingFunction {
        case .custom(let x1, let y1, let x2, let y2):
            if !AnimationEasing.validateBezierParameters(x1: x1, y1: y1, x2: x2, y2: y2) {
                errors.append("Custom easing function has invalid Bézier curve parameters. X values must be in [0, 1] range.")
            }
        case .spring(let damping, let velocity):
            if !AnimationEasing.validateSpringParameters(damping: damping, velocity: velocity) {
                errors.append("Spring easing function has invalid parameters. Damping must be in [0, 2] range and velocity in [-10, 10] range.")
            }
        case .bounce(let intensity):
            if !AnimationEasing.validateBounceParameters(intensity: intensity) {
                errors.append("Bounce easing function has invalid parameters. Intensity must be in [0, 3] range.")
            }
        case .elastic(let amplitude, let period):
            if !AnimationEasing.validateElasticParameters(amplitude: amplitude, period: period) {
                errors.append("Elastic easing function has invalid parameters. Amplitude must be in [0, 2] range and period in (0, 1] range.")
            }
        default:
            break
        }

        return errors
    }

    static let `default` = AnimationConfig()
}

enum AnimationEasing: Equatable, Hashable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case custom(x1: Float, y1: Float, x2: Float, y2: Float)
    case spring(damping: Float, velocity: Float)
    case bounce(intensity: Float)
    case elastic(amplitude: Float, period: Float)
    
    var rawValue: String {
        switch self {
        case .linear:
            return "linear"
        case .easeIn:
            return "ease-in"
        case .easeOut:
            return "ease-out"
        case .easeInOut:
            return "ease-in-out"
        case .custom(let x1, let y1, let x2, let y2):
            return "cubic-bezier(\(x1), \(y1), \(x2), \(y2))"
        case .spring(let damping, let velocity):
            return "spring(\(damping), \(velocity))"
        case .bounce(let intensity):
            return "bounce(\(intensity))"
        case .elastic(let amplitude, let period):
            return "elastic(\(amplitude), \(period))"
        }
    }
    
    static var allCases: [AnimationEasing] {
        return [.linear, .easeIn, .easeOut, .easeInOut]
    }
    
    /// Create AnimationEasing from string representation
    static func from(string: String) -> AnimationEasing? {
        switch string.lowercased() {
        case "linear":
            return .linear
        case "ease-in":
            return .easeIn
        case "ease-out":
            return .easeOut
        case "ease-in-out":
            return .easeInOut
        default:
            // Try to parse different function formats
            if let spring = parseSpring(from: string) {
                return spring
            }
            if let bounce = parseBounce(from: string) {
                return bounce
            }
            if let elastic = parseElastic(from: string) {
                return elastic
            }
            return parseCubicBezier(from: string)
        }
    }
    
    /// Parse spring(damping, velocity) format
    private static func parseSpring(from string: String) -> AnimationEasing? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it starts with "spring(" and ends with ")"
        guard trimmed.hasPrefix("spring(") && trimmed.hasSuffix(")") else {
            return nil
        }
        
        // Extract the parameters
        let parametersString = String(trimmed.dropFirst(7).dropLast(1)) // Remove "spring(" and ")"
        let parameters = parametersString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        guard parameters.count == 2 else {
            return nil
        }
        
        // Parse the float values
        guard let damping = Float(parameters[0]),
              let velocity = Float(parameters[1]) else {
            return nil
        }
        
        // Validate the parameters
        guard validateSpringParameters(damping: damping, velocity: velocity) else {
            return nil
        }
        
        return .spring(damping: damping, velocity: velocity)
    }
    
    /// Parse bounce(intensity) format
    private static func parseBounce(from string: String) -> AnimationEasing? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it starts with "bounce(" and ends with ")"
        guard trimmed.hasPrefix("bounce(") && trimmed.hasSuffix(")") else {
            return nil
        }
        
        // Extract the parameter
        let parameterString = String(trimmed.dropFirst(7).dropLast(1)) // Remove "bounce(" and ")"
        let parameter = parameterString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse the float value
        guard let intensity = Float(parameter) else {
            return nil
        }
        
        // Validate the parameter
        guard validateBounceParameters(intensity: intensity) else {
            return nil
        }
        
        return .bounce(intensity: intensity)
    }
    
    /// Parse elastic(amplitude, period) format
    private static func parseElastic(from string: String) -> AnimationEasing? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it starts with "elastic(" and ends with ")"
        guard trimmed.hasPrefix("elastic(") && trimmed.hasSuffix(")") else {
            return nil
        }
        
        // Extract the parameters
        let parametersString = String(trimmed.dropFirst(8).dropLast(1)) // Remove "elastic(" and ")"
        let parameters = parametersString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        guard parameters.count == 2 else {
            return nil
        }
        
        // Parse the float values
        guard let amplitude = Float(parameters[0]),
              let period = Float(parameters[1]) else {
            return nil
        }
        
        // Validate the parameters
        guard validateElasticParameters(amplitude: amplitude, period: period) else {
            return nil
        }
        
        return .elastic(amplitude: amplitude, period: period)
    }
    
    /// Parse cubic-bezier(x1, y1, x2, y2) format
    private static func parseCubicBezier(from string: String) -> AnimationEasing? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it starts with "cubic-bezier(" and ends with ")"
        guard trimmed.hasPrefix("cubic-bezier(") && trimmed.hasSuffix(")") else {
            return nil
        }
        
        // Extract the parameters
        let parametersString = String(trimmed.dropFirst(13).dropLast(1)) // Remove "cubic-bezier(" and ")"
        let parameters = parametersString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        guard parameters.count == 4 else {
            return nil
        }
        
        // Parse the float values
        guard let x1 = Float(parameters[0]),
              let y1 = Float(parameters[1]),
              let x2 = Float(parameters[2]),
              let y2 = Float(parameters[3]) else {
            return nil
        }
        
        // Validate the parameters
        guard validateBezierParameters(x1: x1, y1: y1, x2: x2, y2: y2) else {
            return nil
        }
        
        return .custom(x1: x1, y1: y1, x2: x2, y2: y2)
    }
    
    /// Validate Bézier curve parameters
    static func validateBezierParameters(x1: Float, y1: Float, x2: Float, y2: Float) -> Bool {
        // X values must be in [0, 1] range for timing functions
        // Y values can be outside [0, 1] for overshoot effects
        return x1 >= 0.0 && x1 <= 1.0 && x2 >= 0.0 && x2 <= 1.0
    }
    
    /// Validate spring parameters
    static func validateSpringParameters(damping: Float, velocity: Float) -> Bool {
        // Damping should be positive (0 = no damping, 1 = critical damping, >1 = overdamped)
        // Velocity can be any value (positive = initial forward velocity, negative = initial backward velocity)
        return damping >= 0.0 && damping <= 2.0 && velocity >= -10.0 && velocity <= 10.0
    }
    
    /// Validate bounce parameters
    static func validateBounceParameters(intensity: Float) -> Bool {
        // Intensity controls the bounce effect strength
        // 0 = no bounce (linear), 1 = moderate bounce, higher values = more intense bounce
        return intensity >= 0.0 && intensity <= 3.0
    }
    
    /// Validate elastic parameters
    static func validateElasticParameters(amplitude: Float, period: Float) -> Bool {
        // Amplitude controls the overshoot amount (0 = no overshoot, 1 = moderate overshoot)
        // Period controls the oscillation frequency (smaller = faster oscillation)
        return amplitude >= 0.0 && amplitude <= 2.0 && period > 0.0 && period <= 1.0
    }
}

/// GPU acceleration mode options
enum GPUAccelerationMode: String, CaseIterable {
    case disabled = "disabled"
    case automatic = "automatic"
    case forced = "forced"
    
    var description: String {
        switch self {
        case .disabled:
            return "GPU acceleration disabled"
        case .automatic:
            return "Automatic GPU acceleration based on system conditions"
        case .forced:
            return "Force GPU acceleration when available"
        }
    }
}
