//
//  FitLink.swift
//  DogmaBot
//

import DiscordBM
import Foundation
import FitAnalysis

/// A fit carried inside a card in the URL of its ship render, so the card holds everything a button under it needs.
///
/// The image server ignores the extra query parameter, and Discord does not show image URLs. A Markdown link with
/// invisible text would be simpler, but Discord renders such a link as raw text.
enum FitLink {

    private static let parameter = "eft"

    /// Characters left as is in the query value; everything else is percent-encoded.
    private static let allowed = CharacterSet(charactersIn:
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

    /// The ship render of the fit with the fit in EFT appended to the URL.
    static func render(of fit: FitSummary) -> Interaction.ActionRow.UnfurledMediaItem {
        let base = "https://images.evetech.net/types/\(fit.shipTypeID)/render?size=128"
        let eft = fit.eft.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return .init(url: .exact("\(base)&\(parameter)=\(eft)"))
    }

    /// Fits in the order their URLs are given; URLs without a fit are skipped.
    static func fits(in urls: [String]) -> [String] {
        urls.compactMap { url in
            URLComponents(string: url)?.queryItems?.first { $0.name == parameter }?.value
        }
    }
}
