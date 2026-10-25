//
//  FitAnalyzerTests.swift
//  FitAnalysisTests
//

import Testing
import FitAnalysis

@Suite("FitAnalyzer")
struct FitAnalyzerTests {

    private static let rifter = """
    [Rifter, Autocannon brawl]
    Damage Control II
    Gyrostabilizer II

    Stasis Webifier II
    1MN Afterburner II

    200mm AutoCannon II, EMP S
    200mm AutoCannon II, EMP S
    200mm AutoCannon II, EMP S
    """

    @Test("EFT fit gives a named summary with non-zero stats")
    func eft() async throws {
        let analysis = try await FitAnalyzer().analyze(Self.rifter)
        let fit = try #require(analysis.fits.first)

        #expect(analysis.fits.count == 1)
        #expect(fit.name == "Autocannon brawl")
        #expect(fit.shipName == "Rifter")
        #expect(fit.damage.dps.total > 0)
        #expect(fit.damage.volley.total > fit.damage.dps.total)
        #expect(fit.defense.effectiveHitPoints.total > fit.defense.hitPoints.total)
        #expect(fit.navigation.maxVelocity > 0)
        #expect(fit.navigation.alignTime > 0)
        #expect(fit.targeting.maxTargetRange > 0)
        #expect(!fit.fitting.cpu.isOverloaded)
        #expect(!fit.fitting.powerGrid.isOverloaded)
    }

    @Test("Unknown items are reported, the rest of the fit is kept")
    func unknownItem() async throws {
        let text = Self.rifter + "\nNot A Real Module II"
        let analysis = try await FitAnalyzer().analyze(text)

        #expect(analysis.fits.count == 1)
        #expect(analysis.warnings.contains { $0.contains("Not A Real Module II") })
    }

    @Test("An armor repairer gives peak tank; sustained tank never exceeds it")
    func tank() async throws {
        let text = """
        [Punisher, Rep]
        Small Armor Repairer II
        Multispectrum Energized Membrane II
        """
        let fit = try #require(try await FitAnalyzer().analyze(text).fits.first)
        let tank = fit.tank

        #expect(tank.peak.armor > 0)
        #expect(tank.peak.shield == 0)
        #expect(tank.peak.passiveShield > 0)
        #expect(tank.sustained.armor <= tank.peak.armor)
        #expect(tank.sustained.passiveShield == tank.peak.passiveShield)
    }

    @Test("Load warnings name the items and repeated ones are counted")
    func namedWarnings() async throws {
        let text = """
        [Rifter, Wrong charges]
        Stasis Webifier II, EMP S
        Stasis Webifier II, EMP S
        """
        let analysis = try await FitAnalyzer().analyze(text)

        #expect(analysis.warnings == ["EMP S does not fit Stasis Webifier II (×2)"])
    }

    @Test("The summary carries the fit as EFT")
    func eftExport() async throws {
        let fit = try #require(try await FitAnalyzer().analyze(Self.rifter).fits.first)

        #expect(fit.eft.hasPrefix("[Rifter, Autocannon brawl]"))
        #expect(fit.eft.contains("200mm AutoCannon II, EMP S"))
    }

    @Test("Text without a fit is rejected")
    func noFit() async throws {
        await #expect(throws: FitAnalysisError.noFitFound) {
            try await FitAnalyzer().analyze("hello, is this rifter fit good?")
        }
    }
}
