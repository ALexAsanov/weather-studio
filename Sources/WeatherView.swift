import AppKit

enum WeatherEffect: String, CaseIterable {
    case snow, rain, sakura, leaves, fireflies, starfall
}

/// Coordinates are local to WeatherView, using Cocoa's bottom-left origin.
struct WeatherSurface {
    var id: UInt32
    var rect: CGRect
    var velocity: CGVector
}

/// A click-through renderer. The owner supplies a timer and window geometry.
final class WeatherView: NSView {
    var effect: WeatherEffect = .snow {
        didSet {
            if oldValue != effect { clear(); needsDisplay = true }
        }
    }
    var intensity: Double = 0.58
    var wind: Double = 0.12
    var speed: Double = 1.0
    var running = true
    var surfaces: [WeatherSurface] = []
    var pointer: CGPoint?
    var fps = 30

    private enum Motion { case falling, resting, splash, spark, glow, meteor }
    private struct Particle {
        var point: CGPoint
        var velocity: CGVector
        var radius: CGFloat
        var angle: CGFloat
        var spin: CGFloat
        var phase: CGFloat
        var age: Double = 0
        var life: Double
        var tint: Int
        var motion: Motion = .falling
        var surface: UInt32 = 0
    }

    private var particles: [Particle] = []
    private var priorSurfaces: [UInt32: CGRect] = [:]
    private var time: Double = 0
    private var spawnCredit: Double = 0
    private var initialized = false
    private var previousPointer: CGPoint?
    private var pointerStillTime: Double = 0
    private var flash: Double = 0
    private var nextFlash: Double = .random(in: 12...22)
    private var surfaceList: [WeatherSurface] = []
    private var surfaceMap: [UInt32: WeatherSurface] = [:]
    private var pileHeights: [UInt32: [Int: CGFloat]] = [:]

    var particleCount: Int { particles.count }
    var settledParticleCount: Int { particles.reduce(0) { $0 + ($1.motion == .resting ? 1 : 0) } }

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
        autoresizingMask = [.width, .height]
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    func clear() {
        particles.removeAll(keepingCapacity: true)
        priorSurfaces.removeAll(keepingCapacity: true)
        pileHeights.removeAll(keepingCapacity: true)
        initialized = false
        spawnCredit = 0
        flash = 0
        time = 0
        nextFlash = .random(in: 12...22)
    }

