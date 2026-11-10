import CoreGraphics
import Foundation

/// Supported physical & regional keyboard layouts for the Aula F75
public enum KeyboardLayoutVariant: String, CaseIterable, Codable, Identifiable, Sendable {
    case isoDE = "ISO-DE (QWERTZ)"
    case ansiUS = "ANSI (US QWERTY)"
    case isoUK = "ISO-UK (QWERTY)"

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .isoDE: return "ISO-DE"
        case .ansiUS: return "ANSI-US"
        case .isoUK: return "ISO-UK"
        }
    }

    public var isISO: Bool {
        self == .isoDE || self == .isoUK
    }
}

/// Keycap colour accent group on the F75
public enum KeycapAccentStyle: String, Codable, Sendable {
    case alpha       // Main typing keys
    case modifier    // Outer modifiers & F-row
    case accent      // Esc, Enter, Space, Arrow keys
    case isoSpecial  // ISO extra keys (<>|, #')
}

/// One physical key on the Aula F75 canvas, bound to its exact Sinowealth hardware LED/matrix slot (`0..125`)
public struct KeyboardKey: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let secondaryLabel: String?
    public let tertiaryLabel: String?
    public let ledIndex: Int
    public let frame: CGRect
    public let row: Int
    public let accentStyle: KeycapAccentStyle
    public let isISOEnter: Bool

    public init(
        id: String,
        label: String,
        secondaryLabel: String? = nil,
        tertiaryLabel: String? = nil,
        ledIndex: Int,
        frame: CGRect,
        row: Int,
        accentStyle: KeycapAccentStyle = .alpha,
        isISOEnter: Bool = false
    ) {
        self.id = id
        self.label = label
        self.secondaryLabel = secondaryLabel
        self.tertiaryLabel = tertiaryLabel
        self.ledIndex = ledIndex
        self.frame = frame
        self.row = row
        self.accentStyle = accentStyle
        self.isISOEnter = isISOEnter
    }
}

/// Complete geometry specification for drawing the Aula F75 (non-Max: 80/81 keys + Rotary Knob, no TFT screen)
public struct KeyboardLayoutSpec: Sendable {
    public let variant: KeyboardLayoutVariant
    public let macMode: Bool
    public let keys: [KeyboardKey]
    public let size: CGSize
    public let knobCenter: CGPoint
    public let knobRadius: CGFloat
    public let statusLEDFrame: CGRect
}

public enum KeyboardLayoutCatalog: Sendable {

