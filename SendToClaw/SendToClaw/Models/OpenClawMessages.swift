import Foundation

struct RPCRequest<P: Encodable>: Encodable {
    let type = "req"
    let id: String
    let method: String
    let params: P
}

struct ConnectParams: Encodable {
    let minProtocol = 3
    let maxProtocol = 3
    let client: ClientInfo
    let role = "operator"
    let scopes = ["operator.read", "operator.write"]
    let auth: AuthInfo
}

struct ClientInfo: Encodable {
    let id = "openclaw-macos"
    let version = "1.0.0"
    let platform = "macos"
    let mode = "ui"
}

struct AuthInfo: Encodable {
    let token: String
}

struct ChatSendParams: Encodable {
    let sessionKey = "main"
    let message: String
    let idempotencyKey: String
}

struct RPCResponse: Decodable {
    let type: String?
    let id: String?
    let ok: Bool?
    let payload: ResponsePayload?
    let error: RPCError?
}

struct ResponsePayload: Decodable {
    let type: String?
    let `protocol`: Int?
    let runId: String?
    let status: String?
}

struct RPCError: Decodable {
    let code: String?
    let message: String?
}
