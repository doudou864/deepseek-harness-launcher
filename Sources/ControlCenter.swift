//
//  ControlCenter.swift
//  DeepSeek Harness 启动器（彩色便当 Bento 风）
//
//  双击启动/停止 DeepSeek Harness Web UI（http://127.0.0.1:3080）
//  编译：swiftc -O -parse-as-library Sources/ControlCenter.swift -o ControlCenter \
//          -target arm64-apple-macosx13.0 -framework SwiftUI -framework AppKit
//

import SwiftUI
import AppKit

// MARK: - 主题常量（与 ui-bento-final.html 设计稿一致）

enum Theme {
    static let cream      = Color(red: 1.00, green: 0.992, blue: 0.973) // #FFFDF8 窗口底色
    static let ink        = Color(red: 0.173, green: 0.141, blue: 0.086) // #2C2416 标题
    static let sand       = Color(red: 0.639, green: 0.584, blue: 0.486) // #A3957C 次要文字
    static let sandTile   = Color(red: 0.941, green: 0.922, blue: 0.878) // #F0EBE0 未运行状态卡
    static let sandBar    = Color(red: 0.953, green: 0.925, blue: 0.867) // #F3ECDD 底部条
    static let sandText   = Color(red: 0.431, green: 0.396, blue: 0.322) // #6E6552
    static let disabledBg = Color(red: 0.929, green: 0.906, blue: 0.851) // #EDE7D9 禁用按钮
    static let disabledTx = Color(red: 0.725, green: 0.690, blue: 0.612) // #B9B09C 禁用文字

    static let runBg   = Color(red: 0.875, green: 0.961, blue: 0.906) // #DFF5E7
    static let runText = Color(red: 0.047, green: 0.361, blue: 0.212) // #0C5C36
    static let runSub  = Color(red: 0.302, green: 0.541, blue: 0.416) // #4D8A6A
    static let runDot  = Color(red: 0.090, green: 0.698, blue: 0.416) // #17B26A

    static let startBg   = Color(red: 0.992, green: 0.941, blue: 0.835) // #FDF0D5
    static let startText = Color(red: 0.541, green: 0.353, blue: 0.000) // #8A5A00
    static let startSub  = Color(red: 0.690, green: 0.522, blue: 0.290) // #B0854A
    static let startDot  = Color(red: 0.961, green: 0.651, blue: 0.137) // #F5A623

    static let blue1 = Color(red: 0.302, green: 0.553, blue: 1.000) // #4D8DFF
    static let blue2 = Color(red: 0.118, green: 0.369, blue: 0.941) // #1E5EF0
    static let red1  = Color(red: 1.000, green: 0.478, blue: 0.361) // #FF7A5C
    static let red2  = Color(red: 0.941, green: 0.243, blue: 0.169) // #F03E2B
    static let amber1 = Color(red: 0.969, green: 0.718, blue: 0.200) // #F7B733
    static let amber2 = Color(red: 0.941, green: 0.596, blue: 0.098) // #F09819
}

// MARK: - 服务状态模型

enum ServiceState { case stopped, starting, running }

@MainActor
final class ServiceModel: ObservableObject {
    @Published var state: ServiceState = .stopped
    @Published var pid: Int32? = nil
    @Published var uptime = ""
    @Published var startElapsed = 0
    @Published var note = ""          // 底部补充/错误提示
    @Published var copied = false     // 地址已复制反馈

    let serviceURL = "http://127.0.0.1:3080"

    nonisolated private let runtimeDir = NSHomeDirectory() + "/Library/Application Support/DeepSeek Harness"
    nonisolated private var pidFile: String { runtimeDir + "/dsh-server.pid" }
    nonisolated private var logFile:  String { runtimeDir + "/dsh-server.log" }

    private var statusTimer: Timer?
    private var readyTimer: Timer?
    private var spawned: Process?

