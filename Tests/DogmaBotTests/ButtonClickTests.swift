//
//  ButtonClickTests.swift
//  DogmaBotTests
//

import DiscordBM
import Foundation
import NIOCore
import Testing
@testable import DogmaBot

@Suite("ButtonClick")
struct ButtonClickTests {

    /// A click on a button inside a Components V2 message, as the gateway delivers it.
    private static let click = """
    {"op":0,"s":42,"t":"INTERACTION_CREATE","d":{
      "id":"1300000000000000001","application_id":"1300000000000000002","type":3,"token":"interaction-token",
      "version":1,"channel_id":"1300000000000000003","locale":"en-US","app_permissions":"0",
      "entitlements":[],"authorizing_integration_owners":{},"attachment_size_limit":10485760,
      "user":{"id":"1300000000000000004","username":"pilot","discriminator":"0","avatar":null,"global_name":null},
      "data":{"custom_id":"eft","component_type":2},
      "message":{"id":"1300000000000000005","channel_id":"1300000000000000003","type":20,"content":"",
        "flags":32768,"timestamp":"2026-10-26T10:00:00.000000+00:00","edited_timestamp":null,"tts":false,
        "mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,
        "author":{"id":"1300000000000000002","username":"DogmaBot","discriminator":"0","avatar":null,"bot":true},
        "components":[{"type":17,"id":1,"components":[{"type":10,"id":2,"content":"## Compare"},
          {"type":9,"id":3,"components":[{"type":10,"id":4,"content":"**A** Rifter"}],
           "accessory":{"type":11,"id":5,"media":{"url":"https://images.evetech.net/types/587/render?size=128&eft=A",
             "proxy_url":"https://images-ext-1.discordapp.net/x","width":128,"height":128,"content_type":"image/jpeg"}}},
          {"type":9,"id":6,"components":[{"type":10,"id":7,"content":"-# Both fits"}],
           "accessory":{"type":2,"id":8,"style":2,"label":"Show EFT","custom_id":"eft"}}]}]}
    }}
    """

    private static func buffer(_ text: String) -> ByteBuffer {
        ByteBuffer(bytes: Array(text.utf8))
    }

    @Test("DiscordBM cannot decode a click on a Components V2 message")
    func discordBMFails() {
        let error = #expect(throws: (any Error).self) {
            try DiscordGlobalConfiguration.decoder.decode(Gateway.Event.self, from: Data(Self.click.utf8))
        }
        #expect(String(describing: error).contains("unexpectedComponentKind"))
    }

    @Test("The click is read from the raw payload")
    func parsed() throws {
        let click = try #require(ButtonClick(Self.buffer(Self.click)))

        #expect(click.id == InteractionSnowflake("1300000000000000001"))
        #expect(click.token == "interaction-token")
        #expect(click.customID == "eft")
        #expect(click.mediaURLs == ["https://images.evetech.net/types/587/render?size=128&eft=A"])
    }

    @Test("Other events are not taken for clicks")
    func otherEvents() {
        let command = Self.click.replacingOccurrences(of: #""type":3"#, with: #""type":2"#)
        let other = #"{"op":0,"s":1,"t":"MESSAGE_CREATE","d":{"id":"1"}}"#

        #expect(ButtonClick(Self.buffer(command)) == nil)
        #expect(ButtonClick(Self.buffer(other)) == nil)
        #expect(ButtonClick(Self.buffer("not json")) == nil)
    }
}
