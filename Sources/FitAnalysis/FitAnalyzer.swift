//
//  FitAnalyzer.swift
//  FitAnalysis
//

import DogmaKit
import DogmaKitIO
import DogmaText

/// Fits found in a text, plus what was lost while reading it.
public struct FitAnalysis: Sendable, Codable, Equatable {
    public var fits: [FitSummary]
    /// Human-readable notes about lines that were skipped or changed on import.
    public var warnings: [String]

    public init(fits: [FitSummary], warnings: [String]) {
        self.fits = fits
        self.warnings = warnings
    }
}

/// Full sheets of the fits found in a text, plus what was lost while reading it.
public struct FitSheets: Sendable, Codable, Equatable {
    public var fits: [FitSheet]
    /// Human-readable notes about lines that were skipped or changed on import.
    public var warnings: [String]

    public init(fits: [FitSheet], warnings: [String]) {
        self.fits = fits
        self.warnings = warnings
    }
}

public enum FitAnalysisError: Error, Sendable, Equatable {
    /// The text holds no fit in any supported format.
    case noFitFound
    /// The fit was read but the engine could not load it.
    case rejected(String)
}

/// Reads fits in EFT, DNA or in-game XML and calculates their stats with all skills at level V.
public struct FitAnalyzer: Sendable {

    /// Build number of the game data the stats are calculated from.
    public static let sdeBuild = SDEVersion.buildNumber

    let names: TextCatalog
    private let importer: FitImporter
    private let exporter: FitExporter

    public init() throws {
        let names = try TextCatalog.english()
        let catalog = try TypeCatalog()
        self.names = names
        self.importer = FitImporter(resolver: names, catalog: catalog)
        self.exporter = FitExporter(names: names, catalog: catalog)
    }

    public func analyze(_ text: String) async throws(FitAnalysisError) -> FitAnalysis {
        let (fits, warnings) = try await evaluate(text) { (engine, document) -> FitSummary? in
            guard var summary = await summarize(engine) else { return nil }
            summary.name = document.name
            summary.eft = exporter.export(document, as: .eft).text
            return summary
        }
        return FitAnalysis(fits: fits, warnings: warnings)
    }

    /// The full sheet of every fit in the text: contents, resources and raw stats.
    public func sheets(_ text: String) async throws(FitAnalysisError) -> FitSheets {
        let (fits, warnings) = try await evaluate(text) { (engine, document) -> FitSheet? in
            guard var sheet = await sheet(engine) else { return nil }
            sheet.name = document.name
            sheet.eft = exporter.export(document, as: .eft).text
            sheet.dna = exporter.export(document, as: .dna).text
            return sheet
        }
        return FitSheets(fits: fits, warnings: warnings)
    }

    /// Loads every fit of the text into its own engine and reads it with `read`; fits it returns `nil` for
    /// are left out.
    private func evaluate<Result>(
        _ text: String,
        read: (DogmaEngine, FitDocument) async -> Result?
    ) async throws(FitAnalysisError) -> ([Result], [String]) {
        let result = importer.load(text)
        guard !result.documents.isEmpty else { throw .noFitFound }

        var warnings = result.warnings.map(describe)
        var fits: [Result] = []
        for document in result.documents {
            // A fresh engine per fit: the session is an actor, so concurrent requests do not share state.
            let engine = DogmaEngine()
            do {
                let loadWarnings = try await engine.load(document)
                warnings += loadWarnings.map(describe)
            } catch {
                throw .rejected(String(describing: error))
            }
            warnings += await launchDrones(engine)
            guard let fit = await read(engine, document) else { continue }
            fits.append(fit)
        }
        guard !fits.isEmpty else { throw .noFitFound }
        return (fits, Self.counted(warnings))
    }