    /// Simulation time is capped so waking the display cannot create a burst.
    func step(_ delta: Double) {
        guard running, bounds.width > 5, bounds.height > 5 else { return }
        let dt = CGFloat(min(max(delta, 0.001), 0.075) * min(max(speed, 0.3), 2.0))
        time += Double(dt)
        flash = max(0, flash - Double(dt) * 1.7)
        let strength = CGFloat(min(max(intensity, 0.2), 1))
        let breeze = CGFloat(min(max(wind, -1), 1))
        updatePointer(dt)
        updateSurfaces()
        if !initialized { seed(strength); initialized = true }

        let areaScale = min(max(bounds.width / 1400, 0.4), 2)
        let rates: [WeatherEffect: CGFloat] = [.snow: 38, .rain: 155, .sakura: 20, .leaves: 18, .fireflies: 3, .starfall: 2.8]
        let rate = (rates[effect] ?? 20) * strength * areaScale
        spawnCredit += Double(rate * dt)
        var newParticles: [Particle] = []
        while spawnCredit >= 1 {
            spawnCredit -= 1
            if particles.count + newParticles.count < 1250 {
                newParticles.append(makeParticle())
            }
        }

        if effect == .rain, time > nextFlash {
            flash = 0.055
            nextFlash = time + Double.random(in: 12...22)
        }

        pileHeights.removeAll(keepingCapacity: true)
        for p in particles where p.motion == .resting {
            let bucket = Int(p.point.x / 9)
            pileHeights[p.surface, default: [:]][bucket, default: 0] += max(0.5, p.radius * 0.25)
        }

        let restingCount = settledParticleCount
        for index in particles.indices {
            var p = particles[index]
            p.age += Double(dt)
            p.angle += p.spin * dt
            let old = p.point

            switch p.motion {
            case .resting:
                let moved: CGVector
                if p.surface == 0 {
                    moved = .zero
                } else if let surface = surfaceMap[p.surface], let previous = priorSurfaces[p.surface] {
                    moved = CGVector(dx: surface.rect.minX - previous.minX, dy: surface.rect.maxY - previous.maxY)
                } else {
                    moved = CGVector(dx: 0, dy: -12)
                }
                let pointerNear = pointer.map { distance(p.point, $0) < 48 } ?? false
                if abs(moved.dx) + abs(moved.dy) > 1.8 || pointerNear {
                    p.motion = .falling
                    p.age = 0
                    p.life = 18
                    p.point.y += 6
                    let push = pointer.map { p.point.x - $0.x } ?? moved.dx
                    p.velocity = CGVector(dx: max(-320, min(320, push * 4 + moved.dx * 8)) + CGFloat.random(in: -35...35),
                                          dy: CGFloat.random(in: 50...140) + max(0, moved.dy * 4))
                    p.spin = CGFloat.random(in: -5...5)
                } else {
                    p.point.x += moved.dx
                    p.point.y += moved.dy
                }

            case .glow:
                let drift = CGVector(dx: sin(CGFloat(time) * 0.63 + p.phase) * 17 + breeze * 13,
                                     dy: cos(CGFloat(time) * 0.54 + p.phase * 1.7) * 14)
                var target = drift
                if let pointer, pointerStillTime > 0.55 {
                    let dx = pointer.x - p.point.x
                    let dy = pointer.y - p.point.y
                    let length = max(1, hypot(dx, dy))
                    if length > 34 {
                        target.dx += dx / length * min(95, length * 0.32)
                        target.dy += dy / length * min(95, length * 0.32)
                    } else {
                        target.dx += -dy * 0.7
                        target.dy += dx * 0.7
                    }
                }
                p.velocity.dx += (target.dx - p.velocity.dx) * min(1, dt * 2)
                p.velocity.dy += (target.dy - p.velocity.dy) * min(1, dt * 2)
                p.point.x += p.velocity.dx * dt
                p.point.y += p.velocity.dy * dt
                wrap(&p)

            case .spark, .splash:
                p.velocity.dy -= (p.motion == .splash ? 240 : 125) * dt
                p.point.x += p.velocity.dx * dt
                p.point.y += p.velocity.dy * dt

            case .meteor:
                p.point.x += (p.velocity.dx + breeze * 30) * dt
                p.point.y += p.velocity.dy * dt
                if hitSurface(from: old, to: p.point) != nil || p.point.y < 2 {
                    newParticles.append(contentsOf: burst(at: p.point, tint: p.tint, rain: false))
                    p.age = p.life + 1
                }

            case .falling:
                let gravity: CGFloat = effect == .rain ? 300 : 58
                let terminal: CGFloat = effect == .snow ? -64 : (effect == .rain ? -880 : -88)
                p.velocity.dy = max(terminal - p.radius * 5, p.velocity.dy - gravity * dt)
                let targetX = breeze * (effect == .rain ? 150 : 85) + sin(CGFloat(time) * 1.1 + p.phase) * (effect == .rain ? 0 : 17)
                p.velocity.dx += (targetX - p.velocity.dx) * min(1, dt * 0.7)
                if let pointer, effect != .rain {
                    let dx = p.point.x - pointer.x
                    let dy = p.point.y - pointer.y
                    let length = max(1, hypot(dx, dy))
                    if length < 72 {
                        p.velocity.dx += dx / length * (72 - length) * 5 * dt
                        p.velocity.dy += dy / length * (72 - length) * 4 * dt
                    }
                }
                p.point.x += p.velocity.dx * dt
                p.point.y += p.velocity.dy * dt
                var contact = p.velocity.dy < 0 ? hitSurface(from: old, to: p.point) : nil
                if p.point.y <= 2, p.velocity.dy < 0 {
                    contact = WeatherSurface(id: 0, rect: CGRect(x: 0, y: 0, width: bounds.width, height: 2), velocity: .zero)
                }
                if let contact {
                    if effect == .rain {
                        p.point.y = contact.rect.maxY
                        newParticles.append(contentsOf: burst(at: p.point, tint: 0, rain: true))
                        p.age = p.life + 1
                    } else if restingCount < 700 {
                        let bucket = Int(p.point.x / 9)
                        let height = min(16, pileHeights[contact.id]?[bucket] ?? 0)
                        p.point.y = contact.rect.maxY + p.radius * 0.45 + height
                        p.motion = .resting
                        p.surface = contact.id
                        p.velocity = .zero
                        p.spin = 0
                        p.age = 0
                        p.life = Double.random(in: 26...48)
                    } else {
                        p.age = p.life + 1
                    }
                }
                if p.point.x < -40 { p.point.x = bounds.width + 20 }
                if p.point.x > bounds.width + 40 { p.point.x = -20 }
            }
            particles[index] = p
        }
        particles.removeAll { $0.age > $0.life || $0.point.y < -110 || ($0.motion == .meteor && $0.point.x > bounds.width + 160) }
        if particles.count < 1400 { particles.append(contentsOf: newParticles.prefix(1400 - particles.count)) }
        priorSurfaces = surfaceMap.mapValues(\.rect)
        needsDisplay = true
    }

