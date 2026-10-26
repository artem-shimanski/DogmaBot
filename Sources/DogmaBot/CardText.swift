//
//  CardText.swift
//  DogmaBot
//

import DiscordBM
import Foundation
import FitAnalysis

/// Text building blocks shared by the cards.
enum CardText {

    static let normalColor: DiscordColor = 0x3B82F6
    static let overloadedColor: DiscordColor = 0xEF4444

    private static let notesLimit = 600

    /// Right-aligns `text` in a column of `width` characters.
    static func pad(_ text: String, _ width: Int) -> String {
        String(repeating: " ", count: max(0, width - text.count)) + text
    }

    /// Left-aligns `text` in a column of `width` characters.
    static func label(_ text: String, _ width: Int) -> String {
        text.padding(toLength: width, withPad: " ", startingAt: 0)
    }

    /// Fit names come from users; Markdown in them must not break the card.
    static func escaped(_ text: String) -> String {
        DiscordUtils.escapingSpecialCharacters(text)
    }

    static func truncated(_ text: String, limit: Int) -> String {
        text.count <= limit ? text : String(text.prefix(limit - 1)) + "…"
    }

    /// The fit in a code block, which Discord gives a copy button.
    static func eftBlock(_ eft: String) -> String {
        // A backtick in a user-supplied fit name would close the block early.
        let text = eft.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "`", with: "'")
        return "```\n\(text)\n```"
    }

    /// Import notes in small print, or `nil` when there are none.
    static func notes(_ notes: [String]) -> Interaction.ActionRow.Component? {
        guard !notes.isEmpty else { return nil }
        let text = notes.map { "-# ⚠️ \($0)" }.joined(separator: "\n")
        return .textDisplay(.init(content: truncated(text, limit: notesLimit)))
    }

    /// The fit page with the fit in the fragment as base64url of its EFT. Browsers do not send the fragment to the
    /// server, so the page reads it on the client.
    static func webLink(_ page: String, eft: String) -> String {
        let base64 = Data(eft.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "\(page)#eft=\(base64)"
    }

    static var footer: Interaction.ActionRow.Component {
        .textDisplay(.init(content: "-# All skills V · raw damage, no application · SDE \(FitAnalyzer.sdeBuild)"))
    }

    static func render(of fit: FitSummary) -> Interaction.ActionRow.UnfurledMediaItem {
        .init(url: .exact("https://images.evetech.net/types/\(fit.shipTypeID)/render?size=128"))
    }

    static func isOverloaded(_ fit: FitSummary) -> Bool {
        fit.fitting.cpu.isOverloaded || fit.fitting.powerGrid.isOverloaded || fit.fitting.calibration.isOverloaded
    }
}
