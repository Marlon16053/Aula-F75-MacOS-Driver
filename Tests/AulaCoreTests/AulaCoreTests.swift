import XCTest
@testable import AulaCore

final class AulaCoreTests: XCTestCase {

    func testWirelessPacketChecksumAndFraming() {
        let req = AulaProtocolCodec.buildWirelessReadRequest(cmd: AulaCommandTable.wirelessOnlineCmd, sub: 0)
        XCTAssertEqual(req.count, 20)
        XCTAssertEqual(Array(req.prefix(5)), [0x13, 0x07, 0x01, 0x00, 0x00])
        XCTAssertEqual(req[19], 0x1B)
        XCTAssertTrue(AulaProtocolCodec.isValidWirelessPacket(req))
    }

    func testWirelessMatrixWriteIs28Packets() {
        let matrix = [UInt8](repeating: 0, count: AulaConstants.matrixLength * 3)
        let packets = AulaProtocolCodec.buildWirelessWritePackets(cmd: AulaCommandTable.wireless.ledMatrix, sub: 0, data: matrix)
        XCTAssertEqual(packets.count, 28)
        XCTAssertTrue(packets.dropLast().allSatisfy { $0[2] == 28 && $0[4] == 14 })
        XCTAssertEqual(packets[27][3], 27)
        XCTAssertEqual(packets[27][4], 6)
        XCTAssertTrue(packets.allSatisfy { AulaProtocolCodec.isValidWirelessPacket($0) })
    }

    func testWiredFeatureReportFraming() {
        let payload = [UInt8](repeating: 0x07, count: 600)
        let packets = AulaProtocolCodec.buildWiredPackets(cmd: AulaCommandTable.wired.ledMatrix, sub: 2, totalLength: payload.count, data: payload)
        XCTAssertEqual(packets.count, 2)
        XCTAssertEqual(Array(packets[0].prefix(8)), [0x06, 0x06, 0x02, 0x00, 0x02, 0x00, 0x00, 0x02])
        XCTAssertEqual(Array(packets[1].prefix(8)), [0x06, 0x06, 0x02, 0x00, 0x02, 0x01, 88, 0x00])
    }

    func testLEDBlockValidationAndNonDestructivePatch() {
        var block = AulaProtocolCodec.defaultLEDBlock()
        XCTAssertTrue(AulaProtocolCodec.isLEDBlockValid(block))

        let config = LightingConfiguration(
            effect: .fixedOn,
            brightness: 6,
            speed: 3,
            rainbowMode: false,
            colorSlot: 2,
            primaryColor: .cyberCyan
        )
        AulaProtocolCodec.patchLEDBlock(&block, config: config)
        AulaProtocolCodec.patchSleepTimeout(&block, timeout: .tenMinutes)

        XCTAssertTrue(AulaProtocolCodec.isLEDBlockValid(block))
        XCTAssertEqual(block[9], 0)
        XCTAssertEqual(block[10], 1)
        XCTAssertEqual(block[0x3A], 6)
        XCTAssertEqual(block[0x3B], (3 << 4) | 2)
        XCTAssertEqual(block[AulaConstants.sleepOffset], 20)

        let parsed = AulaProtocolCodec.parseLEDBlock(block)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.0.effect, .fixedOn)
        XCTAssertEqual(parsed?.0.brightness, 6)
        XCTAssertEqual(parsed?.0.speed, 3)
        XCTAssertEqual(parsed?.1, .tenMinutes)
    }

    func testFactoryKeymapPlausibilityAndISOKeys() {
        let layer0 = AulaKeymapCatalog.factoryLayer0()
        XCTAssertEqual(layer0.count, 512)
        XCTAssertTrue(AulaKeymapCatalog.isKeymapPlausible(layer0))
        // Check ISO-DE < > | at slot 76 (0x64) and # ' at slot 75 (0x32)
        XCTAssertEqual(Array(layer0[(76 * 4)..<(76 * 4 + 4)]), [0x00, 0x00, 0x00, 0x64])
        XCTAssertEqual(Array(layer0[(75 * 4)..<(75 * 4 + 4)]), [0x00, 0x00, 0x00, 0x32])
    }

    func testMacroCompiler() {
        let macro = AulaMacro(index: 0, name: "hi", textInput: "Hi", stepDelayMs: 20)
        let buffer = AulaMacro.compileBuffer([macro])
        XCTAssertEqual(Array(buffer.prefix(4)), [4, 0, 29, 0])
        XCTAssertEqual(Array(buffer[4..<9]), [4, UInt8(ascii: "h"), 0, UInt8(ascii: "i"), 0])
        XCTAssertEqual(Array(buffer[9..<13]), [0x10, 0, 4, 0xE1]) // Shift down (modifier type 1)
        XCTAssertEqual(Array(buffer[13..<17]), [0x00, 0, 20, 0x0B]) // 'H' down (key type 0)
        XCTAssertEqual(Array(buffer[17..<21]), [0x80, 0, 4, 0x0B])  // 'H' up
        XCTAssertEqual(buffer.count, 33)
    }

    func testMultiLayoutCatalog() {
        let isoDE = KeyboardLayoutCatalog.layout(for: .isoDE, macMode: true)
        let ansiUS = KeyboardLayoutCatalog.layout(for: .ansiUS, macMode: false)
        let isoUK = KeyboardLayoutCatalog.layout(for: .isoUK, macMode: true)

        XCTAssertTrue(isoDE.keys.contains(where: { $0.label == "Ü" && $0.ledIndex == 68 }))
        XCTAssertTrue(isoDE.keys.contains(where: { $0.id == "ISO_Backslash" && $0.ledIndex == 76 }))
        XCTAssertTrue(isoDE.keys.contains(where: { $0.isISOEnter && $0.ledIndex == 81 }))
        XCTAssertFalse(ansiUS.keys.contains(where: { $0.isISOEnter }))
        XCTAssertEqual(isoUK.keys.count, isoDE.keys.count)
    }
}
