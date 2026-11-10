import AulaCore
import Foundation
@preconcurrency import IOKit.hid

/// Metadata about a discovered USB / Wireless / Bluetooth HID endpoint
public struct HIDEndpointDescriptor: Identifiable, Hashable, Sendable {
    public let id: String
    public let vendorID: Int
    public let productID: Int
    public let usagePage: Int
    public let usage: Int
    public let maxInputReportSize: Int
    public let maxOutputReportSize: Int
    public let maxFeatureReportSize: Int
    public let productName: String
    public let transport: String

    public var vidPidHex: String {
        String(format: "%04X:%04X", vendorID, productID)
    }

    public var usageHex: String {
        String(format: "0x%04X : 0x%02X", usagePage, usage)
    }

    public var roleDescription: String {
        if vendorID == AulaConstants.wiredVendorID && productID == AulaConstants.wiredProductID {
            if maxFeatureReportSize >= AulaConstants.wiredReportLength {
                return "Wired Config (Report 0x06 · 520B)"
            }
            return "Wired HID Interface"
        }
        if vendorID == AulaConstants.wirelessVendorID && productID == AulaConstants.receiverProductID {
            if usagePage == AulaConstants.wirelessVendorUsagePage {
                return "2.4G Vendor Channel (0xFF02 · Report 0x13)"
            }
            if usagePage == 0x01 && usage == 0x06 {
                return "2.4G Boot Keyboard"
            }
            return "2.4G Receiver Interface"
        }
        if vendorID == AulaConstants.wirelessVendorID &&
            (productID == AulaConstants.bluetoothProductID || productID == AulaConstants.bluetoothAltProductID) {
            return "Bluetooth HID"
        }
        return "HID Endpoint"
    }
}

/// Thread-safe RunLoop listener for 20-byte `0x13` input reports from the 2.4 GHz receiver (`3554:FA09`)
final class WirelessReplyMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private var receivedPackets: [[UInt8]] = []
    private let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    private let device: IOHIDDevice
    private let stoppedSemaphore = DispatchSemaphore(value: 0)
    private var runLoop: CFRunLoop?
    private var isStopped = false

    init(device: IOHIDDevice) {
        self.device = device
        let startedSemaphore = DispatchSemaphore(value: 0)
        Thread { [self] in
            let currentLoop = CFRunLoopGetCurrent()!
            lock.withLock { runLoop = currentLoop }
            IOHIDDeviceRegisterInputReportCallback(
                device,
                buffer,
                64,
                { context, result, _, _, reportID, report, length in
                    guard result == kIOReturnSuccess, let context, length >= 19 else { return }
                    var bytes = Array(UnsafeBufferPointer(start: report, count: length))
                    if reportID == 0x13 && bytes.first != 0x13 {
                        bytes.insert(0x13, at: 0)
                    }
                    guard bytes.count >= 20, bytes[0] == 0x13 else { return }
                    let monitor = Unmanaged<WirelessReplyMonitor>.fromOpaque(context).takeUnretainedValue()
                    monitor.append(Array(bytes.prefix(20)))
                },
                Unmanaged.passUnretained(self).toOpaque()
            )
            IOHIDDeviceScheduleWithRunLoop(device, currentLoop, CFRunLoopMode.defaultMode.rawValue)
            startedSemaphore.signal()
            CFRunLoopRun()
            IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, nil, nil)
            IOHIDDeviceUnscheduleFromRunLoop(device, currentLoop, CFRunLoopMode.defaultMode.rawValue)
            stoppedSemaphore.signal()
        }.start()
        startedSemaphore.wait()
    }

    deinit {
        stop()
        buffer.deallocate()
    }

    func stop() {
        let loopToStop: CFRunLoop? = lock.withLock {
            guard !isStopped else { return nil }
            isStopped = true
            return runLoop
        }
        guard let loop = loopToStop else { return }
        CFRunLoopPerformBlock(loop, CFRunLoopMode.defaultMode.rawValue) {
            CFRunLoopStop(loop)
        }
        CFRunLoopWakeUp(loop)
        stoppedSemaphore.wait()
    }

    func clear() {
        lock.withLock { receivedPackets.removeAll(keepingCapacity: true) }
    }

    func takePackets() -> [[UInt8]] {
        lock.withLock { receivedPackets }
    }

    private func append(_ packet: [UInt8]) {
        lock.withLock {
            if receivedPackets.count >= 256 {
                receivedPackets.removeFirst()
            }
            receivedPackets.append(packet)
        }
    }
}

