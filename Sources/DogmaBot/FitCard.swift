//
//  FitCard.swift
//  DogmaBot
//

import DiscordBM
import FitAnalysis

/// Components V2 layout of fit summaries: one container per fit.
enum FitCard {

    /// A message holds at most 40 components and 4000 characters of text; a card with a battleship fit takes
    /// about 10 components and 1700 characters.
    static let maxFits = 2

    /// - Parameter webPage: the fit page; each card links to it with the fit in the URL fragment.
    static func components(for analysis: FitAnalysis, webPage: String? = nil) -> [Interaction.ActionRow.Component] {
        var components = analysis.fits.prefix(maxFits).map { card(for: $0, webPage: webPage) }
        var notes = analysis.warnings
        if analysis.fits.count > maxFits {
            notes.append("\(analysis.fits.count - maxFits) more fits not shown")
        }
        if let notes = CardText.notes(notes) {
            components.append(notes)
        }
        components.append(CardText.footer)
        return components
    }

    static func card(for fit: FitSummary, webPage: String? = nil) -> Interaction.ActionRow.Component {
        let header = Interaction.ActionRow.Section(
            components: [.textDisplay(.init(content: title(for: fit, webPage: webPage)))],
            accessory: .thumbnail(.init(media: CardText.render(of: fit), description: fit.shipName))
        )

        return .container(.init(
            components: [
                .section(header),
                .separator(.init(divider: true, spacing: .small)),
                .textDisplay(.init(content: [offense(fit), defense(fit), tank(fit)].joined(separator: "\n"))),
                .separator(.init(divider: true, spacing: .small)),
                .textDisplay(.init(content: [capacitor(fit), navigation(fit), targeting(fit), self.fitting(fit)]
                    .joined(separator: "\n"))),
                .separator(.init(divider: true, spacing: .small)),
                .textDisplay(.init(content: CardText.eftBlock(fit.eft)))
            ],
            accent_color: CardText.isOverloaded(fit) ? CardText.overloadedColor : CardText.normalColor
        ))
    }

    // MARK: - Sections

    private static func title(for fit: FitSummary, webPage: String?) -> String {
        var lines = ["## \(fit.shipName)"]
        if let name = fit.name, !name.isEmpty {
            lines.append("**\(CardText.escaped(name))**")
        }
        if !fit.shipGroupName.isEmpty {
            lines.append("-# \(fit.shipGroupName)")
        }
        if let webPage {
            lines.append("[Open in browser](\(CardText.webLink(webPage, eft: fit.eft)))")
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
                .map { CardText.pad(StatFormat.percent($0), 5) }
                .joined()
            return CardText.label(name, 7) + cells + CardText.pad(StatFormat.number(ehp), 8)
        }
        let header = String(repeating: " ", count: 7) + ["EM", "Th", "Kin", "Exp"].map { CardText.pad($0, 5) }.joined()
            + CardText.pad("EHP", 8)
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

    /// Rates per layer. The sustained column is shown only when the capacitor cannot keep every repairer running;
    /// otherwise it repeats the peak column.
    private static func tank(_ fit: FitSummary) -> String {
        let peak = fit.tank.peak
        let sustained = fit.tank.sustained
        let layers: [(String, Double, Double)] = [
            ("Passive", peak.passiveShield, sustained.passiveShield),
            ("Shield", peak.shield, sustained.shield),
            ("Armor", peak.armor, sustained.armor),
            ("Hull", peak.hull, sustained.hull)
        ]
        let isLimited = layers.contains { StatFormat.number($0.1) != StatFormat.number($0.2) }

        let header: String
        let rows: [String]
        let summary: String
        if isLimited {
            header = String(repeating: " ", count: 9) + CardText.pad("Peak", 8) + CardText.pad("Sustained", 11)
            rows = layers.map { name, peak, sustained in
                CardText.label(name, 9)
                    + CardText.pad(StatFormat.number(peak), 8) + CardText.pad(StatFormat.number(sustained), 11)
            }
            summary = "**\(StatFormat.number(sustained.total))** EHP/s sustained · "
                + "**\(StatFormat.number(peak.total))** peak"
        } else {
            header = String(repeating: " ", count: 9) + CardText.pad("EHP/s", 8)
            rows = layers.map { name, peak, _ in
                CardText.label(name, 9) + CardText.pad(StatFormat.number(peak), 8)
            }
            summary = "**\(StatFormat.number(peak.total))** EHP/s"
        }
        return """
            ### Tank
            \(summary)
            ```
            \(header)
            \(rows.joined(separator: "\n"))
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
}
