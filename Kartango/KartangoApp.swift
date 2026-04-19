//
//  KartangoApp.swift
//  Kartango
//
//  Created by Panida Rumriankit on 15/3/2569 BE.
//

import SwiftUI
import CoreData
import BackgroundTasks

@main
struct KartangoApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        BackgroundRefresh.register()
        BackgroundRefresh.schedule()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
