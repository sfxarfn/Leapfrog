//
//  PermissionHelper.swift
//  Micer
//
//  Created by Sofyan Arifin on 22/04/26.
//

import ApplicationServices

enum PermissionHelper {
    /// Prompts the user for Accessibility permission if not granted.
    @discardableResult
    static func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static var hasAccessibility: Bool { AXIsProcessTrusted() }
}
