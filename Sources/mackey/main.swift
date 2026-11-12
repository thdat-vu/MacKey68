// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import MacKeyKit

let helpText = """
mackey — remap a Ziyoulang/68-key keyboard into a Mac keyboard, without software
from the vendor.

USAGE
  mackey list                      Kiểm tra bàn phím đang cắm (VID:PID, layout)
  mackey layouts                   Liệt kê layout vẽ được (68 / TKL / Full)
  mackey keys                      Liệt kê tên phím dùng được trong config
  mackey watch                     In ra mã phím thật khi bạn bấm (để dò Fn+...)
  mackey apply [--config FILE]     Áp dụng keymap
  mackey reset                     Xoá toàn bộ remap
  mackey dump                      Xem remap đang có hiệu lực
  mackey agent [--config FILE]     Chạy nền, tự áp lại mỗi khi cắm lại bàn phím
  mackey install-agent [--config FILE]
  mackey uninstall-agent
  mackey status
  mackey board                     Mở cửa sổ bàn phím của app MacKey68
  mackey init                      Tạo config mẫu ở ~/.config/mackey/keymap.json
  mackey selftest                  Chạy kiểm tra nội bộ

OPTIONS
  --config FILE     Đường dẫn keymap JSON
  --device V:P      Chỉ áp dụng cho một thiết bị, ví dụ 0x3151:0x5029
  --dry-run         Chỉ in ra sẽ làm gì

Config mặc định: ~/.config/mackey/keymap.json
"""

func stderr(_ text: String) {
    FileHandle.standardError.write(Data(text.utf8))
}

func fail(_ message: String) -> Never {
    stderr("mackey: \(message)\n")
    exit(1)
}

func defaultConfigURL() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/mackey/keymap.json")
}

struct Options {
    var command: String = ""
    var configPath: String?
    var device: DeviceID?
    var dryRun = false
}

func parseOptions(_ arguments: [String]) -> Options {
    var options = Options()
    var rest = arguments

    while !rest.isEmpty {
        let argument = rest.removeFirst()
        switch argument {
        case "--config", "-c":
            guard !rest.isEmpty else { fail("--config cần một đường dẫn") }
            options.configPath = rest.removeFirst()
        case "--device", "-d":
            guard !rest.isEmpty else { fail("--device cần giá trị VID:PID") }
            let spec = rest.removeFirst()
            guard let device = DeviceID(spec: spec) else { fail("VID:PID không hợp lệ: \(spec)") }
            options.device = device
        case "--dry-run":
            options.dryRun = true
        case "--help", "-h":
            print(helpText)
            exit(0)
        default:
            if options.command.isEmpty {
                options.command = argument
            } else {
                fail("tham số thừa: \(argument)")
            }
        }
    }
    return options
}

func loadKeymap(_ options: Options) -> (KeymapConfig, URL) {
    let url: URL
    if let path = options.configPath {
        url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    } else {
        url = defaultConfigURL()
    }
    guard FileManager.default.fileExists(atPath: url.path) else {
        fail("không thấy config \(url.path) — chạy `mackey init` trước")
    }
    do {
        return (try KeymapConfig.load(from: url), url)
    } catch {
        fail("đọc config thất bại: \(error)")
    }
}

func effectiveDevice(_ config: KeymapConfig, _ options: Options) -> DeviceID? {
    if let device = options.device { return device }
    if let device = config.device, !device.isEmpty { return device }
    return nil
}

func describe(_ mappings: [ResolvedMapping]) -> String {
    mappings.map { mapping in
        let from = KeyCodes.name(for: mapping.source) ?? String(format: "0x%02X", mapping.source)
        let to = KeyCodes.name(for: mapping.destination) ?? String(format: "0x%02X", mapping.destination)
        return "  \(from)  ->  \(to)"
    }.joined(separator: "\n")
}

// MARK: - Commands

