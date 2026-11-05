//
//  InteractionHandler.swift
//  DogmaBot
//

import DiscordBM
import Foundation
import FitAnalysis

struct InteractionHandler: GatewayEventHandler {
    let event: Gateway.Event
    let client: any DiscordClient
    let analyzer: FitAnalyzer
    /// Address of the fit page; cards link to each fit there.
    let webPage: String

    func onInteractionCreate(_ interaction: Interaction) async throws {
        switch interaction.data {
        case .applicationCommand(let command):
            switch command.name {
            case Commands.fit:
                try await fit(command, for: interaction)
            case Commands.compare:
                try await respond(to: interaction, with: .modal(Commands.compareModal))
            case Commands.analyzeFit:
                // The resolved data of a message command holds exactly the target message.
                let text = command.resolved?.messages?.values.first?.content ?? ""
                try await analyze(text, for: interaction)
            default:
                break
            }
        case .modalSubmit(let submit) where submit.custom_id == Commands.fitModalID:
            try await analyze(submit.components.textValue(of: Commands.fitTextID) ?? "", for: interaction)
        case .modalSubmit(let submit) where submit.custom_id == Commands.compareModalID:
            try await compare(submit.components.textValue(of: Commands.compareTextIDs.0) ?? "",
                              submit.components.textValue(of: Commands.compareTextIDs.1) ?? "",
                              for: interaction)
        default:
            break
        }
    }

    /// Runs a `/fit` subcommand: `text` and `file` analyze the fit they carry.
    /// Anything else, such as a client that still has `/fit` without subcommands cached, gets the fit modal,
    /// so every invocation is answered.
    private func fit(_ command: Interaction.ApplicationCommand, for interaction: Interaction) async throws {
        let subcommand = command.options?.first
        let text: String
        if subcommand?.name == Commands.fitText,
           let option = try? subcommand?.option(named: Commands.fitTextOption)?.requireString() {
            text = option
        } else if subcommand?.name == Commands.fitFile,
                  let id = try? subcommand?.option(named: Commands.fitFileOption)?.requireString(),
                  let attachment = command.resolved?.attachments?[AttachmentSnowflake(id)] {
            do {
                text = try await AttachmentText.load(attachment)
            } catch .tooLarge {
                try await reject(interaction, "The file is too large for a fit.")
                return
            } catch .unreadable {
                try await reject(interaction, "Cannot read the file. Try again or paste the fit with /fit text.")
                return
            }
        } else {
            try await respond(to: interaction, with: .modal(Commands.fitModal))
            return
        }
        try await analyze(text, for: interaction, correctable: true)
    }

    /// Calculation takes milliseconds, so the result is sent as the initial response rather than deferred.
    /// When `correctable`, text without a fit reopens in the fit modal for the user to fix it.
    private func analyze(_ text: String, for interaction: Interaction, correctable: Bool = false) async throws {
        let analysis: FitAnalysis
        do {
            analysis = try await analyzer.analyze(text)
        } catch .noFitFound {
            if correctable, text.utf16.count <= Commands.modalTextLimit {
                try await respond(to: interaction, with: .modal(Commands.fitModal(correcting: text)))
            } else {
                try await reject(interaction, "No fit found. Paste a fit in EFT, DNA or in-game XML format.")
            }
            return
        } catch .rejected(let reason) {
            try await reject(interaction, "The fit cannot be calculated: \(reason)")
            return
        }
        let response = ComponentsResponse(components: FitCard.components(for: analysis, webPage: webPage))
        try await client.createInteractionResponse(id: interaction.id, token: interaction.token, payload: response)
            .guardSuccess()
    }

    /// Compares the first fit of each text.
    private func compare(_ textA: String, _ textB: String, for interaction: Interaction) async throws {
        var fits: [FitSummary] = []
        for (side, text) in [("A", textA), ("B", textB)] {
            do {
                let analysis = try await analyzer.analyze(text)
                fits.append(analysis.fits[0])
            } catch .noFitFound {
                try await reject(interaction, "Fit \(side): no fit found. Paste a fit in EFT, DNA or in-game XML format.")
                return
            } catch .rejected(let reason) {
                try await reject(interaction, "Fit \(side) cannot be calculated: \(reason)")
                return
            }
        }
        let comparison = FitComparison(fits[0], fits[1])
        let response = ComponentsResponse(components: CompareCard.components(for: comparison, webPage: webPage))
        try await client.createInteractionResponse(id: interaction.id, token: interaction.token, payload: response)
            .guardSuccess()
    }

    /// Errors are visible to the invoking user only.
    private func reject(_ interaction: Interaction, _ reason: String) async throws {
        try await respond(to: interaction, with: .channelMessageWithSource(.init(content: reason, flags: [.ephemeral])))
    }

    private func respond(to interaction: Interaction, with response: Payloads.InteractionResponse) async throws {
        try await client.createInteractionResponse(id: interaction.id, token: interaction.token, payload: response)
            .guardSuccess()
    }
}

extension [Interaction.ActionRow] {

    /// Value of the text input with the given id, wherever the modal layout nests it.
    func textValue(of customID: String) -> String? {
        lazy.flatMap(\.components).compactMap { $0.textValue(of: customID) }.first
    }
}

extension Interaction.ActionRow.Component {

    func textValue(of customID: String) -> String? {
        switch self {
        case .textInput(let input) where input.custom_id == customID:
            input.value
        case .label(let label):
            label.component.textValue(of: customID)
        default:
            nil
        }
    }
}
