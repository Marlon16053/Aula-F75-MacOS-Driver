import AppKit
import AulaCore
import SwiftUI

public struct ContentView: View {
    @ObservedObject var model: AppViewModel
    @State private var newProfileName: String = ""
    @State private var newMacroName: String = "Neues Makro"
    @State private var newMacroText: String = "Hello AULA F75!"
    @State private var newMacroDelay: Double = 18
    @State private var keysSubTab: Int = 0 // 0 = Keymap, 1 = Macros

    public init(model: AppViewModel) {
        self.model = model
    }

    private let colorPresets: [(name: String, slot: Int, rgb: RGBColor)] = [
        ("Red", 0, .crimsonPulse),
        ("Green", 1, .matrixGreen),
        ("Blue", 2, RGBColor(r: 40, g: 120, b: 255)),
        ("Amber", 3, .amberGold),
        ("Violet", 4, .ultraViolet),
        ("Cyan", 5, .cyberCyan),
        ("Ice", 6, .appleIce)
    ]

    public var body: some View {
        ZStack {
            // Futuristic Spatial Obsidian Backdrop
            ambientBackground

            VStack(spacing: 12) {
                topHeaderBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Interactive Live 75% Keyboard Stage (always visible as spatial hero)
                stageContainer
                    .frame(height: model.activeTab == .create || model.activeTab == .keys ? 275 : 250)
                    .padding(.horizontal, 20)

                // Main Tab Content Area
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        switch model.activeTab {
                        case .home:
                            homeTabContent
                        case .explore:
                            exploreTabContent
                        case .create:
                            createStudioTabContent
                        case .keys:
                            keysAndMacrosTabContent
                        case .system:
                            systemProfileTabContent
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 96)
                }
            }

            // Floating 5-Button Instagram / TikTok Inspired Bottom Dock
            VStack {
                Spacer()
                bottomNavigationBar
                    .padding(.bottom, 14)
            }
        }
        .frame(minWidth: 980, minHeight: 720)
        .preferredColorScheme(.dark)
    }

    // MARK: - Ambient Background

    private var ambientBackground: some View {
        let c = model.lighting.primaryColor.normalized
        let accent = Color(red: c.r, green: c.g, blue: c.b)
        return ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.035, blue: 0.06),
                    Color(red: 0.05, green: 0.06, blue: 0.095),
                    Color(red: 0.025, green: 0.03, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    accent.opacity(0.16),
                    Color(red: 0.55, green: 0.12, blue: 0.95).opacity(0.06),
                    Color.clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Top Header Bar

    private var topHeaderBar: some View {
        HStack(spacing: 12) {
            // Brand Title & Connection Pill
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.0, green: 0.90, blue: 1.0), Color(red: 0.58, green: 0.28, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)
                    Image(systemName: "keyboard.badge.eye.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("AULA F75")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("STUDIO")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.10), in: Capsule())
                            .foregroundStyle(Color(red: 0.0, green: 0.94, blue: 1.0))
                    }
                    HStack(spacing: 5) {
                        Circle()
                            .fill(linkStatusColor)
                            .frame(width: 7, height: 7)
                        Text(model.activeLink.rawValue)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }

            Spacer()

            // Sustainable Layout Switcher (ISO-DE default, ANSI-US, ISO-UK)
            Picker("", selection: $model.selectedLayout) {
                ForEach(KeyboardLayoutVariant.allCases) { variant in
                    Text(variant.shortTitle).tag(variant)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)
            .help(model.t("Physisches Tastaturlayout wechseln (ISO-DE, ANSI-US, ISO-UK)", "Switch physical keyboard layout"))

            // macOS / Windows Modifier Toggle
            Button {
                model.macMode.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: model.macMode ? "apple.logo" : "window.ceiling")
                        .font(.system(size: 11, weight: .semibold))
                    Text(model.macMode ? "macOS ⌥⌘" : "Win ❖")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Language Switcher (DE / EN)
            Button {
                model.language = model.language == "de" ? "en" : "de"
            } label: {
                Text(model.language.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Sync from Hardware Button
            Button {
                model.syncFromKeyboard()
            } label: {
                HStack(spacing: 5) {
                    if model.isBusy {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(model.t("Sync", "Sync"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.09), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(model.isBusy)

            // Primary Apply to Keyboard Button
            Button {
                if model.activeTab == .keys {
                    model.applyKeymapToKeyboard()
                } else if model.lighting.effect == .perKeyCustom {
                    model.applyPerKeyToKeyboard()
                } else {
                    model.applyLightingToKeyboard()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(model.t("Auf F75 speichern", "Apply to F75"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 0.94, blue: 1.0),
                            Color(red: 0.45, green: 0.82, blue: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .disabled(model.isBusy)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(glassCardBackground(cornerRadius: 18))
    }

    // MARK: - Interactive Stage Container

    private var stageContainer: some View {
        VStack(spacing: 6) {
            KeyboardStageView(model: model)

            // Subtle contextual status bar below stage
            HStack(spacing: 8) {
                Image(systemName: model.isErrorBanner ? "exclamationmark.triangle.fill" : "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(model.isErrorBanner ? Color.orange : Color(red: 0.0, green: 0.92, blue: 1.0))

                Text(model.statusBanner)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(model.isErrorBanner ? Color.orange : Color.white.opacity(0.78))
                    .lineLimit(1)

                Spacer()

                if model.activeTab == .create {
                    Text(model.t("Tipp: Direkt über die Tasten ziehen zum Malen", "Tip: Drag across keys to paint RGB"))
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.0, green: 0.92, blue: 1.0).opacity(0.85))
                } else if model.activeTab == .keys, let sel = model.selectedKeyForRemap {
                    Text("\(sel.label) (Slot \(sel.ledIndex)) → \(model.currentAssignmentLabel(for: sel))")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.0, green: 0.92, blue: 1.0))
                } else {
                    Text("\(model.selectedLayout.rawValue) · \(model.lighting.effect.title(lang: model.language))")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
        }
        .background(glassCardBackground(cornerRadius: 22))
    }

    // MARK: - TAB 1: HOME (Dashboard & Quick Controls)

    private var homeTabContent: some View {
        VStack(spacing: 16) {
            // Row 1: Saved Profiles Strip
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(
                    icon: "rectangle.stack.badge.person.crop.fill",
                    title: model.t("Schnellprofile & Presets", "Quick Profiles & Presets"),
                    subtitle: model.t("Ein Klick lädt Lichteffekt, Farbe & Standby-Timer", "One click loads lighting, color & sleep timeout")
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(model.profiles) { profile in
                            let isSelected = model.activeProfileID == profile.id
                            Button {
                                model.activateProfile(profile)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: profile.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.0, green: 0.92, blue: 1.0))
                                        .frame(width: 34, height: 34)
                                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.name)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Text("\(profile.lighting.effect.title(lang: model.language)) · \(profile.sleepTimeout.label(lang: model.language))")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                    Spacer(minLength: 8)
                                }
                                .padding(12)
                                .frame(width: 235)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(isSelected ? Color.white.opacity(0.13) : Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(isSelected ? Color(red: 0.0, green: 0.92, blue: 1.0) : Color.white.opacity(0.10), lineWidth: isSelected ? 1.5 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
            .background(glassCardBackground(cornerRadius: 18))

            // Row 2: Lighting Control Deck + Hardware Telemetry
            HStack(alignment: .top, spacing: 16) {
                // Left: Quick Lighting Deck
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(
                        icon: "sun.max.trianglebadge.exclamationmark.fill",
                        title: model.t("Lichtsteuerung", "Lighting Deck"),
                        subtitle: model.t("Direktzugriff auf Effekt, Helligkeit, Tempo & Farbkanal", "Direct control over effect, brightness, speed & color slot")
                    )

                    // Horizontal effect selector strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(AulaLightingEffect.hardwareEffects) { fx in
                                let active = model.lighting.effect == fx && model.lighting.studioLiveEffect == .none
                                Button {
                                    model.lighting.studioLiveEffect = .none
                                    model.lighting.effect = fx
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: fx.sfSymbol)
                                            .font(.system(size: 12, weight: .semibold))
                                        Text(fx.title(lang: model.language))
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        active
                                            ? Color(red: 0.0, green: 0.90, blue: 1.0).opacity(0.22)
                                            : Color.white.opacity(0.06),
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule().stroke(
                                            active ? Color(red: 0.0, green: 0.92, blue: 1.0) : Color.white.opacity(0.10),
                                            lineWidth: 1
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Brightness & Speed Sliders
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Label(model.t("Helligkeit", "Brightness"), systemImage: "sun.max.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text("\(model.lighting.brightness) / 9")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.0, green: 0.92, blue: 1.0))
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(model.lighting.brightness) },
                                    set: { model.lighting.brightness = Int($0.rounded()) }
                                ),
                                in: 0...9,
                                step: 1
                            )
                            .tint(Color(red: 0.0, green: 0.92, blue: 1.0))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Label(model.t("Geschwindigkeit", "Speed"), systemImage: "gauge.with.dots.needle.67percent")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text("\(model.lighting.speed + 1) / 5")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.0, green: 0.92, blue: 1.0))
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(model.lighting.speed) },
                                    set: { model.lighting.speed = Int($0.rounded()) }
                                ),
                                in: 0...4,
                                step: 1
                            )
                            .tint(Color(red: 0.0, green: 0.92, blue: 1.0))
                            .disabled(!model.lighting.effect.supportsSpeed)
                        }
                    }

                    // Color Swatches & Rainbow Toggle
                    HStack(spacing: 10) {
                        Toggle(isOn: $model.lighting.rainbowMode) {
                            Label(model.t("Multicolor / Rainbow", "Multicolor / Rainbow"), systemImage: "rainbow")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        Spacer()

                        ForEach(colorPresets, id: \.slot) { item in
                            let norm = item.rgb.normalized
                            let isSelected = !model.lighting.rainbowMode && model.lighting.colorSlot == item.slot
                            Button {
                                model.lighting.rainbowMode = false
                                model.lighting.colorSlot = item.slot
                                model.lighting.primaryColor = item.rgb
                            } label: {
                                Circle()
                                    .fill(Color(red: norm.r, green: norm.g, blue: norm.b))
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: isSelected ? 2.5 : 0.6)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(glassCardBackground(cornerRadius: 18))

                // Right: Hardware Status & Quick Sleep Card
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(
                        icon: "cpu.fill",
                        title: model.t("Hardware-Status", "Hardware Telemetry"),
                        subtitle: model.t("AULA F75 Controller & Energie", "AULA F75 Controller & Power")
                    )

                    VStack(spacing: 8) {
                        telemetryRow(
                            label: model.t("Verbindung", "Transport"),
                            value: model.activeLink.rawValue
                        )
                        telemetryRow(
                            label: model.t("Tastaturlayout", "Layout"),
                            value: "\(model.selectedLayout.shortTitle) (\(model.macMode ? "macOS" : "Win"))"
                        )
                        telemetryRow(
                            label: model.t("HID-Endpunkte", "HID Endpoints"),
                            value: "\(model.endpoints.count) aktiv"
                        )
                    }

                    Divider().overlay(Color.white.opacity(0.1))

                    HStack {
                        Label(model.t("Standby-Timer", "Sleep Timeout"), systemImage: "moon.zzz.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Picker("", selection: $model.sleepTimeout) {
                            ForEach(AulaSleepTimeout.allCases) { item in
                                Text(item.label(lang: model.language)).tag(item)
                            }
                        }
                        .frame(width: 135)
                    }
                }
                .padding(16)
                .frame(width: 310)
                .background(glassCardBackground(cornerRadius: 18))
            }
        }
    }

    // MARK: - TAB 2: EXPLORE / SEARCH (`magnifyingglass`)

    private var exploreTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Search & Filter Bar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color(red: 0.0, green: 0.92, blue: 1.0))
                    TextField(
                        model.t("Suche nach Lichteffekten, Cyberpunk, Matrix, Fn-Shortcuts …", "Search effects, Cyberpunk, Matrix, Fn-shortcuts …"),
                        text: $model.searchQuery
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .rounded))

                    if !model.searchQuery.isEmpty {
                        Button {
                            model.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Picker("", selection: $model.exploreFilter) {
                    ForEach(ExploreFilter.allCases) { filter in
                        Text(filter.label(lang: model.language)).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }
            .padding(14)
            .background(glassCardBackground(cornerRadius: 18))

            // 1. Curated Moods / Scenes
            if model.exploreFilter == .all || model.exploreFilter == .moods {
                let moods = filteredMoods
                if !moods.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(
                            icon: "sparkles",
                            title: model.t("Kuratierte Atmosphären & Szenen", "Curated Moods & Scenes"),
                            subtitle: model.t("Kombinierte Hardware- & Studio-Looks", "Combined hardware & studio lighting looks")
                        )

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                            ForEach(moods) { mood in
                                Button {
                                    model.applyMood(mood)
                                } label: {
                                    HStack(spacing: 12) {
                                        let c = mood.config.primaryColor.normalized
                                        Image(systemName: mood.icon)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(Color(red: c.r, green: c.g, blue: c.b))
                                            .frame(width: 40, height: 40)
                                            .background(Color(red: c.r, green: c.g, blue: c.b).opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(model.t(mood.titleDE, mood.titleEN))
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white)
                                            Text(model.t(mood.subtitleDE, mood.subtitleEN))
                                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.65))
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .background(glassCardBackground(cornerRadius: 18))
                }
            }

            // 2. All 18 Hardware Effects Gallery
            if model.exploreFilter == .all || model.exploreFilter == .effects {
                let effects = filteredEffects
                if !effects.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(
                            icon: "light.panel.fill",
                            title: model.t("Alle 18 Hardware-Lichteffekte (AULA F75 Firmware)", "All 18 Hardware Lighting Effects"),
                            subtitle: model.t("Werden direkt im Onboard-Speicher der Tastatur ausgeführt", "Run natively on the keyboard's onboard controller")
                        )

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 10)], spacing: 10) {
                            ForEach(effects) { fx in
                                let active = model.lighting.effect == fx && model.lighting.studioLiveEffect == .none
                                Button {
                                    model.lighting.studioLiveEffect = .none
                                    model.lighting.effect = fx
                                } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: fx.sfSymbol)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(active ? Color(red: 0.0, green: 0.94, blue: 1.0) : .white.opacity(0.8))
                                            .frame(width: 28, height: 28)
                                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(fx.title(lang: model.language))
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            Text("ID #\(fx.rawValue)")
                                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.45))
                                        }
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(
                                        active ? Color(red: 0.0, green: 0.90, blue: 1.0).opacity(0.18) : Color.white.opacity(0.04),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(active ? Color(red: 0.0, green: 0.94, blue: 1.0) : Color.white.opacity(0.08), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .background(glassCardBackground(cornerRadius: 18))
                }
            }

            // 3. Hardware Fn-Shortcuts Reference
            if model.exploreFilter == .all || model.exploreFilter == .shortcuts {
                let shortcuts = filteredShortcuts
                if !shortcuts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(
                            icon: "command.square.fill",
                            title: model.t("AULA F75 Hardware Fn-Tastenkombinationen", "AULA F75 Hardware Fn-Shortcuts"),
                            subtitle: model.t("Direkt auf der Tastatur ausführbare System- & Funk-Kürzel", "Onboard hardware shortcuts for wireless channels, macOS mode & battery")
                        )

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 10)], spacing: 10) {
                            ForEach(shortcuts) { item in
                                HStack(spacing: 10) {
                                    Text(item.keys)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(red: 0.0, green: 0.94, blue: 1.0))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                                    Text(model.t(item.titleDE, item.titleEN))
                                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.85))
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(16)
                    .background(glassCardBackground(cornerRadius: 18))
                }
            }
        }
    }

    // MARK: - TAB 3: `+` CREATE / STUDIO (`plus` Center Action)

    private var createStudioTabContent: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Left: Per-Key RGB Painter Studio
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(
                        icon: "paintbrush.pointed.fill",
                        title: model.t("Per-Key RGB Studio (126 LEDs)", "Per-Key RGB Studio (126 LEDs)"),
                        subtitle: model.t("Wähle ein Werkzeug und male direkt oben auf der Tastatur", "Pick a tool and paint directly on the keyboard stage above")
                    )

                    // Paint Tool Picker
                    HStack(spacing: 8) {
                        ForEach(PaintTool.allCases) { tool in
                            let selected = model.selectedPaintTool == tool
                            Button {
                                model.selectedPaintTool = tool
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: tool.sfSymbol)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(tool.label(lang: model.language))
                                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    selected ? Color(red: 0.0, green: 0.92, blue: 1.0).opacity(0.22) : Color.white.opacity(0.06),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule().stroke(selected ? Color(red: 0.0, green: 0.92, blue: 1.0) : Color.white.opacity(0.10), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Brush Color Swatches + Native ColorPicker
                    HStack(spacing: 10) {
                        Text(model.t("Pinselfarbe:", "Brush Color:"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))

                        ForEach(colorPresets, id: \.slot) { preset in
                            let norm = preset.rgb.normalized
                            Button {
                                model.paintBrushColor = preset.rgb
                                model.lighting.primaryColor = preset.rgb
                            } label: {
                                Circle()
                                    .fill(Color(red: norm.r, green: norm.g, blue: norm.b))
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle().stroke(
                                            Color.white,
                                            lineWidth: model.paintBrushColor == preset.rgb ? 2.4 : 0.6
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        ColorPicker(
                            "",
                            selection: Binding(
                                get: {
                                    let n = model.paintBrushColor.normalized
                                    return Color(red: n.r, green: n.g, blue: n.b)
                                },
                                set: { newColor in
                                    if let cg = NSColor(newColor).usingColorSpace(.sRGB) {
                                        let rgb = RGBColor(
                                            r: UInt8(clamping: Int(cg.redComponent * 255)),
                                            g: UInt8(clamping: Int(cg.greenComponent * 255)),
                                            b: UInt8(clamping: Int(cg.blueComponent * 255))
                                        )
                                        model.paintBrushColor = rgb
                                        model.lighting.primaryColor = rgb
                                    }
                                }
                            )
                        )
                        .labelsHidden()
                    }

                    // Quick Canvas Templates + Flash Button
                    HStack(spacing: 8) {
                        Button("WASD Cyber") { model.applyQuickPerKeyPreset("wasd") }
                            .buttonStyle(StudioPillButtonStyle())
                        Button("ISO Coder") { model.applyQuickPerKeyPreset("iso-coder") }
                            .buttonStyle(StudioPillButtonStyle())
                        Button("Sunset") { model.applyQuickPerKeyPreset("sunset") }
                            .buttonStyle(StudioPillButtonStyle())
                        Button(model.t("Leeren", "Clear")) { model.applyQuickPerKeyPreset("clear") }
                            .buttonStyle(StudioPillButtonStyle())

                        Spacer()

                        Button {
                            model.applyPerKeyToKeyboard()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.doc.on.clipboard")
                                Text(model.t("Per-Key Matrix flashen", "Flash Per-Key Matrix"))
                            }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color(red: 0.0, green: 0.92, blue: 1.0), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(glassCardBackground(cornerRadius: 18))

                // Right: Live Studio Procedural FX & Profile Creator
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(
                        icon: "waveform.and.magnifyingglass",
                        title: model.t("Live Studio FX & Profil-Creator", "Live Studio FX & Profile Creator"),
                        subtitle: model.t("Echtzeit-Shader & eigene Profile speichern", "Real-time shaders & custom profile builder")
                    )

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(StudioLiveEffect.allCases) { liveFX in
                            let active = model.lighting.studioLiveEffect == liveFX
                            Button {
                                model.lighting.studioLiveEffect = liveFX
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: liveFX.sfSymbol)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(liveFX.rawValue)
                                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(9)
                                .background(
                                    active ? Color(red: 1.0, green: 0.22, blue: 0.58).opacity(0.24) : Color.white.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(active ? Color(red: 1.0, green: 0.28, blue: 0.62) : Color.white.opacity(0.10), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Toggle(isOn: $model.liveHardwareStreamEnabled) {
                        Text(model.t("Live-Stream an Tastatur senden (0x08 / 0x88)", "Stream Live FX to Keyboard (0x08 / 0x88)"))
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Divider().overlay(Color.white.opacity(0.1))

                    HStack(spacing: 8) {
                        TextField(model.t("Profilname (z.B. Gaming DE)", "Profile name"), text: $newProfileName)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))

                        Button {
                            let name = newProfileName.isEmpty ? "Studio #\(model.profiles.count + 1)" : newProfileName
                            model.saveCurrentAsProfile(name: name)
                            newProfileName = ""
                        } label: {
                            Label(model.t("Speichern", "Save"), systemImage: "plus.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .frame(width: 380)
                .background(glassCardBackground(cornerRadius: 18))
            }
        }
    }

    // MARK: - TAB 4: KEYS & MACROS (`keyboard`)

    private var keysAndMacrosTabContent: some View {
        VStack(spacing: 14) {
            // Sub-Navigation Header
            HStack(spacing: 12) {
                Picker("", selection: $keysSubTab) {
                    Text(model.t("Tastenbelegung (Keymap)", "Key Remapping")).tag(0)
                    Text(model.t("Hardware-Makro Studio", "Hardware Macro Studio")).tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 360)

                Spacer()

                if keysSubTab == 0 {
                    Picker("Layer", selection: $model.selectedLayer) {
                        Text("Layer 0 (Standard)").tag(0)
                        Text("Layer 1 (Fn-Layer)").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)

                    Button {
                        model.swapMacWinModifiersInKeymap()
                    } label: {
                        Label(model.t("⌥ / ⌘ Tausch", "Swap ⌥ / ⌘"), systemImage: "command")
                    }
                    .buttonStyle(StudioPillButtonStyle())

                    Button {
                        model.restoreFactoryLayer0()
                    } label: {
                        Label(model.t("Standard", "Factory"), systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(StudioPillButtonStyle())

                    Button {
                        model.readKeymapFromKeyboard()
                    } label: {
                        Label(model.t("Lesen", "Read"), systemImage: "tray.and.arrow.down.fill")
                    }
                    .buttonStyle(StudioPillButtonStyle())
                }
            }
            .padding(12)
            .background(glassCardBackground(cornerRadius: 16))

            if keysSubTab == 0 {
                keymapRemapperSection
            } else {
                macroStudioSection
            }
        }
    }

    private var keymapRemapperSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Selected Key Inspector
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    icon: "keyboard.fill",
                    title: model.t("Ausgewählte Taste", "Selected Key"),
                    subtitle: model.t("Klicke oben auf eine beliebige Taste der AULA F75", "Click any key on the keyboard stage above")
                )

                if let selectedKey = model.selectedKeyForRemap {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(selectedKey.label.isEmpty ? "Space" : selectedKey.label)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.0, green: 0.94, blue: 1.0))
                            Spacer()
                            Text("Matrix LED #\(selectedKey.ledIndex)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }

                        telemetryRow(
                            label: model.t("Aktuelle Funktion", "Current Binding"),
                            value: model.currentAssignmentLabel(for: selectedKey)
                        )
                        telemetryRow(
                            label: "4-Byte Code",
                            value: model.currentAssignmentCode(for: selectedKey).map { String(format: "%02X", $0) }.joined(separator: " ")
                        )
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }

                // Category Selector
                ForEach(KeyAssignment.Category.allCases, id: \.self) { category in
                    let isSelected = model.selectedAssignmentCategory == category
                    Button {
                        model.selectedAssignmentCategory = category
                    } label: {
                        HStack {
                            Text(category.rawValue)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? Color(red: 0.0, green: 0.92, blue: 1.0).opacity(0.20) : Color.white.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(width: 290)
            .background(glassCardBackground(cornerRadius: 18))

            // Target Assignments Grid
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionHeader(
                        icon: "arrow.right.doc.on.clipboard",
                        title: model.selectedAssignmentCategory.rawValue,
                        subtitle: model.t("Klicken, um der ausgewählten Taste diese Funktion zuzuweisen", "Click an action to assign it to the selected key")
                    )
                    Spacer()
                    Button {
                        model.applyKeymapToKeyboard()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down.on.square.fill")
                            Text(model.t("Keymap auf F75 schreiben", "Flash Keymap to F75"))
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(red: 0.0, green: 0.92, blue: 1.0), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                let assignments = AulaKeymapCatalog.allTargets.filter { $0.category == model.selectedAssignmentCategory }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 8)], spacing: 8) {
                    ForEach(assignments) { target in
                        Button {
                            if let key = model.selectedKeyForRemap {
                                model.assignKey(key, to: target)
                            }
                        } label: {
                            HStack {
                                Text(target.label)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(glassCardBackground(cornerRadius: 18))
        }
    }

    private var macroStudioSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left: Macro List
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(
                    icon: "bolt.badge.clock.fill",
                    title: model.t("Hardware-Makros (Slot 1–8)", "Hardware Macros (Slots 1–8)"),
                    subtitle: model.t("UTF-16LE + 4-Byte Event-Compiler", "UTF-16LE + 4-byte event compiler")
                )

                ForEach(model.macros) { macro in
                    let isSelected = model.selectedMacroID == macro.id
                    HStack {
                        Button {
                            model.selectedMacroID = macro.id
                            newMacroName = macro.name
                            newMacroText = macro.textInput
                            newMacroDelay = Double(macro.stepDelayMs)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("#\(macro.index + 1) · \(macro.name)")
                                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                Text("\(macro.events.count) HID-Events · \(macro.stepDelayMs)ms")
                                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Button {
                            model.deleteMacro(macro)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(
                        isSelected ? Color(red: 0.0, green: 0.92, blue: 1.0).opacity(0.18) : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }

                Button {
                    model.uploadMacrosToKeyboard()
                } label: {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up.fill")
                        Text(model.t("Alle Makros auf Tastatur flashen", "Upload All Macros to Keyboard"))
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color(red: 0.0, green: 0.92, blue: 1.0), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .frame(width: 310)
            .background(glassCardBackground(cornerRadius: 18))

            // Right: Macro Compiler Editor
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    icon: "terminal.fill",
                    title: model.t("Makro-Sequenz Editor", "Macro Sequence Compiler"),
                    subtitle: model.t("Text wird automatisch in KeyDown/KeyUp + Shift-Modifier Events übersetzt", "Automatically compiles text into HID KeyDown/KeyUp + Shift events")
                )

                HStack(spacing: 12) {
                    TextField(model.t("Makro-Name", "Macro Name"), text: $newMacroName)
                        .textFieldStyle(.plain)
                        .padding(9)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))

                    HStack {
                        Text(model.t("Verzögerung:", "Step Delay:"))
                            .font(.system(size: 12))
                        Slider(value: $newMacroDelay, in: 4...120, step: 2)
                            .frame(width: 120)
                        Text("\(Int(newMacroDelay)) ms")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                }

                TextField(model.t("Tastenfolge / Text eingeben …", "Enter keystroke text sequence …"), text: $newMacroText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...5)
                    .padding(10)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 10) {
                    Button {
                        model.addMacro(name: newMacroName, textInput: newMacroText, delayMs: UInt32(newMacroDelay))
                    } label: {
                        Label(model.t("Als neues Makro hinzufügen", "Add as New Macro"), systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(StudioPillButtonStyle())

                    if let selectedID = model.selectedMacroID,
                       let current = model.macros.first(where: { $0.id == selectedID }) {
                        Button {
                            model.updateMacro(current, name: newMacroName, textInput: newMacroText, delayMs: UInt32(newMacroDelay))
                        } label: {
                            Label(model.t("Ausgewähltes aktualisieren", "Update Selected"), systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(StudioPillButtonStyle())
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(glassCardBackground(cornerRadius: 18))
        }
    }

    // MARK: - TAB 5: SYSTEM / PROFILE (`person.crop.circle`)

    private var systemProfileTabContent: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Left: Hardware Safety Backup & Power Management
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(
                        icon: "checkmark.shield.fill",
                        title: model.t("Hardware-Schutz & Backup", "Hardware Safety & Backup"),
                        subtitle: model.t("Signaturprüfung (5A A5) & automatisches Vorab-Backup", "Signature verification (5A A5) & automatic pre-write backup")
                    )

                    if let backup = model.safetyBackup {
                        VStack(alignment: .leading, spacing: 6) {
                            telemetryRow(label: model.t("Backup-Status", "Backup Status"), value: model.t("Gesichert (128B LED + Keymap)", "Secured (128B LED + Keymap)"))
                            telemetryRow(label: model.t("Verbindung beim Backup", "Backup Transport"), value: backup.linkType)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

                        Button {
                            model.restoreSafetyBackupToKeyboard()
                        } label: {
                            Label(model.t("Hardware-Backup wiederherstellen", "Restore Hardware Backup"), systemImage: "arrow.uturn.backward.circle.fill")
                        }
                        .buttonStyle(StudioPillButtonStyle())
                    } else {
                        Text(model.t(
                            "Beim ersten Lesen oder Schreiben wird automatisch ein lokales Backup unter ~/.config/aula-f75-driver/hardware-backup.json angelegt.",
                            "An automatic local backup is created at ~/.config/aula-f75-driver/hardware-backup.json on first sync or write."
                        ))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.65))
                    }

                    Divider().overlay(Color.white.opacity(0.1))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.t("macOS Eingabeüberwachung (IOKit HID)", "macOS Input Monitoring (IOKit HID)"))
                                .font(.system(size: 12, weight: .bold))
                            Text(model.hasInputMonitoring
                                 ? model.t("Berechtigung erteilt", "Permission Granted")
                                 : model.t("Berechtigung erforderlich für 2.4G/USB-Zugriff", "Permission required for 2.4G/USB access"))
                                .font(.system(size: 11))
                                .foregroundStyle(model.hasInputMonitoring ? Color.green : Color.orange)
                        }
                        Spacer()
                        Button {
                            model.requestPermissions()
                        } label: {
                            Text(model.t("Systemeinstellungen", "Open Settings"))
                        }
                        .buttonStyle(StudioPillButtonStyle())
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(glassCardBackground(cornerRadius: 18))

                // Right: Discovered HID Endpoints
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        sectionHeader(
                            icon: "cable.connector.horizontal",
                            title: model.t("Erkannte HID-Endpunkte", "Discovered HID Endpoints"),
                            subtitle: model.t("USB-C (258A:010C) & 2.4G Receiver (3554:FA09)", "USB-C (258A:010C) & 2.4G Receiver (3554:FA09)")
                        )
                        Spacer()
                        Button {
                            model.refreshEndpoints()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(StudioPillButtonStyle())
                    }

                    if model.endpoints.isEmpty {
                        Text(model.t("Keine AULA F75 HID-Schnittstellen gefunden.", "No AULA F75 HID interfaces found."))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        ForEach(model.endpoints) { ep in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(ep.productName) · \(ep.roleDescription)")
                                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                    Text("VID:PID \(ep.vidPidHex) · Usage \(ep.usageHex) · In/Out/Feat: \(ep.maxInputReportSize)/\(ep.maxOutputReportSize)/\(ep.maxFeatureReportSize)B")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(glassCardBackground(cornerRadius: 18))
            }

            // Packet & Protocol Activity Log
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(
                    icon: "waveform.path.ecg.rectangle.fill",
                    title: model.t("Protokoll- & Paket-Log", "Protocol & Packet Log"),
                    subtitle: model.t("Live-Mitschnitt aller 0x13 (2.4G) & 0x06 (USB-C) Übertragungen", "Live trace of all 0x13 (2.4G) & 0x06 (USB-C) transfers")
                )

                if model.activityLogs.isEmpty {
                    Text(model.t("Noch keine HID-Transaktionen in dieser Sitzung.", "No HID transactions recorded yet in this session."))
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    ForEach(model.activityLogs.prefix(12), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(glassCardBackground(cornerRadius: 18))
        }
    }

    // MARK: - 5-Button Instagram / TikTok Style Bottom Navigation Bar

    private var bottomNavigationBar: some View {
        HStack(spacing: 18) {
            ForEach(NavigationTab.allCases) { tab in
                let isSelected = model.activeTab == tab

                if tab.isCenterAction {
                    // Prominent Center '+' Create / Studio Action Button (Instagram / TikTok Style)
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            model.activeTab = tab
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.0, green: 0.94, blue: 1.0),
                                            Color(red: 0.58, green: 0.28, blue: 1.0),
                                            Color(red: 1.0, green: 0.22, blue: 0.58)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 54, height: 40)
                                .shadow(color: Color(red: 0.0, green: 0.92, blue: 1.0).opacity(0.45), radius: 10, y: 2)

                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(isSelected ? Color.white : Color(red: 0.06, green: 0.07, blue: 0.11))
                                .frame(width: 48, height: 34)

                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(isSelected ? .black : .white)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(model.t("Studio: Per-Key RGB Malen, Live FX & Profile erstellen", "Studio: Paint Per-Key RGB, Live FX & Create Profiles"))
                } else {
                    // Standard Dock Tab Button
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            model.activeTab = tab
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? Color(red: 0.0, green: 0.94, blue: 1.0) : Color.white.opacity(0.55))

                            Text(tab.title(lang: model.language))
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundStyle(isSelected ? .white : .white.opacity(0.50))
                        }
                        .frame(width: 64, height: 44)
                        .background(
                            isSelected ? Color.white.opacity(0.08) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(Color(red: 0.04, green: 0.05, blue: 0.08).opacity(0.78))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.26),
                                    Color(red: 0.0, green: 0.92, blue: 1.0).opacity(0.35),
                                    Color.white.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.1
                        )
                )
                .shadow(color: .black.opacity(0.55), radius: 20, y: 8)
        )
    }

    // MARK: - Search Filters & Reusable UI Building Blocks

    private var filteredMoods: [AulaMoodPreset] {
        let q = model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return model.curatedMoods }
        return model.curatedMoods.filter {
            $0.titleDE.lowercased().contains(q) ||
            $0.titleEN.lowercased().contains(q) ||
            $0.subtitleDE.lowercased().contains(q) ||
            $0.tags.contains(where: { $0.contains(q) })
        }
    }

    private var filteredEffects: [AulaLightingEffect] {
        let q = model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return AulaLightingEffect.hardwareEffects }
        return AulaLightingEffect.hardwareEffects.filter {
            $0.title(lang: "de").lowercased().contains(q) ||
            $0.title(lang: "en").lowercased().contains(q)
        }
    }

    private var filteredShortcuts: [FnShortcutItem] {
        let q = model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return model.fnShortcuts }
        return model.fnShortcuts.filter {
            $0.keys.lowercased().contains(q) ||
            $0.titleDE.lowercased().contains(q) ||
            $0.titleEN.lowercased().contains(q) ||
            $0.category.lowercased().contains(q)
        }
    }

    private var linkStatusColor: Color {
        switch model.activeLink {
        case .wired: return Color(red: 0.15, green: 0.95, blue: 0.65)
        case .receiver: return Color(red: 0.0, green: 0.92, blue: 1.0)
        case .bluetooth: return Color(red: 0.38, green: 0.58, blue: 1.0)
        case .disconnected: return Color.orange
        }
    }

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(red: 0.0, green: 0.92, blue: 1.0))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func telemetryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
            Text(value)
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private func glassCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.045))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

private struct StudioPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.6 : 0.9))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color.white.opacity(configuration.isPressed ? 0.14 : 0.08), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}
