//
//  GatewayRecoveryTests.swift
//  DogmaBotTests
//

import DiscordBM
import Foundation
import Testing
@testable import DogmaBot

@Suite("GatewayRecovery")
struct GatewayRecoveryTests {

    /// A message command interaction as the gateway sends it, targeting a message with the given components.
    static func messageCommand(components: String, extra: String = "") -> Data {
        Data("""
        {"op":0,"s":5,"t":"INTERACTION_CREATE","d":{
          "id":"1300000000000000001","application_id":"1300000000000000002","type":2,
          "token":"token","version":1,"channel_id":"1300000000000000003","guild_id":"1300000000000000004",
          "app_permissions":"0","locale":"en-US","entitlements":[],
          "authorizing_integration_owners":{"0":"1300000000000000004"},
          "member":{"user":{"id":"1300000000000000005","username":"pilot","discriminator":"0","avatar":null},
            "roles":[],"joined_at":"2024-01-01T00:00:00.000000+00:00","deaf":false,"mute":false,"flags":0,
            "permissions":"0"},
          "data":{"id":"1300000000000000006","name":"Analyze fit","type":3,"target_id":"1300000000000000007",
            "resolved":{"messages":{"1300000000000000007":{
              "id":"1300000000000000007","channel_id":"1300000000000000003","type":0,"content":"[Rifter, Test]",
              "author":{"id":"1300000000000000008","username":"bot","discriminator":"0","avatar":null,"bot":true},
              "attachments":[],"embeds":[],"mentions":[],"mention_roles":[],"pinned":false,
              "mention_everyone":false,"tts":false,"timestamp":"2026-11-05T10:00:00.000000+00:00",
              "edited_timestamp":null,"flags":32768,"components":\(components)\(extra)}}}}}}
        """.utf8)
    }

    /// Components of a bot card: a container at the top level.
    static let card = """
        [{"type":17,"id":1,"components":[{"type":10,"id":2,"content":"## Rifter"}]}]
        """

    static func targetContent(of event: Gateway.Event) -> String? {
        guard case .interactionCreate(let interaction) = event.data,
              case .applicationCommand(let command) = interaction.data,
              command.name == "Analyze fit" else {
            return nil
        }
        return command.resolved?.messages?.values.first?.content
    }

    @Test("A target message without Components V2 decodes as is")
    func plainMessage() throws {
        let data = Self.messageCommand(components: "[]")
        let event = try DiscordGlobalConfiguration.decoder.decode(Gateway.Event.self, from: data)
        #expect(Self.targetContent(of: event) == "[Rifter, Test]")
    }

    @Test("A Components V2 target message is recovered with its content")
    func componentsV2() throws {
        let data = Self.messageCommand(components: Self.card)
        #expect(throws: (any Error).self) {
            try DiscordGlobalConfiguration.decoder.decode(Gateway.Event.self, from: data)
        }
        let event = try #require(GatewayRecovery.event(from: data))
        #expect(Self.targetContent(of: event) == "[Rifter, Test]")
    }

    @Test("A reply to a Components V2 message is recovered with its content")
    func replyToComponentsV2() throws {
        let data = Self.messageCommand(components: "[]", extra: """
            ,"message_reference":{"type":0,"message_id":"1300000000000000009","channel_id":"1300000000000000003"},
            "referenced_message":{"id":"1300000000000000009","channel_id":"1300000000000000003","type":20,
              "content":"","author":{"id":"1300000000000000002","username":"DogmaBot","discriminator":"0",
                "avatar":null,"bot":true},
              "attachments":[],"embeds":[],"mentions":[],"mention_roles":[],"pinned":false,
              "mention_everyone":false,"tts":false,"timestamp":"2026-11-05T09:00:00.000000+00:00",
              "edited_timestamp":null,"flags":32768,"components":\(Self.card)}
            """)
        #expect(throws: (any Error).self) {
            try DiscordGlobalConfiguration.decoder.decode(Gateway.Event.self, from: data)
        }
        let event = try #require(GatewayRecovery.event(from: data))
        #expect(Self.targetContent(of: event) == "[Rifter, Test]")
    }

    @Test("Events other than interactions are not recovered")
    func otherEvents() {
        #expect(GatewayRecovery.event(from: Data(#"{"op":0,"s":1,"t":"MESSAGE_CREATE","d":{}}"#.utf8)) == nil)
    }
}
