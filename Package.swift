// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "vapor-composable-architecture",
  platforms: [
    .iOS(.v13),
    .macOS(.v11),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "ComposableArchitecture",
      targets: ["ComposableArchitecture"]),
  ],
  dependencies: [
    .package(url: "https://github.com/TokamakUI/Tokamak.git", from: "0.9.0"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.8.0"),
  ],
  targets: [
    .target(
      name: "ComposableArchitecture",
      dependencies: [
        .product(name: "TokamakDOM", package: "Tokamak"),
        .product(name: "CasePaths", package: "swift-case-paths"),
      ]),
    .testTarget(
      name: "vapor-composable-architectureTests",
      dependencies: ["ComposableArchitecture"]),
  ]
)
