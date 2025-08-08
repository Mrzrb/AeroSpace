# AeroSpace Configuration Examples

This directory contains various configuration examples for AeroSpace, showcasing different use cases and optimization strategies.

## Available Configurations

### 📄 `default-config.toml`
The standard configuration file with all features documented and sensible defaults.

**Features:**
- Basic animations enabled
- GPU acceleration in automatic mode
- Visual effects disabled by default for compatibility
- Comprehensive documentation of all options

**Best for:** New users, general use, learning about available features

### 🚀 `advanced-effects-config.toml`
A showcase configuration that enables all visual effects and advanced features.

**Features:**
- All visual effects enabled (motion blur, particles, ripples)
- GPU acceleration optimized for performance
- Spring-based easing functions
- High-quality particle effects
- Enhanced afterimage trails

**Best for:** Modern hardware, users who want maximum visual appeal, demonstrations

**Requirements:**
- Discrete GPU recommended
- macOS with Metal support
- 16GB+ RAM recommended

### ⚡ `performance-optimized-config.toml`
Optimized for maximum performance and battery life.

**Features:**
- Minimal animations with short durations
- Visual effects disabled
- Conservative GPU settings
- Linear easing for fastest computation
- Reduced concurrent animation limits

**Best for:** Older hardware, battery-powered devices, performance-critical workflows, gaming

### ♿ `accessibility-friendly-config.toml`
Designed for users with accessibility needs or motion sensitivity.

**Features:**
- Very short animation durations (0.08s)
- Linear easing with no acceleration
- All visual effects disabled
- Respects system "Reduce Motion" preferences
- Only one animation at a time
- Larger gaps for better visual separation

**Best for:** Users with motion sensitivity, visual impairments, or other accessibility needs

## How to Use

1. **Choose a configuration** that matches your needs and hardware
2. **Copy the file** to `~/.aerospace.toml`
3. **Customize** the settings to your preferences
4. **Reload** AeroSpace configuration

```bash
# Example: Use the advanced effects configuration
cp docs/config-examples/advanced-effects-config.toml ~/.aerospace.toml

# Reload AeroSpace configuration
aerospace reload-config
```

## Configuration Comparison

| Feature | Default | Advanced | Performance | Accessibility |
|---------|---------|----------|-------------|---------------|
| Animations | ✅ Basic | ✅ Enhanced | ✅ Minimal | ✅ Minimal |
| GPU Acceleration | 🔄 Auto | ✅ Optimized | 🔄 Conservative | ❌ Disabled |
| Visual Effects | ❌ Disabled | ✅ All Enabled | ❌ Disabled | ❌ Disabled |
| Motion Blur | ❌ | ✅ | ❌ | ❌ |
| Particles | ❌ | ✅ | ❌ | ❌ |
| Ripple Effects | ❌ | ✅ | ❌ | ❌ |
| Animation Duration | 0.25s | 0.2s | 0.12s | 0.08s |
| Easing Function | ease-out | spring | linear | linear |
| Max Concurrent | 10 | 15 | 3 | 1 |
| Battery Friendly | ✅ | ❌ | ✅ | ✅ |
| Accessibility | ✅ | ⚠️ | ✅ | ✅ |

## Customization Tips

### Hardware-Based Recommendations

**M1/M2/M3 Macs with 16GB+ RAM:**
- Start with `advanced-effects-config.toml`
- Enable all visual effects
- Use `gpu-acceleration-mode = 'forced'`

**Intel Macs or 8GB RAM:**
- Use `default-config.toml` or `performance-optimized-config.toml`
- Keep visual effects disabled or use low quality
- Use `gpu-acceleration-mode = 'automatic'`

**Older Hardware (2015 and earlier):**
- Use `performance-optimized-config.toml`
- Disable GPU acceleration
- Use minimal animations only

### Use Case Recommendations

**Gaming/Performance Critical:**
```toml
[animations]
    enabled = false  # Disable all animations
[visual-effects]
    enabled = false  # Disable all effects
```

**Presentations/Demos:**
```toml
[animations]
    default-duration = 0.4
    easing-function = 'ease-in-out'
[visual-effects]
    enabled = true
    effect-quality-level = 'ultra'
```

**Battery Conservation:**
```toml
[animations]
    max-concurrent-animations = 2
    gpu-acceleration-enabled = false
[visual-effects]
    enabled = false
```

### Dynamic Configuration

You can create multiple configuration files and switch between them:

```bash
# Work configuration (performance focused)
cp ~/.aerospace-work.toml ~/.aerospace.toml
aerospace reload-config

# Demo configuration (visual effects enabled)
cp ~/.aerospace-demo.toml ~/.aerospace.toml
aerospace reload-config
```

## Troubleshooting

### Performance Issues
1. Try `performance-optimized-config.toml`
2. Disable visual effects
3. Reduce `max-concurrent-animations`
4. Use `linear` easing function

### Visual Glitches
1. Disable GPU acceleration
2. Reduce effect quality level
3. Lower particle counts
4. Disable motion blur

### Accessibility Issues
1. Use `accessibility-friendly-config.toml`
2. Enable `respect-system-preferences`
3. Reduce animation durations
4. Use linear easing only

### Battery Drain
1. Disable visual effects
2. Use CPU-only animations
3. Reduce concurrent animation limits
4. Shorten animation durations

## Contributing

When contributing new configuration examples:

1. **Document the use case** clearly
2. **Test on multiple hardware configurations**
3. **Include performance notes**
4. **Consider accessibility implications**
5. **Update this README** with the new configuration

## Support

For issues with specific configurations:
1. Check the troubleshooting section above
2. Try the `default-config.toml` to isolate issues
3. Report bugs with your hardware specifications
4. Include performance metrics when relevant