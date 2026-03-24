public struct OptimizeBSPCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .optimizeBSP,
        allowInConfig: true,
        help: "",
        flags: [
            "--window-id": optionalWindowIdFlag(),
            "--workspace": optionalWorkspaceFlag(),
        ],
        posArgs: [],
    )
}
