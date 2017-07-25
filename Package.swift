// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "Aliyun",
    dependencies: [
      .Package(url: "https://github.com/PerfectlySoft/Perfect.git", majorVersion: 2),
      .Package(url: "https://github.com/PerfectlySoft/Perfect-INIParser.git", majorVersion: 1)
    ]
)