/// Hardware communication manager for the AULA F75 over USB-C Wired (`258A:010C`) and 2.4 GHz Receiver (`3554:FA09`)
public final class AulaHIDManager: @unchecked Sendable {

    public init() {}

    // MARK: Permission & Discovery

    public static var hasInputMonitoringAccess: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    @discardableResult
    public static func requestInputMonitoringAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    /// Scans all connected AULA F75 endpoints without opening exclusive locks
    public func scanEndpoints() -> (
        activeLink: AulaLinkType,
        wiredPresent: Bool,
        receiverPresent: Bool,
        bluetoothPresent: Bool,
        endpoints: [HIDEndpointDescriptor]
    ) {
        let allDevices = Self.copyAllMatchingDevices()
        var endpoints: [HIDEndpointDescriptor] = []
        var wiredPresent = false
        var receiverPresent = false
        var bluetoothPresent = false

        for (idx, dev) in allDevices.enumerated() {
            let vid = Self.intProp(dev, kIOHIDVendorIDKey)
            let pid = Self.intProp(dev, kIOHIDProductIDKey)
            let page = Self.usagePage(dev)
            let usage = Self.usage(dev)
            let inSize = Self.intProp(dev, kIOHIDMaxInputReportSizeKey)
            let outSize = Self.intProp(dev, kIOHIDMaxOutputReportSizeKey)
            let featSize = Self.intProp(dev, kIOHIDMaxFeatureReportSizeKey)
            let name = Self.stringProp(dev, kIOHIDProductKey) ?? "AULA F75"
            let transport = Self.stringProp(dev, kIOHIDTransportKey) ?? "USB"

            if vid == AulaConstants.wiredVendorID && pid == AulaConstants.wiredProductID {
                wiredPresent = true
            } else if vid == AulaConstants.wirelessVendorID && pid == AulaConstants.receiverProductID {
                receiverPresent = true
            } else if vid == AulaConstants.wirelessVendorID &&
                        (pid == AulaConstants.bluetoothProductID || pid == AulaConstants.bluetoothAltProductID) {
                bluetoothPresent = true
            }

            endpoints.append(
                HIDEndpointDescriptor(
                    id: "\(vid)-\(pid)-\(page)-\(usage)-\(idx)",
                    vendorID: vid,
                    productID: pid,
                    usagePage: page,
                    usage: usage,
                    maxInputReportSize: inSize,
                    maxOutputReportSize: outSize,
                    maxFeatureReportSize: featSize,
                    productName: name,
                    transport: transport
                )
            )
        }

        let activeLink: AulaLinkType
        if wiredPresent {
            activeLink = .wired
        } else if receiverPresent {
            activeLink = .receiver
        } else if bluetoothPresent {
            activeLink = .bluetooth
        } else {
            activeLink = .disconnected
        }

        return (activeLink, wiredPresent, receiverPresent, bluetoothPresent, endpoints)
    }

    // MARK: High-Level Hardware Operations

    /// Reads the current 128-byte LED configuration block from the keyboard (Wired or 2.4G Receiver)
    public func readLEDSettingsBlock() throws -> (block: [UInt8], link: AulaLinkType, log: [String]) {
        let session = try openPreferredSession()
        defer { session.close() }
        let block = try session.readData(cmd: session.cmds.ledBlock, sub: 0, length: AulaConstants.ledBlockLength)
        guard AulaProtocolCodec.isLEDBlockValid(block) else {
            throw AulaError.invalidSettingsSignature
        }
        return (block, session.link, session.logs)
    }