    private func updatePointer(_ dt: CGFloat) {
        if let pointer, let previousPointer, distance(pointer, previousPointer) < 2 {
            pointerStillTime += Double(dt)
        } else { pointerStillTime = 0 }
        previousPointer = pointer
    }

    private func updateSurfaces() {
        surfaceList = surfaces.filter { $0.rect.width > 20 && $0.rect.maxY > 2 && $0.rect.maxY < bounds.height + 1 }
            .sorted { $0.rect.maxY > $1.rect.maxY }
        surfaceMap = [:]
        for s in surfaceList { surfaceMap[s.id] = s }
    }

    private func hitSurface(from old: CGPoint, to point: CGPoint) -> WeatherSurface? {
        for s in surfaceList {
            let y = s.rect.maxY
            if old.y >= y, point.y <= y, point.x >= s.rect.minX, point.x <= s.rect.maxX {
                return s
            }
        }
        return nil
    }

    private func seed(_ strength: CGFloat) {
        let amount: CGFloat
        switch effect {
        case .snow: amount = 110
        case .rain: amount = 155
        case .sakura, .leaves: amount = 65
        case .fireflies: amount = 85
        case .starfall: amount = 3
        }
        for _ in 0..<Int(amount * strength * min(max(bounds.width / 1400, 0.45), 2)) {
            var p = makeParticle()
            p.point.y = CGFloat.random(in: 8...max(9, bounds.height))
            particles.append(p)
        }
    }

    private func makeParticle() -> Particle {
        var p = Particle(point: CGPoint(x: CGFloat.random(in: -20...max(1, bounds.width + 20)), y: bounds.height + 15),
                         velocity: CGVector(dx: CGFloat.random(in: -12...12), dy: -.random(in: 22...70)),
                         radius: .random(in: 1.5...4.2), angle: .random(in: 0...(2 * .pi)),
                         spin: .random(in: -1.8...1.8), phase: .random(in: 0...30), life: 70, tint: Int.random(in: 0...3))
        switch effect {
        case .snow:
            break
        case .rain:
            p.radius = .random(in: 0.6...1.3)
            p.velocity.dy = -.random(in: 570...900)
            p.life = 12
        case .sakura:
            p.radius = .random(in: 3...6.4)
            p.velocity.dy = -.random(in: 24...60)
        case .leaves:
            p.radius = .random(in: 4...7.5)
        case .fireflies:
            p.motion = .glow
            p.point.y = .random(in: 15...max(16, bounds.height - 15))
            p.radius = .random(in: 1.2...2.6)
            p.velocity.dy = .random(in: -16...16)
            p.life = .random(in: 20...38)
        case .starfall:
            p.motion = .meteor
            p.point.x = .random(in: -200...max(1, bounds.width * 0.8))
            p.velocity = CGVector(dx: .random(in: 240...520), dy: -.random(in: 230...510))
            p.radius = .random(in: 1.8...3.1)
            p.life = 12
        }
        return p
    }

    private func burst(at point: CGPoint, tint: Int, rain: Bool) -> [Particle] {
        (0..<(rain ? 3 : 14)).map { index in
            let angle = CGFloat(index) / CGFloat(rain ? 3 : 14) * .pi * 2 + CGFloat.random(in: -0.3...0.3)
            let velocity = CGFloat.random(in: rain ? 28...80 : 45...145)
            return Particle(point: point,
                            velocity: CGVector(dx: cos(angle) * velocity, dy: rain ? CGFloat.random(in: 40...90) : sin(angle) * velocity),
                            radius: rain ? .random(in: 0.65...1.3) : .random(in: 1...2.7),
                            angle: angle, spin: 0, phase: 0, life: rain ? .random(in: 0.25...0.5) : .random(in: 0.4...1.0),
                            tint: tint, motion: rain ? .splash : .spark)
        }
    }

