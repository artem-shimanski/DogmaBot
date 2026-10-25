//
//  Commands.swift
//  DogmaBot
//

import DiscordBM

/// Application commands of the bot and the identifiers of their components.
enum Commands {

    /// Slash command that opens a modal for pasting a fit.
    static let fit = "fit"
    /// Message context menu command that analyzes the fit in the selected message.
    static let analyzeFit = "Analyze fit"

    static let fitModalID = "fit-modal"
    static let fitTextID = "fit-text"

    /// Usable on servers, in DMs with the bot and, when installed to a user account, in any chat.
    private static let contexts: [Interaction.ContextKind] = [.guild, .botDm, .privateChannel]
    private static let integrationTypes: [DiscordApplication.IntegrationKind] = [.guildInstall, .userInstall]

    static let all: [Payloads.ApplicationCommandCreate] = [
        .init(name: fit,
              description: "Calculate the stats of a fit (EFT, DNA or in-game XML)",
              type: .chatInput,
              integration_types: integrationTypes,
              contexts: contexts),
        .init(name: analyzeFit,
              type: .message,
              integration_types: integrationTypes,
              contexts: contexts)
    ]

    static let fitModal = Payloads.InteractionResponse.Modal(
        custom_id: fitModalID,
        title: "Analyze fit",
        textInputs: [
            .init(custom_id: fitTextID,
                  style: .paragraph,
                  label: "Fit",
                  min_length: 1,
                  max_length: 4_000,
                  required: true,
                  placeholder: "[Rifter, My fit]\nDamage Control II\n…")
        ]
    )

    static func register(on client: any DiscordClient, guildID: GuildSnowflake?) async throws {
        if let guildID {
            try await client.bulkSetGuildApplicationCommands(guildId: guildID, payload: all).guardSuccess()
        } else {
            try await client.bulkSetApplicationCommands(payload: all).guardSuccess()
        }
    }
}
