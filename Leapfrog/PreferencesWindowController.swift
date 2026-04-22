//
//  PreferencesWindowController.swift
//  Micer
//
//  Created by Sofyan Arifin on 22/04/26.
//


import AppKit
import SwiftUI

final class PreferencesWindowController {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    func show(manager: DisplayManager) {
        if let existing = window {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let root = SettingsView().environmentObject(manager)
        let hosting = NSHostingController(rootView: root)

        let w = NSWindow(contentViewController: hosting)
        w.title = "Leapfrog Preferences"
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        w.setContentSize(NSSize(width: 700, height: 480))
        w.center()
        w.isReleasedWhenClosed = false

        // Keep our reference alive; clear it on close.
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: w, queue: .main
        ) { [weak self] _ in
            self?.window = nil
        }

        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}