    /// Reads the 128-byte LED block, patches lighting & sleep non-destructively, writes it back, and verifies readback
    public func applyLightingAndSleep(
        config: LightingConfiguration,
        sleepTimeout: AulaSleepTimeout
    ) throws -> (verifiedBlock: [UInt8], link: AulaLinkType, log: [String]) {
        let session = try openPreferredSession()
        defer { session.close() }

        let originalBlock = try session.readData(cmd: session.cmds.ledBlock, sub: 0, length: AulaConstants.ledBlockLength)
        guard AulaProtocolCodec.isLEDBlockValid(originalBlock) else {
            throw AulaError.invalidSettingsSignature
        }

        var updatedBlock = originalBlock
        AulaProtocolCodec.patchLEDBlock(&updatedBlock, config: config)
        AulaProtocolCodec.patchSleepTimeout(&updatedBlock, timeout: sleepTimeout)

        // If wired and using a custom single color, also update the 512-byte palette
        if session.link == .wired && config.effect.supportsCustomColor && !config.rainbowMode {
            if var palette = try? session.readData(cmd: session.cmds.palette, sub: 2, length: AulaConstants.paletteLength),
               palette.count >= AulaConstants.paletteLength {
                AulaProtocolCodec.patchWiredPalette(&palette, color: config.primaryColor)
                try? session.writeData(cmd: session.cmds.palette, sub: 2, data: palette, delayMs: 20)
            }
        }

        try session.writeData(cmd: session.cmds.ledBlock, sub: 0, data: updatedBlock, delayMs: 15)
        if session.link == .receiver {
            try session.sendWirelessSave()
        }

        let verifyBlock = try session.readData(cmd: session.cmds.ledBlock, sub: 0, length: AulaConstants.ledBlockLength)
        guard AulaProtocolCodec.isLEDBlockValid(verifyBlock),
              verifyBlock[AulaConstants.effectIDOffset] == updatedBlock[AulaConstants.effectIDOffset] else {
            // Rollback on mismatch
            try? session.writeData(cmd: session.cmds.ledBlock, sub: 0, data: originalBlock, delayMs: 15)
            throw AulaError.verificationFailed("LED block readback mismatch")
        }

        return (verifyBlock, session.link, session.logs)
    }

    /// Writes a 126-LED per-key custom RGB canvas to hardware memory (`0x02` wireless / `0x06` wired) and switches to mode 21
    public func applyPerKeyMatrix(
        colors: [RGBColor],
        brightness: Int
    ) throws -> (link: AulaLinkType, log: [String]) {
        let session = try openPreferredSession()
        defer { session.close() }

        let originalBlock = try session.readData(cmd: session.cmds.ledBlock, sub: 0, length: AulaConstants.ledBlockLength)
        guard AulaProtocolCodec.isLEDBlockValid(originalBlock) else {
            throw AulaError.invalidSettingsSignature
        }

        let matrixBytes = AulaProtocolCodec.buildPerKeyMatrixPayload(colors: colors)
        try session.writeData(cmd: session.cmds.ledMatrix, sub: 0, data: matrixBytes, delayMs: 15)

        var updatedBlock = originalBlock
        let perKeyConfig = LightingConfiguration(
            effect: .perKeyCustom,
            brightness: brightness,
            speed: 2,
            rainbowMode: false
        )
        AulaProtocolCodec.patchLEDBlock(&updatedBlock, config: perKeyConfig)
        try session.writeData(cmd: session.cmds.ledBlock, sub: 0, data: updatedBlock, delayMs: 15)

        if session.link == .receiver {
            try session.sendWirelessSave()
        }
        return (session.link, session.logs)
    }

    /// Streams a single live RGB frame (`0x08` wired / `0x88` wireless) without modifying persistent flash
    public func streamRealtimeFrame(colors: [RGBColor]) throws {
        let session = try openPreferredSession()
        defer { session.close() }
        let payload = AulaProtocolCodec.buildRealtimeInterleavedPayload(colors: colors)
        try session.writeData(cmd: session.cmds.realtime, sub: 0, data: payload, delayMs: session.link == .wired ? 7 : 10)
    }

