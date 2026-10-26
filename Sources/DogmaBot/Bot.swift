//
//  Bot.swift
//  DogmaBot
//
//  Environment:
//  - DISCORD_TOKEN: the bot token (required).
//  - DISCORD_GUILD_ID: registers commands on this server only; they update instantly, which suits development.
//    Without it commands are registered globally.
//  - DOGMA_WEB_URL: address of the fit page (required); cards link to it instead of printing the fits.
//

import DiscordBM
import FitAnalysis
import Foundation
import Logging

@main
struct Bot {

    static func main() async throws {
        let logger = Logger(label: "DogmaBot")
        let environment = ProcessInfo.processInfo.environment
        guard let token = environment["DISCORD_TOKEN"], !token.isEmpty else {
            logger.critical("DISCORD_TOKEN is not set")
            exit(1)
        }
        let guildID = environment["DISCORD_GUILD_ID"].flatMap { $0.isEmpty ? nil : GuildSnowflake($0) }

        guard let webPage = environment["DOGMA_WEB_URL"], !webPage.isEmpty else {
            logger.critical("DOGMA_WEB_URL is not set")
            exit(1)
        }
        let analyzer = try FitAnalyzer()
        // Interactions arrive without any intent; message content is read from the interaction itself.
        let bot = await BotGatewayManager(
            token: token,
            presence: .init(activities: [.init(name: "/fit", type: .listening)], status: .online, afk: false),
            intents: []
        )

        await withDiscardingTaskGroup { group in
            group.addTask {
                await bot.connect()
            }
            group.addTask {
                do {
                    try await Commands.register(on: bot.client, guildID: guildID)
                } catch {
                    logger.error("Cannot register commands", metadata: ["error": "\(error)"])
                }
            }
            group.addTask {
                for await (error, _) in await bot.eventFailures {
                    logger.warning("Cannot decode a gateway event", metadata: ["error": "\(error)"])
                }
            }
            for await event in await bot.events {
                group.addTask {
                    await InteractionHandler(event: event, client: bot.client, analyzer: analyzer, webPage: webPage)
                        .handleAsync()
                }
            }
        }
    }
}
