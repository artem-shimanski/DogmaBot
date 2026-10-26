//
//  ButtonClick.swift
//  DogmaBot
//

import DiscordBM
import Foundation
import NIOCore

/// A button click read from a raw gateway payload.
///
/// A click arrives with the message it belongs to, and DiscordBM 1.16 cannot decode a Components V2 message:
/// it expects only action rows at the top level, so the whole event fails to decode and lands in `eventFailures`.
/// Only the fields needed to answer the click are read here.
struct ButtonClick: Sendable {

    let id: InteractionSnowflake
    let token: String
    let customID: String
    /// URLs of every image in the message (thumbnails, galleries), in layout order.
    let mediaURLs: [String]

    private struct Payload: Decodable {
        var t: String?
        var d: Interaction?
    }

    private struct Interaction: Decodable {
        var id: InteractionSnowflake
        var token: String
        var type: Int
        var data: ComponentData?
        var message: Message?
    }

    private struct ComponentData: Decodable {
        var custom_id: String?
    }

    private struct Message: Decodable {
        var components: [Component]?
    }

    /// Any message component; only the fields that can hold or nest media are read.
    private struct Component: Decodable {
        var media: Media?
        var items: [Item]?
        var components: [Component]?
        var component: Box?
        var accessory: Box?

        /// Breaks the recursion of a single nested component.
        final class Box: Decodable {
            let value: Component

            init(from decoder: any Decoder) throws {
                value = try Component(from: decoder)
            }
        }

        struct Media: Decodable {
            var url: String
        }

        /// A media gallery item.
        struct Item: Decodable {
            var media: Media
        }

        var mediaURLs: [String] {
            [media?.url].compactMap { $0 } + (items ?? []).map(\.media.url)
                + (components ?? []).flatMap(\.mediaURLs)
                + [component, accessory].compactMap { $0?.value.mediaURLs }.flatMap { $0 }
        }
    }

    /// https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-object-interaction-type
    private static let messageComponentType = 3

    init?(_ buffer: ByteBuffer) {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(buffer.readableBytesView)),
              payload.t == "INTERACTION_CREATE",
              let interaction = payload.d,
              interaction.type == Self.messageComponentType,
              let customID = interaction.data?.custom_id
        else { return nil }
        self.id = interaction.id
        self.token = interaction.token
        self.customID = customID
        self.mediaURLs = interaction.message?.components?.flatMap(\.mediaURLs) ?? []
    }

    /// URLs of every image in message components encoded as JSON.
    static func mediaURLs(inComponents json: Data) -> [String] {
        (try? JSONDecoder().decode([Component].self, from: json))?.flatMap(\.mediaURLs) ?? []
    }
}
