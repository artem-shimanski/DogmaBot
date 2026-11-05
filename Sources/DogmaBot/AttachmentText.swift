//
//  AttachmentText.swift
//  DogmaBot
//

import AsyncHTTPClient
import DiscordBM
import Foundation
import NIOCore

/// Reads the text of a file attached to a command.
///
/// The download happens before the initial response, which may be a modal and so cannot be deferred;
/// the timeout leaves room for the response within the 3 seconds Discord allows.
enum AttachmentText {

    /// Largest file accepted; fits in any supported format are far smaller.
    static let sizeLimit = 256 * 1024
    static let timeout = TimeAmount.seconds(2)

    enum Failure: Error {
        case tooLarge
        case unreadable
    }

    static func load(_ attachment: DiscordChannel.Message.Attachment) async throws(Failure) -> String {
        guard attachment.size <= sizeLimit else { throw .tooLarge }
        do {
            let response = try await HTTPClient.shared.execute(HTTPClientRequest(url: attachment.url), timeout: timeout)
            guard response.status == .ok else { throw Failure.unreadable }
            let body = try await response.body.collect(upTo: sizeLimit)
            return String(decoding: body.readableBytesView, as: UTF8.self)
        } catch {
            throw .unreadable
        }
    }
}
