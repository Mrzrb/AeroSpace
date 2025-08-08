import AppKit
import Common
import HotKey

func getDefaultConfigUrlFromProject() -> URL {
    var url = URL(filePath: #filePath)
    check(FileManager.default.fileExists(atPath: url.path))
    while !FileManager.default.fileExists(atPath: url.appending(component: ".git").path) {
        url.deleteLastPathComponent()
    }
    let projectRoot: URL = url
    return projectRoot.appending(component: "docs/config-examples/default-config.toml")
}

var defaultConfigUrl: URL {
    if isUnitTest {
        return getDefaultConfigUrlFromProject()
    } else {
        return Bundle.main.url(forResource: "default-config", withExtension: "toml")
            // Useful for debug builds that are not app bundles
            ?? getDefaultConfigUrlFromProject()
    }
}
@MainActor let defaultConfig: Config = {
    guard let configContent = try? String(contentsOf: defaultConfigUrl) else {
        return Config() // Return default config if file can't be read
    }
    let parsedConfig = parseConfig(configContent)
    if !parsedConfig.errors.isEmpty {
        print("Warning: Can't parse default config: \(parsedConfig.errors)")
        return Config() // Return default config if parsing fails
    }
    return parsedConfig.config
}()
@MainActor var config: Config = defaultConfig // todo move to Ctx?
@MainActor var configUrl: URL = defaultConfigUrl

struct Config: ConvenienceCopyable {
    var afterLoginCommand: [any Command] = []
    var afterStartupCommand: [any Command] = []
    var _indentForNestedContainersWithTheSameOrientation: Void = ()
    var enableNormalizationFlattenContainers: Bool = true
    var _nonEmptyWorkspacesRootContainersLayoutOnStartup: Void = ()
    var defaultRootContainerLayout: Layout = .tiles
    var defaultRootContainerOrientation: DefaultContainerOrientation = .auto
    var startAtLogin: Bool = false
    var automaticallyUnhideMacosHiddenApps: Bool = false
    var accordionPadding: Int = 30
    var enableNormalizationOppositeOrientationForNestedContainers: Bool = true
    var execOnWorkspaceChange: [String] = [] // todo deprecate
    var keyMapping = KeyMapping()
    var execConfig: ExecConfig = ExecConfig()

    var onFocusChanged: [any Command] = []
    // var onFocusedWorkspaceChanged: [any Command] = []
    var onFocusedMonitorChanged: [any Command] = []

    var gaps: Gaps = .zero
    var workspaceToMonitorForceAssignment: [String: [MonitorDescription]] = [:]
    var modes: [String: Mode] = [:]
    var onWindowDetected: [WindowDetectedCallback] = []

    var preservedWorkspaceNames: [String] = []
    var bsp: BSPConfig = BSPConfig()
    var animation: AnimationConfig = AnimationConfig()
    var visualEffects: VisualEffectsConfig = VisualEffectsConfig()
}

enum DefaultContainerOrientation: String {
    case horizontal, vertical, auto
}

struct BSPConfig: ConvenienceCopyable {
    var splitRatio: Double = 0.5
    var autoSplitThreshold: Double = 1.2
    var preferredSplitDirection: Orientation? = nil
    var enableIntelligentRebalancing: Bool = true
    var enableAdaptiveWeighting: Bool = true
    var enableAutoOptimization: Bool = true
}
