//
//  ComponentsResponse.swift
//  DogmaBot
//

import DiscordBM

/// An interaction response with a Components V2 message.
///
/// DiscordBM puts every top-level message component into an action row, while a Components V2 message holds
/// layout components (containers, sections, text displays) at the top level, so the payload is encoded here.
struct ComponentsResponse: Sendable, Encodable, ValidatablePayload {

    var components: [Interaction.ActionRow.Component]

    /// https://discord.com/developers/docs/resources/message#message-object-message-flags
    private static let componentsV2Flag = 1 << 15

    /// https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-interaction-callback-type
    private static let channelMessageWithSource = 4

    private enum CodingKeys: String, CodingKey {
        case type, data
    }

    private enum DataKeys: String, CodingKey {
        case flags, components
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.channelMessageWithSource, forKey: .type)
        var data = container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        try data.encode(Self.componentsV2Flag, forKey: .flags)
        try data.encode(components, forKey: .components)
    }

    func validate() -> [ValidationFailure] {
        return components.validate()
    }
}

extension DiscordClient {

    func createInteractionResponse(id: InteractionSnowflake,
                                   token: String,
                                   payload: ComponentsResponse) async throws -> DiscordHTTPResponse {
        let endpoint = APIEndpoint.createInteractionResponse(interactionId: id, interactionToken: token)
        return try await send(request: .init(to: endpoint), payload: payload)
    }
}
