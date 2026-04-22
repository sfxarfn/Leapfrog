//
//  Untitled.swift
//  Micer
//
//  Created by Sofyan Arifin on 22/04/26.
//

import CoreGraphics
import AppKit
import Combine

struct Display: Identifiable, Hashable {
    let id: CGDirectDisplayID
    var pixelFrame: CGRect
    var physicalSize: CGSize
    var worldOriginMM: CGPoint
    var stableKey: String
    var isPrimary: Bool

    var pixelsPerMM: CGSize {
        let w = physicalSize.width  > 0 ? pixelFrame.width  / physicalSize.width  : 4.0
        let h = physicalSize.height > 0 ? pixelFrame.height / physicalSize.height : 4.0
        return CGSize(width: w, height: h)
    }

    func pixelToWorldMM(_ p: CGPoint) -> CGPoint {
        let localX = p.x - pixelFrame.minX
        let localY = p.y - pixelFrame.minY
        return CGPoint(x: worldOriginMM.x + localX / pixelsPerMM.width,
                       y: worldOriginMM.y + localY / pixelsPerMM.height)
    }

    func worldMMToPixel(_ mm: CGPoint) -> CGPoint {
        let localX = (mm.x - worldOriginMM.x) * pixelsPerMM.width
        let localY = (mm.y - worldOriginMM.y) * pixelsPerMM.height
        return CGPoint(x: pixelFrame.minX + localX,
                       y: pixelFrame.minY + localY)
    }
}

final class DisplayManager: ObservableObject {
    @Published private(set) var displays: [Display] = []
    private let store = LayoutStore()

    init() { refresh() }

    func refresh() {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)

        let newDisplays: [Display] = ids.map { id in
            let frame = CGDisplayBounds(id)
            let edidMM = CGDisplayScreenSize(id)
            let key = Self.stableKey(for: id)
            let saved = store.layout(forKey: key)

            var mm = edidMM
            if let override = saved?.physicalSizeMMOverride {
                mm = override
            } else if mm.width == 0 || mm.height == 0 {
                mm = CGSize(width: frame.width / 4.0, height: frame.height / 4.0)
            }

            let ppmm = CGSize(
                width: mm.width > 0 ? frame.width / mm.width : 4.0,
                height: mm.height > 0 ? frame.height / mm.height : 4.0
            )

            let world: CGPoint
            if let saved = saved {
                world = saved.worldOriginMM
            } else {
                world = CGPoint(x: frame.minX / ppmm.width,
                                y: frame.minY / ppmm.height)
            }

            return Display(
                id: id, pixelFrame: frame, physicalSize: mm,
                worldOriginMM: world, stableKey: key,
                isPrimary: CGDisplayIsMain(id) != 0
            )
        }

        print("Displays (\(newDisplays.count)):")
        for d in newDisplays {
            print("  \(d.stableKey) frame=\(d.pixelFrame) mm=\(d.physicalSize) worldMM=\(d.worldOriginMM)")
        }

        // Must publish on main thread.
        if Thread.isMainThread {
            self.displays = newDisplays
        } else {
            DispatchQueue.main.async { self.displays = newDisplays }
        }
    }

    func display(at point: CGPoint) -> Display? {
        displays.first { $0.pixelFrame.contains(point) }
    }

    func display(withId id: CGDirectDisplayID) -> Display? {
        displays.first { $0.id == id }
    }

    func setWorldOrigin(_ origin: CGPoint, for id: CGDirectDisplayID) {
        guard let idx = displays.firstIndex(where: { $0.id == id }) else { return }
        displays[idx].worldOriginMM = origin
        let key = displays[idx].stableKey
        var entry = store.layout(forKey: key)
            ?? DisplayLayout(worldOriginMM: origin, physicalSizeMMOverride: nil)
        entry.worldOriginMM = origin
        store.setLayout(entry, forKey: key)
    }

    func resetLayouts() {
        store.resetAll()
        refresh()
    }

    static func stableKey(for id: CGDirectDisplayID) -> String {
        if CGDisplayIsBuiltin(id) != 0 { return "builtin" }
        let vendor = CGDisplayVendorNumber(id)
        let model  = CGDisplayModelNumber(id)
        let serial = CGDisplaySerialNumber(id)
        if vendor == 0 && model == 0 && serial == 0 {
            return "id-\(id)"
        }
        return "\(vendor)-\(model)-\(serial)"
    }
}
