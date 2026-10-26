//
//  FitComparisonTests.swift
//  FitAnalysisTests
//

import Testing
import FitAnalysis

@Suite("FitComparison")
struct FitComparisonTests {

    private static let base = """
    [Rifter, Base]
    Damage Control II

    200mm AutoCannon II, EMP S
    200mm AutoCannon II, EMP S
    200mm AutoCannon II, EMP S
    """

    private func fit(_ text: String) async throws -> FitSummary {
        try #require(try await FitAnalyzer().analyze(text).fits.first)
    }

    @Test("More damage is better for B; an extra plate makes align worse")
    func better() async throws {
        let a = try await fit(Self.base)
        let b = try await fit(Self.base.replacingOccurrences(of: "Damage Control II",
                                                              with: "Gyrostabilizer II\n200mm Steel Plates II"))
        let rows = Dictionary(uniqueKeysWithValues: FitComparison(a, b).rows.map { ($0.label, $0) })

        let dps = try #require(rows["DPS"])
        #expect(dps.better == .b)
        #expect((dps.change ?? 0) > 0)

        let align = try #require(rows["Align"])
        #expect(align.b > align.a)
        #expect(align.better == .a)
    }

    @Test("Identical fits tie on every row")
    func tie() async throws {
        let a = try await fit(Self.base)
        #expect(FitComparison(a, a).rows.allSatisfy { $0.better == nil && ($0.change ?? 0) == 0 })
    }

    @Test("No change is reported against a zero value")
    func zeroBase() {
        let row = FitComparison.Row(label: "Tank peak", a: 0, b: 10)
        #expect(row.change == nil)
        #expect(row.better == .b)
    }
}