func runList() {
    let devices = HIDDevices.all()
    guard !devices.isEmpty else { fail("không thấy thiết bị HID nào") }
    let keyboards = HIDDevices.uniqueKeyboards()
    let config = try? KeymapConfig.load(from: defaultConfigURL())

    print("Bàn phím:")
    if keyboards.isEmpty {
        print("  (không có)")
    }
    for device in keyboards {
        let layout = Layouts.detect(product: device.product,
                                    manufacturer: device.manufacturer,
                                    vendorID: device.vendorID,
                                    productID: device.productID)
        let managed = config?.devices?.contains { $0.matches(device) } == true
        print(String(format: "  %@  %@  [%@]  layout %@%@",
                     device.id.description,
                     device.label.isEmpty ? "(không tên)" : device.label,
                     device.transport.isEmpty ? "?" : device.transport,
                     layout.shortName,
                     managed ? "  · đã quản lý" : ""))
    }
    print("")
    print("Cổng USB đang cắm (những thứ khác):")
    var seen = Set<String>()
    for device in devices where !device.isKeyboard {
        let key = device.id.description + device.label
        guard seen.insert(key).inserted else { continue }
        print(String(format: "  %@  %@", device.id.description,
                     device.label.isEmpty ? "(không tên)" : device.label))
    }
}

func runLayouts() {
    for id in LayoutID.allCases {
        let layout = Layouts.layout(for: id)
        print(String(format: "  %-4@  %-20@  %3d phím  %5.2f unit",
                     id.shortName, layout.name, id.keyCount, layout.unitCount))
    }
}

func runKeys() {
    for name in KeyCodes.allNames {
        print(name)
    }
}

func runWatch() {
    KeyWatcher.run(filter: nil)
}

func runApply(_ options: Options) {
    let (config, url) = loadKeymap(options)
    let mappings: [ResolvedMapping]
    do {
        mappings = try KeymapResolver.resolve(config.defaultProfile.mappings)
    } catch {
        fail("\(error)")
    }

    let connected = HIDDevices.uniqueKeyboards()
    let targets: [DeviceID]
    if let device = options.device {
        targets = [device]
    } else {
        let managed = config.enabledDevices.filter { entry in
            connected.contains { entry.matches($0) }
        }
        targets = managed.isEmpty
            ? [config.device].compactMap { $0 }
            : managed.map(\.device)
    }
    guard !targets.isEmpty else {
        fail("chưa thấy bàn phím nào đang cắm")
    }

    print("Config: \(url.path)")
    print("Áp dụng cho:")
    for target in targets {
        let name = connected.first { target.matches($0.id) }?.label ?? target.description
        print("  \(target.description)  \(name)")
    }
    print("Mapping:")
    print(mappings.isEmpty ? "  (trống)" : describe(mappings))

    if options.dryRun {
        print("\n--dry-run: không ghi gì cả.")
        return
    }

    do {
        for target in targets {
            let output = try HIDUtil.apply(mappings, matching: target)
            if !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("\n\(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        print("\nXong. Remap chỉ mất khi rút bàn phím ra — dùng `mackey install-agent` để giữ nó.")
    } catch {
        fail("\(error)")
    }
}

func runReset(_ options: Options) {
    let device = options.device
    if options.dryRun {
        print("Sẽ xoá remap cho \(device?.description ?? "tất cả bàn phím").")
        return
    }
    do {
        _ = try HIDUtil.reset(matching: device)
        print("Đã xoá remap cho \(device?.description ?? "tất cả bàn phím").")
    } catch {
        fail("\(error)")
    }
}

func runDump(_ options: Options) {
    do {
        print(try HIDUtil.currentMapping(matching: options.device).trimmingCharacters(in: .whitespacesAndNewlines))
    } catch {
        fail("\(error)")
    }
}

func runAgent(_ options: Options) {
    let (config, url) = loadKeymap(options)
    let mappings: [ResolvedMapping]
    do {
        mappings = try KeymapResolver.resolve(config.defaultProfile.mappings)
    } catch {
        fail("\(error)")
    }
    let device = effectiveDevice(config, options)

    func stamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }

    func apply(reason: String) {
        do {
            _ = try HIDUtil.apply(mappings, matching: device)
            print("[\(stamp())] applied \(mappings.count) mapping(s) — \(reason)")
        } catch {
            stderr("[\(stamp())] apply failed — \(error)\n")
        }
        fflush(stdout)
    }

    print("mackey agent — config \(url.path)")
    print("watch \(device?.description ?? "all keyboards"), \(mappings.count) mapping(s)")
    fflush(stdout)

    apply(reason: "startup")

    let watcher = DeviceWatcher(matching: device) { hit in
        apply(reason: "\(hit.label) connected")
    }
    watcher.start()
    RunLoop.main.run()
}

func runInit(_ options: Options) {
    let url = options.configPath.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
        ?? defaultConfigURL()
    if FileManager.default.fileExists(atPath: url.path) {
        fail("\(url.path) đã tồn tại")
    }
    let sample = """
    {
      "name": "K68 on macOS",
      "device": { "vendorID": null, "productID": null },
      "mappings": [
        { "from": "CapsLock", "to": "Escape" }
      ]
    }
    """
    do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try sample.write(to: url, atomically: true, encoding: .utf8)
        print("Đã tạo \(url.path)")
        print("Sửa file rồi chạy: mackey apply")
    } catch {
        fail("\(error)")
    }
}

