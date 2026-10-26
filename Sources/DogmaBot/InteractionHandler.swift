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
    /// Address of the fit page, or `nil` to leave the link out.
    let webPage: String?

    func onInteractionCreate(_ interaction: Interaction) async throws {
        switch interaction.data {
        case .applicationCommand(let command):
            switch command.name {
            case Commands.fit:
                try await respond(to: interaction, with: .modal(Commands.fitModal))
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
        case .messageComponent(let component):
            let components = try JSONEncoder().encode(interaction.message?.components ?? [])
            try await Self.handleClick(customID: component.custom_id,
                                       mediaURLs: ButtonClick.mediaURLs(inComponents: components),
                                       id: interaction.id,
                                       token: interaction.token,
                                       client: client)
        case .modalSubmit(let submit) where submit.custom_id == Commands.compareModalID:
            try await compare(submit.components.textValue(of: Commands.compareTextIDs.0) ?? "",
                              submit.components.textValue(of: Commands.compareTextIDs.1) ?? "",
                              for: interaction)
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
        let response = ComponentsResponse(components: FitCard.components(for: analysis, webPage: webPage))
        try await client.createInteractionResponse(id: interaction.id, token: interaction.token, payload: response)
            .guardSuccess()
    }

    /// Compares the first fit of each text.
    private func compare(_ textA: String, _ textB: String, for interaction: Interaction) async throws {
        var fits: [FitSummary] = []
        var notes: [String] = []
        for (side, text) in [("A", textA), ("B", textB)] {
            do {
                let analysis = try await analyzer.analyze(text)
                fits.append(analysis.fits[0])
                notes += analysis.warnings.map { "\(side): \($0)" }
            } catch .noFitFound {
                try await reject(interaction, "Fit \(side): no fit found. Paste a fit in EFT, DNA or in-game XML format.")
                return
            } catch .rejected(let reason) {
                try await reject(interaction, "Fit \(side) cannot be calculated: \(reason)")
                return
            }
        }
        let comparison = FitComparison(fits[0], fits[1])
        let response = ComponentsResponse(components: CompareCard.components(for: comparison, notes: notes))
        try await client.createInteractionResponse(id: interaction.id, token: interaction.token, payload: response)
            .guardSuccess()
    }

    /// Answers a button click. Clicks on Components V2 messages bypass the decoded event stream (see `ButtonClick`),
    /// so this is reachable without an `Interaction`.
    /// - Parameter mediaURLs: image URLs of the message the button belongs to; they carry the fits.
    static func handleClick(customID: String,
                            mediaURLs: [String],
                            id: InteractionSnowflake,
                            token: String,
                            client: any DiscordClient) async throws {
        guard customID == CompareCard.eftButtonID else { return }
        let fits = FitLink.fits(in: mediaURLs)
        guard !fits.isEmpty else {
            let message = Payloads.InteractionResponse.Message(content: "No fits found in this card.",
                                                               flags: [.ephemeral])
            try await client.createInteractionResponse(id: id, token: token, payload: .channelMessageWithSource(message))
                .guardSuccess()
            return
        }
        let response = ComponentsResponse(components: CompareCard.eftComponents(for: fits), isEphemeral: true)
        try await client.createInteractionResponse(id: id, token: token, payload: response).guardSuccess()
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
