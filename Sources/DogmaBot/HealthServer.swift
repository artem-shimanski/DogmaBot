//
//  HealthServer.swift
//  DogmaBot
//

import NIOCore
import NIOHTTP1
import NIOPosix

/// A minimal HTTP server for hosting platforms that require the process to listen on a port.
///
/// The bot itself serves no HTTP: it reaches Discord over an outgoing gateway connection. Platforms such as Render
/// still expect a web service to answer on `$PORT`, and their free plans stop a service that receives no requests
/// for a while, so an external scheduler can keep it running by requesting `/health`. `GET` and `HEAD` on `/` and
/// `/health` answer 200 OK; anything else answers 404.
enum HealthServer {

    /// Binds the server and returns its channel; it serves until the channel is closed.
    static func start(host: String = "0.0.0.0",
                      port: Int,
                      group: any EventLoopGroup = MultiThreadedEventLoopGroup.singleton) async throws -> any Channel {
        try await ServerBootstrap(group: group)
            .serverChannelOption(.backlog, value: 64)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.configureHTTPServerPipeline()
                    try channel.pipeline.syncOperations.addHandler(HealthHandler())
                }
            }
            .bind(host: host, port: port)
            .get()
    }

    static let paths: Set<String> = ["/", "/health"]
}

private final class HealthHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private var head: HTTPRequestHead?

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            self.head = head
        case .body:
            break
        case .end:
            guard let head else { return }
            self.head = nil
            respond(to: head, context: context)
        }
    }

    private func respond(to request: HTTPRequestHead, context: ChannelHandlerContext) {
        let path = request.uri.split(separator: "?", maxSplits: 1).first.map(String.init) ?? request.uri
        let isHealthCheck = (request.method == .GET || request.method == .HEAD) && HealthServer.paths.contains(path)
        let status: HTTPResponseStatus = isHealthCheck ? .ok : .notFound
        let body = isHealthCheck ? "OK\n" : "Not Found\n"

        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
        headers.add(name: "Content-Length", value: String(body.utf8.count))
        if !request.isKeepAlive {
            headers.add(name: "Connection", value: "close")
        }
        context.write(wrapOutboundOut(.head(HTTPResponseHead(version: request.version, status: status, headers: headers))),
                      promise: nil)
        if request.method != .HEAD {
            context.write(wrapOutboundOut(.body(.byteBuffer(ByteBuffer(string: body)))), promise: nil)
        }
        let done = context.writeAndFlush(wrapOutboundOut(.end(nil)))
        if !request.isKeepAlive {
            let channel = context.channel
            done.whenComplete { _ in channel.close(promise: nil) }
        }
    }
}
