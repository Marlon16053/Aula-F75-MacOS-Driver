import CoreGraphics
import Foundation

/// Renders real-time RGB colors for every key on the Aula F75 stage,
/// matching both the 18 hardware lighting effects, Per-Key custom matrices,
/// and the live host-driven Studio FX.
public enum LightingEffectRenderer: Sendable {

    public struct ActiveRipple: Sendable {
        public let center: CGPoint
        public let startTime: TimeInterval
        public let color: RGBColor

        public init(center: CGPoint, startTime: TimeInterval, color: RGBColor) {
            self.center = center
            self.startTime = startTime
            self.color = color
        }
    }

    public static func renderFrame(
        spec: KeyboardLayoutSpec,
        config: LightingConfiguration,
        perKeyColors: [Int: RGBColor],
        ripples: [ActiveRipple],
        audioLevel: Double = 0.0,
        time: TimeInterval
    ) -> [Int: RGBColor] {
        var result: [Int: RGBColor] = [:]
        result.reserveCapacity(spec.keys.count)

        let brightnessFactor = Double(config.brightness) / 9.0
        guard config.effect != .off, brightnessFactor > 0.01 else {
            for key in spec.keys { result[key.ledIndex] = .off }
            return result
        }

        // Studio Live FX overrides if active
        if config.studioLiveEffect != .none {
            for key in spec.keys {
                let normPos = CGPoint(
                    x: key.frame.midX / max(spec.size.width, 1),
                    y: key.frame.midY / max(spec.size.height, 1)
                )
                let raw = studioColor(
                    effect: config.studioLiveEffect,
                    pos: normPos,
                    baseColor: config.primaryColor,
                    ripples: ripples,
                    audioLevel: audioLevel,
                    time: time
                )
                result[key.ledIndex] = scale(raw, by: brightnessFactor)
            }
            return result
        }

        // Per-key Custom RGB Studio
        if config.effect == .perKeyCustom {
            for key in spec.keys {
                let c = perKeyColors[key.ledIndex] ?? config.primaryColor
                result[key.ledIndex] = scale(c, by: brightnessFactor)
            }
            return result
        }

        // Hardware effects
        let speedMultiplier = 0.45 + Double(config.speed) * 0.42
        let t = time * speedMultiplier
        let useRainbow = !config.effect.supportsCustomColor || config.rainbowMode

        for key in spec.keys {
            let nx = Double(key.frame.midX / max(spec.size.width, 1))
            let ny = Double(key.frame.midY / max(spec.size.height, 1))
            let base = useRainbow
                ? hsvToRGB(h: fmod(nx * 0.85 + ny * 0.25 - t * 0.25 + 10.0, 1.0), s: 0.9, v: 1.0)
                : config.primaryColor

            let raw = hardwareEffectColor(
                effect: config.effect,
                nx: nx,
                ny: ny,
                ledIndex: key.ledIndex,
                base: base,
                useRainbow: useRainbow,
                ripples: ripples,
                t: t,
                realTime: time
            )
            result[key.ledIndex] = scale(raw, by: brightnessFactor)
        }
        return result
    }

