//
//  MenuContent.swift
//  Micer
//
//  Created by Sofyan Arifin on 22/04/26.
//


import SwiftUI
import AppKit

struct MenuContent: View {
    @EnvironmentObject var manager: DisplayManager

    var body: some View {
        Button("Preferences…") {
            PreferencesWindowController.shared.show(manager: manager)
        }

        Divider()

        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
