import Foundation

// MARK: - Hardware Constants & Identifiers

public enum AulaConstants: Sendable {
    /// USB-C Wired connection (Sinowealth / BYK916 `CDevG5KB`)
    public static let wiredVendorID = 0x258A
    public static let wiredProductID = 0x010C
    public static let wiredReportID: UInt8 = 0x06
    public static let wiredReportLength = 520
    public static let wiredChunkLength = 512

    /// 2.4 GHz Wireless Receiver (Compx `CDev3632`)
    public static let wirelessVendorID = 0x3554
    public static let receiverProductID = 0xFA09
    public static let bluetoothProductID = 0xFA08
    public static let bluetoothAltProductID = 0xFA07
    public static let wirelessVendorUsagePage = 0xFF02
    public static let wirelessReportID: UInt8 = 0x13
    public static let wirelessPacketLength = 20
    public static let wirelessChunkLength = 14

    /// Matrix & Buffer Dimensions (from AULA `KB.ini`)
    public static let ledCount = 126          // 21 columns × 6 rows (`led = col * 6 + row`)
    public static let matrixLength = 128      // `MatrixLen = 128`
    public static let ledBlockLength = 128    // 128-byte LED configuration block
    public static let paletteLength = 512     // 512-byte colour palette block
    public static let keymapLayerLength = 512 // 128 keys × 4 bytes per layer

    /// Offsets in the 128-byte LED Settings Block
    public static let customModeOffset = 9    // 1 = per-key self-define mode, 0 = built-in effect
    public static let effectIDOffset = 10     // Hardware effect ID (0 = Off, 1..18 = built-in, 21 = Per-key)
    public static let sleepOffset = 0x18      // Sleep timeout hardware value (`SleepHW`)
    public static let effectTableOffset = 0x3A // Start of per-effect [brightness, (speed<<4)|color] pairs
    public static let signatureOffset0 = 126  // Must be `0x5A`
    public static let signatureOffset1 = 127  // Must be `0xA5`

    /// Palette Regions in the 512-byte Wired Palette Block
    public static let wiredPaletteRegions: [(start: Int, length: Int)] = [
        (21, 105),
        (147, 42),
        (210, 84),
        (315, 63)
    ]
}

// MARK: - Transport & Commands

public enum AulaLinkType: String, Codable, CaseIterable, Sendable {
    case wired = "USB-C Wired"
    case receiver = "2.4 GHz Receiver"
    case bluetooth = "Bluetooth"
    case disconnected = "Offline / Demo"

    public var isWireless: Bool {
        self == .receiver || self == .bluetooth
    }

    public var supportsConfigurationWrite: Bool {
        self == .wired || self == .receiver
    }
}

public struct AulaCommandTable: Sendable {
    public let keymap: UInt8
    public let ledMatrix: UInt8
    public let macros: UInt8
    public let ledBlock: UInt8
    public let palette: UInt8
    public let realtime: UInt8
    public let readFlag: UInt8

    public static let wireless = AulaCommandTable(
        keymap: 0x01,
        ledMatrix: 0x02,
        macros: 0x03,
        ledBlock: 0x04,
        palette: 0x09,
        realtime: 0x88,
        readFlag: 0x40
    )

    public static let wired = AulaCommandTable(
        keymap: 0x03,
        ledMatrix: 0x06,
        macros: 0x05,
        ledBlock: 0x04,
        palette: 0x0A,
        realtime: 0x08,
        readFlag: 0x80
    )

    public static let wirelessSaveCmd: UInt8 = 0x0A
    public static let wirelessOnlineCmd: UInt8 = 0x07

    public static func forLink(_ link: AulaLinkType) -> AulaCommandTable {
        link == .wired ? .wired : .wireless
    }
}

// MARK: - Errors

public enum AulaError: LocalizedError, Sendable {
    case deviceNotFound
    case bluetoothWriteUnsupported
    case permissionDenied(String)
    case openFailed(Int32)
    case hidTransferFailed(String, Int32)
    case invalidSettingsSignature
    case incompleteWirelessReply(String)
    case verificationFailed(String)
    case invalidKeymapBlock

    public var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "AULA F75 wurde nicht gefunden. Bitte per USB-C-Kabel oder 2.4-GHz-Empfänger verbinden."
        case .bluetoothWriteUnsupported:
            return "Über Bluetooth ist nur die Statusanzeige verfügbar. Zum Speichern von Profilen bitte 2.4G oder USB-C nutzen."
        case .permissionDenied(let detail):
            return "macOS verweigert den HID-Zugriff (Input Monitoring: \(detail)). Bitte unter Systemeinstellungen → Datenschutz & Sicherheit → Eingabeüberwachung freigeben."
        case .openFailed(let code):
            return "HID-Gerät konnte nicht geöffnet werden (IOReturn 0x\(String(UInt32(bitPattern: code), radix: 16)))."
        case .hidTransferFailed(let op, let code):
            return "\(op) fehlgeschlagen (IOReturn 0x\(String(UInt32(bitPattern: code), radix: 16)))."
        case .invalidSettingsSignature:
            return "Ungültige Hardware-Signatur (5A A5 fehlt) – Schreibvorgang zum Schutz der Tastatur abgebrochen."
        case .incompleteWirelessReply(let detail):
            return "Unvollständige Antwort über 2.4G (\(detail)). Ist die Tastatur im Standby? Bitte eine Taste drücken."
        case .verificationFailed(let detail):
            return "Verifizierung fehlgeschlagen (\(detail)). Vorherige Einstellungen wurden wiederhergestellt."
        case .invalidKeymapBlock:
            return "Gelesene Keymap-Matrix ist unvollständig oder verschoben – Schreibvorgang abgebrochen."
        }
    }
}

// MARK: - RGB & Lighting Model

