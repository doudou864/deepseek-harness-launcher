#!/bin/bash
# ============================================================
#  DeepSeek Harness 一键停止脚本（macOS）
#  停止由「启动 DeepSeek Harness.command」拉起的服务
# ============================================================

# 切到脚本所在目录（PID 文件记录在旁边）
cd "$(dirname "$0")" || exit 1

URL="http://127.0.0.1:3080"
# 与 .app 版共用同一运行时目录（PID/日志统一）
RUNTIME_DIR="$HOME/Library/Application Support/DeepSeek Harness"
PID_FILE="$RUNTIME_DIR/dsh-server.pid"
mkdir -p "$RUNTIME_DIR"

echo "=============================================="
echo "  DeepSeek Harness 停止器"
echo "=============================================="

# ---------- 1. 读取启动器记录的 PID ----------
if [ ! -f "$PID_FILE" ]; then
    echo "[信息] 未找到 PID 记录文件：$PID_FILE"
    if curl -s -o /dev/null --max-time 2 "$URL"; then
        echo ""
        echo "[警告] 检测到 $URL 有服务在运行，但并非由本启动器拉起，"
        echo "       为避免误杀，脚本不会动它。"
        echo "       请到启动它的那个 Terminal 窗口按 Ctrl+C 停止。"
        echo ""
        read -r -p "按回车键退出..."
        exit 1
    fi
    echo "[信息] 服务当前未运行，无需停止。"
    read -r -p "按回车键退出..."
    exit 0
fi

SERVER_PID=$(cat "$PID_FILE" 2>/dev/null)

# ---------- 2. 检查进程是否还活着 ----------
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "[信息] 进程 $SERVER_PID 已不存在（服务可能已停止）。清理记录文件。"
    rm -f "$PID_FILE"
    read -r -p "按回车键退出..."
    exit 0
fi

# ---------- 3. 停止服务 ----------
echo "[信息] 正在停止服务，PID：$SERVER_PID"

# 先尝试终止其子进程，再终止主进程
pkill -P "$SERVER_PID" 2>/dev/null
kill "$SERVER_PID" 2>/dev/null

# 等待端口释放（最长 15 秒）
STOPPED=0
for i in $(seq 1 15); do
    if ! curl -s -o /dev/null --max-time 2 "$URL"; then
        STOPPED=1
        break
    fi
    sleep 1
done

# 端口仍未释放则强制结束
if [ "$STOPPED" = "0" ]; then
    echo "[信息] 端口仍被占用，尝试强制结束..."
    pkill -9 -P "$SERVER_PID" 2>/dev/null
    kill -9 "$SERVER_PID" 2>/dev/null
fi

rm -f "$PID_FILE"

if [ "$STOPPED" = "1" ]; then
    echo "[完成] 服务已停止，$URL 已不可访问。"
else
    echo "[警告] 已发送终止信号，但 $URL 仍可访问，请手动检查。"
fi

echo ""
read -r -p "按回车键退出..."
