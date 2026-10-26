//
//  FitLinkTests.swift
//  DogmaBotTests
//

import Foundation
import Testing
import FitAnalysis
@testable import DogmaBot

@Suite("FitLink")
struct FitLinkTests {

    private static let analyzer = Result { try FitAnalyzer() }

    private func fit(_ text: String) async throws -> FitSummary {
        try #require(try await Self.analyzer.get().analyze(text).fits.first)
    }

    @Test("A fit survives the round trip through the render URL, including reserved characters")
    func roundTrip() async throws {
        let fit = try await fit("[Rifter, (Brawl) & co + 100% «тест» #1?]\nDamage Control II")
        let url = try #require(FitLink.render(of: fit).url as String?)

        #expect(url.hasPrefix("https://images.evetech.net/types/587/render?size=128&eft="))
        #expect(FitLink.fits(in: [url]) == [fit.eft])
    }

    @Test("URLs without a fit are skipped")
    func plainRender() {
        #expect(FitLink.fits(in: ["https://images.evetech.net/types/587/render?size=128"]).isEmpty)
    }

    @Test("The EFT button gets both fits back from the compare card")
    func compareCard() async throws {
        let a = try await fit("[Rifter, A]\nDamage Control II")
        let b = try await fit("[Punisher, B]\nSmall Armor Repairer II")
        let components = CompareCard.components(for: FitComparison(a, b), notes: [])

        let urls = ButtonClick.mediaURLs(inComponents: try JSONEncoder().encode(components))

        #expect(FitLink.fits(in: urls) == [a.eft, b.eft])
    }
}