    private func wrap(_ p: inout Particle) {
        if p.point.x < -15 { p.point.x = bounds.width + 10 }
        if p.point.x > bounds.width + 15 { p.point.x = -10 }
        if p.point.y < -15 { p.point.y = bounds.height + 10 }
        if p.point.y > bounds.height + 15 { p.point.y = -10 }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        ctx.setAllowsAntialiasing(true)
        if flash > 0 { ctx.setFillColor(NSColor(calibratedRed: 0.75, green: 0.85, blue: 1, alpha: flash).cgColor); ctx.fill(bounds) }

        for p in particles {
            let alpha: CGFloat
            if p.motion == .resting { alpha = CGFloat(min(1, max(0, (p.life - p.age) / 5))) }
            else if p.motion == .spark || p.motion == .splash { alpha = CGFloat(max(0, 1 - p.age / p.life)) }
            else if p.motion == .glow { alpha = CGFloat(min(1, p.age + 0.3) * min(1, (p.life - p.age) / 3)) }
            else { alpha = 1 }

            switch p.motion {
            case .spark:
                let c = starColor(p.tint, alpha * 0.9)
                circle(ctx, p.point, p.radius * 3, starColor(p.tint, alpha * 0.07))
                circle(ctx, p.point, p.radius, c)
            case .splash:
                ctx.setStrokeColor(NSColor(calibratedRed: 0.62, green: 0.82, blue: 1, alpha: alpha * 0.7).cgColor)
                ctx.setLineWidth(p.radius)
                ctx.move(to: p.point)
                ctx.addLine(to: CGPoint(x: p.point.x - p.velocity.dx * 0.022, y: p.point.y - p.velocity.dy * 0.022))
                ctx.strokePath()
            case .glow:
                let pulse = 0.55 + 0.45 * sin(CGFloat(time) * 1.8 + p.phase)
                let a = alpha * pulse
                circle(ctx, p.point, p.radius * 5.5, NSColor(calibratedRed: 0.6, green: 1, blue: 0.3, alpha: a * 0.035))
                circle(ctx, p.point, p.radius * 3.2, NSColor(calibratedRed: 0.8, green: 1, blue: 0.35, alpha: a * 0.1))
                circle(ctx, p.point, p.radius, NSColor(calibratedRed: 0.93, green: 1, blue: 0.64, alpha: a))
            case .meteor:
                let len = hypot(p.velocity.dx, p.velocity.dy)
                let ux = p.velocity.dx / max(1, len), uy = p.velocity.dy / max(1, len)
                for step in (1...9).reversed() {
                    let a = CGFloat(10 - step) / 10
                    ctx.setStrokeColor(starColor(p.tint, a * a * 0.75).cgColor)
                    ctx.setLineWidth(p.radius * a * 1.2)
                    ctx.setLineCap(.round)
                    ctx.move(to: CGPoint(x: p.point.x - ux * CGFloat(step) * 10, y: p.point.y - uy * CGFloat(step) * 10))
                    ctx.addLine(to: CGPoint(x: p.point.x - ux * CGFloat(step - 1) * 10, y: p.point.y - uy * CGFloat(step - 1) * 10))
                    ctx.strokePath()
                }
                circle(ctx, p.point, p.radius * 3, starColor(p.tint, 0.13))
                circle(ctx, p.point, p.radius, .white)
            case .falling, .resting:
                drawPrecipitation(p, alpha: alpha, in: ctx)
            }
        }
    }

