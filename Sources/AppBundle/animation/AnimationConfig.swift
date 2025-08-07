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

        return errors
    }

    static let `default` = AnimationConfig()
}

enum AnimationEasing: String, CaseIterable {
    case linear = "linear"
    case easeIn = "ease-in"
    case easeOut = "ease-out"
    case easeInOut = "ease-in-out"
}
