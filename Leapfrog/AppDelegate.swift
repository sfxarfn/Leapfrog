//
//  AppDelegate.swift
//  Micer
//
//  Created by Sofyan Arifin on 22/04/26.
//


import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?
    
    /// Set by the App struct's init before applicationDidFinishLaunching runs.
    static var sharedManagerBootstrap: DisplayManager?

    private(set) var displayManager: DisplayManager?
    private var mouseEngine: MouseEngine?
    
    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = PermissionHelper.requestAccessibility()

        displayManager = Self.sharedManagerBootstrap

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.displayManager?.refresh()
        }

        startEngineIfEnabled()
    }

    func startEngineIfEnabled() {
        print("🟢 startEngineIfEnabled called")
        guard EnginePreferences.isEnabled else {
            print("🟢 preference is disabled, stopping")
            stopEngine()
            return
        }
        guard mouseEngine == nil else {
            print("🟢 mouseEngine already exists, skipping")
            return
        }
        guard let manager = displayManager else {
            print("🔴 displayManager is nil")
            return
        }
        guard PermissionHelper.hasAccessibility else {
            print("🔴 Accessibility not granted")
            return
        }
        let engine = MouseEngine(displayManager: manager)
        engine.start()
        mouseEngine = engine
        print("🟢 Engine started")
    }

    func stopEngine() {
        print("🟠 stopEngine called, mouseEngine exists: \(mouseEngine != nil)")
        mouseEngine?.stop()
        mouseEngine = nil
        print("🟠 Engine stopped")
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopEngine()
    }
}
