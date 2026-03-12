import SwiftUI

private func sampleAppState(
    state: TextInputState,
    text: String = "",
    connected: Bool = true,
    channelName: String = "Office"
) -> AppState {
    let a = AppState()
    a.textInputState = state
    a.textInputContent = text
    a.isConnected = connected
    a.connectedChannelName = connected ? channelName : ""
    a.channels = [
        Channel(id: UUID(), type: .web, name: "Office", host: "192.168.1.100", port: 18789, token: "abc"),
        Channel(id: UUID(), type: .telegram, name: "Telegram", botUsername: "bot"),
    ]
    return a
}

#Preview("Editing") {
    TextInputPanelView(appState: sampleAppState(state: .editing))
        .padding(40)
        .background(.black.opacity(0.5))
}
//
//#Preview("Editing with Text") {
//    TextInputPanelView(appState: sampleAppState(state: .editing, text: "Hello, this is a message"))
//        .padding(40)
//        .background(.black.opacity(0.5))
//}
//
//#Preview("Sending") {
//    TextInputPanelView(appState: sampleAppState(state: .sending, text: "Sending…"))
//        .padding(40)
//        .background(.black.opacity(0.5))
//}
//
//#Preview("Sent") {
//    TextInputPanelView(appState: sampleAppState(state: .sent))
//        .padding(40)
//        .background(.black.opacity(0.5))
//}
//
//#Preview("Error") {
//    TextInputPanelView(appState: sampleAppState(state: .error("Connection lost")))
//        .padding(40)
//        .background(.black.opacity(0.5))
//}
//
//#Preview("Disconnected") {
//    TextInputPanelView(appState: sampleAppState(state: .editing, connected: false, channelName: ""))
//        .padding(40)
//        .background(.black.opacity(0.5))
//}
