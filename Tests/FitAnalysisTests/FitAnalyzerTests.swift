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

    @Test("The sheet lists the fit's contents in rack order and agrees with the summary")
    func sheet() async throws {
        let text = Self.rifter + "\n\nWarrior II x2\n"
        let analyzer = try FitAnalyzer()
        let sheet = try #require(try await analyzer.sheets(text).fits.first)
        let summary = try #require(try await analyzer.analyze(text).fits.first)

        #expect(sheet.name == "Autocannon brawl")
        #expect(sheet.ship.name == "Rifter")
        #expect(sheet.modules.map(\.slot) == [.hi, .hi, .hi, .med, .med, .low, .low])
        let gun = try #require(sheet.modules.first)
        #expect(gun.item.name == "200mm AutoCannon II")
        #expect(gun.charge?.item.name == "EMP S")
        #expect((gun.charge?.count ?? 0) > 1)
        #expect(sheet.drones.map(\.item.name) == ["Warrior II"])
        #expect(sheet.drones.first?.count == 2)
        #expect(sheet.resources.slots[.hi] == .init(used: 3, total: 3))
        #expect(sheet.resources.turrets.used == 3)

        #expect(sheet.damage.dps == summary.damage.dps)
        let sources = [sheet.damage.turrets, sheet.damage.launchers, sheet.damage.drones,
                       sheet.damage.fighters, sheet.damage.otherModules]
        #expect(abs(sources.map(\.total).reduce(0, +) - summary.damage.dps.total) < 1e-6)
        #expect(sheet.hitPoints == summary.defense.hitPoints)
        #expect(abs(1 - sheet.resonance.armor.em - summary.defense.armorResistances.em) < 1e-6)
        #expect(sheet.capacitor.capacity == summary.capacitor.capacity)
        #expect(sheet.navigation.mass > 0)
        #expect(sheet.targeting.sensorType == .ladar)
        #expect(sheet.fuel == nil)
        #expect(sheet.eft == summary.eft)

        // DNA carries no fit name, but reads back as the same fit.
        #expect(sheet.dna.hasPrefix("\(sheet.ship.typeID):"))
        let fromDNA = try #require(try await analyzer.sheets(sheet.dna).fits.first)
        #expect(fromDNA.modules == sheet.modules)
        #expect(fromDNA.damage == sheet.damage)
    }

    @Test("Only as many drones as the pilot can control go to space, the strongest first")
    func droneLimit() async throws {
        let text = """
        [Vexor, Drones]

        Hobgoblin II x5
        Hammerhead II x5
        """
        let analysis = try await FitAnalyzer().sheets(text)
        let sheet = try #require(analysis.fits.first)
        let launched = sheet.drones.filter(\.isActive)

        #expect(launched.map(\.item.name) == ["Hammerhead II"])
        #expect(sheet.resources.dronesInSpace == .init(used: 5, total: 5))
        #expect(sheet.damage.drones.total == sheet.damage.dps.total)
        #expect(analysis.warnings == ["Left in the drone bay: Hobgoblin II x5"])
    }

    @Test("A stack that fits only in part is split between space and the bay")
    func droneSplit() async throws {
        let text = """
        [Ishtar, Split]

        Ogre II x3
        Hobgoblin II x10
        """
        let sheet = try #require(try await FitAnalyzer().sheets(text).fits.first)
        let drones = sheet.drones.map { "\($0.item.name) x\($0.count) \($0.isActive ? "space" : "bay")" }

        #expect(drones == ["Ogre II x3 space", "Hobgoblin II x2 space", "Hobgoblin II x8 bay"])
        #expect(sheet.resources.dronesInSpace.used == 5)
    }

    @Test("Fighters launch up to the squadron slots of their type")
    func fighterLimit() async throws {
        let text = """
        [Thanatos, Fighters]

        Templar II x9
        Templar II x9
        Templar II x9
        Templar II x9
        """
        let analysis = try await FitAnalyzer().sheets(text)
        let sheet = try #require(analysis.fits.first)
        let light = try #require(sheet.resources.squadrons[.light])

        #expect(sheet.drones.filter(\.isActive).count == light.total)
        #expect(sheet.resources.fighterTubes.used == light.total)
        #expect(analysis.warnings == ["Left in the fighter hangar: Templar II x9"])
    }

    @Test("Implants and boosters are put on the pilot and change the stats")
    func implantsAndBoosters() async throws {
        let base = """
        [Rifter, Pilot]

        Small Shield Booster II
        """
        let analyzer = try FitAnalyzer()
        let bare = try #require(try await analyzer.analyze(base).fits.first)
        let boosted = try #require(try await analyzer.analyze(base + """


            High-grade Snake Alpha
            High-grade Snake Beta

            Strong Blue Pill Booster
            """).fits.first)
        let sheet = try #require(try await analyzer.sheets(base + "\n\nHigh-grade Snake Alpha\n").fits.first)

        #expect(boosted.navigation.maxVelocity > bare.navigation.maxVelocity)
        #expect(boosted.tank.peak.shield > bare.tank.peak.shield)
        #expect(sheet.implants.map(\.name) == ["High-grade Snake Alpha"])
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