    private func drawPrecipitation(_ p: Particle, alpha: CGFloat, in ctx: CGContext) {
        switch effect {
        case .snow:
            let a = alpha * (0.55 + p.radius / 10)
            circle(ctx, p.point, p.radius * 1.7, NSColor(calibratedRed: 0.75, green: 0.87, blue: 1, alpha: a * 0.08))
            circle(ctx, p.point, p.radius, NSColor(calibratedRed: 0.94, green: 0.97, blue: 1, alpha: a))
            if p.radius > 3.6, p.motion != .resting {
                ctx.saveGState(); ctx.translateBy(x: p.point.x, y: p.point.y); ctx.rotate(by: p.angle)
                ctx.setStrokeColor(NSColor.white.withAlphaComponent(a * 0.7).cgColor); ctx.setLineWidth(0.65)
                for branch in 0..<3 {
                    let angle = CGFloat(branch) * .pi / 3
                    ctx.move(to: CGPoint(x: cos(angle) * -p.radius * 1.4, y: sin(angle) * -p.radius * 1.4))
                    ctx.addLine(to: CGPoint(x: cos(angle) * p.radius * 1.4, y: sin(angle) * p.radius * 1.4))
                }
                ctx.strokePath(); ctx.restoreGState()
            }
        case .rain:
            ctx.setLineCap(.round)
            ctx.setLineWidth(p.radius)
            ctx.setStrokeColor(NSColor(calibratedRed: 0.63, green: 0.82, blue: 1, alpha: alpha * 0.5).cgColor)
            ctx.move(to: p.point)
            ctx.addLine(to: CGPoint(x: p.point.x - p.velocity.dx * 0.022, y: p.point.y - p.velocity.dy * 0.022))
            ctx.strokePath()
        case .sakura:
            ctx.saveGState(); ctx.translateBy(x: p.point.x, y: p.point.y); ctx.rotate(by: p.angle)
            let r = p.radius, squash = 0.55 + abs(sin(CGFloat(time) + p.phase)) * 0.45
            ctx.scaleBy(x: squash, y: 1)
            ctx.setFillColor(NSColor(calibratedRed: 1, green: p.tint % 2 == 0 ? 0.66 : 0.8, blue: 0.85, alpha: alpha * 0.94).cgColor)
            ctx.move(to: CGPoint(x: 0, y: -r))
            ctx.addCurve(to: CGPoint(x: -r * 0.15, y: r), control1: CGPoint(x: -r * 1.3, y: -r * 0.1), control2: CGPoint(x: -r, y: r * 1.3))
            ctx.addLine(to: CGPoint(x: 0, y: r * 0.65))
            ctx.addLine(to: CGPoint(x: r * 0.2, y: r))
            ctx.addCurve(to: CGPoint(x: 0, y: -r), control1: CGPoint(x: r * 1.1, y: r), control2: CGPoint(x: r * 1.2, y: -r * 0.4))
            ctx.fillPath(); ctx.restoreGState()
        case .leaves:
            ctx.saveGState(); ctx.translateBy(x: p.point.x, y: p.point.y); ctx.rotate(by: p.angle)
            let r = p.radius
            let palette: [(CGFloat, CGFloat, CGFloat)] = [(0.96,0.56,0.15), (0.91,0.29,0.12), (0.98,0.73,0.21), (0.73,0.35,0.15)]
            let c = palette[p.tint % palette.count]
            ctx.setFillColor(NSColor(calibratedRed: c.0, green: c.1, blue: c.2, alpha: alpha * 0.94).cgColor)
            ctx.move(to: CGPoint(x: 0, y: -r))
            ctx.addCurve(to: CGPoint(x: 0, y: r * 1.4), control1: CGPoint(x: -r * 1.3, y: -r * 0.25), control2: CGPoint(x: -r * 1.2, y: r))
            ctx.addCurve(to: CGPoint(x: 0, y: -r), control1: CGPoint(x: r * 1.2, y: r * 0.8), control2: CGPoint(x: r, y: -r * 0.5))
            ctx.fillPath()
            ctx.setStrokeColor(NSColor(calibratedRed: 0.35, green: 0.16, blue: 0.05, alpha: alpha * 0.5).cgColor)
            ctx.setLineWidth(0.65); ctx.move(to: CGPoint(x: 0, y: -r * 1.2)); ctx.addLine(to: CGPoint(x: 0, y: r)); ctx.strokePath()
            ctx.restoreGState()
        case .fireflies, .starfall:
            break
        }
    }

    private func circle(_ ctx: CGContext, _ point: CGPoint, _ radius: CGFloat, _ color: NSColor) {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }

    private func starColor(_ tint: Int, _ alpha: CGFloat) -> NSColor {
        switch tint % 3 {
        case 0: return NSColor(calibratedRed: 0.6, green: 0.84, blue: 1, alpha: alpha)
        case 1: return NSColor(calibratedRed: 0.83, green: 0.65, blue: 1, alpha: alpha)
        default: return NSColor(calibratedRed: 1, green: 0.87, blue: 0.61, alpha: alpha)
        }
    }
}
