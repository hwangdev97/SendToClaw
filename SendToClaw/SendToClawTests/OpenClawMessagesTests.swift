import Testing
import Foundation
@testable import SendToClaw

@Suite("OpenClaw Messages Tests")
struct OpenClawMessagesTests {

    @Test("ConnectParams encodes with correct client fields")
    func connectParamsEncoding() throws {
        let params = ConnectParams(
            client: ClientInfo(),
            auth: AuthInfo(token: "my-token")
        )
        let request = RPCRequest(id: "1", method: "connect", params: params)
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["type"] as? String == "req")
        #expect(json["id"] as? String == "1")
        #expect(json["method"] as? String == "connect")

        let reqParams = json["params"] as! [String: Any]
        #expect(reqParams["minProtocol"] as? Int == 3)
        #expect(reqParams["maxProtocol"] as? Int == 3)
        #expect(reqParams["role"] as? String == "operator")

        let auth = reqParams["auth"] as! [String: Any]
        #expect(auth["token"] as? String == "my-token")

        // Validate client fields match OpenClaw protocol enum values
        let client = reqParams["client"] as! [String: Any]
        #expect(client["id"] as? String == "openclaw-macos")
        #expect(client["mode"] as? String == "ui")
        #expect(client["platform"] as? String == "macos")
        #expect(client["version"] as? String == "1.0.0")
        // Must NOT have "name" field
        #expect(client["name"] == nil)
    }

    @Test("ChatSendParams uses 'message' field (not 'text')")
    func chatSendParamsEncoding() throws {
        let params = ChatSendParams(message: "Hello OpenClaw", idempotencyKey: "test-key")
        let request = RPCRequest(id: "2", method: "chat.send", params: params)
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["method"] as? String == "chat.send")

        let reqParams = json["params"] as! [String: Any]
        #expect(reqParams["sessionKey"] as? String == "main")
        #expect(reqParams["message"] as? String == "Hello OpenClaw")
        #expect(reqParams["idempotencyKey"] as? String == "test-key")
        // Must NOT have "text" field
        #expect(reqParams["text"] == nil)
    }

    @Test("RPCResponse decodes success with optional id")
    func decodeSuccessResponse() throws {
        let json = """
        {"type":"res","id":"1","ok":true,"payload":{"type":"hello-ok","protocol":3}}
        """
        let response = try JSONDecoder().decode(RPCResponse.self, from: Data(json.utf8))

        #expect(response.type == "res")
        #expect(response.id == "1")
        #expect(response.ok == true)
        #expect(response.payload?.type == "hello-ok")
        #expect(response.payload?.protocol == 3)
    }

    @Test("RPCResponse decodes server event without id")
    func decodeServerEvent() throws {
        let json = """
        {"type":"event","event":"connect.challenge","payload":{"nonce":"abc","ts":123}}
        """
        let response = try JSONDecoder().decode(RPCResponse.self, from: Data(json.utf8))

        #expect(response.type == "event")
        #expect(response.id == nil)
    }

    @Test("RPCResponse decodes error")
    func decodeErrorResponse() throws {
        let json = """
        {"type":"res","id":"2","ok":false,"error":{"code":"AUTH_FAILED","message":"Invalid token"}}
        """
        let response = try JSONDecoder().decode(RPCResponse.self, from: Data(json.utf8))

        #expect(response.ok == false)
        #expect(response.error?.code == "AUTH_FAILED")
        #expect(response.error?.message == "Invalid token")
    }
}
