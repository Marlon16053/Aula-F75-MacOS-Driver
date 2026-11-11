import AppKit
import AulaCore
import Combine
import Foundation
import SwiftUI

public typealias RGBColor = AulaCore.RGBColor

// MARK: - 5-Button Bottom Navigation Tabs (Instagram / TikTok Inspired)

public enum NavigationTab: String, CaseIterable, Identifiable, Sendable {
    case home = "home"
    case explore = "explore"
    case create = "create"
    case keys = "keys"
    case system = "system"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .home: return "house.fill"
        case .explore: return "magnifyingglass"
        case .create: return "plus"
        case .keys: return "keyboard"
        case .system: return "person.crop.circle"
        }
    }

    public func title(lang: String) -> String {
        let isDE = lang.lowercased().hasPrefix("de")
        switch self {
        case .home: return "Home"
        case .explore: return isDE ? "Suche" : "Explore"
        case .create: return "Studio"
        case .keys: return isDE ? "Tasten" : "Keys"
        case .system: return isDE ? "Profil" : "Profile"
        }
    }

    public var isCenterAction: Bool {
        self == .create
    }
}

// MARK: - Studio Painting Tools & Filters

public enum PaintTool: String, CaseIterable, Identifiable, Sendable {
    case brush = "Brush"
    case bucketFill = "Fill All"
    case rowFill = "Row Fill"
    case gradient = "Cyber Gradient"
    case eyedropper = "Eyedropper"
    case eraser = "Eraser"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .brush: return "paintbrush.pointed.fill"
        case .bucketFill: return "drop.fill"
        case .rowFill: return "rectangle.split.1x2.fill"
        case .gradient: return "swatchpalette.fill"
        case .eyedropper: return "eyedropper.halffull"
        case .eraser: return "eraser.fill"
        }
    }

    public func label(lang: String) -> String {
        let isDE = lang.lowercased().hasPrefix("de")
        switch self {
        case .brush: return isDE ? "Pinsel" : "Brush"
        case .bucketFill: return isDE ? "Alle füllen" : "Fill All"
        case .rowFill: return isDE ? "Reihe füllen" : "Row Fill"
        case .gradient: return isDE ? "Verlauf" : "Gradient"
        case .eyedropper: return isDE ? "Pipette" : "Eyedropper"
        case .eraser: return isDE ? "Radierer" : "Eraser"
        }
    }
}

public enum ExploreFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case effects = "Effects"
    case moods = "Moods"
    case shortcuts = "Fn-Keys"

    public var id: String { rawValue }

    public func label(lang: String) -> String {
        let isDE = lang.lowercased().hasPrefix("de")
        switch self {
        case .all: return isDE ? "Alles" : "All"
        case .effects: return isDE ? "18 Effekte" : "18 Effects"
        case .moods: return isDE ? "Szenen" : "Moods"
        case .shortcuts: return isDE ? "Fn-Kürzel" : "Fn-Shortcuts"
        }
    }
}

// MARK: - Profiles, Moods & Shortcuts

public struct AulaProfile: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var icon: String
    public var accentHex: String
    public var lighting: LightingConfiguration
    public var sleepTimeout: AulaSleepTimeout
    public var perKeyColors: [Int: RGBColor]

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        accentHex: String,
        lighting: LightingConfiguration,
        sleepTimeout: AulaSleepTimeout = .fiveMinutes,
        perKeyColors: [Int: RGBColor] = [:]
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.accentHex = accentHex
        self.lighting = lighting
        self.sleepTimeout = sleepTimeout
        self.perKeyColors = perKeyColors
    }
}

public struct AulaMoodPreset: Identifiable, Sendable {
    public let id: String
    public let titleDE: String
    public let titleEN: String
    public let subtitleDE: String
    public let subtitleEN: String
    public let icon: String
    public let tags: [String]
    public let config: LightingConfiguration
}

public struct FnShortcutItem: Identifiable, Sendable {
    public let id: String
    public let keys: String
    public let titleDE: String
    public let titleEN: String
    public let category: String
}

public struct HardwareSafetyBackup: Codable, Sendable {
    public let createdAt: Date
    public let linkType: String
    public let ledSettingsBlock: [UInt8]
    public let layer0Keymap: [UInt8]?
}

// MARK: - Main Application ViewModel

@MainActor
public final class AppViewModel: ObservableObject {

    // Navigation & UI State
    @Published public var activeTab: NavigationTab = .home
    @Published public var language: String = "de"
    @Published public var selectedLayout: KeyboardLayoutVariant = .isoDE
    @Published public var macMode: Bool = true

