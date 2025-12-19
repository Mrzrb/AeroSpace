import Foundation
import CoreGraphics
import QuartzCore
import Common

enum AnimationInterpolator {

    // MARK: - CAMediaTimingFunction Integration

    /// Get CAMediaTimingFunction for the given easing type
    static func timingFunction(for easing: AnimationEasing) -> CAMediaTimingFunction {
        switch easing {
            case .linear:
                return CAMediaTimingFunction(name: .linear)
            case .easeIn:
                return CAMediaTimingFunction(name: .easeIn)
            case .easeOut:
                return CAMediaTimingFunction(name: .easeOut)
            case .easeInOut:
                return CAMediaTimingFunction(name: .easeInEaseOut)
            case .custom(let x1, let y1, let x2, let y2):
                return CAMediaTimingFunction(controlPoints: x1, y1, x2, y2)
            case .spring:
                // Spring animations don't map directly to CAMediaTimingFunction
                // We'll use a custom approximation
                return CAMediaTimingFunction(name: .easeOut)
            case .bounce:
                // Bounce animations don't map directly to CAMediaTimingFunction
                // We'll use a custom approximation
                return CAMediaTimingFunction(name: .easeOut)
            case .elastic:
                // Elastic animations don't map directly to CAMediaTimingFunction
                // We'll use a custom approximation
                return CAMediaTimingFunction(name: .easeOut)
        }
    }

    /// Apply CAMediaTimingFunction-based easing to progress
    static func applyTimingFunction(_ progress: Double, timingFunction: CAMediaTimingFunction) -> Double {
        let clampedProgress = max(0.0, min(1.0, progress))

        // CAMediaTimingFunction uses cubic bezier curves with control points
        // For timing functions, we need to solve for Y given X (progress)
        // This requires iterative solving since we can't directly invert the bezier curve

        // Get control points for the timing function
        var cp1 = [Float](repeating: 0, count: 2)
        var cp2 = [Float](repeating: 0, count: 2)
        timingFunction.getControlPoint(at: 1, values: &cp1)
        timingFunction.getControlPoint(at: 2, values: &cp2)

        // For standard timing functions, use optimized calculations
        // This avoids the complexity of bezier curve solving
        return evaluateTimingFunctionOptimized(progress: clampedProgress, cp1: cp1, cp2: cp2)
    }

    /// Optimized evaluation for standard timing functions
    private static func evaluateTimingFunctionOptimized(progress: Double, cp1: [Float], cp2: [Float]) -> Double {
        let x1 = Double(cp1[0])
        let y1 = Double(cp1[1])
        let x2 = Double(cp2[0])
        let y2 = Double(cp2[1])

        // For standard easing functions, we can use approximations that are very close
        // to the actual bezier curve evaluation but much faster

        // Check if this matches standard timing functions (with some tolerance)
        if abs(x1 - 0.0) < 0.001 && abs(y1 - 0.0) < 0.001 && abs(x2 - 1.0) < 0.001 && abs(y2 - 1.0) < 0.001 {
            // Linear
            return progress
        } else if abs(x1 - 0.42) < 0.01 && abs(y1 - 0.0) < 0.01 && abs(x2 - 1.0) < 0.01 && abs(y2 - 1.0) < 0.01 {
            // Ease-in
            return progress * progress
        } else if abs(x1 - 0.0) < 0.01 && abs(y1 - 0.0) < 0.01 && abs(x2 - 0.58) < 0.01 && abs(y2 - 1.0) < 0.01 {
            // Ease-out
            return 1.0 - (1.0 - progress) * (1.0 - progress)
        } else if abs(x1 - 0.42) < 0.01 && abs(y1 - 0.0) < 0.01 && abs(x2 - 0.58) < 0.01 && abs(y2 - 1.0) < 0.01 {
            // Ease-in-out
            if progress < 0.5 {
                return 2.0 * progress * progress
            } else {
                return 1.0 - 2.0 * (1.0 - progress) * (1.0 - progress)
            }
        }

        // For custom timing functions, use bezier approximation
        return evaluateCubicBezierApproximation(t: progress, x1: x1, y1: y1, x2: x2, y2: y2)
    }

    /// Simplified cubic bezier approximation for timing functions
    private static func evaluateCubicBezierApproximation(t: Double, x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
        // Use a simplified approximation that works well for timing functions
        // This is based on the fact that timing functions are monotonic
        let t2 = t * t
        let t3 = t2 * t
        let mt = 1.0 - t
        let mt2 = mt * mt

        // Cubic bezier with control points (0,0), (x1,y1), (x2,y2), (1,1)
        return 3 * mt2 * t * y1 + 3 * mt * t2 * y2 + t3
    }

    // MARK: - Manual Easing Functions (Legacy/Performance Comparison)

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