    public static func layout(for variant: KeyboardLayoutVariant, macMode: Bool = true) -> KeyboardLayoutSpec {
        var builder = LayoutBuilder()

        // Row 0: Function Row (Esc, Status LED Bar, F1-F4, F5-F8, F9-F12, Rotary Knob at x=15.5)
        builder.startRow(0, y: 0.0)
        builder.add("Esc", id: "Esc", led: 0, width: 1.0, style: .accent)
        builder.skip(0.5)
        let fLeds = [12, 18, 24, 30, 36, 42, 48, 54, 60, 66, 72, 78]
        let fIcons = ["☀️-", "☀️+", "Mission", "Search", "🎙", "🌙", "⏮", "⏯", "⏭", "🔇", "🔉", "🔊"]
        for i in 0..<12 {
            if i == 4 || i == 8 { builder.skip(0.25) }
            let style: KeycapAccentStyle = (i >= 4 && i <= 7) ? .modifier : .alpha
            builder.add("F\(i + 1)", id: "F\(i + 1)", top: fIcons[i], led: fLeds[i], width: 1.0, style: style)
        }

        // Row 1: Number Row
        builder.startRow(1, y: 1.22)
        switch variant {
        case .isoDE:
            builder.add("^", id: "Grave", top: "°", led: 1, style: .modifier)
            builder.add("1", id: "1", top: "!", led: 7)
            builder.add("2", id: "2", top: "\"", sub: "²", led: 13)
            builder.add("3", id: "3", top: "§", sub: "³", led: 19)
            builder.add("4", id: "4", top: "$", led: 25)
            builder.add("5", id: "5", top: "%", led: 31)
            builder.add("6", id: "6", top: "&", led: 37)
            builder.add("7", id: "7", top: "/", sub: "{", led: 43)
            builder.add("8", id: "8", top: "(", sub: "[", led: 49)
            builder.add("9", id: "9", top: ")", sub: "]", led: 55)
            builder.add("0", id: "0", top: "=", sub: "}", led: 61)
            builder.add("ß", id: "Minus", top: "?", sub: "\\", led: 67)
            builder.add("´", id: "Equal", top: "`", led: 73)
        case .isoUK:
            builder.add("`", id: "Grave", top: "¬", sub: "¦", led: 1, style: .modifier)
            builder.add("1", id: "1", top: "!", led: 7)
            builder.add("2", id: "2", top: "\"", led: 13)
            builder.add("3", id: "3", top: "£", led: 19)
            builder.add("4", id: "4", top: "$", sub: "€", led: 25)
            builder.add("5", id: "5", top: "%", led: 31)
            builder.add("6", id: "6", top: "^", led: 37)
            builder.add("7", id: "7", top: "&", led: 43)
            builder.add("8", id: "8", top: "*", led: 49)
            builder.add("9", id: "9", top: "(", led: 55)
            builder.add("0", id: "0", top: ")", led: 61)
            builder.add("-", id: "Minus", top: "_", led: 67)
            builder.add("=", id: "Equal", top: "+", led: 73)
        case .ansiUS:
            builder.add("`", id: "Grave", top: "~", led: 1, style: .modifier)
            let tops = ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"]
            let numLeds = [7, 13, 19, 25, 31, 37, 43, 49, 55, 61]
            let nums = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
            for i in 0..<10 {
                builder.add(nums[i], id: nums[i], top: tops[i], led: numLeds[i])
            }
            builder.add("-", id: "Minus", top: "_", led: 67)
            builder.add("=", id: "Equal", top: "+", led: 73)
        }
        builder.add("⌫", id: "Backspace", top: "Bksp", led: 79, width: 2.0, style: .modifier)
        builder.skip(0.15)
        builder.add(variant == .isoDE ? "Entf" : "Del", id: "Del", led: 85, width: 1.0, style: .modifier)

        // Row 2: Top Alpha Row (Tab + Q..P + Brackets)
        builder.startRow(2, y: 2.22)
        builder.add("Tab", id: "Tab", top: "⇥", led: 2, width: 1.5, style: .modifier)
        let row2Letters = variant == .isoDE
            ? ["Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P"]
            : ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
        let row2Leds = [8, 14, 20, 26, 32, 38, 44, 50, 56, 62]
        for (idx, ch) in row2Letters.enumerated() {
            let sub: String? = (variant == .isoDE && ch == "Q") ? "@" : ((variant == .isoDE && ch == "E") ? "€" : nil)
            builder.add(ch, id: "R2_\(idx)", sub: sub, led: row2Leds[idx])
        }

        switch variant {
        case .isoDE:
            builder.add("Ü", id: "LBracket", led: 68)
            builder.add("+", id: "RBracket", top: "*", sub: "~", led: 74)
            // ISO Enter spans Row 2 (x: 13.5..15.0) and Row 3 (x: 13.75..15.0)
            builder.addISOEnter(label: "↵", id: "Enter", led: 81, x: 13.5, y: 2.22, width: 1.5, height: 2.0)
        case .isoUK:
            builder.add("[", id: "LBracket", top: "{", led: 68)
            builder.add("]", id: "RBracket", top: "}", led: 74)
            builder.addISOEnter(label: "↵", id: "Enter", led: 81, x: 13.5, y: 2.22, width: 1.5, height: 2.0)
        case .ansiUS:
            builder.add("[", id: "LBracket", top: "{", led: 68)
            builder.add("]", id: "RBracket", top: "}", led: 74)
            builder.add("\\", id: "Backslash", top: "|", led: 80, width: 1.5, style: .modifier)
        }
        builder.setX(15.15)
        builder.add(variant == .isoDE ? "Bild↑" : "PgUp", id: "PgUp", led: 86, width: 1.0, style: .modifier)

        // Row 3: Home Row (Caps + A..L + Semicolon/Quote + Enter)
        builder.startRow(3, y: 3.22)
        builder.add("Caps", id: "Caps", top: "⇪", led: 3, width: 1.75, style: .modifier)
        let row3Letters = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
        let row3Leds = [9, 15, 21, 27, 33, 39, 45, 51, 57]
        for (idx, ch) in row3Letters.enumerated() {
            builder.add(ch, id: ch, led: row3Leds[idx])
        }
        switch variant {
        case .isoDE:
            builder.add("Ö", id: "Semicolon", led: 63)
            builder.add("Ä", id: "Quote", led: 69)
            builder.add("#", id: "ISO_Hash", top: "'", led: 75, width: 1.0, style: .isoSpecial)
            // Skip 1.25u occupied by bottom of ISO Enter
            builder.setX(15.15)
        case .isoUK:
            builder.add(";", id: "Semicolon", top: ":", led: 63)
            builder.add("'", id: "Quote", top: "@", led: 69)
            builder.add("#", id: "ISO_Hash", top: "~", led: 75, width: 1.0, style: .isoSpecial)
            builder.setX(15.15)
        case .ansiUS:
            builder.add(";", id: "Semicolon", top: ":", led: 63)
            builder.add("'", id: "Quote", top: "\"", led: 69)
            builder.add("Enter ↵", id: "Enter", led: 81, width: 2.25, style: .accent)
            builder.skip(0.15)
        }
        builder.add(variant == .isoDE ? "Bild↓" : "PgDn", id: "PgDn", led: 87, width: 1.0, style: .modifier)

        // Row 4: Shift Row
        builder.startRow(4, y: 4.22)
        if variant.isISO {
            builder.add("⇧", id: "LShift", top: "Shift", led: 4, width: 1.25, style: .modifier)
            let isoLeftLabel = variant == .isoDE ? "<" : "\\"
            let isoLeftTop = variant == .isoDE ? ">" : "|"
            let isoLeftSub: String? = variant == .isoDE ? "|" : nil
            builder.add(isoLeftLabel, id: "ISO_Backslash", top: isoLeftTop, sub: isoLeftSub, led: 76, width: 1.0, style: .isoSpecial)
        } else {
            builder.add("Shift ⇧", id: "LShift", led: 4, width: 2.25, style: .modifier)
        }

        let row4Letters = variant == .isoDE
            ? ["Y", "X", "C", "V", "B", "N", "M"]
            : ["Z", "X", "C", "V", "B", "N", "M"]
        let row4Leds = [10, 16, 22, 28, 34, 40, 46]
        for (idx, ch) in row4Letters.enumerated() {
            let sub: String? = (variant == .isoDE && ch == "M") ? "µ" : nil
            builder.add(ch, id: "R4_\(idx)", sub: sub, led: row4Leds[idx])
        }

        if variant == .isoDE {
            builder.add(",", id: "Comma", top: ";", led: 52)
            builder.add(".", id: "Period", top: ":", led: 58)
            builder.add("-", id: "Slash", top: "_", led: 64)
        } else {
            builder.add(",", id: "Comma", top: "<", led: 52)
            builder.add(".", id: "Period", top: ">", led: 58)
            builder.add("/", id: "Slash", top: "?", led: 64)
        }
        builder.add("⇧", id: "RShift", top: "Shift", led: 70, width: 1.75, style: .modifier)
        builder.add("↑", id: "Up", led: 82, width: 1.0, style: .accent)
        builder.skip(0.15)
        builder.add(variant == .isoDE ? "Ende" : "End", id: "End", led: 88, width: 1.0, style: .modifier)

        // Row 5: Bottom Modifiers + Spacebar + Arrow Cluster
        builder.startRow(5, y: 5.22)
        builder.add("⌃", id: "LCtrl", top: variant == .isoDE ? "Strg" : "Ctrl", led: 5, width: 1.25, style: .modifier)
        if macMode {
            builder.add("⌥", id: "LWin", top: "Option", led: 11, width: 1.25, style: .modifier)
            builder.add("⌘", id: "LAlt", top: "Cmd", led: 17, width: 1.25, style: .modifier)
        } else {
            builder.add("Win", id: "LWin", top: "❖", led: 11, width: 1.25, style: .modifier)
            builder.add("Alt", id: "LAlt", led: 17, width: 1.25, style: .modifier)
        }
        builder.add("", id: "Space", led: 35, width: 6.25, style: .accent)
        builder.add("Fn", id: "Fn", top: "✦", led: 53, width: 1.0, style: .modifier)
        if macMode {
            builder.add("⌥", id: "RCtrl", top: variant == .isoDE ? "AltGr" : "Opt", led: 59, width: 1.0, style: .modifier)
        } else {
            builder.add(variant == .isoDE ? "AltGr" : "Ctrl", id: "RCtrl", led: 59, width: 1.0, style: .modifier)
        }

        // Slightly offset arrow cluster (signature Aula F75 look)
        builder.setX(12.25)
        builder.yOffset = 0.08
        builder.add("←", id: "Left", led: 77, width: 1.0, style: .accent)
        builder.add("↓", id: "Down", led: 83, width: 1.0, style: .accent)
        builder.add("→", id: "Right", led: 89, width: 1.0, style: .accent)

        return KeyboardLayoutSpec(
            variant: variant,
            macMode: macMode,
            keys: builder.keys,
            size: CGSize(width: 16.15, height: 6.35),
            knobCenter: CGPoint(x: 15.65, y: 0.5),
            knobRadius: 0.45,
            statusLEDFrame: CGRect(x: 1.18, y: 0.2, width: 0.1, height: 0.6)
        )
    }
}

