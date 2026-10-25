//
//  FitCardTests.swift
//  DogmaBotTests
//

import Foundation
import Testing
import FitAnalysis
@testable import DogmaBot

@Suite("FitCard")
struct FitCardTests {

    private static let rifter = """
    [Rifter, *Brawl* [test]]
    Damage Control II
    Gyrostabilizer II

    Stasis Webifier II
    1MN Afterburner II

    200mm AutoCannon II, EMP S
    200mm AutoCannon II, EMP S
    200mm AutoCannon II, EMP S

    Hobgoblin II x2
    """

    /// A large fit with repairers, so every section of the card is present.
    private static let dominix = """
    [Dominix, Armor Drone Boat]
    Large Armor Repairer II
    Large Armor Repairer II
    Multispectrum Energized Membrane II
    Multispectrum Energized Membrane II
    Damage Control II
    Drone Damage Amplifier II
    Drone Damage Amplifier II

    Large Cap Battery II
    Large Cap Battery II
    Omnidirectional Tracking Link II
    Omnidirectional Tracking Link II
    500MN Microwarpdrive II

    Neutron Blaster Cannon II, Void L
    Neutron Blaster Cannon II, Void L
    Neutron Blaster Cannon II, Void L
    Neutron Blaster Cannon II, Void L
    Neutron Blaster Cannon II, Void L
    Neutron Blaster Cannon II, Void L

    Large Auxiliary Nano Pump II
    Large Nanobot Accelerator II
    Large Trimark Armor Pump II

    Ogre II x5
    Hammerhead II x5
    """

    private func response(_ text: String) async throws -> [String: Any] {
        let analysis = try await FitAnalyzer().analyze(text)
        let data = try JSONEncoder().encode(ComponentsResponse(components: FitCard.components(for: analysis)))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("The response is a Components V2 message with a container per fit")
    func layout() async throws {
        let json = try await response(Self.rifter)
        let data = try #require(json["data"] as? [String: Any])
        let flags = try #require(data["flags"] as? Int)
        let components = try #require(data["components"] as? [[String: Any]])

        #expect(json["type"] as? Int == 4)
        #expect(flags & (1 << 15) != 0)
        #expect(flags & (1 << 6) == 0)
        #expect(components.first?["type"] as? Int == 17)
        #expect(components.dropFirst().allSatisfy { $0["type"] as? Int == 10 })
    }

    @Test("Several fits stay within the message limits of 40 components and 4000 characters")
    func limits() async throws {
        let text = Array(repeating: Self.dominix + "\nFoo Bar", count: FitCard.maxFits + 2).joined(separator: "\n\n")
        let json = try await response(text)
        let data = try #require(json["data"] as? [String: Any])

        var count = 0
        var characters = 0
        func walk(_ value: Any) {
            if let object = value as? [String: Any] {
                if object["type"] != nil { count += 1 }
                if let content = object["content"] as? String { characters += content.count }
                object.values.forEach(walk)
            } else if let array = value as? [Any] {
                array.forEach(walk)
            }
        }
        walk(data["components"] as Any)

        #expect(count <= 40)
        #expect(characters <= 4_000)
    }

    @Test("Markdown in the fit name is escaped")
    func escapedName() async throws {
        let analysis = try await FitAnalyzer().analyze(Self.rifter)
        let data = try JSONEncoder().encode(FitCard.card(for: try #require(analysis.fits.first)))
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains(#"\\*Brawl\\*"#))
    }
}