    /// Bounce easing with configurable intensity
    static func bounce(_ progress: Double, intensity: Float) -> Double {
        let clampedProgress = max(0.0, min(1.0, progress))
        let intensityFactor = Double(intensity)

        // Handle edge cases
        if clampedProgress == 0.0 {
            return 0.0
        }
        if clampedProgress == 1.0 {
            return 1.0
        }

        // Bounce easing implementation
        // Based on Robert Penner's easing equations with configurable intensity
        let n1 = 7.5625
        let d1 = 2.75
        let scaledIntensity = 1.0 + (intensityFactor - 1.0) * 0.5 // Scale intensity effect

        var result: Double

        if clampedProgress < 1.0 / d1 {
            result = n1 * clampedProgress * clampedProgress
        } else if clampedProgress < 2.0 / d1 {
            let adjustedProgress = clampedProgress - 1.5 / d1
            result = n1 * adjustedProgress * adjustedProgress + 0.75
        } else if clampedProgress < 2.5 / d1 {
            let adjustedProgress = clampedProgress - 2.25 / d1
            result = n1 * adjustedProgress * adjustedProgress + 0.9375
        } else {
            let adjustedProgress = clampedProgress - 2.625 / d1
            result = n1 * adjustedProgress * adjustedProgress + 0.984375
        }

        // Apply intensity scaling
        if intensityFactor != 1.0 {
            // Enhance the bounce effect by scaling the overshoot
            let overshoot = result - clampedProgress
            result = clampedProgress + overshoot * scaledIntensity
        }

        return result
    }

    /// Elastic easing with configurable amplitude and period
    static func elastic(_ progress: Double, amplitude: Float, period: Float) -> Double {
        // Handle edge cases
        if progress == 0.0 {
            return 0.0
        }
        if progress == 1.0 {
            return 1.0
        }

        let amp = Double(max(1.0, amplitude))
        let p = Double(period)
        
        // Standard easeOutElastic formula
        // Starts slow, accelerates to target, overshoots, oscillates back
        let s = p / (2.0 * Double.pi) * asin(1.0 / amp)
        return amp * pow(2.0, -10.0 * progress) * sin((progress - s) * (2.0 * Double.pi) / p) + 1.0
    }

    /// Spring physics easing with damping and initial velocity
    static func spring(_ progress: Double, damping: Float, velocity: Float) -> Double {
        let clampedProgress = max(0.0, min(1.0, progress))

        // Handle edge cases
        if clampedProgress == 0.0 {
            return 0.0
        }
        if clampedProgress == 1.0 {
            return 1.0
        }

        // Convert parameters to spring physics constants
        let dampingRatio = Double(damping)
        let initialVelocity = Double(velocity)

        // Spring physics calculation for animation easing
        // We want to go from 0 to 1, so we solve for displacement from equilibrium
        // Using normalized time (progress) from 0 to 1

        let omega = 8.0 // Natural frequency (affects animation speed)
        let zeta = dampingRatio // Damping ratio
        let t = clampedProgress // Normalized time

        if zeta > 1.0 {
            // Overdamped - no oscillation, smooth approach to target
            let discriminant = sqrt(zeta * zeta - 1.0)
            let r1 = -omega * (zeta + discriminant)
            let r2 = -omega * (zeta - discriminant)

            // Initial conditions: x(0) = 0, x'(0) = initialVelocity
            let c2 = initialVelocity / (omega * (r1 - r2))
            let c1 = -c2

            let result = 1.0 + c1 * exp(r1 * t) + c2 * exp(r2 * t)
            return max(0.0, min(2.0, result)) // Allow slight overshoot but clamp extremes

        } else if zeta == 1.0 {
            // Critically damped - fastest approach without oscillation
            let c1 = -1.0
            let c2 = initialVelocity - omega * c1

            let result = 1.0 + (c1 + c2 * t) * exp(-omega * t)
            return max(0.0, min(2.0, result))

        } else {
            // Underdamped - oscillatory behavior
            let omegaD = omega * sqrt(1.0 - zeta * zeta) // Damped frequency

            // Initial conditions: x(0) = 0, x'(0) = initialVelocity
            let A = 1.0 / omegaD
            let phi = atan2(initialVelocity + zeta * omega, omegaD)

            let envelope = exp(-zeta * omega * t)
            let oscillation = sin(omegaD * t + phi)

            let result = 1.0 - A * envelope * oscillation
            return result // Allow overshoot for spring effect
        }
    }