public struct RGBColor: Hashable, Codable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    public init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        self.init(
            r: UInt8((value >> 16) & 0xFF),
            g: UInt8((value >> 8) & 0xFF),
            b: UInt8(value & 0xFF)
        )
    }

    public var hexString: String {
        String(format: "#%02X%02X%02X", r, g, b)
    }

    public var normalized: (r: Double, g: Double, b: Double) {
        (Double(r) / 255.0, Double(g) / 255.0, Double(b) / 255.0)
    }

    public static let cyberCyan = RGBColor(r: 0, g: 240, b: 255)
    public static let neonMagenta = RGBColor(r: 255, g: 42, b: 133)
    public static let appleIce = RGBColor(r: 210, g: 230, b: 255)
    public static let matrixGreen = RGBColor(r: 0, g: 255, b: 102)
    public static let amberGold = RGBColor(r: 255, g: 180, b: 40)
    public static let ultraViolet = RGBColor(r: 148, g: 82, b: 255)
    public static let crimsonPulse = RGBColor(r: 255, g: 50, b: 60)
    public static let off = RGBColor(r: 0, g: 0, b: 0)
}

/// All 18 hardware effects + Off (0) + Per-Key Custom (21) from AULA's `KB.ini`
public enum AulaLightingEffect: Int, CaseIterable, Codable, Identifiable, Sendable {
    case off = 0
    case fixedOn = 1
    case respire = 2
    case rainbow = 3
    case flashAway = 4
    case raindrops = 5
    case rainbowWheel = 6
    case ripplesShining = 7
    case starsTwinkle = 8
    case shadowDisappear = 9
    case retroSnake = 10
    case neonStream = 11
    case reaction = 12
    case sineWave = 13
    case retinueScanning = 14
    case rotatingWindmill = 15
    case colorfulWaterfall = 16
    case blossoming = 17
    case rotatingStorm = 18
    case perKeyCustom = 21

    public var id: Int { rawValue }

    /// Effects selectable in the main hardware effect gallery
    public static var hardwareEffects: [AulaLightingEffect] {
        allCases.filter { $0 != .perKeyCustom }
    }

    /// Slot index in the 128-byte LED settings block (`0x3A + slot * 2`)
    public var blockSlotIndex: Int? {
        let ordered: [AulaLightingEffect] = [
            .fixedOn, .respire, .rainbow, .flashAway, .raindrops, .rainbowWheel,
            .ripplesShining, .starsTwinkle, .shadowDisappear, .retroSnake, .neonStream,
            .reaction, .sineWave, .retinueScanning, .rotatingWindmill, .colorfulWaterfall,
            .blossoming, .rotatingStorm, .perKeyCustom
        ]
        return ordered.firstIndex(of: self)
    }

    public func title(lang: String = "de") -> String {
        let isDE = lang.lowercased().hasPrefix("de")
        switch self {
        case .off: return isDE ? "Aus" : "LED Off"
        case .fixedOn: return isDE ? "Statisch" : "Fixed On"
        case .respire: return isDE ? "Atmen" : "Respire"
        case .rainbow: return isDE ? "Regenbogen" : "Rainbow"
        case .flashAway: return isDE ? "Aufblitzen" : "Flash Away"
        case .raindrops: return isDE ? "Regentropfen" : "Raindrops"
        case .rainbowWheel: return isDE ? "Farbrad" : "Rainbow Wheel"
        case .ripplesShining: return isDE ? "Wellen (Tipp-Impuls)" : "Ripples"
        case .starsTwinkle: return isDE ? "Sternenfunkeln" : "Stars Twinkle"
        case .shadowDisappear: return isDE ? "Schattenspur" : "Shadow Fade"
        case .retroSnake: return isDE ? "Retro Snake" : "Retro Snake"
        case .neonStream: return isDE ? "Neon-Strom" : "Neon Stream"
        case .reaction: return isDE ? "Reaktion (Tasten)" : "Reaction"
        case .sineWave: return isDE ? "Sinuswelle" : "Sine Wave"
        case .retinueScanning: return isDE ? "Scanner" : "Scanner"
        case .rotatingWindmill: return isDE ? "Windmühle" : "Windmill"
        case .colorfulWaterfall: return isDE ? "Wasserfall" : "Waterfall"
        case .blossoming: return isDE ? "Aufblühen" : "Blossoming"
        case .rotatingStorm: return isDE ? "Rotierender Sturm" : "Rotating Storm"
        case .perKeyCustom: return isDE ? "Per-Key Studio" : "Per-Key Custom"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .off: return "moon.zzz.fill"
        case .fixedOn: return "sun.max.fill"
        case .respire: return "wind"
        case .rainbow: return "rainbow"
        case .flashAway: return "bolt.horizontal.fill"
        case .raindrops: return "cloud.rain.fill"
        case .rainbowWheel: return "circle.hexagongrid.fill"
        case .ripplesShining: return "dot.radiowaves.left.and.right"
        case .starsTwinkle: return "sparkles"
        case .shadowDisappear: return "rays"
        case .retroSnake: return "scribble.variable"
        case .neonStream: return "water.waves"
        case .reaction: return "hand.tap.fill"
        case .sineWave: return "waveform.path.ecg"
        case .retinueScanning: return "barcode.viewfinder"
        case .rotatingWindmill: return "fanblades.fill"
        case .colorfulWaterfall: return "arrow.down.to.line.compact"
        case .blossoming: return "camera.macro"
        case .rotatingStorm: return "hurricane"
        case .perKeyCustom: return "paintbrush.pointed.fill"
        }
    }

    public var supportsCustomColor: Bool {
        switch self {
        case .off, .rainbow, .rotatingWindmill, .colorfulWaterfall, .blossoming, .perKeyCustom:
            return false
        default:
            return true
        }
    }