func runInstallAgent(_ options: Options) {    let (_, url) = loadKeymap(options)
    guard let executable = Bundle.main.executableURL else { fail("không xác định được đường dẫn binary") }
    var arguments = ["agent", "--config", url.path]
    if let device = options.device {
        arguments += ["--device", device.description]
    }
    do {
        try LaunchAgent.install(executable: executable, arguments: arguments)
        print("Đã cài LaunchAgent \(LaunchAgent.label) (log: \(LaunchAgent.logURL.path))")
    } catch {
        fail("\(error)")
    }
}

func runUninstallAgent(_ options: Options) {
    do {
        try LaunchAgent.uninstall()
        _ = try? HIDUtil.reset(matching: options.device)
        print("Đã gỡ LaunchAgent và xoá remap.")
    } catch {
        fail("\(error)")
    }
}

// MARK: - Open app

func runBoard() {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let candidates = [
        home.appendingPathComponent("Applications/MacKey68.app").path,
        "/Applications/MacKey68.app",
    ]
    let installed = candidates.first { FileManager.default.fileExists(atPath: $0) }

    @discardableResult
    func open(_ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // Mở app trước (nếu chưa chạy), rồi gửi URL sau khi app đã lên.
    if let installed {
        guard open([installed]) else {
            fail("không mở được \(installed)")
        }
        Thread.sleep(forTimeInterval: 1.2)
    }
    guard open(["mackey68://board"]) else {
        fail("chưa cài app. Chạy ./scripts/install-app.sh rồi thử lại.")
    }
}

// MARK: - Self test

/// XCTest is only shipped with a full Xcode install, so the sanity checks live
/// here instead and run with `mackey selftest`.
func runSelftest() -> Never {
    var failures = 0

    func check(_ condition: Bool, _ description: String) {
        if condition {
            print("  ok    \(description)")
        } else {
            print("  FAIL  \(description)")
            failures += 1
        }
    }

    print("KeyCodes")
    check(KeyCodes.code(for: "caps") == 0x39, "caps -> CapsLock")
    check(KeyCodes.code(for: "CapsLock") == 0x39, "CapsLock -> CapsLock")
    check(KeyCodes.code(for: "Esc") == 0x29, "Esc -> Escape")
    check(KeyCodes.code(for: "Cmd") == 0xE3, "Cmd -> LeftGUI")
    check(KeyCodes.code(for: "win") == 0xE3, "win -> LeftGUI")
    check(KeyCodes.code(for: "Option") == 0xE2, "Option -> LeftAlt")
    check(KeyCodes.code(for: "backtick") == 0x35, "backtick -> Grave")
    check(KeyCodes.code(for: "enter") == 0x28, "enter -> Return")
    check(KeyCodes.code(for: "0x39") == 0x39, "hex literal accepted")
    check(KeyCodes.code(for: "Fn") == nil, "Fn is rejected")
    check(KeyCodes.code(for: "banana") == nil, "garbage is rejected")
    check(KeyCodes.usage(0x04) == 0x7_0000_0004, "hidutil usage namespace")

    print("Keymap")
    let config = KeymapConfig(mappings: [
        KeyMapping(from: "CapsLock", to: "Escape"),
        KeyMapping(from: "RightAlt", to: "RightGUI"),
    ])
    let resolved = (try? KeymapResolver.resolve(config.mappings ?? [])) ?? []
    check(resolved == [
        ResolvedMapping(source: 0x39, destination: 0x29),
        ResolvedMapping(source: 0xE6, destination: 0xE7),
    ], "resolve keeps order")

    let duplicate = KeymapConfig(mappings: [
        KeyMapping(from: "CapsLock", to: "Escape"),
        KeyMapping(from: "CapsLock", to: "LeftControl"),
    ])
    check((try? KeymapResolver.resolve(duplicate.mappings ?? [])) == nil, "duplicate source rejected")

    print("DeviceID")
    check(DeviceID(spec: "0x3151:0x5029") == DeviceID(vendorID: 0x3151, productID: 0x5029),
          "0x-prefixed spec")
    check(DeviceID(spec: "3151:5029") == DeviceID(vendorID: 0x3151, productID: 0x5029),
          "bare hex spec")
    check(DeviceID(spec: "nope") == nil, "bad spec rejected")
    check(DeviceID().matches(DeviceID(vendorID: 1, productID: 2)), "wildcard matches")
    check(!DeviceID(vendorID: 1, productID: 2).matches(DeviceID(vendorID: 1, productID: 3)),
          "product mismatch")

    print("Layouts")
    check(Layouts.all.count == 3, "three layouts available")
    for id in LayoutID.allCases {
        let layout = Layouts.layout(for: id)
        let ids = layout.keys.map(\.id)
        check(Set(ids).count == ids.count, "\(id.shortName): key ids unique")
        check(Set(layout.rows.map(\.id)).count == layout.rows.count,
              "\(id.shortName): row ids unique")
        check(layout.rows.allSatisfy { abs($0.unitWidth - layout.unitCount) < 0.001 },
              "\(id.shortName): rows are \(layout.unitCount) units wide")
        check(layout.keys.contains { $0.usage == 0x2C }, "\(id.shortName): has spacebar")
        check(layout.keys.contains { $0.usage == 0xE0 }, "\(id.shortName): has left control")
    }
    check(Layouts.detect(product: "OnMicro K68 BT5.0", vendorID: 0x9AEA, productID: 0x1029) == .k68,
          "detect K68")
    check(Layouts.detect(product: "SONiX USB DEVICE", vendorID: 0x0C45, productID: 0x7644) == .tkl,
          "detect Edra EK387 Pro as TKL")
    check(Layouts.detect(product: "Generic 104 keyboard", vendorID: nil, productID: nil) == .full,
          "detect full-size by name")
    check(Layouts.detect(product: "K8 Pro", manufacturer: "Keychron",
                         vendorID: nil, productID: nil) == .tkl,
          "detect Keychron K8 as TKL")
    check(Layouts.detect(product: "K5", manufacturer: "Keychron",
                         vendorID: nil, productID: nil) == .full,
          "detect Keychron K5 as full-size")
    check(Layouts.detect(product: "3068B Plus", manufacturer: "Akko",
                         vendorID: nil, productID: nil) == .k68,
          "detect Akko 3068 as 68-key")
    check(Layouts.detect(product: "FL104", manufacturer: "FL-Esports",
                         vendorID: nil, productID: nil) == .full,
          "detect FL104 as full-size")
    check(Layouts.detect(product: "G915 TKL", manufacturer: "Logitech",
                         vendorID: nil, productID: nil) == .tkl,
          "G915 TKL beats generic G915")
    check(Layouts.detect(product: "G915", manufacturer: "Logitech",
                         vendorID: nil, productID: nil) == .full,
          "G915 full-size")

    let sonixID = DeviceID(vendorID: 0x0C45, productID: 0x7644)
    let edra = DeviceConfig(device: sonixID, model: "SONiX USB DEVICE", layout: "tkl")
    let other = DeviceConfig(device: sonixID, model: "Some Other Board", layout: "68")
    let edraHID = HIDDevice(vendorID: 0x0C45, productID: 0x7644,
                            product: "SONiX USB DEVICE", manufacturer: "SONiX",
                            usagePage: 1, usage: 6, transport: "USB")
    check(edra.matches(edraHID), "same VID:PID + model matches")
    check(!other.matches(edraHID), "same VID:PID but different model does not match")
    check(edra.id != other.id, "model makes config entries unique")

    print("Profile sharing")
    let shared = Profile(id: "share-me",
                         name: "Shared",
                         autoFor: ["com.riotgames."],
                         mappings: [KeyMapping(from: "CapsLock", to: "Grave")])
    if let data = try? ProfileTransfer.data(for: shared, keyboard: "K68"),
       let back = try? ProfileTransfer.profile(from: data) {
        check(back == shared, "profile round-trip")
    } else {
        check(false, "profile round-trip")
    }
    check((try? ProfileTransfer.profile(from: Data("{}".utf8))) == nil,
          "garbage profile rejected")
    check(ProfileTransfer.withUniqueID(shared, existing: [shared]).id == "share-me-2",
          "id collision gets a suffix")
    if let partial = try? JSONDecoder().decode(
        Profile.self,
        from: Data(#"{"name":"Minimal","mappings":[{"from":"CapsLock","to":"Escape"}]}"#.utf8)
    ) {
        check(partial.autoFor.isEmpty && partial.id == "profile",
              "hand-written profile without autoFor/id loads")
    } else {
        check(false, "hand-written profile without autoFor/id loads")
    }
    let k68 = Layouts.layout(for: .k68)
    check(k68.keys.first { $0.usage == 0x39 }?.label == "caps", "K68 caps key present")
    let full = Layouts.layout(for: .full)
    check(full.keys.filter { (0x53...0x63).contains(Int($0.usage)) }.count >= 17,
          "full-size has numpad keys")
    check(Layouts.layout(for: .tkl).keys.contains { $0.usage == 0x4B },
          "TKL has PageUp")

    print("")
    if failures == 0 {
        print("Tất cả ok.")
        exit(0)
    }
    print("\(failures) test lỗi.")
    exit(1)
}

// MARK: - Entry point

let options = parseOptions(Array(CommandLine.arguments.dropFirst()))

switch options.command {
case "list": runList()
case "layouts": runLayouts()
case "keys": runKeys()
case "watch": runWatch()
case "apply": runApply(options)
case "reset": runReset(options)
case "dump": runDump(options)
case "agent": runAgent(options)
case "init": runInit(options)
case "install-agent": runInstallAgent(options)
case "uninstall-agent": runUninstallAgent(options)
case "selftest": runSelftest()
case "status":
    print("agent: \(LaunchAgent.status())")
    print("config: \(defaultConfigURL().path)")
case "board": runBoard()
case "help", "":
    print(helpText)
default:
    fail("không biết lệnh '\(options.command)'. `mackey --help` để xem.")
}
