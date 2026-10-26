//
//  CompareCard.swift
//  DogmaBot
//

import DiscordBM
import FitAnalysis
import Foundation

/// Components V2 layout of a comparison of two fits.
enum CompareCard {

    private static let labelWidth = 11
    private static let valueWidth = 8
    private static let changeWidth = 9

    /// - Parameter webPage: the fit page; each fit links to it with the fit in the URL fragment.
    static func components(for comparison: FitComparison,
                           webPage: String) -> [Interaction.ActionRow.Component] {
        let a = comparison.a
        let b = comparison.b
        let accent = CardText.isOverloaded(a) || CardText.isOverloaded(b)
            ? CardText.overloadedColor
            : CardText.normalColor

        var components: [Interaction.ActionRow.Component] = [
            .container(.init(
                components: [
                    .textDisplay(.init(content: "## Compare")),
                    header("A", a, webPage: webPage),
                    header("B", b, webPage: webPage),
                    .separator(.init(divider: true, spacing: .small)),
                    .textDisplay(.init(content: table(comparison)))
                ],
                accent_color: accent
            ))
        ]
        components.append(CardText.footer)
        return components
    }

    /// One line per fit with a small ship render; a media gallery would stretch the renders to the card width.
    private static func header(_ side: String, _ fit: FitSummary, webPage: String) -> Interaction.ActionRow.Component {
        var text = "**\(side)** \(fit.shipName)"
        if let name = fit.name, !name.isEmpty {
            text += "\n-# \(CardText.escaped(name))"
        }
        text += "\n\(CardText.openLink(webPage, fit: fit))"
        return .section(.init(
            components: [.textDisplay(.init(content: text))],
            accessory: .thumbnail(.init(media: CardText.render(of: fit), description: fit.shipName))
        ))
    }

    /// Values of both fits and the change from A to B; the arrow marks the side with the better value.
    private static func table(_ comparison: FitComparison) -> String {
        let header = CardText.label("", labelWidth) + CardText.pad("A", valueWidth) + CardText.pad("B", valueWidth)
            + CardText.pad("B vs A", changeWidth)
        var lines = [header]
        for row in comparison.rows {
            lines.append(CardText.label(row.label, labelWidth)
                         + CardText.pad(format(row.a, row.kind), valueWidth)
                         + CardText.pad(format(row.b, row.kind), valueWidth)
                         + CardText.pad(change(row.change, row.better), changeWidth))
        }
        lines.append(capacitorRow(comparison.a.capacitor, comparison.b.capacitor))
        return """
            ```
            \(lines.joined(separator: "\n"))
            ```
            -# ▲ B is better · ▼ A is better
            """
    }

    /// A stable capacitor beats an unstable one; between two stable ones the higher level wins,
    /// between two unstable ones the longer-lasting.
    private static func capacitorRow(_ a: FitSummary.Capacitor, _ b: FitSummary.Capacitor) -> String {
        func value(_ capacitor: FitSummary.Capacitor) -> String {
            capacitor.stableLevel.map(StatFormat.percent) ?? StatFormat.duration(capacitor.lastsFor ?? 0)
        }
        func score(_ capacitor: FitSummary.Capacitor) -> (Int, Double) {
            capacitor.stableLevel.map { (1, $0) } ?? (0, capacitor.lastsFor ?? 0)
        }
        let better: FitComparison.Side? = score(a) == score(b) ? nil : (score(b) > score(a) ? .b : .a)
        return CardText.label("Capacitor", labelWidth)
            + CardText.pad(value(a), valueWidth)
            + CardText.pad(value(b), valueWidth)
            + CardText.pad(marker(better), changeWidth)
    }

    private static func format(_ value: Double, _ kind: FitComparison.Kind) -> String {
        switch kind {
        case .number: StatFormat.number(value)
        case .duration: StatFormat.duration(value)
        case .distance: StatFormat.distance(value)
        }
    }

    private static func change(_ change: Double?, _ better: FitComparison.Side?) -> String {
        guard let change, better != nil else { return marker(better) }
        let percent = change * 100
        let text: String
        if change >= 2 {
            // Past +200% a ratio reads better than a percentage.
            let ratio = change + 1
            text = ratio < 10 ? String(format: "×%.1f", ratio) : String(format: "×%.0f", ratio)
        } else {
            text = abs(percent) < 1 ? "<1%" : String(format: "%+.0f%%", percent)
        }
        return "\(text) \(marker(better))"
    }

    private static func marker(_ better: FitComparison.Side?) -> String {
        switch better {
        case .a: "▼"
        case .b: "▲"
        case nil: ""
        }
    }
}
