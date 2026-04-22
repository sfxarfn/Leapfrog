//
//  EnginePreferences.swift
//  Micer
//
//  Created by Sofyan Arifin on 22/04/26.
//


import Foundation

enum EnginePreferences {
    private static let enabledKey = "engineEnabled"

    static var isEnabled: Bool {
        get {
            // Default to true on first run.
            if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
        }
    }
}