    init() {
        try? FileManager.default.createDirectory(atPath: runtimeDir, withIntermediateDirectories: true)
        refresh()
        // 每 3 秒自动同步状态（服务被外部停止也能及时反映）
        statusTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state != .starting else { return }
                self.refresh()
            }
        }
    }

    // MARK: 状态检测

    func refresh() {
        checkPort { [weak self] up in
            Task { @MainActor in
                guard let self else { return }
                self.state = up ? .running : .stopped
                self.pid = up ? self.readPID() : nil
                if up { self.updateUptime() }
            }
        }
    }

    nonisolated private func checkPort(done: @escaping (Bool) -> Void) {
        var req = URLRequest(url: URL(string: serviceURL)!)
        req.timeoutInterval = 1.5
        req.httpMethod = "HEAD"
        URLSession.shared.dataTask(with: req) { _, resp, err in
            // 任意 HTTP 响应即视为服务在线；连接被拒/超时视为离线
            done(err == nil && resp != nil)
        }.resume()
    }

    @discardableResult
    nonisolated private func readPID() -> Int32? {
        guard let s = try? String(contentsOfFile: pidFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let v = Int32(s), v > 0 else { return nil }
        return v
    }

    private func updateUptime() {
        guard let pid else { uptime = ""; return }
        let out = shell("/bin/ps", ["-p", String(pid), "-o", "etime="]).trimmingCharacters(in: .whitespacesAndNewlines)
        uptime = Self.formatElapsed(out)
    }

    /// 将 ps 的 etime（[[dd-]hh:]mm:ss）格式化为中文时长
    static func formatElapsed(_ etime: String) -> String {
        var days = 0
        var rest = etime
        if let dash = etime.firstIndex(of: "-") {
            days = Int(etime[..<dash]) ?? 0
            rest = String(etime[etime.index(after: dash)...])
        }
        let parts = rest.split(separator: ":").compactMap { Int($0) }
        var h = 0, m = 0, s = 0
        switch parts.count {
        case 3: h = parts[0]; m = parts[1]; s = parts[2]
        case 2: m = parts[0]; s = parts[1]
        case 1: s = parts[0]
        default: return ""
        }
        if days > 0 { return "\(days) 天 \(h) 小时" }
        if h > 0 { return "\(h) 小时 \(m) 分" }
        if m > 0 { return "\(m) 分 \(s) 秒" }
        return "\(s) 秒"
    }

    nonisolated private func shell(_ exe: String, _ args: [String]) -> String {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return "" }
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: 环境（双击启动时 PATH 极简，按常见安装位置补充 Node.js）

    nonisolated private func expandedPATH() -> String {
        let home = NSHomeDirectory()
        var dirs = [home + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin",
                    home + "/.volta/bin", home + "/.asdf/shims"]
        // nvm：~/.nvm/versions/node/<v>/bin
        let nvmRoot = home + "/.nvm/versions/node"
        if let vers = try? FileManager.default.contentsOfDirectory(atPath: nvmRoot) {
            for v in vers.sorted().reversed() { dirs.append("\(nvmRoot)/\(v)/bin") }
        }
        let fm = FileManager.default
        let good = dirs.filter { fm.isExecutableFile(atPath: $0 + "/node") }
        let base = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        return (good + [base]).joined(separator: ":")
    }

    /// 定位 dsh：优先 npx 缓存（免下载），否则回退 npx 在线运行
    nonisolated private func findCommand() -> (exe: String, args: [String])? {
        let home = NSHomeDirectory()
        let fm = FileManager.default
        let npxCache = home + "/.npm/_npx"
        if let dirs = try? fm.contentsOfDirectory(atPath: npxCache) {
            let candidates = dirs
                .map { "\(npxCache)/\($0)/node_modules/.bin/dsh" }
                .filter { fm.isExecutableFile(atPath: $0) }
                .sorted { a, b in
                    let da = (try? fm.attributesOfItem(atPath: a)[.modificationDate] as? Date) ?? .distantPast
                    let db = (try? fm.attributesOfItem(atPath: b)[.modificationDate] as? Date) ?? .distantPast
                    return da > db
                }
            if let dsh = candidates.first { return (dsh, ["web"]) }
        }
        // 回退：在扩展 PATH 里找 npx
        for dir in expandedPATH().split(separator: ":") {
            let npx = String(dir) + "/npx"
            if fm.isExecutableFile(atPath: npx) { return (npx, ["-y", "@deepseek-ai/dsh", "web"]) }
        }
        return nil
    }

    // MARK: 启动

    func start() {
        guard state == .stopped else { return }
        state = .starting
        note = ""
        startElapsed = 0

        DispatchQueue.global(qos: .userInitiated).async {
            guard let cmd = self.findCommand() else {
                Task { @MainActor in self.failStart("未检测到 Node.js / dsh，请先安装 Node.js（brew install node）") }
                return
            }
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = self.expandedPATH()

            FileManager.default.createFile(atPath: self.logFile, contents: nil)
            guard let logHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: self.logFile)) else {
                Task { @MainActor in self.failStart("无法写入日志文件") }
                return
            }

            let p = Process()
            p.executableURL = URL(fileURLWithPath: cmd.exe)
            p.arguments = cmd.args
            p.environment = env
            p.standardOutput = logHandle
            p.standardError = logHandle
            do { try p.run() } catch {
                Task { @MainActor in self.failStart("进程启动失败：\(error.localizedDescription)") }
                return
            }
            try? String(p.processIdentifier).write(toFile: self.pidFile, atomically: true, encoding: .utf8)

            Task { @MainActor in
                self.spawned = p
                self.beginReadyWatch()
            }
        }
    }

    private func beginReadyWatch() {
        readyTimer?.invalidate()
        startElapsed = 0
        readyTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.startElapsed += 1
                // 进程意外退出 → 立即失败
                if let p = self.spawned, !p.isRunning {
                    self.readyTimer?.invalidate()
                    self.failStart("服务进程意外退出，请查看日志 dsh-server.log")
                    return
                }
                self.checkPort { up in
                    Task { @MainActor in
                        if up {
                            self.readyTimer?.invalidate()
                            self.state = .running
                            self.pid = self.readPID()
                            self.updateUptime()
                            self.openBrowser()
                        } else if self.startElapsed >= 90 {
                            self.readyTimer?.invalidate()
                            self.failStart("等待端口就绪超时（90s），请查看日志 dsh-server.log")
                        }
                    }
                }
            }
        }
    }

    private func failStart(_ message: String) {
        if let p = spawned, p.isRunning { p.terminate() }
        spawned = nil
        try? FileManager.default.removeItem(atPath: pidFile)
        state = .stopped
        note = message   // 启动失败为错误信息，常驻至下次操作
    }

    /// 非错误类提示：展示 4 秒后自动消退
    private func flashNote(_ message: String) {
        note = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if self.note == message { self.note = "" }
        }
    }

    // MARK: 停止

    func stop() {
        guard state == .running || pid != nil else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            defer { Task { @MainActor in self.refresh() } }
            guard let pid = self.readPID(), kill(pid, 0) == 0 else {
                try? FileManager.default.removeItem(atPath: self.pidFile)
                Task { @MainActor in self.flashNote("PID 记录已失效，已清理") }
                return
            }
            // 先终止子进程，再终止主进程
            _ = self.shell("/usr/bin/pkill", ["-P", String(pid)])
            kill(pid, SIGTERM)
            var down = false
            for _ in 1...15 {
                if kill(pid, 0) != 0 { down = true; break }
                Thread.sleep(forTimeInterval: 1)
            }
            if !down {
                _ = self.shell("/usr/bin/pkill", ["-9", "-P", String(pid)])
                kill(pid, SIGKILL)
            }
            try? FileManager.default.removeItem(atPath: self.pidFile)
            Task { @MainActor in self.flashNote(down ? "服务已停止" : "已发送强制终止信号") }
        }
    }

    // MARK: 辅助操作

    func openBrowser() {
        NSWorkspace.shared.open(URL(string: serviceURL)!)
    }

    func copyAddress() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(serviceURL, forType: .string)
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self.copied = false
        }
    }
}

