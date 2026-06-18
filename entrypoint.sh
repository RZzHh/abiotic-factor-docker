#!/usr/bin/env bash
set -euo pipefail

# --------- 环境变量默认值（可在 docker-compose 里覆盖） / Default env values (overridable in docker-compose) ---------
MaxServerPlayers="${MaxServerPlayers:-6}"
Port="${Port:-7777}"
QueryPort="${QueryPort:-27015}"
ServerPassword="${ServerPassword:-password}"
SteamServerName="${SteamServerName:-LinuxServer}"
WorldSaveName="${WorldSaveName:-Cascade}"
AdditionalArgs="${AdditionalArgs:-}"

# 是否在容器启动时自动更新 / 首次安装 / Auto-update or install on container start
AutoUpdate="${AutoUpdate:-false}"

# 优化参数开关 / Performance tuning switches
UsePerfThreads="${UsePerfThreads:-true}"
NoAsyncLoadingThread="${NoAsyncLoadingThread:-true}"

SetUsePerfThreads="-useperfthreads "
if [[ "${UsePerfThreads,,}" == "false" ]]; then
  SetUsePerfThreads=""
fi

SetNoAsyncLoadingThread="-NoAsyncLoadingThread "
if [[ "${NoAsyncLoadingThread,,}" == "false" ]]; then
  SetNoAsyncLoadingThread=""
fi

# 公网服务器务必改掉默认密码 / Change the default password for any internet-facing server
if [[ "${ServerPassword}" == "password" ]]; then
  echo "[entrypoint] WARNING: ServerPassword is still the default 'password'. Set a strong one in docker-compose."
fi

# --------- Wine 前缀环境 / Wine prefix environment ---------
export WINEPREFIX="${WINEPREFIX:-/server/.wine}"
export WINEARCH="${WINEARCH:-win64}"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"

# 初始化 Wine 前缀。注意：服务端是无界面控制台程序，不需要 X / Xvfb，直接命令行初始化即可
# Initialize the Wine prefix. The server is a headless console app — no X/Xvfb needed
if [ ! -d "${WINEPREFIX}" ]; then
  echo "[entrypoint] Initializing Wine prefix at ${WINEPREFIX} (win64)…"
  wineboot --init || true
fi

# --------- 使用 SteamCMD 安装 / 更新 Abiotic Factor / Install or update via SteamCMD ---------
# AppID 2857200 = Abiotic Factor Dedicated Server
if [ ! -d "/server/AbioticFactor/Binaries/Win64" ] || [[ "${AutoUpdate,,}" == "true" ]]; then
  echo "[entrypoint] Installing / updating Abiotic Factor dedicated server via SteamCMD…"
  # SteamCMD 即便基本成功也可能返回非 0；用 if 包住，避免 set -e 在起服前中断容器
  # SteamCMD can exit non-zero even on near-success; guard it so set -e doesn't kill the container before launch
  if ! steamcmd \
        +@sSteamCmdForcePlatformType windows \
        +force_install_dir /server \
        +login anonymous \
        +app_update 2857200 validate \
        +quit; then
    echo "[entrypoint] WARN: steamcmd exited non-zero; continuing (binary presence is verified below)…"
  fi
fi

SERVER_DIR="/server/AbioticFactor/Binaries/Win64"

# 用 -f 而非 -x：SteamCMD 下载的 Windows 文件不一定带执行位，Wine 也不需要它
# Use -f (not -x): SteamCMD-downloaded Windows files may lack the execute bit, and Wine doesn't need it
if [ ! -f "${SERVER_DIR}/AbioticFactorServer-Win64-Shipping.exe" ]; then
  echo "[entrypoint] ERROR: Server binary not found at ${SERVER_DIR}/AbioticFactorServer-Win64-Shipping.exe"
  exit 1
fi

cd "${SERVER_DIR}"

echo "[entrypoint] Starting Abiotic Factor dedicated server with Wine (headless)…"

exec wine AbioticFactorServer-Win64-Shipping.exe \
  ${SetUsePerfThreads}${SetNoAsyncLoadingThread}-MaxServerPlayers="${MaxServerPlayers}" \
  -PORT="${Port}" \
  -QueryPort="${QueryPort}" \
  -ServerPassword="${ServerPassword}" \
  -SteamServerName="${SteamServerName}" \
  -WorldSaveName="${WorldSaveName}" \
  -tcp \
  ${AdditionalArgs}
