//
//  main.swift
//  dogma-cli
//
//  Usage: dogma-cli [--json | --sheet] [file]
//  Reads a fit (EFT, DNA or in-game XML) from the file or from standard input and prints its stats.
//  --json prints the stats as JSON; --sheet prints the full sheet (contents, resources, raw stats) as JSON.
//

#if os(WASI)
// Full Foundation would add ICU data, tens of megabytes, to the WebAssembly module.
import FoundationEssentials
import WASILibc
#else
import Foundation
#endif
import FitAnalysis

var arguments = Array(CommandLine.arguments.dropFirst())
let json = arguments.contains("--json")
let sheet = arguments.contains("--sheet")
arguments.removeAll { $0 == "--json" || $0 == "--sheet" }

func fail(_ message: String) -> Never {
    #if os(WASI)
    fputs(message + "\n", stderr)
    #else
    FileHandle.standardError.write(Data((message + "\n").utf8))
    #endif
    exit(1)
}

func readStandardInput() -> String {
    #if os(WASI)
    // FoundationEssentials has no `FileHandle`.
    var lines: [String] = []
    while let line = readLine(strippingNewline: false) {
        lines.append(line)
    }
    return lines.joined()
    #else
    String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
    #endif
}

let text: String
if let path = arguments.first {
    do {
        text = try String(contentsOfFile: path, encoding: .utf8)
    } catch {
        fail("Cannot read \(path): \(error)")
    }
} else {
    text = readStandardInput()
}

func report(_ error: Error) -> Never {
    switch error {
    case FitAnalysisError.noFitFound: fail("No fit found")
    case FitAnalysisError.rejected(let reason): fail("Fit rejected: \(reason)")
    default: fail("Cannot load game data: \(error)")
    }
}

func printJSON(_ value: some Encodable) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(value), as: UTF8.self))
}

if sheet {
    do {
        try printJSON(try await FitAnalyzer().sheets(text))
    } catch {
        report(error)
    }
    exit(0)
}

let analysis: FitAnalysis
do {
    analysis = try await FitAnalyzer().analyze(text)
} catch {
    report(error)
}

if json {
    try printJSON(analysis)
    exit(0)
}

for fit in analysis.fits {
    let title = fit.name.map { "\(fit.shipName) — \($0)" } ?? fit.shipName
    let defense = fit.defense
    print("""
    \(title)
      DPS          \(StatFormat.number(fit.damage.dps.total))   volley \(StatFormat.number(fit.damage.volley.total))
      EHP          \(StatFormat.number(defense.effectiveHitPoints.total)) \
    (shield \(StatFormat.number(defense.effectiveHitPoints.shield)), \
    armor \(StatFormat.number(defense.effectiveHitPoints.armor)), \
    hull \(StatFormat.number(defense.effectiveHitPoints.hull)))
      Resists      shield \(StatFormat.resistances(defense.shieldResistances)), \
    armor \(StatFormat.resistances(defense.armorResistances))
      Capacitor    \(StatFormat.capacitor(fit.capacitor))
      Speed        \(StatFormat.number(fit.navigation.maxVelocity)) m/s   align \(StatFormat.duration(fit.navigation.alignTime))
      Signature    \(StatFormat.distance(fit.navigation.signatureRadius))
      Targeting    \(StatFormat.distance(fit.targeting.maxTargetRange)), \
    \(StatFormat.number(fit.targeting.scanResolution)) mm, \(fit.targeting.maxLockedTargets) targets
      CPU          \(StatFormat.usage(fit.fitting.cpu))
      Power grid   \(StatFormat.usage(fit.fitting.powerGrid))
      Calibration  \(StatFormat.usage(fit.fitting.calibration))

    """)
}
for warning in analysis.warnings {
    print("warning: \(warning)")
}
