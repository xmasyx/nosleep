// swift-tools-version: 6.0
import PackageDescription

// NoSleep — il Mac resta sveglio finché il lavoro non è finito.
//
// Quattro prodotti, e la divisione non è estetica:
//   • NoSleepCore   — logica pura, testabile senza schermo e senza root
//   • NoSleepApp    — la barra dei menu, gira come l'utente
//   • nosleep-helper — il cane da guardia, gira da root e sopravvive all'app
//   • nosleep       — la riga di comando che gli hook usano per le prenotazioni
//
// L'helper è un eseguibile separato perché deve poter restare vivo quando l'app
// muore: è quello, e non un `atexit`, che garantisce il ritorno al sonno.
let package = Package(
    name: "NoSleep",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "NoSleepCore", targets: ["NoSleepCore"]),
        .executable(name: "NoSleepApp", targets: ["NoSleepApp"]),
        .executable(name: "nosleep-helper", targets: ["NoSleepHelper"]),
        .executable(name: "nosleep", targets: ["NoSleepCLI"]),
    ],
    targets: [
        .target(
            name: "NoSleepCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "NoSleepApp",
            dependencies: ["NoSleepCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "NoSleepHelper",
            dependencies: ["NoSleepCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "NoSleepCLI",
            dependencies: ["NoSleepCore"],
            path: "Sources/NoSleepCLI",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "NoSleepCoreTests",
            dependencies: ["NoSleepCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
