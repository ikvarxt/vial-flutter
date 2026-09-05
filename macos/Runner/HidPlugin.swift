// SPDX-License-Identifier: GPL-2.0-or-later
import Cocoa
import FlutterMacOS
import IOKit.hid

/// Bridges IOHIDManager to Dart over the "vial/hid" method channel.
///
/// Everything runs on the main run loop: reads never block, they park a
/// FlutterResult that is completed by the input-report callback or by a
/// timeout. This mirrors hidapi's read(timeout_ms) semantics closely enough
/// for the 32-byte request/response protocol Vial uses.
final class HidPlugin: NSObject {
  private static let channelName = "vial/hid"
  private static let usagePairsKey = "DeviceUsagePairs"

  private final class Opened {
    let device: IOHIDDevice
    var buffer: [UInt8]
    var queue: [[UInt8]] = []
    var pending: FlutterResult?
    var pendingToken = 0
    var removed = false

    init(device: IOHIDDevice, reportSize: Int) {
      self.device = device
      self.buffer = [UInt8](repeating: 0, count: max(reportSize, 64))
    }
  }

  private let channel: FlutterMethodChannel
  private var opened: [Int: Opened] = [:]
  private var nextHandle = 1

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: HidPlugin.channelName, binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "enumerate":
      result(enumerate())
    case "open":
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
        result(FlutterError(code: "args", message: "path required", details: nil))
        return
      }
      open(path: path, result: result)
    case "write":
      guard let args = call.arguments as? [String: Any],
        let handle = args["handle"] as? Int,
        let data = args["data"] as? FlutterStandardTypedData
      else {
        result(FlutterError(code: "args", message: "handle/data required", details: nil))
        return
      }
      write(handle: handle, data: [UInt8](data.data), result: result)
    case "read":
      guard let args = call.arguments as? [String: Any],
        let handle = args["handle"] as? Int
      else {
        result(FlutterError(code: "args", message: "handle required", details: nil))
        return
      }
      let length = args["length"] as? Int ?? 32
      let timeoutMs = args["timeoutMs"] as? Int ?? 0
      read(handle: handle, length: length, timeoutMs: timeoutMs, result: result)
    case "close":
      guard let args = call.arguments as? [String: Any], let handle = args["handle"] as? Int else {
        result(FlutterError(code: "args", message: "handle required", details: nil))
        return
      }
      close(handle: handle)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - enumeration

  private func allDevices() -> [IOHIDDevice] {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(manager, nil)
    guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
    return Array(set)
  }

  private func registryId(_ device: IOHIDDevice) -> UInt64 {
    let service = IOHIDDeviceGetService(device)
    var entryId: UInt64 = 0
    IORegistryEntryGetRegistryEntryID(service, &entryId)
    return entryId
  }

  private func intProp(_ device: IOHIDDevice, _ key: String) -> Int {
    return (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0
  }

  private func strProp(_ device: IOHIDDevice, _ key: String) -> String {
    return (IOHIDDeviceGetProperty(device, key as CFString) as? String) ?? ""
  }

  /// One entry per (usage page, usage) pair, like hidapi does on macOS, so a
  /// composite keyboard exposes its raw-HID collection separately.
  private func enumerate() -> [[String: Any]] {
    var out: [[String: Any]] = []
    for device in allDevices() {
      let id = registryId(device)
      var pairs: [(Int, Int)] = []
      if let list = IOHIDDeviceGetProperty(device, HidPlugin.usagePairsKey as CFString) as? [[String: Any]] {
        for pair in list {
          let page = (pair[kIOHIDDeviceUsagePageKey] as? NSNumber)?.intValue ?? 0
          let usage = (pair[kIOHIDDeviceUsageKey] as? NSNumber)?.intValue ?? 0
          pairs.append((page, usage))
        }
      }
      if pairs.isEmpty {
        pairs.append((intProp(device, kIOHIDPrimaryUsagePageKey), intProp(device, kIOHIDPrimaryUsageKey)))
      }
      for (page, usage) in pairs {
        out.append([
          "path": "\(id):\(page):\(usage)",
          "vendorId": intProp(device, kIOHIDVendorIDKey),
          "productId": intProp(device, kIOHIDProductIDKey),
          "serialNumber": strProp(device, kIOHIDSerialNumberKey),
          "manufacturer": strProp(device, kIOHIDManufacturerKey),
          "product": strProp(device, kIOHIDProductKey),
          "usagePage": page,
          "usage": usage,
        ])
      }
    }
    return out
  }

  // MARK: - open / close

  private func open(path: String, result: @escaping FlutterResult) {
    guard let idText = path.split(separator: ":").first, let wanted = UInt64(idText) else {
      result(FlutterError(code: "path", message: "malformed path \(path)", details: nil))
      return
    }
    guard let device = allDevices().first(where: { registryId($0) == wanted }) else {
      result(FlutterError(code: "notfound", message: "device \(path) not present", details: nil))
      return
    }
    let ret = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    guard ret == kIOReturnSuccess else {
      result(FlutterError(code: "open", message: "IOHIDDeviceOpen failed: \(ret)", details: nil))
      return
    }

    let reportSize = intProp(device, kIOHIDMaxInputReportSizeKey)
    let entry = Opened(device: device, reportSize: reportSize)
    let handle = nextHandle
    nextHandle += 1
    opened[handle] = entry

    let context = Unmanaged.passUnretained(entry).toOpaque()
    entry.buffer.withUnsafeMutableBufferPointer { buf in
      IOHIDDeviceRegisterInputReportCallback(
        device, buf.baseAddress!, buf.count, HidPlugin.inputReportCallback, context)
    }
    IOHIDDeviceRegisterRemovalCallback(device, HidPlugin.removalCallback, context)
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    result(handle)
  }

  private func close(handle: Int) {
    guard let entry = opened.removeValue(forKey: handle) else { return }
    if let pending = entry.pending {
      entry.pending = nil
      pending(FlutterStandardTypedData(bytes: Data()))
    }
    if !entry.removed {
      IOHIDDeviceUnscheduleFromRunLoop(entry.device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
      IOHIDDeviceRegisterInputReportCallback(entry.device, &entry.buffer, entry.buffer.count, nil, nil)
      IOHIDDeviceClose(entry.device, IOOptionBits(kIOHIDOptionsTypeNone))
    }
  }

  // MARK: - I/O

  private func write(handle: Int, data: [UInt8], result: @escaping FlutterResult) {
    guard let entry = opened[handle], !entry.removed else {
      result(FlutterError(code: "closed", message: "device is not open", details: nil))
      return
    }
    // Report ID 0: the report data is sent as-is, hidapi strips the leading
    // zero byte the same way.
    let ret = data.withUnsafeBufferPointer { buf in
      IOHIDDeviceSetReport(entry.device, kIOHIDReportTypeOutput, 0, buf.baseAddress!, buf.count)
    }
    if ret == kIOReturnSuccess {
      result(nil)
    } else {
      result(FlutterError(code: "write", message: "IOHIDDeviceSetReport failed: \(ret)", details: nil))
    }
  }

  private func read(handle: Int, length: Int, timeoutMs: Int, result: @escaping FlutterResult) {
    guard let entry = opened[handle] else {
      result(FlutterError(code: "closed", message: "device is not open", details: nil))
      return
    }
    if !entry.queue.isEmpty {
      let report = entry.queue.removeFirst()
      result(FlutterStandardTypedData(bytes: Data(report.prefix(length))))
      return
    }
    if entry.removed {
      result(FlutterError(code: "removed", message: "device was unplugged", details: nil))
      return
    }
    // Only one outstanding read per device; a second one cancels the first.
    if let previous = entry.pending {
      previous(FlutterStandardTypedData(bytes: Data()))
    }
    entry.pendingToken += 1
    let token = entry.pendingToken
    entry.pending = { value in
      if let data = value as? FlutterStandardTypedData {
        result(FlutterStandardTypedData(bytes: data.data.prefix(length)))
      } else {
        result(value)
      }
    }
    if timeoutMs > 0 {
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) {
        guard entry.pendingToken == token, let pending = entry.pending else { return }
        entry.pending = nil
        pending(FlutterStandardTypedData(bytes: Data()))
      }
    }
  }

  private static let inputReportCallback: IOHIDReportCallback = {
    context, _, _, _, _, report, reportLength in
    guard let context = context else { return }
    let entry = Unmanaged<Opened>.fromOpaque(context).takeUnretainedValue()
    let bytes = [UInt8](UnsafeBufferPointer(start: report, count: Int(reportLength)))
    if let pending = entry.pending {
      entry.pending = nil
      pending(FlutterStandardTypedData(bytes: Data(bytes)))
    } else {
      entry.queue.append(bytes)
    }
  }

  private static let removalCallback: IOHIDCallback = { context, _, _ in
    guard let context = context else { return }
    let entry = Unmanaged<Opened>.fromOpaque(context).takeUnretainedValue()
    entry.removed = true
    if let pending = entry.pending {
      entry.pending = nil
      pending(FlutterError(code: "removed", message: "device was unplugged", details: nil))
    }
  }
}
