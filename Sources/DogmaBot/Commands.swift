//
//  Commands.swift
//  DogmaBot
//

import DiscordBM

/// Application commands of the bot and the identifiers of their components.
enum Commands {

    /// Slash command group for a single fit; each subcommand takes the fit its own way.
    static let fit = "fit"
    /// `/fit text`: a fit pasted into the required option; the option keeps line breaks, so any format works.
    static let fitText = "text"
    /// `/fit file`: a file holding a fit in any supported format.
    static let fitFile = "file"
    static let fitTextOption = "fit"
    static let fitFileOption = "file"
    /// Slash command that opens a modal for pasting two fits.
    static let compare = "compare"
    /// Message context menu command that analyzes the fit in the selected message.
    static let analyzeFit = "Analyze fit"
    /// Reply to `analyzeFit` on a message without a fit, such as a card of the bot: what the command reads
    /// and where to take other fits.
    static let analyzeFitHelp = """
        No fit in this message. **\(analyzeFit)** reads a fit written in the message text: EFT, DNA or in-game XML.
        For a fit file use `/\(fit) \(fitFile)`, to paste a fit use `/\(fit) \(fitText)`.
        """

    static let fitModalID = "fit-modal"
    static let fitTextID = "fit-text"
    static let compareModalID = "compare-modal"
    static let compareTextIDs = ("compare-a", "compare-b")

    /// Usable on servers, in DMs with the bot and, when installed to a user account, in any chat.
    private static let contexts: [Interaction.ContextKind] = [.guild, .botDm, .privateChannel]
    private static let integrationTypes: [DiscordApplication.IntegrationKind] = [.guildInstall, .userInstall]

    static let all: [Payloads.ApplicationCommandCreate] = [
        .init(name: fit,
              description: "Calculate the stats of a fit (EFT, DNA or in-game XML)",
              options: [
                  .init(type: .subCommand,
                        name: fitText,
                        description: "Calculate a fit pasted as text (EFT, DNA or in-game XML)",
                        options: [
                            .init(type: .string,
                                  name: fitTextOption,
                                  description: "Fit in EFT, DNA or in-game XML format, or a fitting link copied from the game",
                                  required: true,
                                  max_length: 6_000)
                        ]),
                  .init(type: .subCommand,
                        name: fitFile,
                        description: "Calculate a fit from a file (EFT, DNA or in-game XML)",
                        options: [
                            .init(type: .attachment,
                                  name: fitFileOption,
                                  description: "Text file with a fit",
                                  required: true)
                        ])
              ],
              type: .chatInput,
              integration_types: integrationTypes,
              contexts: contexts),
        .init(name: compare,
              description: "Compare the stats of two fits",
              type: .chatInput,
              integration_types: integrationTypes,
              contexts: contexts),
        .init(name: analyzeFit,
              type: .message,
              integration_types: integrationTypes,
              contexts: contexts)
    ]

    /// Longest text a modal text input holds.
    static let modalTextLimit = 4_000

    static let fitModal = Payloads.InteractionResponse.Modal(
        custom_id: fitModalID,
        title: "Analyze fit",
        textInputs: [fitInput(id: fitTextID, label: "Fit")]
    )

    /// The fit modal prefilled with text in which no fit was found, so the user can correct it.
    /// The text must fit `modalTextLimit`.
    static func fitModal(correcting text: String) -> Payloads.InteractionResponse.Modal {
        .init(custom_id: fitModalID,
              title: "No fit found, check the text",
              textInputs: [fitInput(id: fitTextID, label: "Fit", value: text)])
    }

    static let compareModal = Payloads.InteractionResponse.Modal(
        custom_id: compareModalID,
        title: "Compare fits",
        textInputs: [
            fitInput(id: compareTextIDs.0, label: "Fit A"),
            fitInput(id: compareTextIDs.1, label: "Fit B")
        ]
    )

    private static func fitInput(id: String, label: String, value: String? = nil) -> Interaction.ActionRow.TextInput {
        .init(custom_id: id,
              style: .paragraph,
              label: label,
              min_length: 1,
              max_length: modalTextLimit,
              required: true,
              value: value,
              placeholder: "[Rifter, My fit]\nDamage Control II\n…")
    }

    static func register(on client: any DiscordClient, guildID: GuildSnowflake?) async throws {
        if let guildID {
            try await client.bulkSetGuildApplicationCommands(guildId: guildID, payload: all).guardSuccess()
        } else {
            try await client.bulkSetApplicationCommands(payload: all).guardSuccess()
        }
    }
}