    public var supportsSpeed: Bool {
        self != .off && self != .fixedOn && self != .perKeyCustom
    }

    public var isTypingReactive: Bool {
        self == .ripplesShining || self == .reaction
    }
}

/// Host-driven live studio animations rendered at 30-50 fps
public enum StudioLiveEffect: String, CaseIterable, Codable, Identifiable, Sendable {
    case none = "Off"
    case typingRipple = "Typing Ripple"
    case cyberWave = "Cyber Horizon"
    case matrixRain = "Matrix Digital Rain"
    case auroraPlasma = "Aurora Spatial"
    case audioVisualizer = "Audio Pulse"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .none: return "pause.circle"
        case .typingRipple: return "water.waves.and.arrow.up"
        case .cyberWave: return "waveform.path"
        case .matrixRain: return "chevron.down.dotted.2"
        case .auroraPlasma: return "aqi.medium"
        case .audioVisualizer: return "waveform"
        }
    }
}

public struct LightingConfiguration: Hashable, Codable, Sendable {
    public var effect: AulaLightingEffect
    public var brightness: Int      // 0..9
    public var speed: Int           // 0..4
    public var rainbowMode: Bool    // true = multicolour (7), false = single colour
    public var colorSlot: Int       // 0..6 (Red, Green, Blue, Yellow, Magenta, Cyan, White)
    public var primaryColor: RGBColor
    public var studioLiveEffect: StudioLiveEffect

    public init(
        effect: AulaLightingEffect = .neonStream,
        brightness: Int = 8,
        speed: Int = 2,
        rainbowMode: Bool = false,
        colorSlot: Int = 5,
        primaryColor: RGBColor = .cyberCyan,
        studioLiveEffect: StudioLiveEffect = .none
    ) {
        self.effect = effect
        self.brightness = min(max(brightness, 0), 9)
        self.speed = min(max(speed, 0), 4)
        self.rainbowMode = rainbowMode
        self.colorSlot = min(max(colorSlot, 0), 6)
        self.primaryColor = primaryColor
        self.studioLiveEffect = studioLiveEffect
    }
}

// MARK: - Sleep Timeout Options (`SleepHW` in `KB.ini`)

public enum AulaSleepTimeout: Int, CaseIterable, Codable, Identifiable, Sendable {
    case never = 0
    case oneMinute = 60
    case ninetySeconds = 90
    case twoMinutes = 120
    case threeMinutes = 180
    case fourMinutes = 240
    case fiveMinutes = 300
    case tenMinutes = 600
    case fifteenMinutes = 900
    case twentyMinutes = 1200

    public var id: Int { rawValue }

    public var hardwareByte: UInt8 {
        switch self {
        case .never: return 0
        case .oneMinute: return 2
        case .ninetySeconds: return 3
        case .twoMinutes: return 4
        case .threeMinutes: return 6
        case .fourMinutes: return 8
        case .fiveMinutes: return 10
        case .tenMinutes: return 20
        case .fifteenMinutes: return 30
        case .twentyMinutes: return 40
        }
    }

    public static func fromHardwareByte(_ byte: UInt8) -> AulaSleepTimeout {
        allCases.first { $0.hardwareByte == byte } ?? .fiveMinutes
    }

    public func label(lang: String = "de") -> String {
        let isDE = lang.lowercased().hasPrefix("de")
        switch self {
        case .never: return isDE ? "Nie (Immer an)" : "Never"
        case .oneMinute: return "1 Min"
        case .ninetySeconds: return "1.5 Min"
        case .twoMinutes: return "2 Min"
        case .threeMinutes: return "3 Min"
        case .fourMinutes: return "4 Min"
        case .fiveMinutes: return "5 Min"
        case .tenMinutes: return "10 Min"
        case .fifteenMinutes: return "15 Min"
        case .twentyMinutes: return "20 Min"
        }
    }
}

// MARK: - Packet Framing & Protocol Codec

public enum AulaProtocolCodec: Sendable {

    // MARK: 20-Byte Wireless Packet Framing (`0x13`)

    public static func wirelessChecksum(_ packet: [UInt8]) -> UInt8 {
        packet.prefix(AulaConstants.wirelessPacketLength - 1).reduce(0, &+)
    }

    public static func isValidWirelessPacket(_ packet: [UInt8]) -> Bool {
        guard packet.count >= AulaConstants.wirelessPacketLength,
              packet[0] == AulaConstants.wirelessReportID else {
            return false
        }
        return packet[19] == wirelessChecksum(packet)
    }

    /// Splits arbitrary data into 20-byte `0x13` wireless packets (`CDev3632::AccessData`)
    public static func buildWirelessWritePackets(cmd: UInt8, sub: UInt8, data: [UInt8]) -> [[UInt8]] {
        let chunkLen = AulaConstants.wirelessChunkLength
        let total = max(1, (data.count + chunkLen - 1) / chunkLen)
        var packets: [[UInt8]] = []
        packets.reserveCapacity(total)

        for index in 0..<total {
            let start = index * chunkLen
            let end = min(start + chunkLen, data.count)
            let slice = start < end ? Array(data[start..<end]) : []

            var pkt = [UInt8](repeating: 0, count: AulaConstants.wirelessPacketLength)
            pkt[0] = AulaConstants.wirelessReportID
            pkt[1] = cmd
            pkt[2] = UInt8(total & 0xFF)
            pkt[3] = UInt8(index & 0xFF)
            pkt[4] = (sub << 4) | UInt8(slice.count & 0x0F)
            for (i, byte) in slice.enumerated() {
                pkt[5 + i] = byte
            }
            pkt[19] = wirelessChecksum(pkt)
            packets.append(pkt)
        }
        return packets
    }