    // Hardware Connection & Diagnostics
    @Published public var activeLink: AulaLinkType = .disconnected
    @Published public var wiredPresent: Bool = false
    @Published public var receiverPresent: Bool = false
    @Published public var bluetoothPresent: Bool = false
    @Published public var keyboardAwake: Bool = true
    @Published public var hasInputMonitoring: Bool = true
    @Published public var endpoints: [HIDEndpointDescriptor] = []
    @Published public var isBusy: Bool = false
    @Published public var statusBanner: String = "Bereit · AULA F75 Studio"
    @Published public var isErrorBanner: Bool = false
    @Published public var activityLogs: [String] = []
    @Published public var safetyBackup: HardwareSafetyBackup?

    // Lighting & Sleep State
    @Published public var lighting: LightingConfiguration = LightingConfiguration()
    @Published public var sleepTimeout: AulaSleepTimeout = .fiveMinutes
    @Published public var liveHardwareStreamEnabled: Bool = false
    @Published public var autoOffOnMacSleep: Bool = true
    private var lightingBeforeMacSleep: LightingConfiguration?

    // Studio Per-Key & Interactive Stage State
    @Published public var perKeyColors: [Int: RGBColor] = [:]
    @Published public var selectedPaintTool: PaintTool = .brush
    @Published public var paintBrushColor: RGBColor = .cyberCyan
    @Published public var secondaryGradientColor: RGBColor = .neonMagenta
    @Published public var activeRipples: [LightingEffectRenderer.ActiveRipple] = []
    @Published public var knobAngle: Double = 220.0

    // Keymap & Macro Studio State
    @Published public var selectedLayer: Int = 0
    @Published public var layer0Keymap: [UInt8] = AulaKeymapCatalog.factoryLayer0()
    @Published public var layer1Keymap: [UInt8] = [UInt8](repeating: 0, count: AulaConstants.keymapLayerLength)
    @Published public var selectedKeyForRemap: KeyboardKey?
    @Published public var selectedAssignmentCategory: KeyAssignment.Category = .modifiers
    @Published public var keySearchFilter: String = ""
    @Published public var macros: [AulaMacro] = []
    @Published public var selectedMacroID: UUID?

    // Explore / Search & Profiles
    @Published public var searchQuery: String = ""
    @Published public var exploreFilter: ExploreFilter = .all
    @Published public var profiles: [AulaProfile] = []
    @Published public var activeProfileID: UUID?

    private let hidManager = AulaHIDManager()
    private var pollTimer: Timer?
    private var lastLiveStreamTime: TimeInterval = 0

    public init() {
        setupDefaultProfilesAndMacros()
        loadSafetyBackupFromDisk()
        refreshEndpoints()

        if !hasInputMonitoring && activeLink.supportsConfigurationWrite {
            _ = AulaHIDManager.requestInputMonitoringAccess()
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasGranted = self.hasInputMonitoring
                self.refreshEndpoints(silent: true)
                if !wasGranted && self.hasInputMonitoring {
                    self.syncFromKeyboard()
                }
            }
        }

