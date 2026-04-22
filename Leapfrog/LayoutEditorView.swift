//
//  LayoutEditorView.swift
//  Micer
//
//  Created by Sofyan Arifin on 22/04/26.
//

import SwiftUI
import AppKit

struct LayoutEditorView: View {
    @EnvironmentObject var manager: DisplayManager
    @State private var dragOrigins: [CGDirectDisplayID: CGPoint] = [:]
    @State private var lastScale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Arrange Displays by Physical Position").font(.headline)
            Text("Drag each rectangle to match where the display physically sits on your desk. Sizes shown are the actual physical dimensions (mm).")
                .font(.caption).foregroundStyle(.secondary)

            GeometryReader { geo in
                let transform = computeTransform(in: geo.size)
                ZStack(alignment: .topLeading) {
                    Color(NSColor.controlBackgroundColor)
                    gridBackground(size: geo.size, transform: transform)

                    ForEach(manager.displays) { display in
                        rectangle(for: display, transform: transform)
                    }
                }
                .clipped()
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
            }
            .frame(minHeight: 260)

            HStack {
                Button("Reload from system") { manager.refresh() }
                Button("Reset to defaults", role: .destructive) {
                    manager.resetLayouts()
                }
                Spacer()
                Text("Scale: 1 mm = \(String(format: "%.2f", lastScale)) pt")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func computeTransform(in size: CGSize) -> (scale: CGFloat, offset: CGPoint) {
        let displays = manager.displays
        guard !displays.isEmpty else { return (1, .zero) }

        let minX = displays.map { $0.worldOriginMM.x }.min() ?? 0
        let minY = displays.map { $0.worldOriginMM.y }.min() ?? 0
        let maxX = displays.map { $0.worldOriginMM.x + $0.physicalSize.width }.max() ?? 0
        let maxY = displays.map { $0.worldOriginMM.y + $0.physicalSize.height }.max() ?? 0

        let bboxW = max(1, maxX - minX)
        let bboxH = max(1, maxY - minY)
        let padding: CGFloat = 30

        let scale = min((size.width - padding * 2) / bboxW,
                        (size.height - padding * 2) / bboxH)

        let usedW = bboxW * scale
        let usedH = bboxH * scale
        let offsetX = (size.width  - usedW) / 2 - minX * scale
        let offsetY = (size.height - usedH) / 2 - minY * scale

        DispatchQueue.main.async { self.lastScale = scale }
        return (scale, CGPoint(x: offsetX, y: offsetY))
    }

    private func rectangle(for display: Display,
                           transform: (scale: CGFloat, offset: CGPoint)) -> some View {
        let origin = dragOrigins[display.id] ?? display.worldOriginMM
        let x = origin.x * transform.scale + transform.offset.x
        let y = origin.y * transform.scale + transform.offset.y
        let w = max(30, display.physicalSize.width  * transform.scale)
        let h = max(20, display.physicalSize.height * transform.scale)

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(display.isPrimary ? Color.accentColor.opacity(0.25)
                                        : Color.blue.opacity(0.20))
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(display.isPrimary ? Color.accentColor : Color.blue, lineWidth: 2)
            VStack(spacing: 2) {
                Text(display.isPrimary ? "Primary" : "Display")
                    .font(.caption).bold()
                Text("\(Int(display.pixelFrame.width))×\(Int(display.pixelFrame.height)) px")
                    .font(.caption2)
                Text("\(Int(display.physicalSize.width))×\(Int(display.physicalSize.height)) mm")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(4)
        }
        .frame(width: w, height: h)
        .position(x: x + w / 2, y: y + h / 2)
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .local)
                .onChanged { value in
                    let dxMM = value.translation.width  / transform.scale
                    let dyMM = value.translation.height / transform.scale
                    dragOrigins[display.id] = CGPoint(
                        x: display.worldOriginMM.x + dxMM,
                        y: display.worldOriginMM.y + dyMM
                    )
                }
                .onEnded { _ in
                    guard let newOrigin = dragOrigins[display.id] else { return }
                    manager.setWorldOrigin(newOrigin, for: display.id)
                    dragOrigins.removeValue(forKey: display.id)
                }
        )
    }

    @ViewBuilder
    private func gridBackground(size: CGSize,
                                transform: (scale: CGFloat, offset: CGPoint)) -> some View {
        let step: CGFloat = 100 * transform.scale
        if step > 6 {
            Canvas { ctx, s in
                var x = transform.offset.x.truncatingRemainder(dividingBy: step)
                while x < s.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: s.height))
                    ctx.stroke(path, with: .color(.gray.opacity(0.15)), lineWidth: 0.5)
                    x += step
                }
                var y = transform.offset.y.truncatingRemainder(dividingBy: step)
                while y < s.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: s.width, y: y))
                    ctx.stroke(path, with: .color(.gray.opacity(0.15)), lineWidth: 0.5)
                    y += step
                }
            }
        }
    }
}