    private static func hardwareEffectColor(
        effect: AulaLightingEffect,
        nx: Double,
        ny: Double,
        ledIndex: Int,
        base: RGBColor,
        useRainbow: Bool,
        ripples: [ActiveRipple],
        t: Double,
        realTime: TimeInterval
    ) -> RGBColor {
        switch effect {
        case .off:
            return .off
        case .fixedOn:
            return base
        case .respire:
            let pulse = 0.15 + 0.85 * (0.5 + 0.5 * sin(t * 2.2))
            return scale(base, by: pulse)
        case .rainbow:
            return hsvToRGB(h: fmod(nx - t * 0.35 + 10.0, 1.0), s: 0.92, v: 1.0)
        case .flashAway:
            let wave = exp(-pow((nx - fmod(t * 0.6, 1.4)) * 4.5, 2))
            return scale(base, by: min(1.0, 0.2 + wave * 0.95))
        case .raindrops:
            let seed = Double((ledIndex * 73 + 19) % 97) / 97.0
            let phase = fmod(t * (0.7 + seed * 0.8) + seed * 6.28, 6.28)
            let drop = max(0.12, pow(max(0, sin(phase)), 4))
            return scale(base, by: drop)
        case .rainbowWheel:
            let dx = nx - 0.5
            let dy = (ny - 0.5) * 0.45
            let angle = atan2(dy, dx) / (2.0 * .pi) + 0.5
            let h = fmod(angle + t * 0.25 + 10.0, 1.0)
            return useRainbow ? hsvToRGB(h: h, s: 0.9, v: 1.0) : scale(base, by: 0.35 + 0.65 * sin(h * 2 * .pi))
        case .ripplesShining, .reaction:
            var intensity = 0.08
            for ripple in ripples {
                let age = realTime - ripple.startTime
                guard age >= 0 && age < 1.2 else { continue }
                let dist = hypot(nx - Double(ripple.center.x), (ny - Double(ripple.center.y)) * 0.45)
                if effect == .reaction {
                    if dist < 0.08 {
                        intensity = max(intensity, 1.0 - age / 1.0)
                    }
                } else {
                    let ring = abs(dist - age * 0.9)
                    if ring < 0.12 {
                        intensity = max(intensity, (1.0 - ring / 0.12) * (1.0 - age / 1.2))
                    }
                }
            }
            // Subtle idle preview pulse if no recent ripple
            if ripples.isEmpty {
                let autoAge = fmod(t * 0.6, 1.2)
                let dist = hypot(nx - 0.5, (ny - 0.5) * 0.45)
                let ring = abs(dist - autoAge * 0.75)
                if ring < 0.14 {
                    intensity = max(intensity, (1.0 - ring / 0.14) * (1.0 - autoAge / 1.2))
                }
            }
            return scale(base, by: min(1.0, intensity))
        case .starsTwinkle:
            let seed = Double((ledIndex * 131 + 7) % 113) / 113.0
            let twinkle = 0.15 + 0.85 * pow(0.5 + 0.5 * sin(t * 3.2 + seed * 12.0), 6)
            return scale(base, by: twinkle)
        case .shadowDisappear:
            let sweep = 0.25 + 0.75 * (0.5 + 0.5 * cos((nx * 3.5 - t * 2.0)))
            return scale(base, by: sweep)
        case .retroSnake:
            let pos = fmod(t * 14.0, Double(AulaConstants.ledCount))
            let diff = abs(Double(ledIndex) - pos)
            let tail = max(0.12, 1.0 - diff / 18.0)
            return scale(base, by: tail)
        case .neonStream:
            let stream = 0.3 + 0.7 * (0.5 + 0.5 * sin(nx * 5.0 - t * 2.6 + ny * 1.5))
            return useRainbow
                ? hsvToRGB(h: fmod(nx * 0.5 - t * 0.2 + 10.0, 1.0), s: 0.85, v: stream)
                : scale(base, by: stream)
        case .sineWave:
            let waveY = 0.5 + 0.38 * sin(nx * 6.28 - t * 2.5)
            let proximity = max(0.15, 1.0 - abs(ny - waveY) * 2.2)
            return scale(base, by: proximity)
        case .retinueScanning:
            let scannerX = 0.5 + 0.48 * sin(t * 1.8)
            let beam = max(0.12, 1.0 - abs(nx - scannerX) * 4.2)
            return scale(base, by: beam)
        case .rotatingWindmill:
            let dx = nx - 0.5
            let dy = (ny - 0.5) * 0.5
            let angle = atan2(dy, dx) + t * 1.6
            let blades = 0.35 + 0.65 * (0.5 + 0.5 * sin(angle * 4.0))
            return hsvToRGB(h: fmod(angle / (2 * .pi) + 10.0, 1.0), s: 0.88, v: blades)
        case .colorfulWaterfall:
            return hsvToRGB(h: fmod(ny * 0.7 - t * 0.4 + nx * 0.15 + 10.0, 1.0), s: 0.9, v: 1.0)
        case .blossoming:
            let dist = hypot(nx - 0.5, (ny - 0.5) * 0.5)
            return hsvToRGB(h: fmod(dist * 1.4 - t * 0.35 + 10.0, 1.0), s: 0.88, v: 1.0)
        case .rotatingStorm:
            let dx = nx - 0.5
            let dy = (ny - 0.5) * 0.5
            let dist = hypot(dx, dy)
            let swirl = atan2(dy, dx) + dist * 6.0 - t * 2.4
            let val = 0.25 + 0.75 * (0.5 + 0.5 * sin(swirl * 2.0))
            return scale(base, by: val)
        case .perKeyCustom:
            return base
        }
    }

