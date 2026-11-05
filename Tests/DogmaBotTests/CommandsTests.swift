//
//  CommandsTests.swift
//  DogmaBotTests
//

import DiscordBM
import Foundation
import Testing
@testable import DogmaBot

@Suite("Commands")
struct CommandsTests {

    @Test("/fit subcommands each take one required option")
    func fitSubcommands() throws {
        let fit = try #require(Commands.all.first { $0.name == Commands.fit })
        let subcommands = try #require(fit.options)
        #expect(subcommands.map(\.name) == [Commands.fitText, Commands.fitFile])
        #expect(subcommands.allSatisfy { $0.type == .subCommand && $0.description.count <= 100 })
        let options = subcommands.map { $0.options ?? [] }
        #expect(options[0].map(\.name) == [Commands.fitTextOption])
        #expect(options[1].map(\.name) == [Commands.fitFileOption])
        #expect(options.joined().allSatisfy { $0.required == true && $0.description.count <= 100 })
    }

    @Test("The Analyze fit help names registered /fit subcommands")
    func analyzeFitHelp() throws {
        let fit = try #require(Commands.all.first { $0.name == Commands.fit })
        for subcommand in fit.options ?? [] {
            #expect(Commands.analyzeFitHelp.contains("`/\(fit.name) \(subcommand.name)`"))
        }
        #expect(Commands.all.contains { $0.name == Commands.analyzeFit && $0.type == .message })
        #expect(Commands.analyzeFitHelp.count <= 2000)
    }

    @Test("The correcting modal keeps the fit id and prefills the text")
    func correctingModal() throws {
        let text = "587:not-a-fit"
        let modal = Commands.fitModal(correcting: text)
        let json = String(decoding: try JSONEncoder().encode(modal), as: UTF8.self)
        #expect(modal.custom_id == Commands.fitModalID)
        #expect(modal.title.count <= 45)
        #expect(json.contains("\"value\":\"\(text)\""))
        #expect(json.contains("\"custom_id\":\"\(Commands.fitTextID)\""))
    }
}
