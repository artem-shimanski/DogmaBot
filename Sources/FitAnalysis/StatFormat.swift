//
//  StatFormat.swift
//  FitAnalysis
//

import Foundation

/// Compact, locale-independent formatting of stat values for chat and terminal output.
public enum StatFormat {

    /// `950`, `12.3k`, `1.25M`.
    public static func number(_ value: Double) -> String {
        let magnitude = abs(value)
        switch magnitude {
        case 1_000_000...: return String(format: "%.2fM", value / 1_000_000)
        case 10_000...: return String(format: "%.1fk", value / 1_000)
        case 100...: return String(format: "%.0f", value)
        default: return String(format: "%.1f", value)
        }
    }

    /// Meters below 10 km, kilometers above.
    public static func distance(_ meters: Double) -> String {
        meters < 10_000 ? String(format: "%.0f m", meters) : String(format: "%.1f km", meters / 1_000)
    }

    /// `42.0 s`, `3m 05s`, `1h 12m`.
    public static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "∞" }
        if seconds < 60 { return String(format: "%.1f s", seconds) }
        let total = Int(seconds.rounded())
        if total < 3600 { return String(format: "%dm %02ds", total / 60, total % 60) }
        return String(format: "%dh %02dm", total / 3600, total % 3600 / 60)
    }

    /// A fraction 0…1 as a whole percentage.
    public static func percent(_ fraction: Double) -> String {
        String(format: "%.0f%%", fraction * 100)
    }

    public static func usage(_ usage: FitSummary.Usage) -> String {
        "\(number(usage.used)) / \(number(usage.total))"
    }

    /// Resistances as `EM/Th/Kin/Exp` percentages.
    public static func resistances(_ profile: FitSummary.DamageProfile) -> String {
        [profile.em, profile.thermal, profile.kinetic, profile.explosive]
            .map { String(format: "%.0f", $0 * 100) }
            .joined(separator: " / ")
    }

    public static func capacitor(_ capacitor: FitSummary.Capacitor) -> String {
        if let level = capacitor.stableLevel {
            return "Stable at \(percent(level))"
        }
        return "Lasts \(duration(capacitor.lastsFor ?? 0))"
    }
}
