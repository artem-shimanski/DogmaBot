//
//  InteractionHandler.swift
//  DogmaBot
//

import DiscordBM
import FitAnalysis

struct InteractionHandler: GatewayEventHandler {
    let event: Gateway.Event
    let client: any DiscordClient
    let analyzer: FitAnalyzer

    func onInteractionCreate(_ interaction: Interaction) async throws {
        switch interaction.data {
        case .applicationCommand(let command):
            switch command.name {
            case Commands.fit:
                try await respond(to: interaction, with: .modal(Commands.fitModal))
            case Commands.analyzeFit:
                // The resolved data of a message command holds exactly the target message.
                let text = command.resolved?.messages?.values.first?.content ?? ""
                try await analyze(text, for: interaction)
            default:
                break
            }
        case .modalSubmit(let submit) where submit.custom_id == Commands.fitModalID:
            try await analyze(submit.components.textValue(of: Commands.fitTextID) ?? "", for: interaction)
        default:
            break
        }
    }

    /// Calculation takes milliseconds, so the result is sent as the initial response rather than deferred.
    private func analyze(_ text: String, for interaction: Interaction) async throws {
        let analysis: FitAnalysis
        do {
            analysis = try await analyzer.analyze(text)
        } catch .noFitFound {
            try await reject(interaction, "No fit found. Paste a fit in EFT, DNA or in-game XML format.")
            return
        } catch .rejected(let reason) {
            try await reject(interaction, "The fit cannot be calculated: \(reason)")
            return
        }
        let response = ComponentsResponse(components: FitCard.components(for: analysis))
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
