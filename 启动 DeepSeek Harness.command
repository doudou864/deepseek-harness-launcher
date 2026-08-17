#!/bin/bash
# ============================================================
#  DeepSeek Harness 一键启动器（macOS）
#  双击本文件即可启动 Web UI：http://127.0.0.1:3080
#  关闭 Terminal 窗口或按 Ctrl+C 即停止服务
# ============================================================

# 无论从哪里双击，都切到脚本所在目录（日志文件写在旁边）
cd "$(dirname "$0")" || exit 1

# 双击启动时 PATH 极简，找不到用户自装的 Node.js，按常见安装位置补充
for _p in "$HOME/.local/bin" /opt/homebrew/bin /usr/local/bin \
          "$HOME/.volta/bin" "$HOME/.asdf/shims" "$HOME/.nvm/versions/node/"*/bin; do
    [ -x "$_p/node" ] && PATH="$_p:$PATH"
done
export PATH; unset _p

URL="http://127.0.0.1:3080"
# 与 .app 版共用同一运行时目录（PID/日志统一）
RUNTIME_DIR="$HOME/Library/Application Support/DeepSeek Harness"
LOG="$RUNTIME_DIR/dsh-server.log"
PID_FILE="$RUNTIME_DIR/dsh-server.pid"
mkdir -p "$RUNTIME_DIR"

echo "=============================================="
echo "  DeepSeek Harness 启动器"
echo "=============================================="

# ---------- 1. 检查 Node.js ----------
if ! command -v node >/dev/null 2>&1; then
    echo ""
    echo "[错误] 未检测到 Node.js。"
    echo "请先安装 Node.js（推荐用 Homebrew）："
    echo "    brew install node"
    echo ""
    read -r -p "按回车键退出..."
    exit 1
fi

# ---------- 2. 端口已占用则直接开浏览器 ----------
if curl -s -o /dev/null --max-time 2 "$URL"; then
    echo "[提示] 检测到 $URL 已在运行，直接打开浏览器，不再重复启动。"
    open "$URL"
    exit 0
fi

# ---------- 3. 优先复用已下载的 dsh 缓存（不重复下载）----------
DSH_BIN=""
# 在 npm 的 npx 缓存目录里找最新的 dsh 可执行文件
for d in "$HOME"/.npm/_npx/*/node_modules/.bin/dsh; do
    [ -x "$d" ] && DSH_BIN="$d"
done

if [ -n "$DSH_BIN" ]; then
    echo "[信息] 使用已缓存的 dsh：$DSH_BIN"
    RUN_CMD=("$DSH_BIN" "web")
else
    echo "[信息] 未找到本地缓存，首次运行将通过 npx 下载（需要联网，仅一次）。"
    RUN_CMD=(npx -y @deepseek-ai/dsh web)
fi

# ---------- 4. 启动服务（后台运行，日志落盘）----------
echo "[信息] 正在启动 DeepSeek Harness，日志写入 $LOG ..."
"${RUN_CMD[@]}" > "$LOG" 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" > "$PID_FILE"   # 记录 PID，供停止脚本使用

# ---------- 5. 等待端口就绪后自动打开浏览器 ----------
echo "[信息] 等待服务就绪（最长 90 秒）..."
READY=0
for i in $(seq 1 90); do
    if curl -s -o /dev/null --max-time 2 "$URL"; then
        READY=1
        break
    fi
    # 服务进程意外退出则立即报错
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        break
    fi
    sleep 1
done

if [ "$READY" = "1" ]; then
    echo "[完成] 服务已就绪，正在打开浏览器：$URL"
    open "$URL"
else
    echo ""
    echo "[错误] 服务未能正常启动。请查看日志：$LOG"
    echo "       （可用命令查看：cat \"$LOG\"）"
    if kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "       按 Ctrl+C 可停止后台服务。"
    fi
fi

echo ""
echo "----------------------------------------------"
echo " 服务正在运行中。关闭本窗口或按 Ctrl+C 停止。"
echo "----------------------------------------------"

# 前台等待服务进程结束，保持窗口打开
wait "$SERVER_PID"
# 进程结束后清理 PID 文件
rm -f "$PID_FILE"
echo ""
echo "[信息] 服务已停止。"
read -r -p "按回车键关闭窗口..."
