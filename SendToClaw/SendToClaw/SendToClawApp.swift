//
//  SendToClawApp.swift
//  SendToClaw
//
//  Created by Hwang on 3/11/26.
//

import SwiftUI
import CoreData

@main
struct SendToClawApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