// MARK: - 组件：呼吸状态灯

struct PulseDot: View {
    let color: Color
    var period: Double = 2.2
    @State private var ripple = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.45), lineWidth: 2.5)
                .frame(width: 13, height: 13)
                .scaleEffect(ripple ? 1.9 : 1.0)
                .opacity(ripple ? 0 : 0.9)
            Circle()
                .fill(color)
                .frame(width: 13, height: 13)
        }
        .frame(width: 26, height: 26)
        .onAppear {
            withAnimation(.easeOut(duration: period).repeatForever(autoreverses: false)) {
                ripple = true
            }
        }
    }
}

// MARK: - 组件：触感按钮样式

struct TactileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - 组件：主操作大按钮

struct ActionButton: View {
    let title: String
    let en: String
    let symbol: String          // SF Symbol；空串表示转圈
    let colors: (Color, Color)  // 渐变
    let shadow: Color
    let enabled: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(enabled ? 0.24 : 0.5))
                        .frame(width: 42, height: 42)
                    if symbol.isEmpty {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white.opacity(enabled ? 1 : 0.85))
                            .offset(x: symbol == "play.fill" ? 2 : 0) // 播放键光学校正
                    }
                }
                Spacer(minLength: 8)
                Text(title)
                    .font(.system(size: 16.5, weight: .heavy))
                Text(en)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            .foregroundStyle(enabled ? .white : Theme.disabledTx)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(enabled
                          ? LinearGradient(colors: [colors.0, colors.1],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [Theme.disabledBg, Theme.disabledBg],
                                           startPoint: .top, endPoint: .bottom))
            )
            .shadow(color: enabled ? shadow.opacity(hovering ? 0.45 : 0.32) : .clear,
                    radius: hovering ? 14 : 10, y: hovering ? 7 : 5)
            .offset(y: hovering && enabled ? -2 : 0)
            .animation(.easeOut(duration: 0.15), value: hovering)
        }
        .buttonStyle(TactileButtonStyle())
        .disabled(!enabled)
        .onHover { hovering = $0 }
        .frame(height: 116)
    }
}

