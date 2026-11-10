import AulaCore
import SwiftUI

/// Interactive 30fps spatial hardware stage rendering the physical AULA F75 (ISO-DE, ANSI-US, or ISO-UK)
/// including the L-shaped ISO Enter key, status LED bar, and knurled metallic rotary knob.
public struct KeyboardStageView: View {
    @ObservedObject var model: AppViewModel
    @State private var lastPaintedKeyID: String?

    public init(model: AppViewModel) {
        self.model = model
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let spec = model.currentLayoutSpec
            let renderedColors = LightingEffectRenderer.renderFrame(
                spec: spec,
                config: model.lighting,
                perKeyColors: model.perKeyColors,
                ripples: model.activeRipples,
                audioLevel: 0.45 + 0.35 * sin(now * 3.1),
                time: now
            )

            GeometryReader { geo in
                let stageTransform = StageTransform(canvasSize: geo.size, layoutSize: spec.size)

                ZStack {
                    Canvas { context, size in
                        drawChassis(context: &context, transform: stageTransform, spec: spec, time: now)
                        drawStatusIndicator(context: &context, transform: stageTransform, spec: spec)
                        drawRotaryKnob(context: &context, transform: stageTransform, spec: spec, time: now)

                        for key in spec.keys {
                            let rgb = renderedColors[key.ledIndex] ?? .off
                            let isSelected = (model.activeTab == .keys && model.selectedKeyForRemap?.id == key.id)
                            drawKey(
                                context: &context,
                                transform: stageTransform,
                                key: key,
                                rgb: rgb,
                                isSelected: isSelected
                            )
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if let hitKey = stageTransform.hitTest(point: value.location, keys: spec.keys) {
                                    if lastPaintedKeyID != hitKey.id {
                                        lastPaintedKeyID = hitKey.id
                                        model.handleStageKeyTap(hitKey)
                                    }
                                }
                            }
                            .onEnded { _ in
                                lastPaintedKeyID = nil
                            }
                    )
                }
                .onChange(of: Int(now * 8)) { _, _ in
                    model.streamLiveFrameIfNeeded(renderedColors: renderedColors, timestamp: now)
                }
            }
        }
    }

    // MARK: - Canvas Drawing Routines

    private func drawChassis(
        context: inout GraphicsContext,
        transform: StageTransform,
        spec: KeyboardLayoutSpec,
        time: TimeInterval
    ) {
        let boardRect = transform.boardRect
        let outerRect = boardRect.insetBy(dx: -14, dy: -12)
        let outerPath = Path(roundedRect: outerRect, cornerRadius: 24, style: .continuous)

        // Ambient underglow shadow
        let p = model.lighting.primaryColor.normalized
        let glowColor = Color(red: p.r, green: p.g, blue: p.b)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 22))
            layer.fill(outerPath, with: .color(glowColor.opacity(Double(model.lighting.brightness) / 9.0 * 0.22)))
        }

        // Main anodized aluminum/obsidian body
        context.fill(
            outerPath,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.13),
                    Color(red: 0.04, green: 0.05, blue: 0.08)
                ]),
                startPoint: CGPoint(x: outerRect.minX, y: outerRect.minY),
                endPoint: CGPoint(x: outerRect.maxX, y: outerRect.maxY)
            )
        )

        // Recessed plate cavity
        let plateRect = boardRect.insetBy(dx: -5, dy: -5)
        let platePath = Path(roundedRect: plateRect, cornerRadius: 16, style: .continuous)
        context.fill(platePath, with: .color(Color(red: 0.03, green: 0.035, blue: 0.055)))

        // Specular hairline rim
        context.stroke(
            outerPath,
            with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(0.24),
                    glowColor.opacity(0.38),
                    Color.white.opacity(0.07)
                ]),
                startPoint: CGPoint(x: outerRect.minX, y: outerRect.minY),
                endPoint: CGPoint(x: outerRect.maxX, y: outerRect.maxY)
            ),
            lineWidth: 1.2
        )
    }

    private func drawStatusIndicator(
        context: inout GraphicsContext,
        transform: StageTransform,
        spec: KeyboardLayoutSpec
    ) {
        let ledRect = transform.rect(for: spec.statusLEDFrame).insetBy(dx: 1.5, dy: 2)
        let path = Path(roundedRect: ledRect, cornerRadius: ledRect.width / 2)
        let linkColor: Color = {
            switch model.activeLink {
            case .wired: return Color(red: 0.15, green: 0.95, blue: 0.65)
            case .receiver: return Color(red: 0.0, green: 0.92, blue: 1.0)
            case .bluetooth: return Color(red: 0.38, green: 0.58, blue: 1.0)
            case .disconnected: return Color.white.opacity(0.25)
            }
        }()
        context.fill(path, with: .color(linkColor))
    }

    private func drawRotaryKnob(
        context: inout GraphicsContext,
        transform: StageTransform,
        spec: KeyboardLayoutSpec,
        time: TimeInterval
    ) {
        let center = transform.point(for: spec.knobCenter)
        let radius = spec.knobRadius * transform.unitScale * 0.94
        let housingRect = CGRect(
            x: center.x - radius * 1.12,
            y: center.y - radius * 1.12,
            width: radius * 2.24,
            height: radius * 2.24
        )
        let p = model.lighting.primaryColor.normalized
        let ringColor = Color(red: p.r, green: p.g, blue: p.b)

        // Glowing accent ring around rotary encoder
        context.stroke(
            Path(ellipseIn: housingRect),
            with: .color(ringColor.opacity(0.75)),
            lineWidth: 1.8
        )

        let knobRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(
            Path(ellipseIn: knobRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.24, green: 0.26, blue: 0.33),
                    Color(red: 0.09, green: 0.10, blue: 0.15)
                ]),
                center: center,
                startRadius: 1,
                endRadius: radius
            )
        )
        context.stroke(Path(ellipseIn: knobRect), with: .color(Color.white.opacity(0.28)), lineWidth: 1)

        // Indicator notch on knob
        let angleRad = (model.knobAngle + sin(time * 0.8) * 8.0) * .pi / 180.0
        let indicatorEnd = CGPoint(
            x: center.x + CGFloat(cos(angleRad)) * radius * 0.68,
            y: center.y + CGFloat(sin(angleRad)) * radius * 0.68
        )
        var notch = Path()
        notch.move(to: center)
        notch.addLine(to: indicatorEnd)
        context.stroke(notch, with: .color(ringColor), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
    }

    private func drawKey(
        context: inout GraphicsContext,
        transform: StageTransform,
        key: KeyboardKey,
        rgb: RGBColor,
        isSelected: Bool
    ) {
        let keyRect = transform.rect(for: key.frame).insetBy(dx: 2.2, dy: 2.2)
        let keyPath = key.isISOEnter
            ? isoEnterPath(in: keyRect, unitScale: transform.unitScale)
            : Path(roundedRect: keyRect, cornerRadius: 7, style: .continuous)

        let c = rgb.normalized
        let ledColor = Color(red: c.r, green: c.g, blue: c.b)
        let intensity = max(c.r, max(c.g, c.b))

        // 1. Per-key RGB switch diffuser glow
        if intensity > 0.02 {
            context.fill(keyPath, with: .color(ledColor.opacity(0.28 + intensity * 0.36)))
        }

        // 2. Sculpted inner keycap top surface
        let capRect = keyRect.insetBy(dx: 2.2, dy: 2.2)
        let capPath = key.isISOEnter
            ? isoEnterPath(in: capRect, unitScale: transform.unitScale - 3.0)
            : Path(roundedRect: capRect, cornerRadius: 5.5, style: .continuous)

        let baseSurfaceColor: Color = {
            switch key.accentStyle {
            case .accent:
                return Color(red: 0.13, green: 0.16, blue: 0.24)
            case .isoSpecial:
                return Color(red: 0.12, green: 0.15, blue: 0.22)
            case .modifier:
                return Color(red: 0.09, green: 0.10, blue: 0.15)
            case .alpha:
                return Color(red: 0.065, green: 0.075, blue: 0.11)
            }
        }()

        context.fill(capPath, with: .color(baseSurfaceColor.opacity(0.90)))

        // Tint keycap top slightly with LED backlight
        if intensity > 0.02 {
            context.fill(capPath, with: .color(ledColor.opacity(0.16 * intensity)))
        }

        // Border stroke (highlight if selected for remapping)
        let borderColor: Color = isSelected
            ? Color(red: 0.0, green: 0.95, blue: 1.0)
            : (intensity > 0.05 ? ledColor.opacity(0.65) : Color.white.opacity(0.14))
        context.stroke(
            keyPath,
            with: .color(borderColor),
            lineWidth: isSelected ? 2.2 : 1.0
        )

        // 3. Keycap Legends (Primary, Secondary top, Tertiary AltGr bottom-right)
        let legendColor: Color = intensity > 0.25
            ? Color.white
            : Color.white.opacity(0.86)

        let fontSize = max(9.0, min(12.0, transform.unitScale * 0.24))
        let subFontSize = max(7.0, min(9.0, transform.unitScale * 0.17))

        if let topLabel = key.secondaryLabel {
            let topText = Text(topLabel)
                .font(.system(size: subFontSize, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.55))
            context.draw(
                topText,
                at: CGPoint(x: capRect.minX + 6, y: capRect.minY + 5),
                anchor: .topLeading
            )
        }

        if let subLabel = key.tertiaryLabel {
            let subText = Text(subLabel)
                .font(.system(size: subFontSize, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0.35, green: 0.88, blue: 1.0).opacity(0.85))
            context.draw(
                subText,
                at: CGPoint(x: capRect.maxX - 5, y: capRect.maxY - 4),
                anchor: .bottomTrailing
            )
        }

        if !key.label.isEmpty {
            let mainText = Text(key.label)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundColor(legendColor)
            let centerPoint = key.isISOEnter
                ? CGPoint(x: capRect.minX + capRect.width * 0.58, y: capRect.midY)
                : CGPoint(
                    x: capRect.midX,
                    y: key.secondaryLabel != nil ? capRect.midY + 4 : capRect.midY
                )
            context.draw(mainText, at: centerPoint, anchor: .center)
        }

        // If on Keys tab and key is remapped to a custom value/macro, draw a subtle badge dot
        if model.activeTab == .keys {
            let code = model.currentAssignmentCode(for: key)
            if code[0] == 0x03 || code == [0, 0, 0, 0] {
                let badgeRect = CGRect(x: capRect.maxX - 8, y: capRect.minY + 3, width: 5, height: 5)
                context.fill(Path(ellipseIn: badgeRect), with: .color(Color(red: 1.0, green: 0.25, blue: 0.55)))
            }
        }
    }

    /// Authentic L-shaped ISO Enter key outline (wider top row 1.5u, stepped 1.25u lower stem)
    private func isoEnterPath(in rect: CGRect, unitScale: CGFloat) -> Path {
        let stepX = rect.minX + rect.width * (0.25 / 1.5)
        let stepY = rect.minY + rect.height * 0.48
        let r: CGFloat = 6.0

        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: stepX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: stepX, y: rect.maxY - r), control: CGPoint(x: stepX, y: rect.maxY))
        p.addLine(to: CGPoint(x: stepX, y: stepY + r))
        p.addQuadCurve(to: CGPoint(x: stepX - r, y: stepY), control: CGPoint(x: stepX, y: stepY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: stepY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: stepY - r), control: CGPoint(x: rect.minX, y: stepY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Coordinate Transform & Hit-Testing

private struct StageTransform {
    let unitScale: CGFloat
    let origin: CGPoint
    let boardRect: CGRect

    init(canvasSize: CGSize, layoutSize: CGSize) {
        let horizontalPadding: CGFloat = 34
        let verticalPadding: CGFloat = 28
        let availW = max(100, canvasSize.width - horizontalPadding * 2)
        let availH = max(80, canvasSize.height - verticalPadding * 2)
        let scale = min(availW / layoutSize.width, availH / layoutSize.height)
        self.unitScale = scale
        let boardW = layoutSize.width * scale
        let boardH = layoutSize.height * scale
        let ox = (canvasSize.width - boardW) / 2.0
        let oy = (canvasSize.height - boardH) / 2.0
        self.origin = CGPoint(x: ox, y: oy)
        self.boardRect = CGRect(x: ox, y: oy, width: boardW, height: boardH)
    }

    func rect(for keyFrame: CGRect) -> CGRect {
        CGRect(
            x: origin.x + keyFrame.minX * unitScale,
            y: origin.y + keyFrame.minY * unitScale,
            width: keyFrame.width * unitScale,
            height: keyFrame.height * unitScale
        )
    }

    func point(for layoutPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: origin.x + layoutPoint.x * unitScale,
            y: origin.y + layoutPoint.y * unitScale
        )
    }

    func hitTest(point: CGPoint, keys: [KeyboardKey]) -> KeyboardKey? {
        for key in keys {
            let r = rect(for: key.frame)
            if key.isISOEnter {
                let stepX = r.minX + r.width * (0.25 / 1.5)
                let stepY = r.minY + r.height * 0.48
                let inTop = CGRect(x: r.minX, y: r.minY, width: r.width, height: stepY - r.minY).contains(point)
                let inBottom = CGRect(x: stepX, y: stepY, width: r.maxX - stepX, height: r.maxY - stepY).contains(point)
                if inTop || inBottom { return key }
            } else if r.contains(point) {
                return key
            }
        }
        return nil
    }
}