    /// Reads the 512-byte keymap for a layer (`0` = Base, `1` = Fn)
    public func readKeymap(layer: UInt8) throws -> (keymap: [UInt8], link: AulaLinkType, log: [String]) {
        let session = try openPreferredSession()
        defer { session.close() }
        let data = try session.readData(cmd: session.cmds.keymap, sub: layer, length: AulaConstants.keymapLayerLength)
        if layer == 0 && !AulaKeymapCatalog.isKeymapPlausible(data) {
            throw AulaError.invalidKeymapBlock
        }
        return (data, session.link, session.logs)
    }

    /// Writes a 512-byte keymap layer after verifying layer plausibility
    public func writeKeymap(layer: UInt8, data: [UInt8]) throws -> (link: AulaLinkType, log: [String]) {
        guard data.count == AulaConstants.keymapLayerLength else {
            throw AulaError.invalidKeymapBlock
        }
        if layer == 0 && !AulaKeymapCatalog.isKeymapPlausible(data) {
            throw AulaError.invalidKeymapBlock
        }
        let session = try openPreferredSession()
        defer { session.close() }
        try session.writeData(cmd: session.cmds.keymap, sub: layer, data: data, delayMs: 15)
        if session.link == .receiver {
            try session.sendWirelessSave()
        }
        return (session.link, session.logs)
    }

    /// Uploads compiled hardware macros (`0x05` wired / `0x03` wireless 512-byte pages)
    public func uploadMacros(_ macros: [AulaMacro]) throws -> (link: AulaLinkType, log: [String]) {
        let buffer = AulaMacro.compileBuffer(macros)
        guard !buffer.isEmpty else { return (.disconnected, []) }
        let session = try openPreferredSession()
        defer { session.close() }

        Thread.sleep(forTimeInterval: 0.1)
        if session.link == .wired {
            try session.writeData(cmd: session.cmds.macros, sub: 0, data: buffer, delayMs: 20)
        } else {
            let pageSize = 512
            let pages = stride(from: 0, to: buffer.count, by: pageSize).map {
                Array(buffer[$0..<min($0 + pageSize, buffer.count)])
            }
            for (pageIndex, chunk) in pages.enumerated() {
                try session.writeData(cmd: session.cmds.macros, sub: UInt8(pageIndex), data: chunk, delayMs: 15)
                Thread.sleep(forTimeInterval: 0.1)
            }
            try session.sendWirelessSave()
        }
        return (session.link, session.logs)
    }

    /// Checks whether the keyboard is awake and linked to the 2.4 GHz receiver (`cmd 0x07`)
    public func queryWirelessOnline() -> Bool? {
        guard let session = try? openPreferredSession() else { return nil }
        defer { session.close() }
        if session.link == .wired { return true }
        guard let reply = try? session.readData(cmd: AulaCommandTable.wirelessOnlineCmd, sub: 0, length: 1),
              let first = reply.first else {
            return nil
        }
        return first != 0
    }

    // MARK: - Internal Transport Session

    private final class TransportSession {
        let device: IOHIDDevice
        let link: AulaLinkType
        let cmds: AulaCommandTable
        let monitor: WirelessReplyMonitor?
        var logs: [String] = []

        init(device: IOHIDDevice, link: AulaLinkType) {
            self.device = device
            self.link = link
            self.cmds = AulaCommandTable.forLink(link)
            self.monitor = (link == .receiver) ? WirelessReplyMonitor(device: device) : nil
        }