    /// Stats of the first pilot's hull. The fit name and EFT text are left for the caller to fill.
    private func summarize(_ engine: DogmaEngine) async -> FitSummary? {
        let names = names
        return await engine.evaluate { stats in
            guard let pilotID = stats.pilots.allIDs.first(where: { _ in true }) else { return nil }
            let hull = stats[pilotID.hull]

            let resonance = hull.resonance
            let hitPoints = hull.hitPoints
            let effective = hitPoints.effective(resonance: resonance)
            let capacitor = hull.capacitor()
            let tank = hull.tank().effective(resonance: resonance)
            let sustainedTank = hull.sustainableTank(capacitor: capacitor).effective(resonance: resonance)
            let navigation = hull.navigation
            let targeting = hull.targeting

            return FitSummary(
                name: nil,
                shipTypeID: hull.typeID.rawValue,
                shipName: names.name(of: hull.typeID) ?? "#\(hull.typeID.rawValue)",
                shipGroupName: names.name(of: hull.groupID) ?? "",
                damage: .init(dps: .init(hull.dps()), volley: .init(hull.volleyDamage())),
                defense: .init(hitPoints: .init(hitPoints),
                               effectiveHitPoints: .init(effective),
                               shieldResistances: .init(resistance: resonance.shield),
                               armorResistances: .init(resistance: resonance.armor),
                               hullResistances: .init(resistance: resonance.hull)),
                tank: .init(peak: .init(tank), sustained: .init(sustainedTank)),
                capacitor: .init(capacity: capacitor.capacity,
                                 rechargeTime: capacitor.rechargeTime,
                                 stableLevel: capacitor.stableLevel,
                                 lastsFor: capacitor.isStable ? nil : capacitor.lastsFor),
                navigation: .init(maxVelocity: navigation.maxVelocity,
                                  alignTime: navigation.alignTime,
                                  signatureRadius: navigation.signatureRadius,
                                  warpSpeed: navigation.warpSpeed),
                targeting: .init(maxTargetRange: targeting.maxTargetRange,
                                 scanResolution: targeting.scanResolution,
                                 maxLockedTargets: targeting.maxLockedTargets),
                fitting: .init(cpu: .init(hull.cpu),
                               powerGrid: .init(hull.powerGrid),
                               calibration: .init(hull.calibration)),
                eft: "")
        }
    }

    func name(_ typeID: TypeID) -> String {
        names.name(of: typeID) ?? "#\(typeID.rawValue)"
    }

    /// Repeated notes collapse into one with a count, keeping the order of first appearance.
    private static func counted(_ warnings: [String]) -> [String] {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for warning in warnings {
            if counts[warning] == nil { order.append(warning) }
            counts[warning, default: 0] += 1
        }
        return order.map { warning in
            let count = counts[warning] ?? 1
            return count > 1 ? "\(warning) (×\(count))" : warning
        }
    }

    private func describe(_ warning: FitDocument.Warning) -> String {
        switch warning {
        case .unknownFormat(let format): "Unknown document format: \(format)"
        case .unsupportedVersion(let version): "Unsupported document version: \(version)"
        case .pilotRejected(let index, let error): "Pilot \(index + 1) rejected: \(error)"
        case .typeRejected(let typeID, _): "Cannot be fitted: \(name(typeID))"
        case .skillNotFound(let typeID): "Unknown skill: \(name(typeID))"
        case .chargeRejected(let charge, let module, _): "\(name(charge)) does not fit \(name(module))"
        case .mutationRejected(let mutaplasmid, let typeID, _):
            "\(name(mutaplasmid)) cannot be applied to \(name(typeID))"
        case .rollRejected(_, let typeID, _): "Mutation roll out of range: \(name(typeID))"
        case .targetOutOfRange: "Projection target is not in the fit"
        case .valueClamped(let typeID, let value): "\(name(typeID)): \(value) adjusted"
        }
    }

    private func describe(_ warning: ImportWarning) -> String {
        switch warning {
        case .unknownType(let name): "Unknown item: \(name)"
        case .unknownTypeID(let typeID): "Unknown type ID: \(typeID.rawValue)"
        case .malformedLine(let line): "Unrecognized line: \(line)"
        case .malformedHeader(let header): "Unrecognized fit header: \(header)"
        case .noFitsFound: "No fit found"
        case .droppedCargo(let typeID, let quantity): "Cargo ignored: \(name(typeID)) x\(quantity)"
        case .droppedUnfitted(let typeID): "Unfitted item ignored: \(name(typeID))"
        case .unboundCharge(let typeID): "Charge fits no module: \(name(typeID))"
        case .unknownMutaplasmid(let name): "Unknown mutaplasmid: \(name)"
        case .mutationRollsDropped(let typeID): "Mutation rolls lost: \(name(typeID))"
        case .unknownAttribute(let name): "Unknown attribute: \(name)"
        }
    }
}

// MARK: - Conversions from engine values

extension FitSummary.DamageProfile {
    init(_ vector: DamageVector) {
        self.init(em: vector.em, thermal: vector.thermal, kinetic: vector.kinetic, explosive: vector.explosive)
    }

    /// Resistance is the complement of the engine's resonance (damage multiplier).
    init(resistance resonance: DamageVector) {
        self.init(em: 1 - resonance.em,
                  thermal: 1 - resonance.thermal,
                  kinetic: 1 - resonance.kinetic,
                  explosive: 1 - resonance.explosive)
    }
}

extension FitSummary.Repair {
    init(_ tank: DogmaKit.Tank) {
        self.init(passiveShield: tank.passiveShield,
                  shield: tank.shieldRepair,
                  armor: tank.armorRepair,
                  hull: tank.hullRepair)
    }
}

extension FitSummary.Layers {
    init(_ hitPoints: HitPoints) {
        self.init(shield: hitPoints.shield, armor: hitPoints.armor, hull: hitPoints.hull)
    }
}

extension FitSummary.Usage {
    init(_ resource: Resource) {
        self.init(used: resource.used, total: resource.total)
    }
}
