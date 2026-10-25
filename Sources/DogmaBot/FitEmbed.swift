//
//  FitEmbed.swift
//  DogmaBot
//

import DiscordBM
import FitAnalysis

/// Discord embeds for fit summaries.
enum FitEmbed {

    /// Discord allows up to 10 embeds per message; one is kept for the import notes.
    static let maxFits = 9

    private static let fieldLimit = 1_024
    private static let normalColor: DiscordColor = 0x3B82F6
    private static let overloadedColor: DiscordColor = 0xEF4444

    static func embeds(for analysis: FitAnalysis) -> [Embed] {
        var embeds = analysis.fits.prefix(maxFits).map(embed)
        if !analysis.warnings.isEmpty {
            embeds.append(Embed(title: "Import notes",
                                description: truncated(analysis.warnings.map { "• \($0)" }.joined(separator: "\n"),
                                                       limit: 4_096)))
        }
        return embeds
    }

    static func embed(for fit: FitSummary) -> Embed {
        let defense = fit.defense
        let ehp = defense.effectiveHitPoints
        let fitting = fit.fitting
        let isOverloaded = fitting.cpu.isOverloaded || fitting.powerGrid.isOverloaded
            || fitting.calibration.isOverloaded

        return Embed(
            title: fit.name.map { "\(fit.shipName) — \($0)" } ?? fit.shipName,
            color: isOverloaded ? overloadedColor : normalColor,
            footer: .init(text: "All skills at V · raw damage, no application"),
            thumbnail: .init(url: .exact("https://images.evetech.net/types/\(fit.shipTypeID)/render?size=128")),
            fields: [
                field("Damage", """
                    DPS **\(StatFormat.number(fit.damage.dps.total))**
                    Volley \(StatFormat.number(fit.damage.volley.total))
                    """),
                field("Defense", """
                    EHP **\(StatFormat.number(ehp.total))**
                    S \(StatFormat.number(ehp.shield)) · A \(StatFormat.number(ehp.armor)) · \
                    H \(StatFormat.number(ehp.hull))
                    """),
                field("Capacitor", """
                    \(StatFormat.capacitor(fit.capacitor))
                    \(StatFormat.number(fit.capacitor.capacity)) GJ
                    """),
                field("Navigation", """
                    \(StatFormat.number(fit.navigation.maxVelocity)) m/s
                    Align \(StatFormat.duration(fit.navigation.alignTime))
                    Signature \(StatFormat.distance(fit.navigation.signatureRadius))
                    """),
                field("Targeting", """
                    \(StatFormat.distance(fit.targeting.maxTargetRange))
                    \(StatFormat.number(fit.targeting.scanResolution)) mm
                    \(fit.targeting.maxLockedTargets) targets
                    """),
                field("Fitting", """
                    CPU \(usage(fitting.cpu))
                    PG \(usage(fitting.powerGrid))
                    Calibration \(usage(fitting.calibration))
                    """),
                field("Resistances (EM / Th / Kin / Exp)", """
                    ```
                    Shield \(StatFormat.resistances(defense.shieldResistances))
                    Armor  \(StatFormat.resistances(defense.armorResistances))
                    Hull   \(StatFormat.resistances(defense.hullResistances))
                    ```
                    """, inline: false)
            ]
        )
    }

    private static func usage(_ usage: FitSummary.Usage) -> String {
        usage.isOverloaded ? "**\(StatFormat.usage(usage))** ⚠️" : StatFormat.usage(usage)
    }

    private static func field(_ name: String, _ value: String, inline: Bool = true) -> Embed.Field {
        Embed.Field(name: name, value: truncated(value, limit: fieldLimit), inline: inline)
    }

    private static func truncated(_ text: String, limit: Int) -> String {
        text.count <= limit ? text : String(text.prefix(limit - 1)) + "…"
    }
}
