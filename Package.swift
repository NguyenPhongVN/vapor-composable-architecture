  // swift-tools-version:5.5
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
    .package(url: "https://github.com/OpenCombine/OpenCombine.git", from: "0.13.0"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.8.0"),
  ],
  targets: [
    .target(
      name: "ComposableArchitecture",
      dependencies: [
        "OpenCombine",
        .product(name: "OpenCombineFoundation", package: "OpenCombine"),
        .product(name: "OpenCombineDispatch", package: "OpenCombine"),
        .product(name: "CasePaths", package: "swift-case-paths"),
      ]),
    .testTarget(
      name: "vapor-composable-architectureTests",
      dependencies: ["ComposableArchitecture"]),
  ]
)
