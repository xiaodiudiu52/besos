#!/bin/bash
# ==========================================================
# 极路由Go (HC5611) 定制 OpenWrt 固件构建脚本
# 必须在 Linux x86_64 上运行（Ubuntu/Debian 或 GitHub Actions）
# ==========================================================
set -e

VER="24.10.8"
TARGET_DIR="ramips-mt76x8"
PROFILE="hiwifi_hc5611"
IB="openwrt-imagebuilder-${VER}-${TARGET_DIR}.Linux-x86_64"
URL="https://downloads.openwrt.org/releases/${VER}/targets/ramips/mt76x8/${IB}.tar.zst"

# 中文界面
LANG_PKGS="luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn luci-i18n-package-manager-zh-cn luci-i18n-commands-zh-cn"
# 网页场景模式页面（Lua CBI 运行环境）
LUA_PKGS="luci-lua-runtime luci-compat luci-app-commands"
# 网页终端
TTYD_PKGS="ttyd luci-app-ttyd"
# 现场调试工具
TOOLS_PKGS="tcpdump iperf3 ethtool arp-scan nmap"
# 宽带拨号（PPPoE）支持，官方镜像默认不带
PPP_PKGS="ppp ppp-mod-pppoe"
# UI 主题：Material Design 风格（科技感），同时保留官方默认主题可随时切回
THEME_PKGS="luci-theme-material luci-theme-openwrt"

PACKAGES="${LANG_PKGS} ${LUA_PKGS} ${TTYD_PKGS} ${TOOLS_PKGS} ${PPP_PKGS} ${THEME_PKGS}"

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
FILES="${WORKDIR}/files"

echo ">>> 下载 OpenWrt ImageBuilder ${VER}"
cd "${WORKDIR}"
if [ ! -d "${IB}" ]; then
	curl -sSLO "${URL}"
	tar --zstd -xf "${IB}.tar.zst"
fi

echo ">>> 给注入的脚本加执行权限"
chmod +x "${FILES}"/usr/bin/gomode "${FILES}"/usr/bin/gomode-led \
	"${FILES}"/etc/init.d/gomode "${FILES}"/etc/init.d/gomode-led \
	"${FILES}"/etc/uci-defaults/99-hc5611-custom

echo ">>> 开始构建（约 5-15 分钟）"
cd "${IB}"
make image \
	PROFILE="${PROFILE}" \
	PACKAGES="${PACKAGES}" \
	FILES="${FILES}" \
	EXTRA_IMAGE_NAME="custom"

echo ">>> 构建完成，生成的固件："
ls -lh bin/targets/ramips/mt76x8/ || true
