import Foundation

public enum AulaSelfTest: Sendable {
    @discardableResult
    public static func runAll() -> (passed: Int, failed: Int, summary: [String]) {
        var passed = 0
        var failed = 0
        var logs: [String] = []

        func check(_ name: String, _ condition: @autoclosure () -> Bool) {
            if condition() {
                passed += 1
                logs.append("PASS: \(name)")
            } else {
                failed += 1
                logs.append("FAIL: \(name)")
            }
        }

        // 1. Wireless 0x13 Framing & Checksum
        let readReq = AulaProtocolCodec.buildWirelessReadRequest(cmd: 0x44, sub: 0)
        check("Wireless 0x13 read packet is 20 bytes", readReq.count == 20 && readReq[0] == 0x13)
        check("Wireless 0x13 read checksum valid (0x58)", readReq[19] == 0x58 && AulaProtocolCodec.isValidWirelessPacket(readReq))

        // 2. Wireless Save 0x0A Packet
        let savePkt = AulaProtocolCodec.buildWirelessSavePacket()
        check("Wireless 0x0A save packet valid", AulaProtocolCodec.isValidWirelessPacket(savePkt) && savePkt[1] == 0x0A && savePkt[5] == 0x07)

        // 3. 128-Byte LED Block Multi-Packet Split (10 packets of 14B)
        let block = AulaProtocolCodec.defaultLEDBlock()
        let writePkts = AulaProtocolCodec.buildWirelessWritePackets(cmd: 0x04, sub: 0, data: block)
        check("128B LED block splits into 10 wireless 0x13 packets", writePkts.count == 10 && writePkts.allSatisfy { AulaProtocolCodec.isValidWirelessPacket($0) })

        // 4. Wired 520-Byte Feature Report 0x06 Framing
        let wiredPkts = AulaProtocolCodec.buildWiredPackets(cmd: 0x04, sub: 0, totalLength: 128, data: block)
        check("Wired 0x06 report is 520 bytes", wiredPkts.count == 1 && wiredPkts[0].count == 520 && wiredPkts[0][0] == 0x06)

        // 5. Non-Destructive LED Block Patching & Signature Preservation
        var patched = block
        patched[42] = 0xAB // Simulate custom Fn-table byte
        let cfg = LightingConfiguration(effect: .rotatingStorm, brightness: 9, speed: 4, rainbowMode: false, colorSlot: 5, primaryColor: .cyberCyan)
        AulaProtocolCodec.patchLEDBlock(&patched, config: cfg)
        AulaProtocolCodec.patchSleepTimeout(&patched, timeout: .tenMinutes)
        check("LED block signature 5A A5 preserved", AulaProtocolCodec.isLEDBlockValid(patched) && patched[42] == 0xAB)
        if let (parsedCfg, parsedSleep) = AulaProtocolCodec.parseLEDBlock(patched) {
            check("LED block round-trip effect & sleep", parsedCfg.effect == .rotatingStorm && parsedCfg.brightness == 9 && parsedCfg.speed == 4 && parsedSleep == .tenMinutes)
        } else {
            check("LED block round-trip parse", false)
        }

        // 6. Multi-Layout Geometry (ISO-DE, ANSI-US, ISO-UK)
        let isoDE = KeyboardLayoutCatalog.layout(for: .isoDE, macMode: true)
        let ansiUS = KeyboardLayoutCatalog.layout(for: .ansiUS, macMode: false)
        let isoUK = KeyboardLayoutCatalog.layout(for: .isoUK, macMode: true)
        check("ISO-DE has L-shaped Enter (LED 81) and < > | (LED 76) and # ' (LED 75)",
              isoDE.keys.contains(where: { $0.ledIndex == 81 && $0.isISOEnter }) &&
              isoDE.keys.contains(where: { $0.ledIndex == 76 && $0.label == "<" }) &&
              isoDE.keys.contains(where: { $0.ledIndex == 75 && $0.label == "#" }))
        check("ISO-DE has QWERTZ (Z at LED 38, Y at LED 10)",
              isoDE.keys.contains(where: { $0.ledIndex == 38 && $0.label == "Z" }) &&
              isoDE.keys.contains(where: { $0.ledIndex == 10 && $0.label == "Y" }))
        check("ANSI-US has QWERTY and horizontal Enter",
              ansiUS.keys.contains(where: { $0.ledIndex == 38 && $0.label == "Y" }) &&
              ansiUS.keys.contains(where: { $0.ledIndex == 81 && !$0.isISOEnter }))
        check("ISO-UK has L-shaped Enter and £ legend",
              isoUK.keys.contains(where: { $0.ledIndex == 81 && $0.isISOEnter }) &&
              isoUK.keys.contains(where: { $0.ledIndex == 19 && $0.secondaryLabel == "£" }))

        // 7. Keymap Plausibility & Macro Compiler
        let layer0 = AulaKeymapCatalog.factoryLayer0()
        check("Factory Layer 0 keymap is 512 bytes & plausible", layer0.count == 512 && AulaKeymapCatalog.isKeymapPlausible(layer0))

        let macro = AulaMacro(index: 0, name: "Test", textInput: "Hi!", stepDelayMs: 15)
        let compiled = AulaMacro.compileBuffer([macro])
        check("Hardware Macro compiler produces valid header & events", !macro.events.isEmpty && compiled.count > 10)

        return (passed, failed, logs)
    }
}
