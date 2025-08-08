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

        // Validate easing function
        if case .custom(let x1, let y1, let x2, let y2) = easingFunction {
            if !AnimationEasing.validateBezierParameters(x1: x1, y1: y1, x2: x2, y2: y2) {
                errors.append("Custom easing function has invalid Bézier curve parameters. X values must be in [0, 1] range.")
            }
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
            // Try to parse cubic-bezier format
            return parseCubicBezier(from: string)
        }
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
}
