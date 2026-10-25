//
//  FitCard.swift
//  DogmaBot
//

import DiscordBM
import FitAnalysis

/// Components V2 layout of fit summaries: one container per fit.
enum FitCard {

    /// A message holds at most 40 components and 4000 characters of text; a card takes about 10 and 800.
    static let maxFits = 3

    private static let normalColor: DiscordColor = 0x3B82F6
    private static let overloadedColor: DiscordColor = 0xEF4444
    private static let warningsLimit = 600

    static func components(for analysis: FitAnalysis) -> [Interaction.ActionRow.Component] {
        var components = analysis.fits.prefix(maxFits).map { card(for: $0) }
        var notes = analysis.warnings.map { "⚠️ \($0)" }
        if analysis.fits.count > maxFits {
            notes.append("\(analysis.fits.count - maxFits) more fits not shown")
        }
        if !notes.isEmpty {
            components.append(.textDisplay(.init(content: truncated(notes.map { "-# \($0)" }.joined(separator: "\n"),
                                                                    limit: warningsLimit))))
        }
        components.append(.textDisplay(.init(content: "-# All skills V · raw damage, no application · "
                                             + "SDE \(FitAnalyzer.sdeBuild)")))
        return components
    }

    static func card(for fit: FitSummary) -> Interaction.ActionRow.Component {
        let fitting = fit.fitting
        let isOverloaded = fitting.cpu.isOverloaded || fitting.powerGrid.isOverloaded
            || fitting.calibration.isOverloaded

        let render = "https://images.evetech.net/types/\(fit.shipTypeID)/render?size=128"
        let header = Interaction.ActionRow.Section(
            components: [.textDisplay(.init(content: title(for: fit)))],
            accessory: .thumbnail(.init(media: .init(url: .exact(render)), description: fit.shipName))
        )

        return .container(.init(
            components: [
                .section(header),
                .separator(.init(divider: true, spacing: .small)),
                .textDisplay(.init(content: offense(fit) + "\n" + defense(fit))),
                .separator(.init(divider: true, spacing: .small)),
                .textDisplay(.init(content: [capacitor(fit), navigation(fit), targeting(fit), self.fitting(fit)]
                    .joined(separator: "\n")))
            ],
            accent_color: isOverloaded ? overloadedColor : normalColor
        ))
    }

    // MARK: - Sections

    private static func title(for fit: FitSummary) -> String {
        var lines = ["## \(fit.shipName)"]
        if let name = fit.name, !name.isEmpty {
            lines.append("**\(escaped(name))**")
        }
        if !fit.shipGroupName.isEmpty {
            lines.append("-# \(fit.shipGroupName)")
        }
        return lines.joined(separator: "\n")
    }

    private static func offense(_ fit: FitSummary) -> String {
        let dps = fit.damage.dps
        return """
            ### Offense
            **\(StatFormat.number(dps.total))** DPS · **\(StatFormat.number(fit.damage.volley.total))** volley
            -# EM \(StatFormat.number(dps.em)) · Thermal \(StatFormat.number(dps.thermal)) · \
            Kinetic \(StatFormat.number(dps.kinetic)) · Explosive \(StatFormat.number(dps.explosive))
            """
    }

    /// Resistances and hit points as a monospaced table, the one layout that keeps columns aligned on every client.
    private static func defense(_ fit: FitSummary) -> String {
        let defense = fit.defense
        func row(_ name: String, _ resistances: FitSummary.DamageProfile, _ ehp: Double) -> String {
            let cells = [resistances.em, resistances.thermal, resistances.kinetic, resistances.explosive]
                .map { pad(StatFormat.percent($0), 5) }
                .joined()
            return name.padding(toLength: 7, withPad: " ", startingAt: 0) + cells + pad(StatFormat.number(ehp), 8)
        }
        let header = String(repeating: " ", count: 7) + ["EM", "Th", "Kin", "Exp"].map { pad($0, 5) }.joined()
            + pad("EHP", 8)
        return """
            ### Defense
            **\(StatFormat.number(defense.effectiveHitPoints.total))** EHP
            ```
            \(header)
            \(row("Shield", defense.shieldResistances, defense.effectiveHitPoints.shield))
            \(row("Armor", defense.armorResistances, defense.effectiveHitPoints.armor))
            \(row("Hull", defense.hullResistances, defense.effectiveHitPoints.hull))
            ```
            """
    }

    private static func capacitor(_ fit: FitSummary) -> String {
        "**Capacitor** \(StatFormat.capacitor(fit.capacitor)) · \(StatFormat.number(fit.capacitor.capacity)) GJ"
    }

    private static func navigation(_ fit: FitSummary) -> String {
        let navigation = fit.navigation
        return "**Navigation** \(StatFormat.number(navigation.maxVelocity)) m/s · "
            + "align \(StatFormat.duration(navigation.alignTime)) · "
            + "signature \(StatFormat.distance(navigation.signatureRadius)) · "
            + "warp \(StatFormat.warpSpeed(navigation.warpSpeed))"
    }

    private static func targeting(_ fit: FitSummary) -> String {
        let targeting = fit.targeting
        return "**Targeting** \(StatFormat.distance(targeting.maxTargetRange)) · "
            + "\(StatFormat.number(targeting.scanResolution)) mm · \(targeting.maxLockedTargets) targets"
    }

    private static func fitting(_ fit: FitSummary) -> String {
        let fitting = fit.fitting
        return "**Fitting** CPU \(usage(fitting.cpu)) · PG \(usage(fitting.powerGrid)) · "
            + "calibration \(usage(fitting.calibration))"
    }

    // MARK: - Helpers

    private static func usage(_ usage: FitSummary.Usage) -> String {
        usage.isOverloaded ? "⚠️ **\(StatFormat.usage(usage))**" : StatFormat.usage(usage)
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        String(repeating: " ", count: max(0, width - text.count)) + text
    }

    /// Fit names come from users; Markdown in them must not break the card.
    private static func escaped(_ text: String) -> String {
        DiscordUtils.escapingSpecialCharacters(text)
    }

    private static func truncated(_ text: String, limit: Int) -> String {
        text.count <= limit ? text : String(text.prefix(limit - 1)) + "…"
    }
}
