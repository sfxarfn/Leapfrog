//
//  SettingsView.swift
//  Micer
//
//  Created by Sofyan Arifin on 22/04/26.
//


import SwiftUI
import AppKit

struct SettingsView: View {
    var body: some View {
        TabView {
            LayoutEditorView()
                .tabItem { Label("Layout", systemImage: "rectangle.on.rectangle") }

            DisplayInfoView()
                .tabItem { Label("Info", systemImage: "info.circle") }
        }
        .frame(minWidth: 620, minHeight: 440)
    }
}

struct DisplayInfoView: View {
    @EnvironmentObject var manager: DisplayManager
    @State private var engineEnabled: Bool = EnginePreferences.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Detected Displays").font(.title3).bold()
                Spacer()
                Text(PermissionHelper.hasAccessibility
                     ? "Accessibility: granted ✅"
                     : "Accessibility: not granted ❌")
                    .font(.caption)
            }
            
            Toggle("Enable cursor remapping", isOn: Binding(
                get: { engineEnabled },
                set: { newValue in
                    engineEnabled = newValue
                    EnginePreferences.isEnabled = newValue

                    guard let delegate = AppDelegate.shared else {
                        print("🔴 AppDelegate.shared is nil")
                        return
                    }

                    if newValue {
                        delegate.startEngineIfEnabled()
                    } else {
                        delegate.stopEngine()
                    }
                }
            ))

//            Toggle("Enable cursor remapping", isOn: Binding(
//                get: { engineEnabled },
//                set: { newValue in
//                    print("🔵 Toggle setter called with: \(newValue)")
//                    engineEnabled = newValue
//                    EnginePreferences.isEnabled = newValue
//                    print("🔵 EnginePreferences.isEnabled is now: \(EnginePreferences.isEnabled)")
//
//                    guard let delegate = NSApp.delegate as? AppDelegate else {
//                        print("🔴 Could not cast NSApp.delegate to AppDelegate")
//                        return
//                    }
//                    print("🔵 Got AppDelegate, calling \(newValue ? "start" : "stop")")
//
//                    if newValue {
//                        delegate.startEngineIfEnabled()
//                    } else {
//                        delegate.stopEngine()
//                    }
//                }
//            ))

            Divider()

            if manager.displays.isEmpty {
                Text("No displays detected.").foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(manager.displays) { d in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.isPrimary ? "Display \(d.id) (Primary)" : "Display \(d.id)").bold()
                                Text("Stable key: \(d.stableKey)")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("Pixels: \(Int(d.pixelFrame.width)) × \(Int(d.pixelFrame.height)) at (\(Int(d.pixelFrame.minX)), \(Int(d.pixelFrame.minY)))")
                                    .font(.caption)
                                Text("Physical: \(String(format: "%.0f", d.physicalSize.width)) × \(String(format: "%.0f", d.physicalSize.height)) mm")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("World mm: (\(Int(d.worldOriginMM.x)), \(Int(d.worldOriginMM.y)))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(6)
                        }
                    }
                }
            }

            Button("Refresh") { manager.refresh() }
        }
        .padding()
    }
}
