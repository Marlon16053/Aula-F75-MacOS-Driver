import AppKit
import AulaCore
import SwiftUI

@main
struct AulaF75DriverApp: App {
    @StateObject private var model = AppViewModel()

    init() {
        if CommandLine.arguments.contains("--self-test") {
            let result = AulaSelfTest.runAll()
            for line in result.summary {
                print(line)
            }
            print("==> AulaCore Self-Test: \(result.passed) passed, \(result.failed) failed")
            exit(result.failed == 0 ? 0 : 1)
        }
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("AULA F75 Studio") {
            ContentView(model: model)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1080, height: 780)
        .commands {
            CommandMenu("AULA F75") {
                Button(model.t("1 · Home", "1 · Home")) {
                    model.activeTab = .home
                }
                .keyboardShortcut("1", modifiers: .command)

                Button(model.t("2 · Suche & Effekte", "2 · Explore & Effects")) {
                    model.activeTab = .explore
                }
                .keyboardShortcut("2", modifiers: .command)

                Button(model.t("3 · Studio (+)", "3 · Studio (+)")) {
                    model.activeTab = .create
                }
                .keyboardShortcut("3", modifiers: .command)

                Button(model.t("4 · Tasten & Makros", "4 · Keys & Macros")) {
                    model.activeTab = .keys
                }
                .keyboardShortcut("4", modifiers: .command)

                Button(model.t("5 · Profil & System", "5 · Profile & System")) {
                    model.activeTab = .system
                }
                .keyboardShortcut("5", modifiers: .command)

                Divider()

                Button(model.t("Von Tastatur synchronisieren", "Sync from Keyboard")) {
                    model.syncFromKeyboard()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button(model.t("Auf Tastatur speichern", "Apply to Keyboard")) {
                    if model.activeTab == .keys {
                        model.applyKeymapToKeyboard()
                    } else if model.lighting.effect == .perKeyCustom {
                        model.applyPerKeyToKeyboard()
                    } else {
                        model.applyLightingToKeyboard()
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }
}