    /// Builds a 20-byte `0x13` wireless read request (`SendCMD_3632`)
    public static func buildWirelessReadRequest(cmd: UInt8, sub: UInt8 = 0) -> [UInt8] {
        var pkt = [UInt8](repeating: 0, count: AulaConstants.wirelessPacketLength)
        pkt[0] = AulaConstants.wirelessReportID
        pkt[1] = cmd
        pkt[2] = 0x01
        pkt[3] = 0x00
        pkt[4] = sub << 4
        pkt[19] = wirelessChecksum(pkt)
        return pkt
    }

    /// Builds the wireless commit/save command (`0x0A`)
    public static func buildWirelessSavePacket() -> [UInt8] {
        var pkt = [UInt8](repeating: 0, count: AulaConstants.wirelessPacketLength)
        pkt[0] = AulaConstants.wirelessReportID
        pkt[1] = AulaCommandTable.wirelessSaveCmd
        pkt[2] = 0x01
        pkt[3] = 0x00
        pkt[4] = 0x04
        pkt[5] = 0x07
        pkt[19] = wirelessChecksum(pkt)
        return pkt
    }

    public struct WirelessReply: Sendable, Equatable {
        public let cmd: UInt8
        public let crcError: Bool
        public let total: Int
        public let index: Int
        public let payloadLength: Int
        public let payload: [UInt8]
    }

    public static func parseWirelessReply(_ bytes: [UInt8]) -> WirelessReply? {
        guard bytes.count >= AulaConstants.wirelessPacketLength,
              bytes[0] == AulaConstants.wirelessReportID else {
            return nil
        }
        let len = min(Int(bytes[4] & 0x0F), AulaConstants.wirelessChunkLength)
        return WirelessReply(
            cmd: bytes[1] & 0x7F,
            crcError: (bytes[1] & 0x80 != 0) || (bytes[2] & 0x80 != 0),
            total: Int(bytes[2] & 0x7F),
            index: Int(bytes[3]),
            payloadLength: len,
            payload: Array(bytes[5..<(5 + len)])
        )
    }

    // MARK: 520-Byte Wired Feature Report Framing (`0x06`)

    /// Builds 520-byte `0x06` feature reports for USB-C wired communication (`CDevG5KB::AccessData`)
    public static func buildWiredPackets(cmd: UInt8, sub: UInt8, totalLength: Int, data: [UInt8]?) -> [[UInt8]] {
        let chunkLen = AulaConstants.wiredChunkLength
        let total = max(1, (totalLength + chunkLen - 1) / chunkLen)
        var packets: [[UInt8]] = []
        packets.reserveCapacity(total)

        for index in 0..<total {
            let offset = index * chunkLen
            let size = min(totalLength - offset, chunkLen)
            var pkt = [UInt8](repeating: 0, count: AulaConstants.wiredReportLength)
            pkt[0] = AulaConstants.wiredReportID
            pkt[1] = cmd
            pkt[2] = sub
            pkt[3] = 0x00
            pkt[4] = UInt8(total & 0xFF)
            pkt[5] = UInt8(index & 0xFF)
            pkt[6] = UInt8(size & 0xFF)
            pkt[7] = UInt8((size >> 8) & 0xFF)
            if let data, offset + size <= data.count {
                pkt.replaceSubrange(8..<(8 + size), with: data[offset..<(offset + size)])
            }
            packets.append(pkt)
        }
        return packets
    }

    // MARK: 128-Byte LED Settings Block Validation & Non-Destructive Editing

    public static func isLEDBlockValid(_ block: [UInt8]) -> Bool {
        block.count >= AulaConstants.ledBlockLength &&
        block[AulaConstants.signatureOffset0] == 0x5A &&
        block[AulaConstants.signatureOffset1] == 0xA5
    }

    /// Creates a clean, valid 128-byte synthetic default LED block (used for offline testing/preview)
    public static func defaultLEDBlock() -> [UInt8] {
        var block = [UInt8](repeating: 0, count: AulaConstants.ledBlockLength)
        block[9] = 0
        block[10] = UInt8(AulaLightingEffect.neonStream.rawValue)
        block[AulaConstants.sleepOffset] = AulaSleepTimeout.fiveMinutes.hardwareByte
        block[0x38] = 0xFF
        block[0x39] = 0xFF
        for slot in 0..<19 {
            let o = AulaConstants.effectTableOffset + slot * 2
            block[o] = 8
            block[o + 1] = (2 << 4) | 0x07
        }
        block[AulaConstants.signatureOffset0] = 0x5A
        block[AulaConstants.signatureOffset1] = 0xA5
        return block
    }

    /// Patches only the lighting fields in an existing 128-byte LED block (`0x0048d810`), preserving Fn shortcuts & other parameters
    public static func patchLEDBlock(_ block: inout [UInt8], config: LightingConfiguration) {
        guard block.count >= AulaConstants.ledBlockLength else { return }
        let mode = config.effect
        block[AulaConstants.customModeOffset] = (mode == .perKeyCustom) ? 1 : 0
        block[AulaConstants.effectIDOffset] = UInt8(mode.rawValue)

        if mode == .perKeyCustom {
            block[59] = 0x47
        } else if let slot = mode.blockSlotIndex {
            let offset = AulaConstants.effectTableOffset + slot * 2
            let clampedBrightness = UInt8(min(max(config.brightness, 0), 9))
            let clampedSpeed = UInt8(min(max(config.speed, 0), 4))
            let useRainbow = !mode.supportsCustomColor || config.rainbowMode
            let colorNibble: UInt8 = useRainbow ? 0x07 : UInt8(min(max(config.colorSlot, 0), 6))
            block[offset] = clampedBrightness
            block[offset + 1] = (clampedSpeed << 4) | (colorNibble & 0x0F)
        }
    }

