# AULA F75 Studio — Native macOS Driver (`ISO-DE` · `ANSI-US` · `ISO-UK`)

Native **Swift 6 + SwiftUI + IOKit HID** control center for the **AULA F75 (non-Max)** 75% mechanical keyboard on macOS.

Inspired by the architecture of [VitalyArt/Aula-F75-Max-Driver](https://github.com/VitalyArt/Aula-F75-Max-Driver) and purpose-built for the **standard AULA F75** controller family (both **2.4 GHz Wireless Receiver `0x3554:0xFA09`** and **USB-C Wired `0x258A:0x010C`**), featuring a sustainable multi-layout engine (**ISO-DE QWERTZ**, **ANSI-US QWERTY**, **ISO-UK QWERTY**) and a futuristic, minimalist Apple-inspired interface with a **5-button bottom navigation bar**.

---

## Highlights

- **Native AULA F75 (Non-Max) Hardware Protocol**:
  - **2.4 GHz Wireless Receiver (`0x3554:0xFA09`)**: Communicates over vendor usage page `0xFF02` using 20-byte Report ID `0x13` packets (`[0x13, cmd, total, index, (sub<<4)|len, payload(14B), checksum]`) with `CFRunLoop` ACK verification and commit packet `0x0A`.
  - **USB-C Wired (`0x258A:0x010C`)**: Communicates over Interface 1 using 520-byte Feature Report `0x06` frames (`512B` chunks) and 512-byte custom RGB palette updates.
  - **Non-Destructive Hardware Safety**: Reads the 128-byte LED configuration block (`0x44` wireless / `0x84` wired), verifies the `0x5A 0xA5` hardware signature, creates an automatic local safety backup (`~/.config/aula-f75-driver/hardware-backup.json`), and patches only the target lighting/sleep fields so onboard `Fn` combinations are never lost.
- **Sustainable Multi-Layout Architecture**:
  - **ISO-DE (QWERTZ)**: Authentic 2-row L-shaped `Enter ↵`, short left `Shift` + `< > |`, `# '`, `Ü`, `Ö`, `Ä`, `ß ? \`, `^ °`, and `AltGr` legends (`@`, `€`, `{`, `[`, `]`, `}`, `~`, `µ`).
  - **ANSI (US QWERTY)** & **ISO-UK (QWERTY)**: Instant switch in the top bar so any AULA F75 owner worldwide can use the driver natively.
  - **macOS (`⌥ Option` / `⌘ Command`) & Windows (`Win` / `Alt`) Mode**: Visual legend toggle plus one-click hardware keymap swap.
- **5-Button Bottom Navigation Bar (Instagram / TikTok Inspired)**:
  1. **Home (`house.fill`)** — Live 30fps interactive keyboard stage, quick profile cards, lighting deck (brightness `0..9`, speed `1..5`, rainbow & 7 color slots), and hardware telemetry.
  2. **Explore / Search (`magnifyingglass`)** — Instant global search across all **18 onboard hardware effects**, curated atmospheric moods (`Cyberpunk 2099`, `Cupertino Ice`, `Matrix Operator`, `Aurora Studio`), and the complete `Fn`-shortcut reference.
  3. **`+` Studio (`plus` Center Action)** — Interactive **126-LED Per-Key RGB Painter** (Brush, Fill All, Row Fill, Cyber Gradient, Eyedropper, Eraser — click or drag directly across the keyboard canvas), procedural **Live Studio FX** (`Typing Ripple`, `Cyber Horizon`, `Matrix Digital Rain`, `Aurora Spatial`, `Audio Pulse`) with `0x08`/`0x88` live streaming, and custom profile creation.
  4. **Keys & Macros (`keyboard`)** — Interactive **Layer 0 & Fn Layer 1 Keymap Remapper** (with plausibility protection) and **Hardware Macro Studio** (compiles text & keystrokes into UTF-16LE headers + 4-byte HID events).
  5. **Profile & System (`person.crop.circle`)** — Wireless Standby Timer (`SleepHW` from `1 Min` to `20 Min` or `Never`), one-click hardware backup rollback, IOKit HID endpoint inspector, and live packet log.

---

## Supported Hardware IDs

| Mode | Vendor ID | Product ID | Transport Details |
| :--- | :--- | :--- | :--- |
| **2.4 GHz Receiver** | `0x3554` | `0xFA09` | Vendor Usage Page `0xFF02`, Report ID `0x13` (20-byte Output/Input) |
| **USB-C Wired** | `0x258A` | `0x010C` | Interface 1, Feature Report ID `0x06` (520-byte Feature Report) |
| **Bluetooth** | `0x3554` | `0xFA08` / `0xFA07` | Detected cleanly (status display; profile writes use 2.4G or USB-C) |

---

## Quick Start (macOS)

### Requirements
- macOS 14.0 (Sonoma) or newer (Apple Silicon & Intel)
- Xcode or Command Line Tools (`swift` 6.0+)

### Build & Run

```bash
# Build release binary and package 'build/Aula F75 Driver.app'
make macos-app

# Build and launch the app
make macos-run

# Run AulaCore protocol & layout unit tests
make macos-test

# Create distributable DMG installer
make macos-dmg
```

### macOS Input Monitoring Permission
To allow direct communication with the `0x3554:0xFA09` 2.4 GHz receiver and `0x258A:0x010C` USB-C interface, grant **Input Monitoring** (`Eingabeüberwachung`) in:
`System Settings → Privacy & Security → Input Monitoring`

---

## Project Structure

```text
Aula_F75_MacOS/
├── Package.swift
├── Info.plist
├── Makefile
├── Sources/
│   ├── AulaCore/
│   │   ├── AulaProtocol.swift           # 0x13 & 0x06 framing, 128B LED block, Per-Key matrix, Keymap & Macro compiler
│   │   ├── KeyboardLayout.swift         # ISO-DE, ANSI-US & ISO-UK geometry + hardware LED slot mapping (0..125)
│   │   └── LightingEffectRenderer.swift # 30fps renderer for all 18 hardware effects + 5 Live Studio FX
│   └── AulaF75Driver/
│       ├── AulaF75DriverApp.swift       # App lifecycle & keyboard shortcuts (⌘1..⌘5, ⌘R, ⌘↩)
│       ├── AulaHIDManager.swift         # IOKit HID transport + CFRunLoop WirelessReplyMonitor
│       ├── AppViewModel.swift           # State, profiles, painting tools, keymap & safety backup manager
│       ├── KeyboardStageView.swift      # Interactive 75% Canvas stage with ISO L-Enter & Rotary Knob
│       └── ContentView.swift            # Apple-inspired spatial glass UI + 5-button bottom dock
├── Tests/
│   └── AulaCoreTests/
│       └── AulaCoreTests.swift          # Unit tests for checksums, framing, LED blocks, layouts & macros
└── scripts/macos/
    ├── macos-build.sh
    ├── macos-app.sh
    ├── macos-run.sh
    └── macos-dmg.sh
```

---

## Credits & Protocol References
- Architectural inspiration: [VitalyArt/Aula-F75-Max-Driver](https://github.com/VitalyArt/Aula-F75-Max-Driver)
- Non-Max AULA F75 (`258A:010C` & `3554:FA09`) protocol research: [trenbolone1122/aula-f75-linux](https://github.com/trenbolone1122/aula-f75-linux) & [rushi007941/aula-lights](https://github.com/rushi007941/aula-lights)
