import Foundation
import CoreGraphics
import Common

enum AnimationInterpolator {

    // MARK: - Easing Functions

    /// Linear interpolation - constant rate of change
    static func linear(_ progress: Double) -> Double {
        return progress
    }

    /// Ease-in - slow start, accelerating
    static func easeIn(_ progress: Double) -> Double {
        return progress * progress
    }

    /// Ease-out - fast start, decelerating
    static func easeOut(_ progress: Double) -> Double {
        return 1.0 - (1.0 - progress) * (1.0 - progress)
    }

    /// Ease-in-out - slow start and end, fast middle
    static func easeInOut(_ progress: Double) -> Double {
        if progress < 0.5 {
            return 2.0 * progress * progress
        } else {
            return 1.0 - 2.0 * (1.0 - progress) * (1.0 - progress)
        }
    }

    /// Get easing function for the given easing type
    static func easingFunction(for easing: AnimationEasing) -> (Double) -> Double {
        switch easing {
            case .linear:
                return linear
            case .easeIn:
                return easeIn
            case .easeOut:
                return easeOut
            case .easeInOut:
                return easeInOut
        }
    }

    // MARK: - Interpolation Methods

    /// Interpolate between two CGPoint values
    static func interpolatePoint(_ from: CGPoint, _ to: CGPoint, progress: Double) -> CGPoint {
        let clampedProgress = max(0.0, min(1.0, progress))
        return CGPoint(
            x: from.x + (to.x - from.x) * clampedProgress,
            y: from.y + (to.y - from.y) * clampedProgress,
        )
    }

    /// Interpolate between two CGSize values
    static func interpolateSize(_ from: CGSize, _ to: CGSize, progress: Double) -> CGSize {
        let clampedProgress = max(0.0, min(1.0, progress))
        return CGSize(
            width: from.width + (to.width - from.width) * clampedProgress,
            height: from.height + (to.height - from.height) * clampedProgress,
        )
    }

    /// Interpolate between two Rect values
    static func interpolateRect(_ from: Rect, _ to: Rect, progress: Double) -> Rect {
        let clampedProgress = max(0.0, min(1.0, progress))

        let interpolatedTopLeftX = from.topLeftX + (to.topLeftX - from.topLeftX) * clampedProgress
        let interpolatedTopLeftY = from.topLeftY + (to.topLeftY - from.topLeftY) * clampedProgress
        let interpolatedWidth = from.width + (to.width - from.width) * clampedProgress
        let interpolatedHeight = from.height + (to.height - from.height) * clampedProgress

        return Rect(
            topLeftX: interpolatedTopLeftX,
            topLeftY: interpolatedTopLeftY,
            width: interpolatedWidth,
            height: interpolatedHeight,
        )
    }

    /// Interpolate between two Double values
    static func interpolateDouble(_ from: Double, _ to: Double, progress: Double) -> Double {
        let clampedProgress = max(0.0, min(1.0, progress))
        return from + (to - from) * clampedProgress
    }

    /// Interpolate between two CGFloat values
    static func interpolateCGFloat(_ from: CGFloat, _ to: CGFloat, progress: Double) -> CGFloat {
        let clampedProgress = max(0.0, min(1.0, progress))
        return from + (to - from) * CGFloat(clampedProgress)
    }

    // MARK: - Utility Methods

    /// Calculate progress based on elapsed time and duration
    static func calculateProgress(startTime: Date, duration: TimeInterval, currentTime: Date = Date()) -> Double {
        let elapsed = currentTime.timeIntervalSince(startTime)
        if duration <= 0 {
            return 1.0
        }
        return max(0.0, min(1.0, elapsed / duration))
    }

    /// Apply easing function to raw progress
    static func applyEasing(_ rawProgress: Double, easing: AnimationEasing) -> Double {
        let easingFunc = easingFunction(for: easing)
        return easingFunc(max(0.0, min(1.0, rawProgress)))
    }

    /// Calculate eased progress from start time, duration, and easing function
    static func calculateEasedProgress(
        startTime: Date,
        duration: TimeInterval,
        easing: AnimationEasing,
        currentTime: Date = Date(),
    ) -> Double {
        let rawProgress = calculateProgress(startTime: startTime, duration: duration, currentTime: currentTime)
        return applyEasing(rawProgress, easing: easing)
    }
}
