import Foundation
import AppKit
import CoreGraphics
import QuartzCore

/// Context for managing particle and ripple effects
class ParticleEffectContext {

    // MARK: - Properties

    let windowId: UInt32
    let effectType: ParticleEffectType
    let origin: CGPoint
    let startTime: Date
    let duration: TimeInterval
    let particleCount: Int
    let particleSize: CGSize

    // Particle system state
    private var particles: [Particle] = []
    private var particleEmitter: CAEmitterLayer?
    private var isActive: Bool = true

    // Ripple effect state
    private var rippleLayer: CAShapeLayer?
    private var rippleAnimation: CAAnimationGroup?

    // Performance tracking
    private var frameCount: Int = 0
    private var lastPerformanceCheck: Date = Date()

    // MARK: - Initialization

    init(windowId: UInt32, effectType: ParticleEffectType, origin: CGPoint,
         startTime: Date, duration: TimeInterval, particleCount: Int, particleSize: CGSize)
    {
        self.windowId = windowId
        self.effectType = effectType
        self.origin = origin
        self.startTime = startTime
        self.duration = duration
        self.particleCount = particleCount
        self.particleSize = particleSize

        setupParticleSystem()
    }

    // MARK: - Particle System Setup

    private func setupParticleSystem() {
        switch effectType {
            case .windowMove, .windowResize, .multiWindowOperation:
                setupStandardParticles()
            case .ripple:
                setupRippleEffect()
            case .explosion:
                setupExplosionParticles()
        }
    }

    private func setupStandardParticles() {
        particles.reserveCapacity(particleCount)

        for i in 0 ..< particleCount {
            let particle = createParticle(index: i, type: .spark)
            particles.append(particle)
        }

        setupParticleEmitter()
    }

    private func setupRippleEffect() {
        setupRippleLayer()
        startRippleAnimation()
    }

    private func setupExplosionParticles() {
        particles.reserveCapacity(particleCount * 2) // More particles for explosion

        for i in 0 ..< (particleCount * 2) {
            let particle = createParticle(index: i, type: .geometric)
            particles.append(particle)
        }

        setupParticleEmitter()
    }

    // MARK: - Particle Creation

    private func createParticle(index: Int, type: ParticleType) -> Particle {
        // Random angle for particle direction
        let angle = Double.random(in: 0 ... (2 * Double.pi))

        // Random velocity based on effect type
        let baseVelocity = getBaseVelocity(for: effectType)
        let velocityVariation = Double.random(in: 0.5 ... 1.5)
        let velocity = baseVelocity * velocityVariation

        // Random lifetime
        let lifetime = duration * Double.random(in: 0.7 ... 1.3)

        // Calculate initial position with some spread
        let spread = getParticleSpread(for: effectType)
        let offsetX = Double.random(in: -spread ... spread)
        let offsetY = Double.random(in: -spread ... spread)

        let initialPosition = CGPoint(
            x: origin.x + offsetX,
            y: origin.y + offsetY,
        )

        return Particle(
            id: index,
            type: type,
            position: initialPosition,
            velocity: CGVector(dx: cos(angle) * velocity, dy: sin(angle) * velocity),
            size: particleSize,
            lifetime: lifetime,
            birthTime: startTime,
            color: getParticleColor(for: type),
            opacity: 1.0,
        )
    }

    private func getBaseVelocity(for effectType: ParticleEffectType) -> Double {
        switch effectType {
            case .windowMove: return 80.0
            case .windowResize: return 60.0
            case .multiWindowOperation: return 100.0
            case .ripple: return 0.0 // Ripples don't use particle velocity
            case .explosion: return 150.0
        }
    }

    private func getParticleSpread(for effectType: ParticleEffectType) -> Double {
        switch effectType {
            case .windowMove: return 20.0
            case .windowResize: return 30.0
            case .multiWindowOperation: return 40.0
            case .ripple: return 0.0
            case .explosion: return 10.0
        }
    }

    private func getParticleColor(for type: ParticleType) -> NSColor {
        switch type {
            case .spark:
                return NSColor.systemYellow
            case .bubble:
                return NSColor.systemBlue.withAlphaComponent(0.7)
            case .star:
                return NSColor.systemPurple
            case .geometric:
                return NSColor.systemOrange
        }
    }

    // MARK: - Particle Emitter Setup

    private func setupParticleEmitter() {
        particleEmitter = CAEmitterLayer()
        guard let emitter = particleEmitter else { return }

        emitter.emitterPosition = origin
        emitter.emitterShape = .circle
        emitter.emitterSize = CGSize(width: 20, height: 20)

        // Create emitter cell
        let cell = CAEmitterCell()
        cell.birthRate = Float(particleCount) / Float(duration)
        cell.lifetime = Float(duration)
        cell.velocity = 100.0
        cell.velocityRange = 50.0
        cell.emissionRange = CGFloat.pi * 2
        cell.scale = 0.5
        cell.scaleRange = 0.3
        cell.alphaSpeed = -1.0 / Float(duration)

        // Set particle appearance
        cell.contents = createParticleImage()

        emitter.emitterCells = [cell]
    }

    private func createParticleImage() -> CGImage? {
        let size = CGSize(width: 8, height: 8)
        _ = NSGraphicsContext.current?.cgContext

        // Create a simple circular particle image
        _ = CGRect(origin: .zero, size: size)

        // This would create a simple particle image
        // In a real implementation, you'd create different shapes for different particle types

        return nil // Placeholder - would return actual CGImage
    }

    // MARK: - Ripple Effect Implementation

