//
//  main.swift
//  dogma-cli
//
//  Usage: dogma-cli [--json] [file]
//  Reads a fit (EFT, DNA or in-game XML) from the file or from standard input and prints its stats.
//

import Foundation
import FitAnalysis

var arguments = Array(CommandLine.arguments.dropFirst())
let json = arguments.contains("--json")
arguments.removeAll { $0 == "--json" }

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let text: String
if let path = arguments.first {
    do {
        text = try String(contentsOfFile: path, encoding: .utf8)
    } catch {
        fail("Cannot read \(path): \(error.localizedDescription)")
    }
} else {
    text = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
}

let analysis: FitAnalysis
do {
    analysis = try await FitAnalyzer().analyze(text)
} catch let error as FitAnalysisError {
    switch error {
    case .noFitFound: fail("No fit found")
    case .rejected(let reason): fail("Fit rejected: \(reason)")
    }
} catch {
    fail("Cannot load game data: \(error)")
}

if json {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(analysis), as: UTF8.self))
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
