FROM ubuntu:24.04

# 非交互模式 / Non-interactive mode
ENV DEBIAN_FRONTEND=noninteractive

# 安装 WineHQ 官方源与稳定版、SteamCMD，以及无界面运行所需的 Xvfb
# Install WineHQ repo + stable, SteamCMD, and Xvfb required for headless running
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg \
        wget \
        software-properties-common && \
    \
    # 启用 multiverse 以安装 steamcmd / Enable multiverse to install steamcmd
    add-apt-repository -y multiverse && \
    \
    # WineHQ 官方 key 与源（Ubuntu 24.04 = noble），-pm755 对齐官方步骤
    # WineHQ official key and repo (Ubuntu 24.04 = noble); -pm755 matches the official steps
    mkdir -pm755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ \
      https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources && \
    \
    apt-get update && \
    # WineHQ 建议用 --install-recommends 安装 winehq-stable
    # 如需可复现构建，可锁定版本，例如：winehq-stable=11.0.0.0~noble-1
    # For reproducible builds you can pin a version, e.g. winehq-stable=11.0.0.0~noble-1
    apt-get install -y --install-recommends winehq-stable && \
    \
    # 无界面运行 UE 服务端通常需要 Xvfb（entrypoint 一般用 xvfb-run 启动）
    # Headless UE server usually needs Xvfb (entrypoint typically launches via xvfb-run)
    # 如确认 entrypoint 未用 xvfb-run，可删掉这一步；
    # 如需 NTLM 或 winetricks，再加 winbind / cabextract
    apt-get install -y --no-install-recommends xvfb && \
    \
    # 预先接受 steam 许可，避免构建时卡住 / Pre-accept the Steam license to prevent build hangs
    echo steam steam/question select "I AGREE" | debconf-set-selections && \
    echo steam steam/license note '' | debconf-set-selections && \
    apt-get install -y --no-install-recommends steamcmd && \
    \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# SteamCMD 安装在 /usr/games / SteamCMD is installed under /usr/games
ENV PATH="/usr/games:${PATH}"

# 纯 64 位 Wine，禁用多余 debug，避免 gecko/mono 弹窗 / 64-bit Wine with minimal debug to avoid gecko/mono pop-ups
ENV WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/server/.wine \
    WINEDLLOVERRIDES="mscoree,mshtml="

# 游戏安装目录 / Game installation directory
WORKDIR /server

# 拷贝启动脚本 / Copy the startup script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