    /// Patches the wireless sleep timeout (`0x18`) in the 128-byte LED block
    public static func patchSleepTimeout(_ block: inout [UInt8], timeout: AulaSleepTimeout) {
        guard block.count >= AulaConstants.ledBlockLength else { return }
        block[AulaConstants.sleepOffset] = timeout.hardwareByte
    }

    /// Parses the active lighting configuration and sleep timeout from a 128-byte LED block
    public static func parseLEDBlock(_ block: [UInt8], fallbackColor: RGBColor = .cyberCyan) -> (LightingConfiguration, AulaSleepTimeout)? {
        guard isLEDBlockValid(block) else { return nil }
        let rawEffect = Int(block[AulaConstants.effectIDOffset])
        let effect = AulaLightingEffect(rawValue: rawEffect) ?? .fixedOn
        let sleep = AulaSleepTimeout.fromHardwareByte(block[AulaConstants.sleepOffset])

        let lookupEffect = (effect == .off) ? .fixedOn : effect
        let slot = lookupEffect.blockSlotIndex ?? 0
        let offset = AulaConstants.effectTableOffset + slot * 2
        let brightness = min(Int(block[offset]), 9)
        let flags = block[offset + 1]
        let speed = min(Int(flags >> 4), 4)
        let nibble = Int(flags & 0x0F)
        let rainbow = (nibble == 7)

        let config = LightingConfiguration(
            effect: effect,
            brightness: brightness,
            speed: speed,
            rainbowMode: rainbow,
            colorSlot: min(nibble, 6),
            primaryColor: fallbackColor,
            studioLiveEffect: .none
        )
        return (config, sleep)
    }

    // MARK: Per-Key RGB & Live Streaming Payloads

    /// Builds the 384-byte planar RGB matrix (`R[126] + G[126] + B[126] + 6 padding bytes`) for `ledMatrix` (`0x02` wireless / `0x06` wired)
    public static func buildPerKeyMatrixPayload(colors: [RGBColor]) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: AulaConstants.matrixLength * 3) // 384 bytes
        let count = min(colors.count, AulaConstants.ledCount)
        for led in 0..<count {
            let c = colors[led]
            buffer[0 * AulaConstants.ledCount + led] = c.r
            buffer[1 * AulaConstants.ledCount + led] = c.g
            buffer[2 * AulaConstants.ledCount + led] = c.b
        }
        return buffer
    }

    /// Builds the 378-byte interleaved RGB payload (`126 * 3`) for real-time streaming (`0x08` wired / `0x88` wireless)
    public static func buildRealtimeInterleavedPayload(colors: [RGBColor]) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: AulaConstants.ledCount * 3)
        let count = min(colors.count, AulaConstants.ledCount)
        for led in 0..<count {
            let c = colors[led]
            buffer[led * 3] = c.r
            buffer[led * 3 + 1] = c.g
            buffer[led * 3 + 2] = c.b
        }
        return buffer
    }

    /// Compact wireless live RGB groups (`[R, G, B, count, leds...]`) for fast 2.4G/BT live effects
    public static func buildCompactWirelessLivePackets(groups: [(color: RGBColor, leds: [Int])]) -> [[UInt8]] {
        var data: [UInt8] = []
        for group in groups where !group.leds.isEmpty {
            data.append(group.color.r)
            data.append(group.color.g)
            data.append(group.color.b)
            data.append(UInt8(min(group.leds.count, 126)))
            for led in group.leds.prefix(126) {
                data.append(UInt8(clamping: led))
            }
        }
        let chunkLen = AulaConstants.wirelessChunkLength
        let chunks = stride(from: 0, to: data.count, by: chunkLen).map {
            Array(data[$0..<min($0 + chunkLen, data.count)])
        }
        return chunks.enumerated().map { idx, chunk in
            var pkt = [UInt8](repeating: 0, count: AulaConstants.wirelessPacketLength)
            pkt[0] = AulaConstants.wirelessReportID
            pkt[1] = 0x88
            pkt[2] = UInt8(chunks.count)
            pkt[3] = UInt8(idx)
            pkt[4] = 0x10 + UInt8(chunk.count)
            pkt.replaceSubrange(5..<(5 + chunk.count), with: chunk)
            pkt[19] = wirelessChecksum(pkt)
            return pkt
        }
    }

    /// Patches the 512-byte wired colour palette with a custom RGB colour
    public static func patchWiredPalette(_ palette: inout [UInt8], color: RGBColor) {
        guard palette.count >= AulaConstants.paletteLength else { return }
        for region in AulaConstants.wiredPaletteRegions {
            for idx in stride(from: region.start, to: region.start + region.length, by: 3) {
                palette[idx] = color.r
                palette[idx + 1] = color.g
                palette[idx + 2] = color.b
            }
        }
    }
}

// MARK: - Keymap & Remapping Engine

public struct KeyAssignment: Hashable, Codable, Identifiable, Sendable {
    public var id: String { "\(category.rawValue)-\(label)-\(code.map { String(format: "%02X", $0) }.joined())" }
    public let label: String
    public let category: Category
    public let code: [UInt8] // 4-byte hardware code `[type, mod, hi, lo]`

    public enum Category: String, CaseIterable, Codable, Sendable {
        case letters = "Letters"
        case numbers = "Numbers & Symbols"
        case function = "F-Keys"
        case navigation = "Navigation & Editing"
        case modifiers = "Modifiers (Mac / Win)"
        case media = "Media & System"
        case macros = "Hardware Macros"
    }

    public init(label: String, category: Category, code: [UInt8]) {
        self.label = label
        self.category = category
        self.code = code
    }

    public static func keyboard(label: String, category: Category, usage: UInt8, modifiers: UInt8 = 0) -> KeyAssignment {
        KeyAssignment(label: label, category: category, code: [0x00, modifiers, 0x00, usage])
    }

