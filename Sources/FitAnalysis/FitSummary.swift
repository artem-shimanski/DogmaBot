//
//  FitSummary.swift
//  FitAnalysis
//

/// Stats of one fit as plain values, independent of the engine and of any presentation.
///
/// Units follow the game: meters, m/s, seconds, GJ, AU/s, millimeters for scan resolution.
public struct FitSummary: Sendable, Codable, Equatable {
    /// Fit name from the source text, if any.
    public var name: String?
    public var shipTypeID: UInt32
    public var shipName: String
    public var shipGroupName: String
    public var damage: Damage
    public var defense: Defense
    public var tank: Tank
    public var capacitor: Capacitor
    public var navigation: Navigation
    public var targeting: Targeting
    public var fitting: Fitting
    /// The fit as calculated, in EFT: what was recognized on import, in canonical order and naming.
    public var eft: String

    public init(name: String?,
                shipTypeID: UInt32,
                shipName: String,
                shipGroupName: String,
                damage: Damage,
                defense: Defense,
                tank: Tank,
                capacitor: Capacitor,
                navigation: Navigation,
                targeting: Targeting,
                fitting: Fitting,
                eft: String) {
        self.name = name
        self.shipTypeID = shipTypeID
        self.shipName = shipName
        self.shipGroupName = shipGroupName
        self.damage = damage
        self.defense = defense
        self.tank = tank
        self.capacitor = capacitor
        self.navigation = navigation
        self.targeting = targeting
        self.fitting = fitting
        self.eft = eft
    }
}

extension FitSummary {

    /// A value per damage type.
    public struct DamageProfile: Sendable, Codable, Equatable {
        public var em: Double
        public var thermal: Double
        public var kinetic: Double
        public var explosive: Double

        public init(em: Double, thermal: Double, kinetic: Double, explosive: Double) {
            self.em = em
            self.thermal = thermal
            self.kinetic = kinetic
            self.explosive = explosive
        }

        public var total: Double { em + thermal + kinetic + explosive }
    }

    /// A value per defense layer.
    public struct Layers: Sendable, Codable, Equatable {
        public var shield: Double
        public var armor: Double
        public var hull: Double

        public init(shield: Double, armor: Double, hull: Double) {
            self.shield = shield
            self.armor = armor
            self.hull = hull
        }

        public var total: Double { shield + armor + hull }
    }

    /// Raw damage with no tracking, range or missile application penalties.
    public struct Damage: Sendable, Codable, Equatable {
        public var dps: DamageProfile
        public var volley: DamageProfile

        public init(dps: DamageProfile, volley: DamageProfile) {
            self.dps = dps
            self.volley = volley
        }
    }

    public struct Defense: Sendable, Codable, Equatable {
        public var hitPoints: Layers
        /// Effective hit points against a uniform damage pattern.
        public var effectiveHitPoints: Layers
        /// Resistances per layer, 0…1.
        public var shieldResistances: DamageProfile
        public var armorResistances: DamageProfile
        public var hullResistances: DamageProfile

        public init(hitPoints: Layers,
                    effectiveHitPoints: Layers,
                    shieldResistances: DamageProfile,
                    armorResistances: DamageProfile,
                    hullResistances: DamageProfile) {
            self.hitPoints = hitPoints
            self.effectiveHitPoints = effectiveHitPoints
            self.shieldResistances = shieldResistances
            self.armorResistances = armorResistances
            self.hullResistances = hullResistances
        }
    }

    /// Repair rates, effective HP per second against a uniform damage pattern.
    public struct Repair: Sendable, Codable, Equatable {
        public var passiveShield: Double
        public var shield: Double
        public var armor: Double
        public var hull: Double

        public init(passiveShield: Double, shield: Double, armor: Double, hull: Double) {
            self.passiveShield = passiveShield
            self.shield = shield
            self.armor = armor
            self.hull = hull
        }

        public var total: Double { passiveShield + shield + armor + hull }
    }

    public struct Tank: Sendable, Codable, Equatable {
        /// Passive regeneration plus every repairer running at full rate.
        public var peak: Repair
        /// What the capacitor can keep running indefinitely; equals `peak` when the capacitor is stable.
        public var sustained: Repair

        public init(peak: Repair, sustained: Repair) {
            self.peak = peak
            self.sustained = sustained
        }
    }

    public struct Capacitor: Sendable, Codable, Equatable {
        public var capacity: Double
        public var rechargeTime: Double
        /// Stable charge level, 0…1; `nil` if the capacitor runs dry.
        public var stableLevel: Double?
        /// Time until the capacitor runs dry; `nil` if it is stable.
        public var lastsFor: Double?

        public init(capacity: Double, rechargeTime: Double, stableLevel: Double?, lastsFor: Double?) {
            self.capacity = capacity
            self.rechargeTime = rechargeTime
            self.stableLevel = stableLevel
            self.lastsFor = lastsFor
        }

        public var isStable: Bool { stableLevel != nil }
    }

    public struct Navigation: Sendable, Codable, Equatable {
        public var maxVelocity: Double
        public var alignTime: Double
        public var signatureRadius: Double
        public var warpSpeed: Double

        public init(maxVelocity: Double, alignTime: Double, signatureRadius: Double, warpSpeed: Double) {
            self.maxVelocity = maxVelocity
            self.alignTime = alignTime
            self.signatureRadius = signatureRadius
            self.warpSpeed = warpSpeed
        }
    }

    public struct Targeting: Sendable, Codable, Equatable {
        public var maxTargetRange: Double
        public var scanResolution: Double
        public var maxLockedTargets: Int

        public init(maxTargetRange: Double, scanResolution: Double, maxLockedTargets: Int) {
            self.maxTargetRange = maxTargetRange
            self.scanResolution = scanResolution
            self.maxLockedTargets = maxLockedTargets
        }
    }

    public struct Usage: Sendable, Codable, Equatable {
        public var used: Double
        public var total: Double

        public init(used: Double, total: Double) {
            self.used = used
            self.total = total
        }

        public var isOverloaded: Bool { used > total }
    }

    public struct Fitting: Sendable, Codable, Equatable {
        public var cpu: Usage
        public var powerGrid: Usage
        public var calibration: Usage

        public init(cpu: Usage, powerGrid: Usage, calibration: Usage) {
            self.cpu = cpu
            self.powerGrid = powerGrid
            self.calibration = calibration
        }
    }
}