// MARK: - 组件：胶囊小按钮

struct PillButton: View {
    let title: String
    let symbol: String
    let shortcut: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                Text(shortcut)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.sand.opacity(0.8))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Theme.sandBar, in: RoundedRectangle(cornerRadius: 4))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .foregroundStyle(Color(red: 0.361, green: 0.310, blue: 0.212))
            .background(Theme.cream, in: Capsule())
            .shadow(color: Color(red: 0.47, green: 0.35, blue: 0.12).opacity(0.14), radius: 2, y: 1)
        }
        .buttonStyle(TactileButtonStyle())
    }
}

// MARK: - 主界面

struct ContentView: View {
    @StateObject private var model = ServiceModel()

    var body: some View {
        VStack(spacing: 12) {
            header
            statusTile
            HStack(spacing: 12) {
                startButton
                stopButton
            }
            bottomBar
            footer
            Spacer(minLength: 0)   // 内容顶对齐，多余空间沉到底部
        }
        .padding(.horizontal, 14)
        .padding(.top, 30)      // 避让隐藏式标题栏的交通灯
        .padding(.bottom, 14)
        .background(Theme.cream)
        .frame(minWidth: 420, idealWidth: 452, maxWidth: 640,
               minHeight: 430, idealHeight: 462, maxHeight: 720)
    }

    // MARK: 头部

