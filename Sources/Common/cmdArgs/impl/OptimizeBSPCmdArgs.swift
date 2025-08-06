public struct OptimizeBSPCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .optimizeBSP,
        allowInConfig: true,
        help: optimize_bsp_help_generated,
        options: [
            "--window-id": optionalWindowIdFlag(),
            "--workspace": optionalWorkspaceFlag(),
        ],
        arguments: [],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}