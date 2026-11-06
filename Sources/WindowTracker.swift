import AppKit
import CoreGraphics

/// Reads window geometry only. This does not capture pixels or request system permissions.
final class WindowTracker {
    private struct WindowGeometry {
        let id: CGWindowID
        let rect: CGRect
        let velocity: CGVector
        let isDock: Bool
    }

    private struct PreviousGeometry {
        let rect: CGRect
        let time: TimeInterval
    }

    private var previous: [CGWindowID: PreviousGeometry] = [:]
    private var cachedWindows: [WindowGeometry] = []
    private var lastRefresh: TimeInterval = -.infinity
    private(set) var visibleWindowCount = 0

    func sample(for screen: NSScreen, excluding: Set<CGWindowID>) -> [WeatherSurface] {
        let windows = snapshot().filter { !excluding.contains($0.id) }
        visibleWindowCount = windows.filter { !$0.isDock }.count
        let screenRect = screen.frame
        var occluders: [CGRect] = []
        var surfaces: [WeatherSurface] = []

        // Core Graphics returns windows front to back, so every accumulated rectangle
        // can cover the top edge of the current window.
        for window in windows {
            let rect = window.rect
            defer {
                if rect.intersects(screenRect) { occluders.append(rect) }
            }
            guard rect.intersects(screenRect),
                  rect.maxY >= screenRect.minY,
                  rect.maxY <= screenRect.maxY + 1 else { continue }

            let left = max(rect.minX, screenRect.minX)
            let right = min(rect.maxX, screenRect.maxX)
            guard right - left >= 12 else { continue }
            var segments: [ClosedRange<CGFloat>] = [left...right]
            for blocker in occluders {
                // An occluder must actually cross the surface, not merely touch it.
                guard blocker.minY < rect.maxY + 1,
                      blocker.maxY > rect.maxY - 1 else { continue }
                segments = segments.flatMap { segment -> [ClosedRange<CGFloat>] in
                    let cutLeft = max(segment.lowerBound, blocker.minX)
                    let cutRight = min(segment.upperBound, blocker.maxX)
                    guard cutRight > cutLeft else { return [segment] }
                    var remaining: [ClosedRange<CGFloat>] = []
                    if cutLeft - segment.lowerBound >= 12 {
                        remaining.append(segment.lowerBound...cutLeft)
                    }
                    if segment.upperBound - cutRight >= 12 {
                        remaining.append(cutRight...segment.upperBound)
                    }
                    return remaining
                }
                if segments.isEmpty { break }
            }

            for (index, segment) in segments.enumerated() {
                let localRect = CGRect(
                    x: segment.lowerBound - screenRect.minX,
                    y: max(rect.minY, screenRect.minY) - screenRect.minY,
                    width: segment.upperBound - segment.lowerBound,
                    height: rect.maxY - max(rect.minY, screenRect.minY)
                )
                guard localRect.height > 0 else { continue }
                surfaces.append(WeatherSurface(
                    id: surfaceID(window: window.id, segment: index),
                    rect: localRect,
                    velocity: window.velocity
                ))
            }
        }
        return surfaces
    }

    func isFullscreen(on screen: NSScreen, excluding: Set<CGWindowID>) -> Bool {
        let rect = screen.frame
        guard rect.width > 0, rect.height > 0 else { return false }
        // Look at the foremost ordinary window on this display. Checking every
        // background window would incorrectly pause when a small app is in front.
        guard let front = snapshot().first(where: {
            !$0.isDock && !excluding.contains($0.id) &&
            $0.rect.intersection(rect).width > 40 &&
            $0.rect.intersection(rect).height > 40
        }) else { return false }
        let covered = front.rect.intersection(rect)
        return covered.width >= rect.width - 3 && covered.height >= rect.height - 3
    }

    private func snapshot() -> [WindowGeometry] {
        let now = ProcessInfo.processInfo.systemUptime
        // Keep separate displays and the fullscreen check on the same observation.
        if now - lastRefresh < 0.065 { return cachedWindows }
        lastRefresh = now

        guard let mainTop = NSScreen.screens.first?.frame.maxY,
              let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
                as? [[String: Any]] else {
            cachedWindows = []
            previous = [:]
            visibleWindowCount = 0
            return []
        }

        var nextPrevious: [CGWindowID: PreviousGeometry] = [:]
        var output: [WindowGeometry] = []
        for info in list {
            guard let number = info[kCGWindowNumber as String] as? NSNumber,
                  let layer = info[kCGWindowLayer as String] as? NSNumber,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let cgRect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  cgRect.width.isFinite, cgRect.height.isFinite,
                  cgRect.origin.x.isFinite, cgRect.origin.y.isFinite,
                  cgRect.width >= 64, cgRect.height >= 24 else { continue }
            let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            guard alpha > 0.05 else { continue }
            let owner = info[kCGWindowOwnerName as String] as? String ?? ""
            let isDock = owner == "Dock" && layer.intValue > 0 &&
                cgRect.width > cgRect.height * 2 && cgRect.height <= 240
            guard layer.intValue == 0 || isDock else { continue }

            let id = CGWindowID(number.uint32Value)
            // CG coordinates have their origin at the upper-left of the primary
            // display; AppKit screen rectangles use one global bottom-left space.
            let rect = CGRect(x: cgRect.minX, y: mainTop - cgRect.maxY,
                              width: cgRect.width, height: cgRect.height)
            var velocity = CGVector.zero
            if let old = previous[id] {
                let elapsed = now - old.time
                if elapsed > 0.001 && elapsed < 0.6 {
                    velocity = CGVector(dx: (rect.minX - old.rect.minX) / elapsed,
                                        dy: (rect.maxY - old.rect.maxY) / elapsed)
                }
            }
            nextPrevious[id] = PreviousGeometry(rect: rect, time: now)
            output.append(WindowGeometry(id: id, rect: rect,
                                         velocity: velocity, isDock: isDock))
        }
        previous = nextPrevious
        cachedWindows = output
        return output
    }

    private func surfaceID(window: CGWindowID, segment: Int) -> UInt32 {
        // A deterministic 32-bit mixing function keeps each left-to-right segment
        // attached to its parent window across successive observations.
        var value = window &* 2_654_435_761
        value ^= UInt32(truncatingIfNeeded: segment + 1) &* 2_246_822_519
        return value == 0 ? 1 : value
    }
}