    public static func consumer(label: String, usage: UInt16) -> KeyAssignment {
        KeyAssignment(
            label: label,
            category: .media,
            code: [0x02, 0x00, UInt8((usage >> 8) & 0xFF), UInt8(usage & 0xFF)]
        )
    }

    public static func macro(index: UInt8, repeatCount: UInt8 = 1, mode: UInt8 = 1) -> KeyAssignment {
        KeyAssignment(
            label: "Macro #\(index + 1)",
            category: .macros,
            code: [0x03, mode, max(1, repeatCount), index]
        )
    }
}

public enum AulaKeymapCatalog: Sendable {
    public static let allTargets: [KeyAssignment] = {
        var list: [KeyAssignment] = [
            KeyAssignment(label: "Disabled", category: .navigation, code: [0, 0, 0, 0])
        ]
        // Letters A-Z
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        for (i, ch) in letters.enumerated() {
            list.append(.keyboard(label: String(ch), category: .letters, usage: UInt8(0x04 + i)))
        }
        // Numbers 1-0
        let digits = Array("1234567890")
        for (i, ch) in digits.enumerated() {
            list.append(.keyboard(label: String(ch), category: .numbers, usage: UInt8(0x1E + i)))
        }
        // Symbols & ISO keys
        let symbols: [(String, UInt8)] = [
            ("- / ß", 0x2D), ("= / ´", 0x2E), ("[ / Ü", 0x2F), ("] / +", 0x30),
            ("\\", 0x31), ("# / ' (ISO)", 0x32), ("; / Ö", 0x33), ("' / Ä", 0x34),
            ("` / ^°", 0x35), (", / ;", 0x36), (". / :", 0x37), ("/ / -", 0x38),
            ("< > | (ISO)", 0x64)
        ]
        for (label, usage) in symbols {
            list.append(.keyboard(label: label, category: .numbers, usage: usage))
        }
        // Function Keys F1-F12
        for i in 0..<12 {
            list.append(.keyboard(label: "F\(i + 1)", category: .function, usage: UInt8(0x3A + i)))
        }
        // Navigation & Editing
        let nav: [(String, UInt8)] = [
            ("Enter ↵", 0x28), ("Esc", 0x29), ("Backspace ⌫", 0x2A), ("Tab ⇥", 0x2B),
            ("Space", 0x2C), ("Caps Lock ⇪", 0x39), ("Print Screen", 0x46), ("Scroll Lock", 0x47),
            ("Pause", 0x48), ("Insert", 0x49), ("Home", 0x4A), ("Page Up", 0x4B),
            ("Delete ⌦", 0x4C), ("End", 0x4D), ("Page Down", 0x4E),
            ("Right →", 0x4F), ("Left ←", 0x50), ("Down ↓", 0x51), ("Up ↑", 0x52)
        ]
        for (label, usage) in nav {
            list.append(.keyboard(label: label, category: .navigation, usage: usage))
        }
        // Modifiers
        let mods: [(String, UInt8)] = [
            ("Left Control ⌃", 1 << 0),
            ("Left Shift ⇧", 1 << 1),
            ("Left Option / Alt ⌥", 1 << 2),
            ("Left Command / Win ⌘", 1 << 3),
            ("Right Control ⌃", 1 << 4),
            ("Right Shift ⇧", 1 << 5),
            ("Right Option / AltGr ⌥", 1 << 6),
            ("Right Command / Super ⌘", 1 << 7)
        ]
        for (label, mask) in mods {
            list.append(.keyboard(label: label, category: .modifiers, usage: 0x00, modifiers: mask))
        }
        // Media & System
        let media: [(String, UInt16)] = [
            ("Play / Pause ⏯", 0x00CD), ("Next Track ⏭", 0x00B5), ("Previous Track ⏮", 0x00B6),
            ("Stop ⏹", 0x00B7), ("Mute 🔇", 0x00E2), ("Volume Up 🔊", 0x00E9),
            ("Volume Down 🔉", 0x00EA), ("Calculator", 0x0192), ("Browser", 0x0196), ("Mail", 0x018A)
        ]
        for (label, usage) in media {
            list.append(.consumer(label: label, usage: usage))
        }
        // Hardware Macros 1..8
        for i in 0..<8 {
            list.append(.macro(index: UInt8(i)))
        }
        return list
    }()

