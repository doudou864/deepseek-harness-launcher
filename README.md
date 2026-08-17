# DeepSeek Harness 一键启动器（macOS）

在 macOS 上双击一个图标，即可启动 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 的 Web UI。

> 本项目是非官方的第三方启动器，与 DeepSeek AI 无隶属关系。DeepSeek Harness 本身请以其官方仓库为准。

## 前置要求

1. **macOS 13 或更高版本**
2. **已安装 Node.js** —— 能成功运行官方命令 `npx @deepseek-ai/dsh web` 即可（安装方式不限：Homebrew、nvm、volta、asdf、mise 等均可）。未安装可先执行 `brew install node`
3. **首次使用需联网** —— 仅第一次下载 dsh 包，之后离线可用

本启动器只负责"双击启动/停止"这一件事；DeepSeek Harness 自身的安装与使用问题请查阅[官方仓库](https://github.com/deepseek-ai/deepseek-harness)。

## 推荐入口：DeepSeek Harness 启动器（App）

**双击 `DeepSeek Harness 启动器.app`**，打开彩色便当（Bento）风控制面板：

- **顶部**：应用 Logo + 标题 + 版本号
- **状态卡**：运行绿（呼吸灯效 + 已运行时长）/ 启动中琥珀（转圈 + 秒数计时）/ 未运行沙色；右侧地址胶囊**点击可复制**
- **主按钮**：左 **启动**（蓝色），右 **退出服务**（红色），按状态自动启用/禁用，图标徽章 + 中英双语标签
- **底部**：`在浏览器中打开`（⌘O）、`刷新状态`（⌘R）
- 窗口**支持自由调整大小**（有最小尺寸保护）；关闭面板不影响后台服务，服务仍由共享 PID 管理

> 控制面板为开源 SwiftUI 实现，源码见 `Sources/ControlCenter.swift`，可自行修改编译（见文末）。

## 其他入口（效果相同，任选其一）

| 入口 | 形态 | 特点 |
| --- | --- | --- |
| **`启动 DeepSeek Harness.app`** | App（带图标） | 双击即启动，无终端窗口，系统通知反馈，服务后台运行 |
| **`停止 DeepSeek Harness.app`** | App（带图标） | 双击即停止 |
| **`启动 DeepSeek Harness.command`** | 终端脚本 | 双击弹出 Terminal，可实时看到日志 |
| **`停止 DeepSeek Harness.command`** | 终端脚本 | 双击即停止 |

> 图标均使用仓库中的 `logo-1.png`，可固定到程序坞/访达边栏。

## 使用方法（启动器面板，推荐）

1. 双击 **`DeepSeek Harness 启动器.app`**。
2. 点左侧 **启动** —— 状态卡变为琥珀色"正在启动"并计时；服务就绪后自动变绿，浏览器自动打开 `http://127.0.0.1:3080`。
3. 要停止时，点右侧 **退出服务** —— 按启动时记录的 PID 精确停止，绝不误伤其他程序。
4. `在浏览器中打开`（⌘O）可随时重新打开页面；`刷新状态`（⌘R）手动同步状态；点状态卡右侧的地址胶囊可复制地址。

> 若点"启动"时服务已在运行（比如之前用别的入口启动过），会直接视为成功并打开浏览器，不会重复启动。

## 停止服务（通用）

任何入口启动的服务，都能被任意入口停止（共用同一份 PID 记录）：

- 启动器面板右侧 **退出服务** 按钮（推荐）
- 双击 **`停止 DeepSeek Harness.app`** 或 **`停止 DeepSeek Harness.command`**
- 在启动服务的 Terminal 窗口里按 `Ctrl+C`（仅命令行版适用）

## 工作原理

脚本按顺序做四件事：

1. **定位 Node.js** —— 所有入口（含控制面板）都会自动在常见安装位置（`~/.local/bin`、Homebrew、nvm、volta、asdf）查找 node；找不到则提示安装方式（`brew install node`）。
2. **检查端口 3080** —— 如果服务已在运行，直接打开浏览器，不重复启动。
3. **优先复用已下载的 dsh** —— 从 `~/.npm/_npx/*/node_modules/.bin/dsh` 查找本地缓存直接运行；只有从未下载过时才用 `npx -y @deepseek-ai/dsh web` 联网下载（仅一次）。
4. **等待就绪并打开浏览器** —— 轮询端口最长 90 秒，就绪后自动 `open` 浏览器。

服务日志与 PID 记录统一存放在 `~/Library/Application Support/DeepSeek Harness/`（`dsh-server.log` / `dsh-server.pid`），各入口共用，停止时据此精确匹配；服务退出后 PID 记录自动清除。启动失败可用 `cat ~/Library/Application\ Support/DeepSeek\ Harness/dsh-server.log` 排查。

## 停止与卸载

- **停止**：双击 `停止 DeepSeek Harness.app` 或 `停止 DeepSeek Harness.command`，或按 `Ctrl+C`。
- **卸载**：直接删除本目录下的文件 + 删掉 `~/Library/Application Support/DeepSeek Harness/` 即可，不写注册表、不留后台进程。

## 常见问题

| 问题 | 解决 |
| --- | --- |
| 双击提示无法打开/未签名 | 右键 → 打开；或 系统设置 → 隐私与安全性 → 仍要打开 |
| 提示未检测到 Node.js | 先安装 Node.js（如 `brew install node`），并确认终端里 `node -v` 可用 |
| 首次使用需联网 | 仅首次（本地无缓存时）下载 dsh 包，之后离线可用 |
| 端口 3080 被其他程序占用 | 启动器会直接打开该地址，请确认占用方是否是 Harness |

## 附：官方启动方式

- 一键运行（本启动器即封装此命令）：`npx @deepseek-ai/dsh web`
- 从源码运行：`git clone` → `pnpm install` → `pnpm run build` → `pnpm dsh web`
- 官方仓库：https://github.com/deepseek-ai/deepseek-harness

## 自行编译控制面板（可选）

面板源码：`Sources/ControlCenter.swift`（SwiftUI 单文件，macOS 13+）。修改后一行命令重编译：

```bash
# 需先安装 Xcode Command Line Tools：xcode-select --install
swiftc -O -parse-as-library Sources/ControlCenter.swift \
  -o "DeepSeek Harness 启动器.app/Contents/MacOS/ControlCenter" \
  -target arm64-apple-macosx13.0 -framework SwiftUI -framework AppKit
codesign --force --deep --sign - "DeepSeek Harness 启动器.app"
```

UI 设计稿（HTML 预览版）在 `design/` 目录，可浏览器打开查看。

## License

[MIT](LICENSE)
