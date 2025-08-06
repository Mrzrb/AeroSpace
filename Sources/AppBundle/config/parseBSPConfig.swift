import Common

func parseBSPConfig(_ raw: [String: Any]) -> ParsedConfig<BSPConfig> {
    var config = BSPConfig()
    var errors: [String] = []
    
    for (key, value) in raw {
        switch key {
        case "split-ratio":
            if let ratio = value as? Double {
                if ratio > 0.1 && ratio < 0.9 {
                    config.splitRatio = ratio
                } else {
                    errors.append("'split-ratio' must be between 0.1 and 0.9, got: \(ratio)")
                }
            } else {
                errors.append("'split-ratio' must be a number, got: \(value)")
            }
            
        case "auto-split-threshold":
            if let threshold = value as? Double {
                if threshold > 1.0 {
                    config.autoSplitThreshold = threshold
                } else {
                    errors.append("'auto-split-threshold' must be greater than 1.0, got: \(threshold)")
                }
            } else {
                errors.append("'auto-split-threshold' must be a number, got: \(value)")
            }
            
        case "preferred-split-direction":
            if let direction = value as? String {
                switch direction {
                case "horizontal":
                    config.preferredSplitDirection = .h
                case "vertical":
                    config.preferredSplitDirection = .v
                case "auto", "none":
                    config.preferredSplitDirection = nil
                default:
                    errors.append("'preferred-split-direction' must be 'horizontal', 'vertical', 'auto', or 'none', got: \(direction)")
                }
            } else {
                errors.append("'preferred-split-direction' must be a string, got: \(value)")
            }
            
        case "enable-intelligent-rebalancing":
            if let enabled = value as? Bool {
                config.enableIntelligentRebalancing = enabled
            } else {
                errors.append("'enable-intelligent-rebalancing' must be a boolean, got: \(value)")
            }
            
        case "enable-adaptive-weighting":
            if let enabled = value as? Bool {
                config.enableAdaptiveWeighting = enabled
            } else {
                errors.append("'enable-adaptive-weighting' must be a boolean, got: \(value)")
            }
            
        case "enable-auto-optimization":
            if let enabled = value as? Bool {
                config.enableAutoOptimization = enabled
            } else {
                errors.append("'enable-auto-optimization' must be a boolean, got: \(value)")
            }
            
        default:
            errors.append("Unknown BSP config key: '\(key)'")
        }
    }
    
    return ParsedConfig(config: config, errors: errors)
}