    public static func describe(code: [UInt8]) -> String {
        guard code.count == 4 else { return "Unknown" }
        if code == [0, 0, 0, 0] { return "Disabled" }
        if code == [0x0D, 0, 0, 0] { return "Fn (Hardware Layer)" }
        if let match = allTargets.first(where: { $0.code == code }) {
            return match.label
        }
        if code[0] == 0x03 {
            return "Macro #\(code[3] + 1) (×\(code[2]))"
        }
        return code.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    /// Generates the 512-byte factory Layer 0 keymap for the Aula F75 (`KB.ini` verified)
    public static func factoryLayer0() -> [UInt8] {
        var km = [UInt8](repeating: 0, count: AulaConstants.keymapLayerLength)
        let pairs: [(Int, [UInt8])] = [
            (0, [0x00, 0x00, 0x00, 0x29]),  // Esc
            (12, [0x00, 0x00, 0x00, 0x3A]), // F1
            (18, [0x00, 0x00, 0x00, 0x3B]), // F2
            (24, [0x00, 0x00, 0x00, 0x3C]), // F3
            (30, [0x00, 0x00, 0x00, 0x3D]), // F4
            (36, [0x00, 0x00, 0x00, 0x3E]), // F5
            (42, [0x00, 0x00, 0x00, 0x3F]), // F6
            (48, [0x00, 0x00, 0x00, 0x40]), // F7
            (54, [0x00, 0x00, 0x00, 0x41]), // F8
            (60, [0x00, 0x00, 0x00, 0x42]), // F9
            (66, [0x00, 0x00, 0x00, 0x43]), // F10
            (72, [0x00, 0x00, 0x00, 0x44]), // F11
            (78, [0x00, 0x00, 0x00, 0x45]), // F12
            (1, [0x00, 0x00, 0x00, 0x35]),  // ` / ^
            (7, [0x00, 0x00, 0x00, 0x1E]),  // 1
            (13, [0x00, 0x00, 0x00, 0x1F]), // 2
            (19, [0x00, 0x00, 0x00, 0x20]), // 3
            (25, [0x00, 0x00, 0x00, 0x21]), // 4
            (31, [0x00, 0x00, 0x00, 0x22]), // 5
            (37, [0x00, 0x00, 0x00, 0x23]), // 6
            (43, [0x00, 0x00, 0x00, 0x24]), // 7
            (49, [0x00, 0x00, 0x00, 0x25]), // 8
            (55, [0x00, 0x00, 0x00, 0x26]), // 9
            (61, [0x00, 0x00, 0x00, 0x27]), // 0
            (67, [0x00, 0x00, 0x00, 0x2D]), // - / ß
            (73, [0x00, 0x00, 0x00, 0x2E]), // = / ´
            (79, [0x00, 0x00, 0x00, 0x2A]), // Backspace
            (85, [0x00, 0x00, 0x00, 0x4C]), // Delete
            (2, [0x00, 0x00, 0x00, 0x2B]),  // Tab
            (8, [0x00, 0x00, 0x00, 0x14]),  // Q
            (14, [0x00, 0x00, 0x00, 0x1A]), // W
            (20, [0x00, 0x00, 0x00, 0x08]), // E
            (26, [0x00, 0x00, 0x00, 0x15]), // R
            (32, [0x00, 0x00, 0x00, 0x17]), // T
            (38, [0x00, 0x00, 0x00, 0x1C]), // Y / Z
            (44, [0x00, 0x00, 0x00, 0x18]), // U
            (50, [0x00, 0x00, 0x00, 0x0C]), // I
            (56, [0x00, 0x00, 0x00, 0x12]), // O
            (62, [0x00, 0x00, 0x00, 0x13]), // P
            (68, [0x00, 0x00, 0x00, 0x2F]), // [ / Ü
            (74, [0x00, 0x00, 0x00, 0x30]), // ] / +
            (80, [0x00, 0x00, 0x00, 0x31]), // \
            (86, [0x00, 0x00, 0x00, 0x4B]), // PgUp
            (3, [0x00, 0x00, 0x00, 0x39]),  // Caps
            (9, [0x00, 0x00, 0x00, 0x04]),  // A
            (15, [0x00, 0x00, 0x00, 0x16]), // S
            (21, [0x00, 0x00, 0x00, 0x07]), // D
            (27, [0x00, 0x00, 0x00, 0x09]), // F
            (33, [0x00, 0x00, 0x00, 0x0A]), // G
            (39, [0x00, 0x00, 0x00, 0x0B]), // H
            (45, [0x00, 0x00, 0x00, 0x0D]), // J
            (51, [0x00, 0x00, 0x00, 0x0E]), // K
            (57, [0x00, 0x00, 0x00, 0x0F]), // L
            (63, [0x00, 0x00, 0x00, 0x33]), // ; / Ö
            (69, [0x00, 0x00, 0x00, 0x34]), // ' / Ä
            (75, [0x00, 0x00, 0x00, 0x32]), // ISO # '
            (81, [0x00, 0x00, 0x00, 0x28]), // Enter
            (87, [0x00, 0x00, 0x00, 0x4E]), // PgDn
            (4, [0x00, 0x02, 0x00, 0x00]),  // LShift
            (76, [0x00, 0x00, 0x00, 0x64]), // ISO < > |
            (10, [0x00, 0x00, 0x00, 0x1D]), // Z / Y
            (16, [0x00, 0x00, 0x00, 0x1B]), // X
            (22, [0x00, 0x00, 0x00, 0x06]), // C
            (28, [0x00, 0x00, 0x00, 0x19]), // V
            (34, [0x00, 0x00, 0x00, 0x05]), // B
            (40, [0x00, 0x00, 0x00, 0x11]), // N
            (46, [0x00, 0x00, 0x00, 0x10]), // M
            (52, [0x00, 0x00, 0x00, 0x36]), // ,
            (58, [0x00, 0x00, 0x00, 0x37]), // .
            (64, [0x00, 0x00, 0x00, 0x38]), // / / -
            (70, [0x00, 0x20, 0x00, 0x00]), // RShift
            (82, [0x00, 0x00, 0x00, 0x52]), // Up
            (88, [0x00, 0x00, 0x00, 0x4D]), // End
            (5, [0x00, 0x01, 0x00, 0x00]),  // LCtrl
            (11, [0x00, 0x08, 0x00, 0x00]), // LWin / Option
            (17, [0x00, 0x04, 0x00, 0x00]), // LAlt / Command
            (35, [0x00, 0x00, 0x00, 0x2C]), // Space
            (53, [0x0D, 0x00, 0x00, 0x00]), // Fn
            (59, [0x00, 0x10, 0x00, 0x00]), // RCtrl
            (77, [0x00, 0x00, 0x00, 0x50]), // Left
            (83, [0x00, 0x00, 0x00, 0x51]), // Down
            (89, [0x00, 0x00, 0x00, 0x4F])  // Right
        ]
        for (led, code) in pairs {
            km.replaceSubrange((led * 4)..<(led * 4 + 4), with: code)
        }
        return km
    }

    /// Verifies that a read Layer 0 keymap is valid and not shifted by a dropped radio packet
    public static func isKeymapPlausible(_ layer0: [UInt8]) -> Bool {
        guard layer0.count >= AulaConstants.keymapLayerLength else { return false }
        // Esc at slot 0 must be 00 00 00 29
        guard Array(layer0[0..<4]) == [0x00, 0x00, 0x00, 0x29] else { return false }
        // Fn at slot 53 must remain intact (0x0D 0 0 0) or non-shifted
        let checkSlots: [(Int, UInt8)] = [(7, 0x1E), (8, 0x14), (9, 0x04), (20, 0x08), (44, 0x18)]
        let matches = checkSlots.filter { slot, usage in
            Array(layer0[(slot * 4)..<(slot * 4 + 4)]) == [0x00, 0x00, 0x00, usage]
        }.count
        return matches >= 4
    }
}

// MARK: - Hardware Macro Compiler (`FUN_0048d2d0` & `FUN_0048cf00`)

public struct AulaMacroEvent: Hashable, Codable, Identifiable, Sendable {
    public var id = UUID()
    public var usage: UInt8
    public var isKeyDown: Bool
    public var delayMs: UInt32

