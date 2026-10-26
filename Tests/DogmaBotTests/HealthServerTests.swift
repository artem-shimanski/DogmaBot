//
//  HealthServerTests.swift
//  DogmaBotTests
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NIOCore
import Testing
@testable import DogmaBot

@Suite("HealthServer")
struct HealthServerTests {

    private func status(_ method: String, _ path: String, port: Int) async throws -> (Int, String) {
        var request = URLRequest(url: try #require(URL(string: "http://127.0.0.1:\(port)\(path)")))
        request.httpMethod = method
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = try #require(response as? HTTPURLResponse).statusCode
        return (code, String(decoding: data, as: UTF8.self))
    }

    @Test("Health checks answer 200, other requests 404")
    func responses() async throws {
        let channel = try await HealthServer.start(host: "127.0.0.1", port: 0)
        defer { channel.close(promise: nil) }
        let port = try #require(channel.localAddress?.port)

        #expect(try await status("GET", "/health", port: port) == (200, "OK\n"))
        #expect(try await status("GET", "/?from=cron", port: port) == (200, "OK\n"))
        #expect(try await status("HEAD", "/health", port: port) == (200, ""))
        #expect(try await status("GET", "/interactions", port: port).0 == 404)
        #expect(try await status("POST", "/health", port: port).0 == 404)
    }
}
