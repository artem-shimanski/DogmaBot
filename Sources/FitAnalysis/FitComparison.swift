//
//  FitComparison.swift
//  FitAnalysis
//

/// Two fits side by side: the stats that matter for choosing between them.
public struct FitComparison: Sendable, Equatable {

    public enum Side: Sendable, Equatable {
        case a, b
    }

    /// How a value reads, for formatting.
    public enum Kind: Sendable, Equatable {
        case number
        case duration
        case distance
    }

    public struct Row: Sendable, Equatable {
        public var label: String
        public var a: Double
        public var b: Double
        public var kind: Kind
        /// Whether a larger value is the better one; `false` for align time, signature and the like.
        public var higherIsBetter: Bool

        public init(label: String, a: Double, b: Double, kind: Kind = .number, higherIsBetter: Bool = true) {
            self.label = label
            self.a = a
            self.b = b
            self.kind = kind
            self.higherIsBetter = higherIsBetter
        }

        /// Change from `a` to `b`, relative to `a`; `nil` when `a` is zero.
        public var change: Double? {
            a == 0 ? nil : (b - a) / abs(a)
        }

        /// The side with the better value; `nil` on a tie.
        public var better: Side? {
            guard a != b else { return nil }
            return (b > a) == higherIsBetter ? .b : .a
        }
    }

    public var a: FitSummary
    public var b: FitSummary

    public init(_ a: FitSummary, _ b: FitSummary) {
        self.a = a
        self.b = b
    }

    public var rows: [Row] {
        func row(_ label: String,
                 _ kind: Kind = .number,
                 higherIsBetter: Bool = true,
                 _ value: (FitSummary) -> Double) -> Row {
            Row(label: label, a: value(a), b: value(b), kind: kind, higherIsBetter: higherIsBetter)
        }
        return [
            row("DPS") { $0.damage.dps.total },
            row("Volley") { $0.damage.volley.total },
            row("EHP") { $0.defense.effectiveHitPoints.total },
            row("Tank peak") { $0.tank.peak.total },
            row("Tank sust") { $0.tank.sustained.total },
            row("Speed") { $0.navigation.maxVelocity },
            row("Align", .duration, higherIsBetter: false) { $0.navigation.alignTime },
            row("Signature", .distance, higherIsBetter: false) { $0.navigation.signatureRadius },
            row("Lock range", .distance) { $0.targeting.maxTargetRange },
            row("Scan res") { $0.targeting.scanResolution },
            row("CPU free") { $0.fitting.cpu.total - $0.fitting.cpu.used },
            row("PG free") { $0.fitting.powerGrid.total - $0.fitting.powerGrid.used }
        ]
    }
}
