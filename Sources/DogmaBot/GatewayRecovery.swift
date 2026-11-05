//
//  GatewayRecovery.swift
//  DogmaBot
//

import DiscordBM
import Foundation

/// Recovers interactions that DiscordBM cannot decode.
///
/// DiscordBM 1.16 decodes message components only as action rows, so an interaction that carries
/// a Components V2 message (a container or a text display at the top level), such as the target of
/// a message command, fails to decode and is never answered. The bot reads only the content of these
/// messages, so their components are dropped and the event is decoded again.
enum GatewayRecovery {

    static func event(from data: Data) -> Gateway.Event? {
        guard var payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              payload["t"] as? String == "INTERACTION_CREATE",
              var interaction = payload["d"] as? [String: Any] else {
            return nil
        }
        if let message = interaction["message"] {
            interaction["message"] = withoutComponents(message)
        }
        // Only messages are touched: the components of a modal submit in `data` are its input.
        if var command = interaction["data"] as? [String: Any],
           var resolved = command["resolved"] as? [String: Any],
           let messages = resolved["messages"] as? [String: Any] {
            resolved["messages"] = messages.mapValues(withoutComponents)
            command["resolved"] = resolved
            interaction["data"] = command
        }
        payload["d"] = interaction
        guard let sanitized = try? JSONSerialization.data(withJSONObject: payload) else {
            return nil
        }
        return try? DiscordGlobalConfiguration.decoder.decode(Gateway.Event.self, from: sanitized)
    }

    /// The message without components, including the messages it replies to or forwards.
    private static func withoutComponents(_ value: Any) -> Any {
        guard var message = value as? [String: Any] else { return value }
        message["components"] = nil
        if let referenced = message["referenced_message"] {
            message["referenced_message"] = withoutComponents(referenced)
        }
        if let snapshots = message["message_snapshots"] as? [Any] {
            message["message_snapshots"] = snapshots.map { value -> Any in
                guard var snapshot = value as? [String: Any], let inner = snapshot["message"] else { return value }
                snapshot["message"] = withoutComponents(inner)
                return snapshot
            }
        }
        return message
    }
}
