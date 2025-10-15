# SchwimmTagebuch

## Testing in the current environment

This workspace runs on Linux and does not provide Apple's Xcode toolchain. Commands such as `xcodebuild test` or running the SwiftUI preview simulator require macOS.

To allow automated tests to run here you can:

1. Provide a macOS runner with Xcode 15 or newer and Swift 5.9 available in the PATH so that `xcodebuild test` succeeds.
2. Alternatively, add Linux-compatible unit tests that can be exercised with `swift test` and a Package.swift manifest.

Without one of these options the best we can do is review the code statically.