    /// Get manual easing function for the given easing type (for performance comparison)
    static func manualEasingFunction(for easing: AnimationEasing) -> (Double) -> Double {
        switch easing {
            case .linear:
                return linear
            case .easeIn:
                return easeIn
            case .easeOut:
                return easeOut
            case .easeInOut:
                return easeInOut
            case .custom(let x1, let y1, let x2, let y2):
                return { progress in
                    evaluateCubicBezierApproximation(t: progress, x1: Double(x1), y1: Double(y1), x2: Double(x2), y2: Double(y2))
                }
            case .spring(let damping, let velocity):
                return { progress in
                    spring(progress, damping: damping, velocity: velocity)
                }
            case .bounce(let intensity):
                return { progress in
                    bounce(progress, intensity: intensity)
                }
            case .elastic(let amplitude, let period):
                return { progress in
                    elastic(progress, amplitude: amplitude, period: period)
                }
        }
    }

    /// Get easing function for the given easing type (uses CAMediaTimingFunction by default)
    static func easingFunction(for easing: AnimationEasing) -> (Double) -> Double {
        switch easing {
            case .spring, .bounce, .elastic:
                // These animations use manual calculation since CAMediaTimingFunction doesn't support them
                return manualEasingFunction(for: easing)
            default:
                let timingFunc = timingFunction(for: easing)
                return { progress in
                    applyTimingFunction(progress, timingFunction: timingFunc)
                }
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
        // Don't clamp progress - allow overshoot for elastic/bounce easing
        let interpolatedTopLeftX = from.topLeftX + (to.topLeftX - from.topLeftX) * progress
        let interpolatedTopLeftY = from.topLeftY + (to.topLeftY - from.topLeftY) * progress
        let interpolatedWidth = from.width + (to.width - from.width) * progress
        let interpolatedHeight = from.height + (to.height - from.height) * progress

        return Rect(
            topLeftX: interpolatedTopLeftX,
            topLeftY: interpolatedTopLeftY,
            width: max(1.0, interpolatedWidth),  // Prevent negative/zero size
            height: max(1.0, interpolatedHeight),
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
        switch easing {
            case .spring, .bounce, .elastic:
                // These need manual calculation - CAMediaTimingFunction doesn't support them
                let easingFunc = manualEasingFunction(for: easing)
                return easingFunc(max(0.0, min(1.0, rawProgress)))
            default:
                let timingFunc = timingFunction(for: easing)
                return applyTimingFunction(rawProgress, timingFunction: timingFunc)
        }
    }

    /// Apply manual easing function to raw progress (for performance comparison)
    static func applyManualEasing(_ rawProgress: Double, easing: AnimationEasing) -> Double {
        let easingFunc = manualEasingFunction(for: easing)
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

    // MARK: - Performance Benchmarking

    /// Performance benchmark result
    struct EasingPerformanceBenchmark {
        let manualEasingTime: TimeInterval
        let timingFunctionTime: TimeInterval
        let iterations: Int
        let easingType: AnimationEasing

        var speedupFactor: Double {
            return manualEasingTime / timingFunctionTime
        }

        var description: String {
            return """
                Easing Performance Benchmark (\(easingType.rawValue)):
                - Manual easing: \(String(format: "%.6f", manualEasingTime))s
                - CAMediaTimingFunction: \(String(format: "%.6f", timingFunctionTime))s
                - Iterations: \(iterations)
                - Speedup factor: \(String(format: "%.2f", speedupFactor))x
                """
        }
    }

    /// Benchmark performance comparison between manual and CAMediaTimingFunction easing
    static func benchmarkEasingPerformance(
        easing: AnimationEasing,
        iterations: Int = 10000,
    ) -> EasingPerformanceBenchmark {
        let progressValues = (0 ..< iterations).map { Double($0) / Double(iterations - 1) }

        // Benchmark manual easing
        let manualStartTime = CFAbsoluteTimeGetCurrent()
        for progress in progressValues {
            _ = applyManualEasing(progress, easing: easing)
        }
        let manualEndTime = CFAbsoluteTimeGetCurrent()
        let manualEasingTime = manualEndTime - manualStartTime

        // Benchmark CAMediaTimingFunction easing
        let timingFuncStartTime = CFAbsoluteTimeGetCurrent()
        let timingFunc = timingFunction(for: easing)
        for progress in progressValues {
            _ = applyTimingFunction(progress, timingFunction: timingFunc)
        }
        let timingFuncEndTime = CFAbsoluteTimeGetCurrent()
        let timingFunctionTime = timingFuncEndTime - timingFuncStartTime

        return EasingPerformanceBenchmark(
            manualEasingTime: manualEasingTime,
            timingFunctionTime: timingFunctionTime,
            iterations: iterations,
            easingType: easing,
        )
    }

    /// Run comprehensive performance benchmarks for all easing types
    static func runComprehensiveEasingBenchmarks(iterations: Int = 10000) -> [EasingPerformanceBenchmark] {
        return AnimationEasing.allCases.map { easing in
            benchmarkEasingPerformance(easing: easing, iterations: iterations)
        }
    }
}
