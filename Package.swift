import PackageDescription

let package = Package(
	name: "Swamp",
	targets: [
		Target(
			name: "Swamp",
			dependencies: []
		)
	],
	dependencies: [
        .Package(url: "https://github.com/daltoniam/Starscream.git", majorVersion: 4),
		.Package(url: "https://github.com/krzyzanowskim/CryptoSwift", majorVersion: 1),
	],
	exclude: ["Example"]
)