        func close() {
            monitor?.stop()
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        func writeData(cmd: UInt8, sub: UInt8, data: [UInt8], delayMs: UInt64) throws {
            let start = Date()
            if link == .wired {
                let packets = AulaProtocolCodec.buildWiredPackets(cmd: cmd, sub: sub, totalLength: data.count, data: data)
                for pkt in packets {
                    Thread.sleep(forTimeInterval: Double(min(delayMs, 20)) / 1000.0)
                    try sendWiredFeatureReport(pkt)
                }
            } else {
                let wantsAck = (cmd & 0x80) == 0
                let packets = AulaProtocolCodec.buildWirelessWritePackets(cmd: cmd, sub: sub, data: data)
                for (index, pkt) in packets.enumerated() {
                    var tries = 0
                    while true {
                        Thread.sleep(forTimeInterval: Double(delayMs) / 1000.0)
                        monitor?.clear()
                        try sendWirelessOutputReport(pkt)
                        if !wantsAck { break }
                        if waitForWirelessAck(cmd: cmd, expectedIndex: index, timeout: 0.85) {
                            break
                        }
                        tries += 1
                        if tries > 4 {
                            throw AulaError.incompleteWirelessReply(String(format: "Keine Bestätigung für Paket %d (0x%02X)", index, cmd))
                        }
                    }
                }
            }
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            logs.append(String(format: "[%@] WRITE cmd=0x%02X sub=%d bytes=%d (%dms)", link.rawValue, cmd, sub, data.count, elapsed))
        }

        func readData(cmd: UInt8, sub: UInt8, length: Int) throws -> [UInt8] {
            let readCmd = (cmd == AulaCommandTable.wirelessOnlineCmd) ? cmd : (cmd | cmds.readFlag)
            let start = Date()
            let output: [UInt8]

            if link == .wired {
                var collected: [UInt8] = []
                let packets = AulaProtocolCodec.buildWiredPackets(cmd: readCmd, sub: sub, totalLength: length, data: nil)
                for pkt in packets {
                    let expectedSize = Int(pkt[6]) | (Int(pkt[7]) << 8)
                    Thread.sleep(forTimeInterval: 0.02)
                    try sendWiredFeatureReport(pkt)
                    Thread.sleep(forTimeInterval: 0.025)
                    let rx = try getWiredFeatureReport()
                    guard rx.count >= 8 + expectedSize else {
                        throw AulaError.incompleteWirelessReply("Kurze Antwort über USB-C (\(rx.count) Bytes)")
                    }
                    collected.append(contentsOf: rx[8..<(8 + expectedSize)])
                }
                output = collected
            } else {
                output = try readWirelessMultiPacket(readCmd: readCmd, sub: sub, expectedLength: length)
            }

            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            logs.append(String(format: "[%@] READ cmd=0x%02X sub=%d bytes=%d (%dms)", link.rawValue, readCmd, sub, output.count, elapsed))
            return output
        }

        func sendWirelessSave() throws {
            guard link == .receiver else { return }
            let pkt = AulaProtocolCodec.buildWirelessSavePacket()
            monitor?.clear()
            try sendWirelessOutputReport(pkt)
            _ = waitForWirelessAck(cmd: AulaCommandTable.wirelessSaveCmd, expectedIndex: 0, timeout: 0.5)
        }

        private func sendWiredFeatureReport(_ packet: [UInt8]) throws {
            var lastStatus: IOReturn = kIOReturnError
            for _ in 0..<3 {
                let status = packet.withUnsafeBufferPointer { ptr in
                    IOHIDDeviceSetReport(
                        device,
                        kIOHIDReportTypeFeature,
                        CFIndex(AulaConstants.wiredReportID),
                        ptr.baseAddress!,
                        packet.count
                    )
                }
                if status == kIOReturnSuccess { return }
                lastStatus = status
                Thread.sleep(forTimeInterval: 0.06)
            }
            throw AulaError.hidTransferFailed("USB-C SetFeature(0x06)", Int32(lastStatus))
        }

        private func getWiredFeatureReport() throws -> [UInt8] {
            var buffer = [UInt8](repeating: 0, count: AulaConstants.wiredReportLength)
            buffer[0] = AulaConstants.wiredReportID
            var length: CFIndex = buffer.count
            let status = buffer.withUnsafeMutableBufferPointer { ptr in
                IOHIDDeviceGetReport(
                    device,
                    kIOHIDReportTypeFeature,
                    CFIndex(AulaConstants.wiredReportID),
                    ptr.baseAddress!,
                    &length
                )
            }
            guard status == kIOReturnSuccess else {
                throw AulaError.hidTransferFailed("USB-C GetFeature(0x06)", Int32(status))
            }
            return Array(buffer.prefix(length))
        }

        private func sendWirelessOutputReport(_ packet: [UInt8]) throws {
            let status = packet.withUnsafeBufferPointer { ptr in
                IOHIDDeviceSetReport(
                    device,
                    kIOHIDReportTypeOutput,
                    CFIndex(AulaConstants.wirelessReportID),
                    ptr.baseAddress!,
                    packet.count
                )
            }
            guard status == kIOReturnSuccess else {
                throw AulaError.hidTransferFailed("2.4G SetOutput(0x13)", Int32(status))
            }
        }

        private func waitForWirelessAck(cmd: UInt8, expectedIndex: Int, timeout: TimeInterval) -> Bool {
            guard let monitor else { return false }
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                for pkt in monitor.takePackets() where AulaProtocolCodec.isValidWirelessPacket(pkt) {
                    if let reply = AulaProtocolCodec.parseWirelessReply(pkt),
                       reply.cmd == (cmd & 0x7F),
                       !reply.crcError,
                       reply.index == expectedIndex {
                        return true
                    }
                }
                Thread.sleep(forTimeInterval: 0.004)
            }
            return false
        }