    private func setupRippleLayer() {
        rippleLayer = CAShapeLayer()
        guard let layer = rippleLayer else { return }

        layer.fillColor = NSColor.clear.cgColor
        layer.strokeColor = NSColor.systemBlue.withAlphaComponent(0.6).cgColor
        layer.lineWidth = 2.0

        // Create initial circle path
        let initialRadius: CGFloat = 5.0
        let path = CGPath(ellipseIn: CGRect(
            x: origin.x - initialRadius,
            y: origin.y - initialRadius,
            width: initialRadius * 2,
            height: initialRadius * 2,
        ), transform: nil)

        layer.path = path
    }

    private func startRippleAnimation() {
        guard let layer = rippleLayer else { return }

        // Scale animation
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 10.0
        scaleAnimation.duration = duration
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        // Opacity animation
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.8
        opacityAnimation.toValue = 0.0
        opacityAnimation.duration = duration
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        // Group animations
        let groupAnimation = CAAnimationGroup()
        groupAnimation.animations = [scaleAnimation, opacityAnimation]
        groupAnimation.duration = duration
        groupAnimation.fillMode = .forwards
        groupAnimation.isRemovedOnCompletion = false

        layer.add(groupAnimation, forKey: "rippleAnimation")
        rippleAnimation = groupAnimation
    }

    // MARK: - Effect Updates

    /// Update the particle effect with current progress
    func updateEffect(progress: Double) {
        let currentTime = Date()

        switch effectType {
            case .windowMove, .windowResize, .multiWindowOperation, .explosion:
                updateParticles(currentTime: currentTime, progress: progress)
            case .ripple:
                updateRipple(progress: progress)
        }

        // Performance monitoring
        monitorPerformance()
        frameCount += 1
    }

    private func updateParticles(currentTime: Date, progress: Double) {
        for i in 0 ..< particles.count {
            let particle = particles[i]
            let age = currentTime.timeIntervalSince(particle.birthTime)
            let lifeProgress = min(age / particle.lifetime, 1.0)

            if lifeProgress >= 1.0 {
                // Particle has expired
                particles[i].opacity = 0.0
                continue
            }

            // Update position based on velocity
            let deltaTime = 1.0 / 60.0 // Assume 60fps
            let newX = particle.position.x + particle.velocity.dx * deltaTime
            let newY = particle.position.y + particle.velocity.dy * deltaTime

            particles[i].position = CGPoint(x: newX, y: newY)

            // Update opacity (fade out over lifetime)
            particles[i].opacity = 1.0 - lifeProgress

            // Apply gravity or other forces based on particle type
            applyForces(to: &particles[i], deltaTime: deltaTime)
        }

        // Remove expired particles
        particles = particles.filter { $0.opacity > 0.01 }
    }

    private func updateRipple(progress: Double) {
        // Ripple animation is handled by Core Animation
        // We just need to track the progress

        if progress >= 1.0 {
            isActive = false
        }
    }

    private func applyForces(to particle: inout Particle, deltaTime: Double) {
        switch particle.type {
            case .spark:
                // Sparks have slight gravity
                particle.velocity.dy += 50.0 * deltaTime
            case .bubble:
                // Bubbles float upward
                particle.velocity.dy -= 30.0 * deltaTime
            case .star:
                // Stars have no additional forces
                break
            case .geometric:
                // Geometric particles have slight deceleration
                particle.velocity.dx *= 0.99
                particle.velocity.dy *= 0.99
        }
    }

    // MARK: - Public Interface

    /// Check if effect is still active
    var effectIsActive: Bool {
        let elapsed = Date().timeIntervalSince(startTime)

        // For ripple effects, check if the ripple layer exists instead of particles
        if effectType == .ripple {
            return elapsed < duration && isActive && rippleLayer != nil
        }

        return elapsed < duration && isActive && !particles.isEmpty
    }

    /// Get current particle count
    var currentParticleCount: Int {
        return particles.count(where: { $0.opacity > 0.01 })
    }

    /// Clean up resources
    func cleanup() {
        // Clean up particles
        particles.removeAll()

        // Clean up emitter
        particleEmitter?.removeFromSuperlayer()
        particleEmitter = nil

        // Clean up ripple
        rippleLayer?.removeFromSuperlayer()
        rippleLayer = nil
        rippleAnimation = nil

        isActive = false
        frameCount = 0
    }

    // MARK: - Performance Monitoring

    private func monitorPerformance() {
        let now = Date()

        // Check performance every second
        if now.timeIntervalSince(lastPerformanceCheck) >= 1.0 {
            let fps = Double(frameCount) / now.timeIntervalSince(lastPerformanceCheck)

            if fps < 30.0 {
                print("Particle effect performance warning for window \(windowId): \(fps) fps")

                // Reduce quality if performance is poor
                reduceQuality()
            }

            frameCount = 0
            lastPerformanceCheck = now
        }
    }

    private func reduceQuality() {
        // Reduce particle count
        if particles.count > 5 {
            let removeCount = particles.count / 3
            particles.removeLast(removeCount)
        }

        // Reduce particle size
        for i in 0 ..< particles.count {
            particles[i].size = CGSize(
                width: particles[i].size.width * 0.8,
                height: particles[i].size.height * 0.8,
            )
        }
    }
}

// MARK: - Supporting Structures

/// Represents a single particle in the effect system
private struct Particle {
    let id: Int
    let type: ParticleType
    var position: CGPoint
    var velocity: CGVector
    var size: CGSize
    let lifetime: TimeInterval
    let birthTime: Date
    let color: NSColor
    var opacity: Double
}
