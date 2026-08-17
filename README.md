# DeepSeek Harness 一键启动器（macOS）

在 macOS 上双击一个图标，即可启动 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 的 Web UI。

> 本项目是非官方的第三方启动器，与 DeepSeek AI 无隶属关系。DeepSeek Harness 本身请以其官方仓库为准。

## 前置要求

1. **macOS 13 或更高版本**
2. **已安装 Node.js** —— 能成功运行官方命令 `npx @deepseek-ai/dsh web` 即可（安装方式不限：Homebrew、nvm、volta、asdf、mise 等均可）。未安装可先执行 `brew install node`
3. **首次使用需联网** —— 仅第一次下载 dsh 包，之后离线可用

本启动器只负责"双击启动/停止"这一件事；DeepSeek Harness 自身的安装与使用问题请查阅官方仓库。

## 推荐入口：DeepSeek Harness 启动器（App）

**双击 `DeepSeek Harness 启动器.app`**，打开一个控制面板：

- **顶部**：状态指示灯（● 运行中 / ○ 未运行）+ 地址端口
- **中部**：左右双按钮 —— 左 **启动**（蓝色），右 **退出服务**（红色），按状态自动启用/禁用
- **底部**：`在浏览器中打开`、`刷新状态` 辅助按钮
- 关闭面板不影响后台服务；服务仍由共享 PID 管理

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
2. 点左侧 **启动** —— 服务后台启动，浏览器自动打开 `http://127.0.0.1:3080`，状态变为"运行中"。
3. 要停止时，点右侧 **退出服务** —— 按启动时记录的 PID 精确停止，绝不误伤其他程序。
4. 点 `在浏览器中打开` 可随时重新打开页面；点 `刷新状态` 手动同步状态。

> 若点"启动"时服务已在运行（比如之前用别的入口启动过），会直接视为成功并打开浏览器，不会重复启动。

## 停止服务（通用）

任何入口启动的服务，都能被任意入口停止（共用同一份 PID 记录）：

- 启动器面板右侧 **退出服务** 按钮（推荐）
- 双击 **`停止 DeepSeek Harness.app`** 或 **`停止 DeepSeek Harness.command`**
- 在启动服务的 Terminal 窗口里按 `Ctrl+C`（仅命令行版适用）

## 工作原理

脚本按顺序做四件事：

1. **定位 Node.js** —— 双击启动时系统 PATH 极简，脚本会自动在常见安装位置（`~/.local/bin`、Homebrew、nvm、volta、asdf）查找 node；找不到则提示安装方式（`brew install node`）。
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
| `DeepSeek Harness 启动器.app` 点启动无反应 | 该面板为编译好的二进制，不会自动查找 node 安装位置。请改用 `启动 DeepSeek Harness.app` 或 `.command`（它们会自动定位 node），效果相同 |
| 首次使用需联网 | 仅首次（本地无缓存时）下载 dsh 包，之后离线可用 |
| 端口 3080 被其他程序占用 | 启动器会直接打开该地址，请确认占用方是否是 Harness |

## 附：官方启动方式

- 一键运行（本启动器即封装此命令）：`npx @deepseek-ai/dsh web`
- 从源码运行：`git clone` → `pnpm install` → `pnpm run build` → `pnpm dsh web`
- 官方仓库：https://github.com/deepseek-ai/deepseek-harness

## License

[MIT](LICENSE)