        private func readWirelessMultiPacket(readCmd: UInt8, sub: UInt8, expectedLength: Int) throws -> [UInt8] {
            guard let monitor else { throw AulaError.deviceNotFound }
            let req = AulaProtocolCodec.buildWirelessReadRequest(cmd: readCmd, sub: sub)
            var out = [UInt8](repeating: 0, count: max(expectedLength, AulaConstants.wirelessChunkLength))
            var receivedFlags: [Bool] = []
            var totalPackets = 0

            for attempt in 0..<4 {
                if attempt > 0 { Thread.sleep(forTimeInterval: 0.06) }
                monitor.clear()
                try sendWirelessOutputReport(req)

                let deadline = Date().addingTimeInterval(0.65)
                while Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.005)
                    for pkt in monitor.takePackets() where AulaProtocolCodec.isValidWirelessPacket(pkt) {
                        guard let reply = AulaProtocolCodec.parseWirelessReply(pkt),
                              reply.cmd == (readCmd & 0x7F),
                              !reply.crcError else {
                            continue
                        }
                        if totalPackets == 0 {
                            totalPackets = max(1, reply.total)
                            receivedFlags = [Bool](repeating: false, count: totalPackets)
                        }
                        guard reply.index < totalPackets, reply.total == totalPackets else { continue }
                        let offset = reply.index * AulaConstants.wirelessChunkLength
                        if out.count < offset + reply.payloadLength {
                            out.append(contentsOf: repeatElement(0, count: offset + reply.payloadLength - out.count))
                        }
                        out.replaceSubrange(offset..<(offset + reply.payloadLength), with: reply.payload)
                        receivedFlags[reply.index] = true

                        if receivedFlags.allSatisfy({ $0 }) {
                            return Array(out.prefix(expectedLength))
                        }
                    }
                }
            }
            let gotCount = receivedFlags.filter { $0 }.count
            throw AulaError.incompleteWirelessReply("\(gotCount)/\(max(totalPackets, 1)) Pakete empfangen")
        }
    }

    private func openPreferredSession() throws -> TransportSession {
        let devices = Self.copyAllMatchingDevices()

        // 1. Prefer USB-C Wired (258A:010C) with feature report >= 520
        let wiredCandidates = devices.filter {
            Self.intProp($0, kIOHIDVendorIDKey) == AulaConstants.wiredVendorID &&
            Self.intProp($0, kIOHIDProductIDKey) == AulaConstants.wiredProductID &&
            Self.intProp($0, kIOHIDMaxFeatureReportSizeKey) >= AulaConstants.wiredReportLength
        }
        if let wiredDev = wiredCandidates.max(by: {
            Self.intProp($0, kIOHIDMaxFeatureReportSizeKey) < Self.intProp($1, kIOHIDMaxFeatureReportSizeKey)
        }) {
            let status = IOHIDDeviceOpen(wiredDev, IOOptionBits(kIOHIDOptionsTypeNone))
            guard status == kIOReturnSuccess else {
                if !Self.hasInputMonitoringAccess {
                    Self.requestInputMonitoringAccess()
                    throw AulaError.permissionDenied("USB-C Zugriff blockiert")
                }
                throw AulaError.openFailed(Int32(status))
            }
            return TransportSession(device: wiredDev, link: .wired)
        }

        // 2. Next prefer 2.4 GHz Receiver (3554:FA09) on usage page 0xFF02
        let wirelessCandidates = devices.filter {
            Self.intProp($0, kIOHIDVendorIDKey) == AulaConstants.wirelessVendorID &&
            Self.intProp($0, kIOHIDProductIDKey) == AulaConstants.receiverProductID &&
            Self.hasVendorChannel($0, usagePage: AulaConstants.wirelessVendorUsagePage)
        }
        if let wirelessDev = wirelessCandidates.first {
            let status = IOHIDDeviceOpen(wirelessDev, IOOptionBits(kIOHIDOptionsTypeNone))
            guard status == kIOReturnSuccess else {
                if !Self.hasInputMonitoringAccess {
                    Self.requestInputMonitoringAccess()
                    throw AulaError.permissionDenied("2.4G Empfänger Zugriff blockiert")
                }
                throw AulaError.openFailed(Int32(status))
            }
            return TransportSession(device: wirelessDev, link: .receiver)
        }

        // 3. Check if Bluetooth is connected (inform user cleanly)
        let btPresent = devices.contains {
            Self.intProp($0, kIOHIDVendorIDKey) == AulaConstants.wirelessVendorID &&
            (Self.intProp($0, kIOHIDProductIDKey) == AulaConstants.bluetoothProductID ||
             Self.intProp($0, kIOHIDProductIDKey) == AulaConstants.bluetoothAltProductID)
        }
        if btPresent {
            throw AulaError.bluetoothWriteUnsupported
        }

        throw AulaError.deviceNotFound
    }

    // MARK: IOHID Helpers

    private static func copyAllMatchingDevices() -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matchDicts: [[String: Any]] = [
            [kIOHIDVendorIDKey: AulaConstants.wiredVendorID, kIOHIDProductIDKey: AulaConstants.wiredProductID],
            [kIOHIDVendorIDKey: AulaConstants.wirelessVendorID, kIOHIDProductIDKey: AulaConstants.receiverProductID],
            [kIOHIDVendorIDKey: AulaConstants.wirelessVendorID, kIOHIDProductIDKey: AulaConstants.bluetoothProductID],
            [kIOHIDVendorIDKey: AulaConstants.wirelessVendorID, kIOHIDProductIDKey: AulaConstants.bluetoothAltProductID]
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchDicts as CFArray)
        _ = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

        guard let set = IOHIDManagerCopyDevices(manager) else { return [] }
        let count = CFSetGetCount(set)
        var ptrs = [UnsafeRawPointer?](repeating: nil, count: count)
        CFSetGetValues(set, &ptrs)
        return ptrs.compactMap { ptr in
            guard let ptr else { return nil }
            return Unmanaged<IOHIDDevice>.fromOpaque(ptr).retain().takeRetainedValue()
        }
    }

    private static func hasVendorChannel(_ device: IOHIDDevice, usagePage: Int) -> Bool {
        if Self.usagePage(device) == usagePage { return true }
        let pairs = (IOHIDDeviceGetProperty(device, kIOHIDDeviceUsagePairsKey as CFString) as? [[String: Int]]) ?? []
        return pairs.contains { $0[kIOHIDDeviceUsagePageKey] == usagePage }
    }

    private static func intProp(_ device: IOHIDDevice, _ key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0
    }

    private static func stringProp(_ device: IOHIDDevice, _ key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private static func usagePage(_ device: IOHIDDevice) -> Int {
        let primary = intProp(device, kIOHIDPrimaryUsagePageKey)
        return primary != 0 ? primary : intProp(device, kIOHIDDeviceUsagePageKey)
    }

    private static func usage(_ device: IOHIDDevice) -> Int {
        let primary = intProp(device, kIOHIDPrimaryUsageKey)
        return primary != 0 ? primary : intProp(device, kIOHIDDeviceUsageKey)
    }
}