    public init(id: UUID = UUID(), usage: UInt8, isKeyDown: Bool, delayMs: UInt32) {
        self.id = id
        self.usage = usage
        self.isKeyDown = isKeyDown
        self.delayMs = delayMs
    }

    public var isModifier: Bool {
        (0xE0...0xE7).contains(usage)
    }
}

public struct AulaMacro: Hashable, Codable, Identifiable, Sendable {
    public var id = UUID()
    public var index: Int
    public var name: String
    public var textInput: String
    public var stepDelayMs: UInt32
    public var events: [AulaMacroEvent]

    public init(
        id: UUID = UUID(),
        index: Int,
        name: String,
        textInput: String = "",
        stepDelayMs: UInt32 = 18,
        events: [AulaMacroEvent] = []
    ) {
        self.id = id
        self.index = index
        self.name = name
        self.textInput = textInput
        self.stepDelayMs = stepDelayMs
        self.events = events.isEmpty && !textInput.isEmpty
            ? Self.compileTextEvents(textInput, delayMs: stepDelayMs)
            : events
    }

    /// Compiles a string into HID key-down / key-up macro events
    public static func compileTextEvents(_ text: String, delayMs: UInt32 = 18) -> [AulaMacroEvent] {
        var out: [AulaMacroEvent] = []
        for ch in text {
            guard let (usage, needsShift) = charToHIDUsage(ch) else { continue }
            if needsShift {
                out.append(AulaMacroEvent(usage: 0xE1, isKeyDown: true, delayMs: 4))
            }
            out.append(AulaMacroEvent(usage: usage, isKeyDown: true, delayMs: delayMs))
            out.append(AulaMacroEvent(usage: usage, isKeyDown: false, delayMs: 4))
            if needsShift {
                out.append(AulaMacroEvent(usage: 0xE1, isKeyDown: false, delayMs: delayMs))
            }
        }
        return out
    }

    private static func charToHIDUsage(_ ch: Character) -> (UInt8, Bool)? {
        if let ascii = ch.asciiValue {
            if ascii >= UInt8(ascii: "a") && ascii <= UInt8(ascii: "z") {
                return (0x04 + (ascii - UInt8(ascii: "a")), false)
            }
            if ascii >= UInt8(ascii: "A") && ascii <= UInt8(ascii: "Z") {
                return (0x04 + (ascii - UInt8(ascii: "A")), true)
            }
        }
        let plain = Array("1234567890\n\t -=[]\\;'`,./")
        let plainCodes: [UInt8] = [
            0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
            0x28, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x33, 0x34,
            0x35, 0x36, 0x37, 0x38
        ]
        if let idx = plain.firstIndex(of: ch) {
            return (plainCodes[idx], false)
        }
        let shifted = Array("!@#$%^&*()_+{}|:\"~<>?")
        let shiftedCodes: [UInt8] = [
            0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
            0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38
        ]
        if let idx = shifted.firstIndex(of: ch) {
            return (shiftedCodes[idx], true)
        }
        return nil
    }

    /// Serializes a single macro into `[name_len, UTF-16LE name, 4-byte events...]`
    public func serializeBlob() -> [UInt8] {
        let utf16Units = Array(name.utf16.prefix(30))
        var nameBytes: [UInt8] = []
        nameBytes.reserveCapacity(utf16Units.count * 2)
        for unit in utf16Units {
            nameBytes.append(UInt8(unit & 0xFF))
            nameBytes.append(UInt8((unit >> 8) & 0xFF))
        }
        var blob: [UInt8] = [UInt8(nameBytes.count)]
        blob.append(contentsOf: nameBytes)

        for ev in events {
            let clampedDelay = min(ev.delayMs, 0xFFFFF)
            let kind: UInt8 = ev.isModifier ? 1 : 0
            var head = (kind << 4) | UInt8((clampedDelay >> 16) & 0x0F)
            if !ev.isKeyDown {
                head |= 0x80
            }
            blob.append(head)
            blob.append(UInt8((clampedDelay >> 8) & 0xFF))
            blob.append(UInt8(clampedDelay & 0xFF))
            blob.append(ev.usage)
        }
        return blob
    }

    /// Compiles an array of macros into the hardware macro buffer (`N * [addr u16, size u16] + blobs`)
    public static func compileBuffer(_ macros: [AulaMacro]) -> [UInt8] {
        let blobs = macros.map { $0.serializeBlob() }
        var out: [UInt8] = []
        var currentAddr = macros.count * 4
        for blob in blobs {
            let addr = UInt16(clamping: currentAddr)
            let size = UInt16(clamping: blob.count)
            out.append(UInt8(addr & 0xFF))
            out.append(UInt8((addr >> 8) & 0xFF))
            out.append(UInt8(size & 0xFF))
            out.append(UInt8((size >> 8) & 0xFF))
            currentAddr += blob.count
        }
        for blob in blobs {
            out.append(contentsOf: blob)
        }
        return out
    }
}
