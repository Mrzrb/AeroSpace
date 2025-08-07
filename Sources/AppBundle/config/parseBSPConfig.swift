import Common
import TOMLKit

private let bspParser: [String: any ParserProtocol<BSPConfig>] = [
    "split-ratio": Parser(\.splitRatio, parseDouble),
    "auto-split-threshold": Parser(\.autoSplitThreshold, parseDouble),
    "preferred-split-direction": Parser(\.preferredSplitDirection, parseOptionalOrientation),
    "enable-intelligent-rebalancing": Parser(\.enableIntelligentRebalancing, parseBool),
    "enable-adaptive-weighting": Parser(\.enableAdaptiveWeighting, parseBool),
    "enable-auto-optimization": Parser(\.enableAutoOptimization, parseBool),
]

func parseBSPConfig(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> BSPConfig {
    parseTable(raw, BSPConfig(), bspParser, backtrace, &errors)
}

private func parseDouble(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Double> {
    if let doubleValue = raw.double {
        return .success(doubleValue)
    } else if let intValue = raw.int {
        return .success(Double(intValue))
    } else {
        return .failure(expectedActualTypeError(expected: [.double, .int], actual: raw.type, backtrace))
    }
}

private func parseOptionalOrientation(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Orientation?> {
    if raw.string == nil {
        return .success(nil)
    }
    return parseString(raw, backtrace).flatMap { str in
        switch str.lowercased() {
        case "horizontal", "h":
            return .success(.h)
        case "vertical", "v":
            return .success(.v)
        case "auto", "":
            return .success(nil)
        default:
            return .failure(.semantic(backtrace, "'\(str)' orientation isn't supported. Supported orientations: horizontal, vertical, auto"))
        }
    }
}