    private static func studioColor(
        effect: StudioLiveEffect,
        pos: CGPoint,
        baseColor: RGBColor,
        ripples: [ActiveRipple],
        audioLevel: Double,
        time: TimeInterval
    ) -> RGBColor {
        let nx = Double(pos.x)
        let ny = Double(pos.y)
        switch effect {
        case .none:
            return baseColor
        case .typingRipple:
            var out = scale(baseColor, by: 0.12)
            for ripple in ripples {
                let age = time - ripple.startTime
                guard age >= 0 && age < 1.1 else { continue }
                let dist = hypot(nx - Double(ripple.center.x), (ny - Double(ripple.center.y)) * 0.45)
                let ring = abs(dist - age * 0.95)
                if ring < 0.13 {
                    let strength = (1.0 - ring / 0.13) * (1.0 - age / 1.1)
                    out = blend(out, ripple.color, weight: strength)
                }
            }
            return out
        case .cyberWave:
            let w = 0.5 + 0.5 * sin(nx * 6.0 - time * 2.8 + sin(ny * 4.0 + time))
            return blend(.cyberCyan, .neonMagenta, weight: w)
        case .matrixRain:
            let colSeed = Double(Int(nx * 21.0) * 37 % 29) / 29.0
            let headY = fmod(time * (0.9 + colSeed * 0.7) + colSeed * 5.0, 1.6) - 0.2
            let trail = headY - ny
            if trail >= 0 && trail < 0.65 {
                let v = 1.0 - (trail / 0.65)
                return trail < 0.08 ? RGBColor(r: 200, g: 255, b: 220) : scale(.matrixGreen, by: v)
            }
            return RGBColor(r: 0, g: 24, b: 10)
        case .auroraPlasma:
            let v1 = sin(nx * 4.5 + time * 1.4)
            let v2 = cos(ny * 3.8 - time * 1.1)
            let h = fmod(0.48 + 0.22 * (v1 + v2) * 0.5 + 1.0, 1.0)
            return hsvToRGB(h: h, s: 0.82, v: 0.95)
        case .audioVisualizer:
            let bandPhase = sin(nx * 10.0 + time * 5.0) * 0.18
            let level = min(1.0, max(0.2, audioLevel) + 0.35 * (0.5 + 0.5 * sin(time * 4.2 + nx * 5.0)) + bandPhase)
            let active = (1.0 - ny) <= level
            let barColor = blend(.cyberCyan, .neonMagenta, weight: 1.0 - ny)
            return active ? barColor : scale(barColor, by: 0.12)
        }
    }

    public static func scale(_ color: RGBColor, by factor: Double) -> RGBColor {
        let f = min(max(factor, 0.0), 1.0)
        return RGBColor(
            r: UInt8(clamping: Int((Double(color.r) * f).rounded())),
            g: UInt8(clamping: Int((Double(color.g) * f).rounded())),
            b: UInt8(clamping: Int((Double(color.b) * f).rounded()))
        )
    }

    public static func blend(_ a: RGBColor, _ b: RGBColor, weight: Double) -> RGBColor {
        let t = min(max(weight, 0.0), 1.0)
        return RGBColor(
            r: UInt8(clamping: Int(Double(a.r) * (1.0 - t) + Double(b.r) * t)),
            g: UInt8(clamping: Int(Double(a.g) * (1.0 - t) + Double(b.g) * t)),
            b: UInt8(clamping: Int(Double(a.b) * (1.0 - t) + Double(b.b) * t))
        )
    }

    public static func hsvToRGB(h: Double, s: Double, v: Double) -> RGBColor {
        let hue = (h - floor(h)) * 6.0
        let i = Int(floor(hue))
        let f = hue - Double(i)
        let p = v * (1.0 - s)
        let q = v * (1.0 - s * f)
        let t = v * (1.0 - s * (1.0 - f))
        let (r, g, b): (Double, Double, Double)
        switch i % 6 {
        case 0: (r, g, b) = (v, t, p)
        case 1: (r, g, b) = (q, v, p)
        case 2: (r, g, b) = (p, v, t)
        case 3: (r, g, b) = (p, q, v)
        case 4: (r, g, b) = (t, p, v)
        default: (r, g, b) = (v, p, q)
        }
        return RGBColor(
            r: UInt8(clamping: Int((r * 255.0).rounded())),
            g: UInt8(clamping: Int((g * 255.0).rounded())),
            b: UInt8(clamping: Int((b * 255.0).rounded()))
        )
    }
}
