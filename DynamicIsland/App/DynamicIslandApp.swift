//
//  DynamicIslandApp.swift
//  DynamicIsland
//
//  Created by Mohammad Mokaram Khan on 24/04/26.
//

import SwiftUI

@main
struct DynamicIslandApp: App {
    // Settings is the only scene that can remain empty without macOS auto-opening
    // a window at launch. Combined with AppDelegate's .accessory policy, this keeps
    // the app running headless so only the floating island panel is visible.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
