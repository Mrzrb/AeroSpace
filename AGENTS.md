# Repository Guidelines

## Project Structure & Module Organization
AeroSpace is a Swift/macOS project centered on `Package.swift`. Main code lives in `Sources/`: `AppBundle/` contains the app-side server, `Cli/` the command-line client, `Common/` shared code, and `PrivateApi/` platform-specific helpers. Tests live in `Sources/AppBundleTests/`. Documentation sources are in `docs/`, with contributor notes in `dev-docs/`. Generated artifacts and parsers are under `ShellParserGenerated/` and `grammar/`; avoid editing generated files by hand unless you are updating the generator flow.

## Build, Test, and Development Commands
- `make build` or `./build-debug.sh` — build a debug version into `.debug` using SwiftPM.
- `make test` or `./run-tests.sh` — run the repo test flow, including formatting/lint checks.
- `make swift-test` or `./run-swift-test.sh` — run `swift test` only.
- `make format` or `./format.sh` — apply SwiftFormat and run SwiftLint.
- `./run-debug.sh` — launch the debug app bundle.
- `./generate.sh` — regenerate project files and generated sources.

## Coding Style & Naming Conventions
Use 4-space indentation for `*.swift` and `*.sh`; keep lines within 120 columns. Swift formatting is enforced by `.swiftformat`, and linting by `.swiftlint.yml`; run `./format.sh` before opening a PR. Follow existing Swift naming: `UpperCamelCase` for types, `lowerCamelCase` for functions/properties, and descriptive file names matching the primary type or feature.

## Testing Guidelines
Tests use `XCTest` and currently live in `Sources/AppBundleTests/`. Prefer targeted unit tests near the affected subsystem and keep helpers in shared test utilities when reused. Name test files and methods descriptively, e.g. `WorkspaceFocusTests.swift`, `testMovesWindowToNextWorkspace()`. Run `./run-tests.sh` before submission.

## Commit & Pull Request Guidelines
Keep commits atomic: do not mix refactors with functional changes. Recent history uses short, imperative subjects such as `Fix typos` or `Cleanup`; add motivation in the body when helpful. For non-trivial or user-visible changes, discuss the proposal in GitHub Discussions before coding. PRs should explain user-visible behavior, link the related discussion/issue, and include screenshots/videos for UI or window-behavior changes when relevant.

## Contributor Workflow Notes
This repo does not accept direct bug Issues from users; start with GitHub Discussions. If you add commands or config syntax, update the docs in `docs/` and related grammar/completion files.
