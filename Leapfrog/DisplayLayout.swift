//
//  DisplayLayout.swift
//  Micer
//
//  Created by Sofyan Arifin on 22/04/26.
//


import Foundation
import CoreGraphics

/// What we persist per display.
struct DisplayLayout: Codable {
    var worldOriginMM: CGPoint                 // top-left in world mm-space
    var physicalSizeMMOverride: CGSize?        // manual override if EDID missing
}

final class LayoutStore {
    private let defaultsKey = "displayLayouts.v1"
    private(set) var layouts: [String: DisplayLayout] = [:]

    init() { load() }

    func layout(forKey key: String) -> DisplayLayout? { layouts[key] }

    func setLayout(_ layout: DisplayLayout, forKey key: String) {
        layouts[key] = layout
        save()
    }

    func resetAll() {
        layouts.removeAll()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: DisplayLayout].self, from: data) else {
            return
        }
        layouts = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(layouts) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

// Codable support for CGPoint/CGSize via mirror structs.
extension CGPoint {
    enum CodingKeys: String, CodingKey { case x, y }
}
extension CGPoint: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try c.decode(CGFloat.self, forKey: .x),
                  y: try c.decode(CGFloat.self, forKey: .y))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(x, forKey: .x); try c.encode(y, forKey: .y)
    }
}
extension CGSize {
    enum CodingKeys: String, CodingKey { case width, height }
}
extension CGSize: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(width: try c.decode(CGFloat.self, forKey: .width),
                  height: try c.decode(CGFloat.self, forKey: .height))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(width, forKey: .width); try c.encode(height, forKey: .height)
    }
}