import Foundation

class OpenClawService {
    private var webSocket: URLSessionWebSocketTask?
    private var messageId = 0
    private var isConnectedInternal = false

    func connect(channel: Channel) async throws {
        guard let host = channel.host, let port = channel.port, let token = channel.token else {
            throw OpenClawError.invalidURL
        }
        guard let url = URL(string: "ws://\(host):\(port)") else {
            throw OpenClawError.invalidURL
        }

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        // Send connect handshake
        let connectParams = ConnectParams(
            client: ClientInfo(),
            auth: AuthInfo(token: token)
        )
        let connectReq = RPCRequest(
            id: nextId(),
            method: "connect",
            params: connectParams
        )

        let jsonData = try JSONEncoder().encode(connectReq)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        print("[OpenClaw] Sending: \(jsonString)")

        try await webSocket?.send(.string(jsonString))

        // Read responses until we get one with our request id or ok field
        let response = try await waitForResponse(requestId: connectReq.id)
        if response.ok == true {
            isConnectedInternal = true
            print("[OpenClaw] Connected successfully")
        } else {
            throw OpenClawError.connectionRejected(response.error?.message ?? "Unknown error")
        }
    }

    func sendMessage(text: String) async throws {
        guard isConnectedInternal, webSocket != nil else {
            throw OpenClawError.notConnected
        }

        let reqId = nextId()
        let params = ChatSendParams(
            message: text,
            idempotencyKey: UUID().uuidString
        )
        let request = RPCRequest(
            id: reqId,
            method: "chat.send",
            params: params
        )

        let jsonData = try JSONEncoder().encode(request)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        print("[OpenClaw] Sending: \(jsonString)")

        try await webSocket?.send(.string(jsonString))

        let response = try await waitForResponse(requestId: reqId)
        if response.ok != true {
            throw OpenClawError.sendFailed(response.error?.message ?? "Unknown error")
        }
        print("[OpenClaw] Message sent successfully")
    }

    /// Read messages until we find a response matching our request ID.
    /// Skip server-push events that don't have a matching id.
    private func waitForResponse(requestId: String, maxAttempts: Int = 10) async throws -> RPCResponse {
        for _ in 0..<maxAttempts {
            let message = try await webSocket?.receive()
            switch message {
            case .string(let text):
                print("[OpenClaw] Received: \(String(text.prefix(200)))")
                let responseData = Data(text.utf8)
                let response = try JSONDecoder().decode(RPCResponse.self, from: responseData)

                // Check if this is the response we're waiting for
                if response.id == requestId || response.type == "res" {
                    return response
                }
                // Otherwise it's a server event, skip and read next
                print("[OpenClaw] Skipping event: type=\(response.type ?? "nil")")
                continue
            case .data(let data):
                print("[OpenClaw] Received binary data: \(data.count) bytes (skipping)")
                continue
            case .none:
                throw OpenClawError.unexpectedResponse
            @unknown default:
                continue
            }
        }
        throw OpenClawError.unexpectedResponse
    }

    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnectedInternal = false
    }

    private func nextId() -> String {
        messageId += 1
        return String(messageId)
    }
}

enum OpenClawError: LocalizedError {
    case invalidURL
    case connectionRejected(String)
    case unexpectedResponse
    case notConnected
    case sendFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid WebSocket URL"
        case .connectionRejected(let msg): return "Connection rejected: \(msg)"
        case .unexpectedResponse: return "Unexpected response from gateway"
        case .notConnected: return "Not connected to OpenClaw"
        case .sendFailed(let msg): return "Failed to send: \(msg)"
        }
    }
}
