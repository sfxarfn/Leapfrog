//
//  MouseEngine.swift
//  Micer
//
//  Created by Sofyan Arifin on 22/04/26.
//

import CoreGraphics
import AppKit

final class MouseEngine {
    /// How long the cursor must "push against" a screen edge before crossing, in milliseconds.
    var borderDelayMS: Double = 7

    /// Tracks an in-progress crossing attempt so we can enforce the delay.
    private var pendingCrossing: (fromId: CGDirectDisplayID, toId: CGDirectDisplayID, startedAt: Date)?
    
    private static let syntheticEventField = CGEventField(rawValue: 100)!
    private static let syntheticEventMarker: Int64 = 0xB16B00B5
    
    private let displayManager: DisplayManager
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var lastDisplayId: CGDirectDisplayID?
    private var lastPosition: CGPoint = .zero
    private var ignoreNextMove = false    // don't react to events our own warp causes

    init(displayManager: DisplayManager) {
        self.displayManager = displayManager
    }

    func start() {
        let mask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else {
            print("Failed to create event tap — check Accessibility permission")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source

        let pos = CGEvent(source: nil)?.location ?? .zero
        lastPosition = pos
        lastDisplayId = displayManager.display(at: pos)?.id
        print("MouseEngine started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        pendingCrossing = nil
        print("MouseEngine stopped")
    }
    
    // Called from the C callback.
    func handle(event: CGEvent, type: CGEventType) -> CGEvent? {
        // Ignore events we posted ourselves.
        if event.getIntegerValueField(Self.syntheticEventField) == Self.syntheticEventMarker {
            return event
        }
        
        // macOS occasionally disables the tap; re-enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return event
        }

        if ignoreNextMove {
            ignoreNextMove = false
            lastPosition = event.location
            lastDisplayId = displayManager.display(at: lastPosition)?.id
            return event
        }

        let newPos = event.location
        let newDisplay = displayManager.display(at: newPos)
        
        if let fromId = lastDisplayId,
           let toDisplay = newDisplay,
           toDisplay.id != fromId,
           let fromDisplay = displayManager.display(withId: fromId) {

            let direction = crossingDirection(from: fromDisplay, to: toDisplay)
            let requiresDelay =  (direction == .left || direction == .up)   // delay only when crossing left or up

            let corrected = physicallyAlign(
                from: fromDisplay, exit: lastPosition,
                to: toDisplay, attempted: newPos
            )

            if !requiresDelay {
                // No delay for this direction — cross immediately.
                if let synth = CGEvent(mouseEventSource: nil,
                                       mouseType: .mouseMoved,
                                       mouseCursorPosition: corrected,
                                       mouseButton: .left) {
                    synth.setIntegerValueField(Self.syntheticEventField, value: Self.syntheticEventMarker)
                    synth.post(tap: .cghidEventTap)
                }

                pendingCrossing = nil
                lastPosition = corrected
                lastDisplayId = toDisplay.id
                return nil
            }

            // Delayed crossing path.
            let now = Date()
            if pendingCrossing?.fromId != fromId || pendingCrossing?.toId != toDisplay.id {
                pendingCrossing = (fromId, toDisplay.id, now)
            }

            let elapsedMS = now.timeIntervalSince(pendingCrossing!.startedAt) * 1000

            if elapsedMS >= borderDelayMS {
                if let synth = CGEvent(mouseEventSource: nil,
                                       mouseType: .mouseMoved,
                                       mouseCursorPosition: corrected,
                                       mouseButton: .left) {
                    synth.setIntegerValueField(Self.syntheticEventField, value: Self.syntheticEventMarker)
                    synth.post(tap: .cghidEventTap)
                }

                pendingCrossing = nil
                lastPosition = corrected
                lastDisplayId = toDisplay.id
                return nil
            } else {
                // Still resisting — swallow the hardware event.
                return nil
            }
        }

        pendingCrossing = nil
        
//        if let fromId = lastDisplayId,
//           let toDisplay = newDisplay,
//           toDisplay.id != fromId,
//           let fromDisplay = displayManager.display(withId: fromId) {
//
//            let corrected = physicallyAlign(
//                from: fromDisplay, exit: lastPosition,
//                to: toDisplay, attempted: newPos
//            )
//
//            // Post a synthetic move to the corrected position.
//            if let synth = CGEvent(mouseEventSource: nil,
//                                   mouseType: .mouseMoved,
//                                   mouseCursorPosition: corrected,
//                                   mouseButton: .left) {
//                synth.post(tap: .cghidEventTap)
//            }
//
//            lastPosition = corrected
//            lastDisplayId = toDisplay.id
//            return nil    // swallow the original event
//        }

        lastPosition = newPos
        lastDisplayId = newDisplay?.id
        return event
    }
    
    private enum CrossingDirection { case left, right, up, down }

    private func crossingDirection(from: Display, to: Display) -> CrossingDirection {
        let dx = to.pixelFrame.midX - from.pixelFrame.midX
        let dy = to.pixelFrame.midY - from.pixelFrame.midY
        if abs(dx) >= abs(dy) {
            return dx < 0 ? .left : .right
        } else {
            return dy < 0 ? .up : .down
        }
    }

    /// Map an exit point on `from` to a physically-aligned point on `to`
    /// using the world-mm layout.
    private func physicallyAlign(from: Display, exit: CGPoint,
                                 to: Display, attempted: CGPoint) -> CGPoint {
        let worldMM = from.pixelToWorldMM(exit)
        var target = to.worldMMToPixel(worldMM)

        // Clamp inside the target display with a 1px margin.
        target.x = max(to.pixelFrame.minX + 1, min(to.pixelFrame.maxX - 1, target.x))
        target.y = max(to.pixelFrame.minY + 1, min(to.pixelFrame.maxY - 1, target.y))
        return target
    }
}

// MARK: - C callback (must be a free function)

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
    let engine = Unmanaged<MouseEngine>.fromOpaque(userInfo).takeUnretainedValue()
    if let result = engine.handle(event: event, type: type) {
        return Unmanaged.passUnretained(result)
    }
    return nil
}