        // Periodic non-intrusive hardware discovery every 3.5 seconds
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshEndpoints(silent: true)
            }
        }

        registerMacSleepAndPowerObservers()
    }

    private func registerMacSleepAndPowerObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        let sleepNames: [NSNotification.Name] = [
            NSWorkspace.willSleepNotification,
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.willPowerOffNotification
        ]
        for name in sleepNames {
            wsCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleMacGoingToSleepOrOff()
                }
            }
        }

        let wakeNames: [NSNotification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification
        ]
        for name in wakeNames {
            wsCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleMacWakingUp()
                }
            }
        }
    }

    private func handleMacGoingToSleepOrOff() {
        guard autoOffOnMacSleep, activeLink.supportsConfigurationWrite else { return }
        if lighting.effect != .off {
            lightingBeforeMacSleep = lighting
        }
        var offConfig = lighting
        offConfig.effect = .off
        offConfig.brightness = 0
        offConfig.studioLiveEffect = .none
        let safeSleep: AulaSleepTimeout = (sleepTimeout == .never) ? .oneMinute : sleepTimeout
        lighting.effect = .off
        appendLog("Mac entering sleep/shutdown -> turning off AULA F75 LEDs immediately")
        // Synchronous fast write before macOS suspends USB/HID
        _ = try? hidManager.applyLightingAndSleep(config: offConfig, sleepTimeout: safeSleep)
    }

    private func handleMacWakingUp() {
        guard autoOffOnMacSleep, let previous = lightingBeforeMacSleep else { return }
        lightingBeforeMacSleep = nil
        lighting = previous
        appendLog("Mac woke up -> restoring AULA F75 lighting (\(previous.effect.rawValue))")
        applyLightingToKeyboard()
    }

    // MARK: Localization Helper

    public func t(_ de: String, _ en: String) -> String {
        language.lowercased().hasPrefix("de") ? de : en
    }

    public var currentLayoutSpec: KeyboardLayoutSpec {
        KeyboardLayoutCatalog.layout(for: selectedLayout, macMode: macMode)
    }

    // MARK: Curated Moods & Shortcuts

    public let curatedMoods: [AulaMoodPreset] = [
        AulaMoodPreset(
            id: "cyber-blade",
            titleDE: "Cyberpunk 2099",
            titleEN: "Cyberpunk 2099",
            subtitleDE: "Cyan & Neon-Magenta Horizont-Welle",
            subtitleEN: "Cyan & Neon-Magenta horizon wave",
            icon: "sparkles.tv.fill",
            tags: ["cyber", "neon", "cyan", "pink", "gaming"],
            config: LightingConfiguration(effect: .neonStream, brightness: 9, speed: 3, rainbowMode: false, colorSlot: 5, primaryColor: .cyberCyan, studioLiveEffect: .cyberWave)
        ),
        AulaMoodPreset(
            id: "apple-spatial",
            titleDE: "Cupertino Ice",
            titleEN: "Cupertino Ice",
            subtitleDE: "Minimalistisches Eisblau für fokussiertes Coding",
            subtitleEN: "Minimalist ice-blue for deep focus coding",
            icon: "apple.logo",
            tags: ["apple", "minimal", "white", "ice", "focus", "work"],
            config: LightingConfiguration(effect: .fixedOn, brightness: 6, speed: 1, rainbowMode: false, colorSlot: 6, primaryColor: .appleIce, studioLiveEffect: .none)
        ),
        AulaMoodPreset(
            id: "matrix-operator",
            titleDE: "Matrix Operator",
            titleEN: "Matrix Operator",
            subtitleDE: "Digitaler Code-Regen in Smaragdgrün",
            subtitleEN: "Digital code rain in emerald green",
            icon: "terminal.fill",
            tags: ["matrix", "green", "rain", "hacker", "code"],
            config: LightingConfiguration(effect: .raindrops, brightness: 8, speed: 3, rainbowMode: false, colorSlot: 1, primaryColor: .matrixGreen, studioLiveEffect: .matrixRain)
        ),
        AulaMoodPreset(
            id: "aurora-night",
            titleDE: "Polarlicht Studio",
            titleEN: "Aurora Studio",
            subtitleDE: "Sanft fließendes Aurora-Plasma",
            subtitleEN: "Smoothly flowing northern lights plasma",
            icon: "aqi.medium",
            tags: ["aurora", "chill", "night", "ambient", "purple"],
            config: LightingConfiguration(effect: .sineWave, brightness: 7, speed: 2, rainbowMode: true, colorSlot: 4, primaryColor: .ultraViolet, studioLiveEffect: .auroraPlasma)
        ),
        AulaMoodPreset(
            id: "reactive-pulse",
            titleDE: "Tipp-Impuls Pro",
            titleEN: "Reactive Pulse Pro",
            subtitleDE: "Schockwellen bei jedem Tastenanschlag",
            subtitleEN: "Shockwaves on every keystroke",
            icon: "dot.radiowaves.left.and.right",
            tags: ["ripple", "typing", "reactive", "wave"],
            config: LightingConfiguration(effect: .ripplesShining, brightness: 9, speed: 4, rainbowMode: false, colorSlot: 5, primaryColor: .cyberCyan, studioLiveEffect: .none)
        ),
        AulaMoodPreset(
            id: "amber-lounge",
            titleDE: "Warmes Bernstein",
            titleEN: "Warm Amber Lounge",
            subtitleDE: "Augenschonendes Warmlicht für späte Nächte",
            subtitleEN: "Eye-friendly warm glow for late-night sessions",
            icon: "flame.fill",
            tags: ["warm", "amber", "gold", "night", "eye"],
            config: LightingConfiguration(effect: .respire, brightness: 5, speed: 1, rainbowMode: false, colorSlot: 3, primaryColor: .amberGold, studioLiveEffect: .none)
        )
    ]

    public let fnShortcuts: [FnShortcutItem] = [
        FnShortcutItem(id: "fn-mac", keys: "Fn + E", titleDE: "macOS-Modus aktivieren (⌥ / ⌘ & F-Tasten)", titleEN: "Enable macOS Mode (⌥ / ⌘ & Media F-Keys)", category: "System"),
        FnShortcutItem(id: "fn-win", keys: "Fn + W", titleDE: "Windows-Modus aktivieren", titleEN: "Enable Windows Mode", category: "System"),
        FnShortcutItem(id: "fn-24g", keys: "Fn + ~ (^)", titleDE: "2.4 GHz Funk-Kanal (Lang drücken = Pairing)", titleEN: "2.4 GHz Wireless Channel (Hold to Pair)", category: "Wireless"),
        FnShortcutItem(id: "fn-bt1", keys: "Fn + 1 / 2 / 3", titleDE: "Bluetooth-Kanäle BT1, BT2, BT3 wechseln", titleEN: "Switch Bluetooth Channels BT1, BT2, BT3", category: "Wireless"),
        FnShortcutItem(id: "fn-usb", keys: "Fn + 4", titleDE: "USB-C Kabelmodus aktivieren", titleEN: "Switch to USB-C Wired Mode", category: "Wireless"),
        FnShortcutItem(id: "fn-fx", keys: "Fn + \\ (oder #)", titleDE: "Durch die 18 Hardware-Lichteffekte schalten", titleEN: "Cycle through 18 Hardware Lighting Effects", category: "RGB"),
        FnShortcutItem(id: "fn-color", keys: "Fn + Tab", titleDE: "Leuchtfarbe des aktuellen Effekts wechseln", titleEN: "Switch LED Color of Active Effect", category: "RGB"),
        FnShortcutItem(id: "fn-bright", keys: "Fn + ↑ / ↓", titleDE: "LED-Helligkeit erhöhen / verringern", titleEN: "Increase / Decrease LED Brightness", category: "RGB"),
        FnShortcutItem(id: "fn-speed", keys: "Fn + ← / →", titleDE: "Effekt-Geschwindigkeit anpassen", titleEN: "Adjust Lighting Animation Speed", category: "RGB"),
        FnShortcutItem(id: "fn-bat", keys: "Fn + B", titleDE: "Akkustand per Zahlenreihe 1–0 anzeigen", titleEN: "Show Battery Level on Number Row 1–0", category: "Battery"),
        FnShortcutItem(id: "fn-knob", keys: "Drehregler (5s halten)", titleDE: "Drehregler zwischen Lautstärke & RGB-Helligkeit umschalten", titleEN: "Toggle Rotary Knob between Volume & RGB Mode", category: "Hardware"),
        FnShortcutItem(id: "fn-reset", keys: "Fn + Esc (3s)", titleDE: "Werkseinstellungen der Tastatur wiederherstellen", titleEN: "Factory Reset Keyboard", category: "System")
    ]

    // MARK: Hardware Discovery & Permissions

    public func refreshEndpoints(silent: Bool = false) {
        hasInputMonitoring = AulaHIDManager.hasInputMonitoringAccess
        let scan = hidManager.scanEndpoints()
        activeLink = scan.activeLink
        wiredPresent = scan.wiredPresent
        receiverPresent = scan.receiverPresent
        bluetoothPresent = scan.bluetoothPresent
        endpoints = scan.endpoints

        if !silent {
            switch scan.activeLink {
            case .wired:
                setBanner(t("Verbunden über USB-C (258A:010C) · Voller Direktzugriff", "Connected via USB-C (258A:010C) · Full Direct Access"))
            case .receiver:
                setBanner(t("2.4 GHz Empfänger erkannt (3554:FA09 · Kanal 0xFF02 aktiv)", "2.4 GHz Receiver detected (3554:FA09 · Channel 0xFF02 active)"))
            case .bluetooth:
                setBanner(t("Bluetooth erkannt · Für Profil-Uploads bitte 2.4G oder USB-C nutzen", "Bluetooth detected · Use 2.4G or USB-C to flash changes"))
            case .disconnected:
                setBanner(t("Kein Empfänger erkannt · Interaktiver Studio-Vorschaumodus", "No receiver detected · Interactive Studio Preview Mode"))
            }
        }
    }

    public func requestPermissions() {
        _ = AulaHIDManager.requestInputMonitoringAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        appendLog("Requested macOS Input Monitoring permission")
    }

    // MARK: Hardware Read / Sync (`0x44` / `0x84`)

    public func syncFromKeyboard() {
        guard !isBusy else { return }
        isBusy = true
        setBanner(t("Lese aktuelle Konfiguration von AULA F75 …", "Reading configuration from AULA F75 …"))

        let manager = hidManager
        let currentColor = lighting.primaryColor
        Task.detached {
            let result = Result { try manager.readLEDSettingsBlock() }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success(let (block, link, logs)):
                    self.activeLink = link
                    self.keyboardAwake = true
                    for entry in logs { self.appendLog(entry) }
                    self.ensureSafetyBackup(block: block, link: link)
                    if let (parsedConfig, parsedSleep) = AulaProtocolCodec.parseLEDBlock(block, fallbackColor: currentColor) {
                        self.lighting = parsedConfig
                        self.sleepTimeout = parsedSleep
                    }
                    self.setBanner(self.t(
                        "Synchronisiert über \(link.rawValue) (\(self.lighting.effect.title(lang: self.language)), Standby: \(self.sleepTimeout.label(lang: self.language)))",
                        "Synced via \(link.rawValue) (\(self.lighting.effect.title(lang: self.language)), Sleep: \(self.sleepTimeout.label(lang: self.language)))"
                    ))
                case .failure(let error):
                    self.appendLog("ERROR: \(error.localizedDescription)")
                    self.setBanner(error.localizedDescription, isError: true)
                }
            }
        }
    }

    // MARK: Hardware Write Lighting & Sleep (`0x04` + `0x0A`)

    public func applyLightingToKeyboard() {
        guard !isBusy else { return }
        isBusy = true
        // Turn off host-only preview if writing hardware effect
        var configToWrite = lighting
        if configToWrite.effect == .perKeyCustom {
            isBusy = false
            applyPerKeyToKeyboard()
            return
        }
        configToWrite.studioLiveEffect = .none
        let sleepToWrite = sleepTimeout
        let manager = hidManager

        setBanner(t("Übertrage Lichteffekt & Standby-Timer an AULA F75 …", "Flashing lighting & sleep timer to AULA F75 …"))

        Task.detached {
            let result = Result {
                try manager.applyLightingAndSleep(config: configToWrite, sleepTimeout: sleepToWrite)
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success(let (verifiedBlock, link, logs)):
                    self.activeLink = link
                    self.keyboardAwake = true
                    self.ensureSafetyBackup(block: verifiedBlock, link: link)
                    for entry in logs { self.appendLog(entry) }
                    self.setBanner(self.t(
                        "Gespeichert & verifiziert (\(configToWrite.effect.title(lang: self.language)) · Helligkeit \(configToWrite.brightness)/9)",
                        "Saved & verified (\(configToWrite.effect.title(lang: self.language)) · Brightness \(configToWrite.brightness)/9)"
                    ))
                case .failure(let error):
                    self.appendLog("ERROR: \(error.localizedDescription)")
                    self.setBanner(error.localizedDescription, isError: true)
                }
            }
        }
    }

    // MARK: Hardware Write Per-Key RGB Matrix (`0x02` / `0x06` + Mode 21)

    public func applyPerKeyToKeyboard() {
        guard !isBusy else { return }
        isBusy = true
        lighting.effect = .perKeyCustom
        lighting.studioLiveEffect = .none

        var denseColors = [RGBColor](repeating: .off, count: AulaConstants.ledCount)
        for key in currentLayoutSpec.keys where key.ledIndex < AulaConstants.ledCount {
            denseColors[key.ledIndex] = perKeyColors[key.ledIndex] ?? lighting.primaryColor
        }
        let brightness = lighting.brightness
        let manager = hidManager

        setBanner(t("Übertrage 126-LED Per-Key Matrix an Tastatur …", "Uploading 126-LED Per-Key Matrix to keyboard …"))

        Task.detached {
            let result = Result {
                try manager.applyPerKeyMatrix(colors: denseColors, brightness: brightness)
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success(let (link, logs)):
                    self.activeLink = link
                    for entry in logs { self.appendLog(entry) }
                    self.setBanner(self.t(
                        "Per-Key Studio-Matrix erfolgreich auf der AULA F75 gespeichert!",
                        "Per-Key Studio Matrix flashed to AULA F75!"
                    ))
                case .failure(let error):
                    self.appendLog("ERROR: \(error.localizedDescription)")
                    self.setBanner(error.localizedDescription, isError: true)
                }
            }
        }
    }

    /// Streams live Studio FX frames when `liveHardwareStreamEnabled` is toggled on
    public func streamLiveFrameIfNeeded(renderedColors: [Int: RGBColor], timestamp: TimeInterval) {
        guard liveHardwareStreamEnabled,
              !isBusy,
              activeLink.supportsConfigurationWrite,
              timestamp - lastLiveStreamTime >= 0.14 else {
            return
        }
        lastLiveStreamTime = timestamp
        var dense = [RGBColor](repeating: .off, count: AulaConstants.ledCount)
        for (led, color) in renderedColors where led >= 0 && led < AulaConstants.ledCount {
            dense[led] = color
        }
        let manager = hidManager
        Task.detached {
            try? manager.streamRealtimeFrame(colors: dense)
        }
    }

    // MARK: Keymap Read / Write (`0x01` / `0x03`)

    public func readKeymapFromKeyboard() {
        guard !isBusy else { return }
        isBusy = true
        let layer = UInt8(selectedLayer)
        let manager = hidManager
        setBanner(t("Lese Tastenbelegung (Layer \(layer)) …", "Reading Keymap (Layer \(layer)) …"))

        Task.detached {
            let result = Result { try manager.readKeymap(layer: layer) }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success(let (data, link, logs)):
                    self.activeLink = link
                    for entry in logs { self.appendLog(entry) }
                    if layer == 0 {
                        self.layer0Keymap = data
                    } else {
                        self.layer1Keymap = data
                    }
                    self.setBanner(self.t("Keymap Layer \(layer) erfolgreich geladen.", "Keymap Layer \(layer) loaded."))
                case .failure(let error):
                    self.appendLog("ERROR: \(error.localizedDescription)")
                    self.setBanner(error.localizedDescription, isError: true)
                }
            }
        }
    }

    public func applyKeymapToKeyboard() {
        guard !isBusy else { return }
        isBusy = true
        let layer = UInt8(selectedLayer)
        let payload = (selectedLayer == 0) ? layer0Keymap : layer1Keymap
        let manager = hidManager
        setBanner(t("Schreibe Tastenbelegung (Layer \(layer)) …", "Flashing Keymap (Layer \(layer)) …"))

        Task.detached {
            let result = Result { try manager.writeKeymap(layer: layer, data: payload) }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success(let (link, logs)):
                    self.activeLink = link
                    for entry in logs { self.appendLog(entry) }
                    self.setBanner(self.t("Tastenbelegung (Layer \(layer)) gespeichert!", "Keymap (Layer \(layer)) saved!"))
                case .failure(let error):
                    self.appendLog("ERROR: \(error.localizedDescription)")
                    self.setBanner(error.localizedDescription, isError: true)
                }
            }
        }
    }

    public func assignKey(_ key: KeyboardKey, to assignment: KeyAssignment) {
        let offset = key.ledIndex * 4
        guard offset + 4 <= AulaConstants.keymapLayerLength else { return }
        // Protect Fn key (LED 53) on Layer 0 from accidental overwrite
        if selectedLayer == 0 && key.ledIndex == 53 {
            setBanner(t("Die Fn-Taste (Slot 53) ist auf Layer 0 geschützt.", "The Fn key (Slot 53) is protected on Layer 0."), isError: true)
            return
        }
        if selectedLayer == 0 {
            layer0Keymap.replaceSubrange(offset..<(offset + 4), with: assignment.code)
        } else {
            layer1Keymap.replaceSubrange(offset..<(offset + 4), with: assignment.code)
        }
        setBanner(t("Taste '\(key.label)' → \(assignment.label) zugewiesen.", "Assigned '\(key.label)' → \(assignment.label)."))
    }

    public func currentAssignmentCode(for key: KeyboardKey) -> [UInt8] {
        let offset = key.ledIndex * 4
        let source = (selectedLayer == 0) ? layer0Keymap : layer1Keymap
        guard offset + 4 <= source.count else { return [0, 0, 0, 0] }
        return Array(source[offset..<(offset + 4)])
    }

    public func currentAssignmentLabel(for key: KeyboardKey) -> String {
        AulaKeymapCatalog.describe(code: currentAssignmentCode(for: key))
    }

    public func swapMacWinModifiersInKeymap() {
        // Slot 11 (left of Alt) and Slot 17 (left of Space)
        let optCode: [UInt8] = [0x00, 0x04, 0x00, 0x00] // Left Option (Alt)
        let cmdCode: [UInt8] = [0x00, 0x08, 0x00, 0x00] // Left Command (GUI/Win)
        let cur11 = Array(layer0Keymap[(11 * 4)..<(11 * 4 + 4)])
        if cur11 == cmdCode {
            layer0Keymap.replaceSubrange((11 * 4)..<(11 * 4 + 4), with: optCode)
            layer0Keymap.replaceSubrange((17 * 4)..<(17 * 4 + 4), with: cmdCode)
            macMode = true
            setBanner(t("macOS-Layout gesetzt: ⌥ Option links, ⌘ Command neben Leertaste.", "macOS modifier order set: ⌥ Option left, ⌘ Command next to Space."))
        } else {
            layer0Keymap.replaceSubrange((11 * 4)..<(11 * 4 + 4), with: cmdCode)
            layer0Keymap.replaceSubrange((17 * 4)..<(17 * 4 + 4), with: optCode)
            macMode = false
            setBanner(t("Windows-Layout gesetzt: Win links, Alt neben Leertaste.", "Windows modifier order set: Win left, Alt next to Space."))
        }
    }

    public func restoreFactoryLayer0() {
        layer0Keymap = AulaKeymapCatalog.factoryLayer0()
        setBanner(t("Werkseitige Layer-0-Tastenbelegung im Editor wiederhergestellt.", "Factory Layer 0 keymap restored in editor."))
    }

    // MARK: Hardware Macros (`0x03` / `0x05`)

    public func addMacro(name: String, textInput: String, delayMs: UInt32) {
        let nextIndex = macros.count
        let macro = AulaMacro(index: nextIndex, name: name, textInput: textInput, stepDelayMs: delayMs)
        macros.append(macro)
        selectedMacroID = macro.id
        setBanner(t("Makro '\(name)' (\(macro.events.count) Events) erstellt.", "Macro '\(name)' (\(macro.events.count) events) created."))
    }

    public func updateMacro(_ macro: AulaMacro, name: String, textInput: String, delayMs: UInt32) {
        guard let idx = macros.firstIndex(where: { $0.id == macro.id }) else { return }
        macros[idx] = AulaMacro(
            id: macro.id,
            index: idx,
            name: name,
            textInput: textInput,
            stepDelayMs: delayMs
        )
        setBanner(t("Makro '\(name)' aktualisiert.", "Macro '\(name)' updated."))
    }

    public func deleteMacro(_ macro: AulaMacro) {
        macros.removeAll { $0.id == macro.id }
        for idx in macros.indices {
            macros[idx].index = idx
        }
        selectedMacroID = macros.first?.id
    }

    public func uploadMacrosToKeyboard() {
        guard !isBusy, !macros.isEmpty else { return }
        isBusy = true
        let list = macros
        let manager = hidManager
        setBanner(t("Kompiliere & übertrage \(list.count) Hardware-Makros …", "Compiling & uploading \(list.count) hardware macros …"))

        Task.detached {
            let result = Result { try manager.uploadMacros(list) }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success(let (link, logs)):
                    self.activeLink = link
                    for entry in logs { self.appendLog(entry) }
                    self.setBanner(self.t("Alle \(list.count) Makros auf die Tastatur übertragen!", "Uploaded \(list.count) macros to keyboard!"))
                case .failure(let error):
                    self.appendLog("ERROR: \(error.localizedDescription)")
                    self.setBanner(error.localizedDescription, isError: true)
                }
            }
        }
    }

    // MARK: Studio Painting & Interactive Stage

    public func handleStageKeyTap(_ key: KeyboardKey) {
        triggerKeyRipple(for: key)

        switch activeTab {
        case .create:
            paintKey(key)
        case .keys:
            selectedKeyForRemap = key
        default:
            selectedKeyForRemap = key
        }
    }

    public func paintKey(_ key: KeyboardKey) {
        lighting.effect = .perKeyCustom
        lighting.studioLiveEffect = .none
        let spec = currentLayoutSpec

        switch selectedPaintTool {
        case .brush:
            perKeyColors[key.ledIndex] = paintBrushColor
        case .bucketFill:
            for k in spec.keys {
                perKeyColors[k.ledIndex] = paintBrushColor
            }
        case .rowFill:
            for k in spec.keys where k.row == key.row {
                perKeyColors[k.ledIndex] = paintBrushColor
            }
        case .gradient:
            for k in spec.keys {
                let ratio = Double(k.frame.midX / max(spec.size.width, 1))
                perKeyColors[k.ledIndex] = LightingEffectRenderer.blend(paintBrushColor, secondaryGradientColor, weight: ratio)
            }
        case .eyedropper:
            if let sampled = perKeyColors[key.ledIndex] {
                paintBrushColor = sampled
                selectedPaintTool = .brush
            }
        case .eraser:
            perKeyColors[key.ledIndex] = .off
        }
    }

    public func applyQuickPerKeyPreset(_ preset: String) {
        lighting.effect = .perKeyCustom
        lighting.studioLiveEffect = .none
        let spec = currentLayoutSpec
        switch preset {
        case "wasd":
            for k in spec.keys {
                let isHighlight = ["W", "A", "S", "D", "Up", "Down", "Left", "Right", "Esc", "Space"].contains(k.label) ||
                                  ["Up", "Down", "Left", "Right", "Esc", "Space"].contains(k.id)
                perKeyColors[k.ledIndex] = isHighlight ? .cyberCyan : RGBColor(r: 18, g: 22, b: 36)
            }
        case "iso-coder":
            for k in spec.keys {
                switch k.accentStyle {
                case .accent: perKeyColors[k.ledIndex] = .neonMagenta
                case .isoSpecial: perKeyColors[k.ledIndex] = .cyberCyan
                case .modifier: perKeyColors[k.ledIndex] = .ultraViolet
                case .alpha: perKeyColors[k.ledIndex] = .appleIce
                }
            }
        case "sunset":
            for k in spec.keys {
                let ratio = Double(k.frame.midY / max(spec.size.height, 1))
                perKeyColors[k.ledIndex] = LightingEffectRenderer.blend(.neonMagenta, .amberGold, weight: ratio)
            }
        default:
            for k in spec.keys { perKeyColors[k.ledIndex] = .off }
        }
    }

    public func triggerKeyRipple(for key: KeyboardKey) {
        let spec = currentLayoutSpec
        let normCenter = CGPoint(
            x: key.frame.midX / max(spec.size.width, 1),
            y: key.frame.midY / max(spec.size.height, 1)
        )
        let now = Date().timeIntervalSinceReferenceDate
        activeRipples.removeAll { now - $0.startTime > 1.3 }
        activeRipples.append(
            LightingEffectRenderer.ActiveRipple(
                center: normCenter,
                startTime: now,
                color: lighting.primaryColor
            )
        )
    }

    // MARK: Moods, Profiles & Safety Backups

    public func applyMood(_ mood: AulaMoodPreset) {
        lighting = mood.config
        setBanner(t("Szene '\(mood.titleDE)' aktiviert.", "Mood '\(mood.titleEN)' activated."))
    }

    public func activateProfile(_ profile: AulaProfile) {
        activeProfileID = profile.id
        lighting = profile.lighting
        sleepTimeout = profile.sleepTimeout
        if !profile.perKeyColors.isEmpty {
            perKeyColors = profile.perKeyColors
        }
        setBanner(t("Profil '\(profile.name)' geladen.", "Profile '\(profile.name)' loaded."))
    }

    public func saveCurrentAsProfile(name: String, icon: String = "sparkles") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let profile = AulaProfile(
            name: trimmed,
            icon: icon,
            accentHex: lighting.primaryColor.hexString,
            lighting: lighting,
            sleepTimeout: sleepTimeout,
            perKeyColors: perKeyColors
        )
        profiles.append(profile)
        activeProfileID = profile.id
        setBanner(t("Profil '\(trimmed)' gespeichert.", "Profile '\(trimmed)' saved."))
    }

    public func restoreSafetyBackupToKeyboard() {
        guard let backup = safetyBackup,
              AulaProtocolCodec.isLEDBlockValid(backup.ledSettingsBlock),
              let (restoredLighting, restoredSleep) = AulaProtocolCodec.parseLEDBlock(backup.ledSettingsBlock) else {
            setBanner(t("Kein gültiges Hardware-Backup vorhanden.", "No valid hardware backup found."), isError: true)
            return
        }
        lighting = restoredLighting
        sleepTimeout = restoredSleep
        if let km = backup.layer0Keymap, AulaKeymapCatalog.isKeymapPlausible(km) {
            layer0Keymap = km
        }
        applyLightingToKeyboard()
    }

    // MARK: Private Helpers

    private func setupDefaultProfilesAndMacros() {
        let defaultProfiles: [AulaProfile] = [
            AulaProfile(
                name: "Cyber ISO-DE",
                icon: "bolt.shield.fill",
                accentHex: "#00F0FF",
                lighting: LightingConfiguration(effect: .neonStream, brightness: 8, speed: 2, rainbowMode: false, colorSlot: 5, primaryColor: .cyberCyan),
                sleepTimeout: .fiveMinutes
            ),
            AulaProfile(
                name: "Mac Studio Clean",
                icon: "desktopcomputer",
                accentHex: "#D2E6FF",
                lighting: LightingConfiguration(effect: .fixedOn, brightness: 6, speed: 1, rainbowMode: false, colorSlot: 6, primaryColor: .appleIce),
                sleepTimeout: .tenMinutes
            ),
            AulaProfile(
                name: "Late Night Flow",
                icon: "moon.stars.fill",
                accentHex: "#FFB428",
                lighting: LightingConfiguration(effect: .respire, brightness: 4, speed: 1, rainbowMode: false, colorSlot: 3, primaryColor: .amberGold),
                sleepTimeout: .threeMinutes
            )
        ]
        profiles = defaultProfiles
        activeProfileID = defaultProfiles.first?.id

        // Initialize Per-Key canvas with a sleek cyber gradient
        let spec = currentLayoutSpec
        for key in spec.keys {
            let ratio = Double(key.frame.midX / max(spec.size.width, 1))
            perKeyColors[key.ledIndex] = LightingEffectRenderer.blend(.cyberCyan, .neonMagenta, weight: ratio)
        }
        selectedKeyForRemap = spec.keys.first { $0.id == "Caps" } ?? spec.keys.first

        // Default example macros
        macros = [
            AulaMacro(index: 0, name: "Git Commit Push", textInput: "git status\n", stepDelayMs: 16),
            AulaMacro(index: 1, name: "Email Signatur", textInput: "Beste Gruesse\nMarlon", stepDelayMs: 14)
        ]
        selectedMacroID = macros.first?.id
    }

    private var backupFileURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/aula-f75-driver", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("hardware-backup.json")
    }

    private func ensureSafetyBackup(block: [UInt8], link: AulaLinkType) {
        guard safetyBackup == nil, AulaProtocolCodec.isLEDBlockValid(block) else { return }
        let backup = HardwareSafetyBackup(
            createdAt: Date(),
            linkType: link.rawValue,
            ledSettingsBlock: block,
            layer0Keymap: layer0Keymap
        )
        safetyBackup = backup
        if let encoded = try? JSONEncoder().encode(backup) {
            try? encoded.write(to: backupFileURL)
        }
        appendLog("Created automatic hardware safety backup (\(backupFileURL.lastPathComponent))")
    }

    private func loadSafetyBackupFromDisk() {
        guard let data = try? Data(contentsOf: backupFileURL),
              let loaded = try? JSONDecoder().decode(HardwareSafetyBackup.self, from: data) else {
            return
        }
        safetyBackup = loaded
    }

    private func setBanner(_ message: String, isError: Bool = false) {
        statusBanner = message
        isErrorBanner = isError
    }

    public func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let stamped = "[\(formatter.string(from: Date()))] \(message)"
        activityLogs.insert(stamped, at: 0)
        if activityLogs.count > 120 {
            activityLogs.removeLast()
        }
    }
}