    private var header: some View {
        HStack(spacing: 12) {
            if let path = Bundle.main.path(forResource: "logo", ofType: "png"),
               let img = NSImage(contentsOfFile: path) {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 6, y: 2)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("DeepSeek Harness")
                    .font(.system(size: 19.5, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("本地服务控制台")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.sand)
            }
            Spacer()
            Text("v1.1")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Color(red: 0.761, green: 0.714, blue: 0.588))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.sandBar, in: Capsule())
        }
        .padding(.horizontal, 4)
    }

    // MARK: 状态卡

    private var statusTile: some View {
        let (bg, tColor, sColor, dColor): (Color, Color, Color, Color) = {
            switch model.state {
            case .running:  return (Theme.runBg, Theme.runText, Theme.runSub, Theme.runDot)
            case .starting: return (Theme.startBg, Theme.startText, Theme.startSub, Theme.startDot)
            case .stopped:  return (Theme.sandTile, Theme.sandText, Theme.sand, Color(red: 0.706, green: 0.663, blue: 0.561))
            }
        }()

        return HStack(spacing: 12) {
            PulseDot(color: dColor, period: model.state == .starting ? 1.2 : 2.2)
                .frame(width: 13)
                .padding(.leading, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(statusTitle)
                    .font(.system(size: 15.5, weight: .heavy))
                    .foregroundStyle(tColor)
                Text(statusDetail)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(sColor)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            addressChip(tint: tColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeOut(duration: 0.25), value: model.state)
    }

    private var statusTitle: String {
        switch model.state {
        case .running:  return "服务运行中"
        case .starting: return "正在启动…"
        case .stopped:  return "服务未运行"
        }
    }

    private var statusDetail: String {
        switch model.state {
        case .running:
            return model.uptime.isEmpty ? "响应正常" : "已运行 \(model.uptime) · 响应正常"
        case .starting:
            return "等待端口就绪 \(model.startElapsed)s / 最长 90s"
        case .stopped:
            return "点击下方「启动」开始"
        }
    }

    private func addressChip(tint: Color) -> some View {
        Button {
            if model.state == .running { model.copyAddress() }
        } label: {
            HStack(spacing: 5) {
                Text(model.copied ? "已复制 ✓" : "127.0.0.1:3080")
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                if model.state == .running && !model.copied {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .opacity(0.55)
                }
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(.white.opacity(model.state == .stopped ? 0.6 : 0.8), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(model.state != .running)
        .help(model.state == .running ? "点击复制地址" : "")
    }

    // MARK: 主按钮

    private var startButton: some View {
        switch model.state {
        case .starting:
            return ActionButton(title: "启动中…", en: "STARTING", symbol: "",
                                colors: (Theme.amber1, Theme.amber2),
                                shadow: Theme.amber2, enabled: true, action: {})
        case .stopped:
            return ActionButton(title: "启动", en: "START", symbol: "play.fill",
                                colors: (Theme.blue1, Theme.blue2),
                                shadow: Theme.blue2, enabled: true, action: model.start)
        case .running:
            return ActionButton(title: "启动", en: "RUNNING", symbol: "play.fill",
                                colors: (Theme.blue1, Theme.blue2),
                                shadow: Theme.blue2, enabled: false, action: {})
        }
    }

    private var stopButton: some View {
        ActionButton(title: "退出服务", en: "STOP", symbol: "power",
                     colors: (Theme.red1, Theme.red2),
                     shadow: Theme.red2, enabled: model.state == .running, action: model.stop)
    }

    // MARK: 底部

    private var bottomBar: some View {
        HStack(spacing: 10) {
            PillButton(title: "在浏览器中打开", symbol: "safari", shortcut: "⌘O", action: model.openBrowser)
                .keyboardShortcut("o", modifiers: .command)
            PillButton(title: "刷新状态", symbol: "arrow.clockwise", shortcut: "⌘R", action: model.refresh)
                .keyboardShortcut("r", modifiers: .command)
        }
        .padding(10)
        .background(Theme.sandBar, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footer: some View {
        Group {
            if !model.note.isEmpty {
                Text("⚠️ \(model.note)")
            } else {
                switch model.state {
                case .running:
                    Text("● 服务运行中 · 端口 3080 可访问 · 日志 dsh-server.log")
                        .foregroundStyle(Theme.runDot)
                case .starting:
                    Text("● 正在启动 · 首次启动需联网下载，请稍候")
                case .stopped:
                    Text("○ 服务未运行 · 启动后浏览器将自动打开")
                }
            }
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(Theme.sand)
        .lineLimit(1)
    }
}

// MARK: - App

@main
struct ControlCenterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
