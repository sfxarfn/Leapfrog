//
//  MicerApp.swift
//  Micer
//
//  Created by Sofyan Arifin on 22/04/26.
//


import SwiftUI

@main
struct LeapfrogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var displayManager: DisplayManager

    init() {
        let manager = DisplayManager()
        _displayManager = StateObject(wrappedValue: manager)
        // Hand it to the delegate immediately so the engine can start on launch.
        AppDelegate.sharedManagerBootstrap = manager
    }

    var body: some Scene {
        MenuBarExtra("MicerApp", image: "MenuBarIcon") {
            MenuContent()
                .environmentObject(displayManager)
        }
        .menuBarExtraStyle(.menu)
    }
}