private struct LayoutBuilder {
    var keys: [KeyboardKey] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var row: Int = 0
    var yOffset: CGFloat = 0

    mutating func startRow(_ row: Int, y: CGFloat) {
        self.row = row
        self.y = y
        self.x = 0
        self.yOffset = 0
    }

    mutating func skip(_ dx: CGFloat) {
        x += dx
    }

    mutating func setX(_ newX: CGFloat) {
        x = newX
    }

    mutating func add(
        _ label: String,
        id: String,
        top: String? = nil,
        sub: String? = nil,
        led: Int,
        width: CGFloat = 1.0,
        style: KeycapAccentStyle = .alpha
    ) {
        let frame = CGRect(x: x, y: y + yOffset, width: width, height: 1.0)
        keys.append(KeyboardKey(
            id: id,
            label: label,
            secondaryLabel: top,
            tertiaryLabel: sub,
            ledIndex: led,
            frame: frame,
            row: row,
            accentStyle: style,
            isISOEnter: false
        ))
        x += width
    }

    mutating func addISOEnter(
        label: String,
        id: String,
        led: Int,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) {
        let frame = CGRect(x: x, y: y, width: width, height: height)
        keys.append(KeyboardKey(
            id: id,
            label: label,
            secondaryLabel: "Enter",
            tertiaryLabel: nil,
            ledIndex: led,
            frame: frame,
            row: row,
            accentStyle: .accent,
            isISOEnter: true
        ))
    }
}
