#!/bin/bash
#===============================================
# Description: DIY script
# File name: diy-script.sh
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#===============================================

#!/bin/bash

set -e

# ============================================================
# OpenWrt master 初始化设置
# HomeProxy + Surge Rules + DNS
# ============================================================

echo "========================================"
echo "开始执行 OpenWrt 初始化设置..."
echo "========================================"

# ------------------------------------------------------------
# 默认 LAN 地址修改为 192.168.8.1
# ------------------------------------------------------------

echo "修改默认 LAN 地址为 192.168.8.1..."

if [ -f "package/base-files/files/bin/config_generate" ]; then
    sed -i 's/192\.168\.1\.1/192.168.8.1/g' \
        package/base-files/files/bin/config_generate
fi

if [ -f "package/base-files/luci/bin/config_generate" ]; then
    sed -i 's/192\.168\.1\.1/192.168.8.1/g' \
        package/base-files/luci/bin/config_generate
fi

# ------------------------------------------------------------
# config 文件权限
# ------------------------------------------------------------

if [ -d "files/etc/config" ]; then
    chmod 644 files/etc/config/* 2>/dev/null || true
fi

# ============================================================
# HomeProxy
# ============================================================

echo
echo "========================================"
echo "开始处理 HomeProxy..."
echo "========================================"

# OpenWrt 官方 master 默认 LuCI feed 不包含 HomeProxy
# 因此直接将 ImmortalWrt HomeProxy 源码放入 package/
HOMEPROXY_DIR="./package/luci-app-homeproxy"

HOMEPROXY_REPO="https://github.com/immortalwrt/homeproxy.git"
HOMEPROXY_BRANCH="master"

# ------------------------------------------------------------
# 删除旧 HomeProxy
# ------------------------------------------------------------

if [ -d "${HOMEPROXY_DIR}" ]; then
    echo "发现旧 HomeProxy，删除..."
    rm -rf "${HOMEPROXY_DIR}"
fi

# ------------------------------------------------------------
# 下载 HomeProxy
# ------------------------------------------------------------

echo "正在下载 HomeProxy..."

git clone \
    --depth=1 \
    --single-branch \
    --branch "${HOMEPROXY_BRANCH}" \
    "${HOMEPROXY_REPO}" \
    "${HOMEPROXY_DIR}"

if [ ! -d "${HOMEPROXY_DIR}" ]; then
    echo "错误：HomeProxy 下载失败！"
    exit 1
fi

echo "✅ HomeProxy 源码下载成功"

# ------------------------------------------------------------
# 检查 Makefile
# ------------------------------------------------------------

if [ ! -f "${HOMEPROXY_DIR}/Makefile" ]; then
    echo "错误：HomeProxy Makefile 不存在！"
    exit 1
fi

# ------------------------------------------------------------
# 检查 homeproxy 配置
# ------------------------------------------------------------

DNS_CONFIG_FILE="${HOMEPROXY_DIR}/root/etc/config/homeproxy"

if [ ! -f "${DNS_CONFIG_FILE}" ]; then
    echo "错误：HomeProxy 配置文件不存在："
    echo "${DNS_CONFIG_FILE}"
    exit 1
fi

echo "✅ HomeProxy 配置文件存在"

# ------------------------------------------------------------
# 检查资源目录
# ------------------------------------------------------------

HP_PATH="root/etc/homeproxy"
HP_RESOURCES="${HOMEPROXY_DIR}/${HP_PATH}/resources"

mkdir -p "${HP_RESOURCES}"

echo "HomeProxy resources：${HP_RESOURCES}"

# ============================================================
# HomeProxy DNS 配置
# ============================================================

echo
echo "========================================"
echo "配置 HomeProxy DNS..."
echo "========================================"

# 国外 DNS
# AdGuard DNS IPv4 DoH
sed -i \
    "s#option dns_server '8\.8\.8\.8'#option dns_server 'https://1.1.1.1/dns-query'#g" \
    "${DNS_CONFIG_FILE}"

# 国内 DNS
# 阿里 DNS DoH
sed -i \
    "s#option china_dns_server '223\.5\.5\.5'#option china_dns_server 'https://223.5.5.5/dns-query'#g" \
    "${DNS_CONFIG_FILE}"

echo "当前 HomeProxy DNS："

grep -E \
    "option (dns_server|china_dns_server)" \
    "${DNS_CONFIG_FILE}" || true

echo "✅ HomeProxy DNS 配置完成"

# ============================================================
# Surge Rules
# ============================================================

echo
echo "========================================"
echo "开始更新 HomeProxy 规则..."
echo "========================================"

HP_RULE="surge"
RULE_REPO="https://github.com/Loyalsoldier/surge-rules.git"

rm -rf "./${HP_RULE}"

git clone \
    -q \
    --depth=1 \
    --single-branch \
    --branch "release" \
    "${RULE_REPO}" \
    "./${HP_RULE}"

if [ ! -d "./${HP_RULE}" ]; then
    echo "错误：surge-rules 下载失败！"
    exit 1
fi

cd "./${HP_RULE}"

# ------------------------------------------------------------
# 获取规则版本
# ------------------------------------------------------------

RES_VER="$(git log -1 --pretty=format:'%s' | grep -oE '[0-9]+' | head -1 || true)"

if [ -z "${RES_VER}" ]; then
    RES_VER="$(date +%Y%m%d)"
fi

echo "规则版本：${RES_VER}"

# ------------------------------------------------------------
# 生成版本文件
# ------------------------------------------------------------

printf '%s\n' "${RES_VER}" > china_ip4.ver
printf '%s\n' "${RES_VER}" > china_ip6.ver
printf '%s\n' "${RES_VER}" > china_list.ver
printf '%s\n' "${RES_VER}" > gfw_list.ver

# ------------------------------------------------------------
# IPv4 / IPv6 中国 IP
# ------------------------------------------------------------

if [ -f "cncidr.txt" ]; then

    awk -F, '
    /^IP-CIDR,/ {
        print $2
    }
    ' cncidr.txt > china_ip4.txt

    awk -F, '
    /^IP-CIDR6,/ {
        print $2
    }
    ' cncidr.txt > china_ip6.txt

else
    echo "警告：cncidr.txt 不存在"
    : > china_ip4.txt
    : > china_ip6.txt
fi

# ------------------------------------------------------------
# 国内域名
# ------------------------------------------------------------

if [ -f "direct.txt" ]; then
    sed 's/^\.//g' direct.txt > china_list.txt
else
    echo "警告：direct.txt 不存在"
    : > china_list.txt
fi

# ------------------------------------------------------------
# GFW 域名
# ------------------------------------------------------------

if [ -f "gfw.txt" ]; then
    sed 's/^\.//g' gfw.txt > gfw_list.txt
else
    echo "警告：gfw.txt 不存在"
    : > gfw_list.txt
fi

# ------------------------------------------------------------
# 返回 OpenWrt 根目录
# ------------------------------------------------------------

cd ..

# ------------------------------------------------------------
# 清理旧规则
# ------------------------------------------------------------

rm -f \
    "${HP_RESOURCES}/china_ip4.ver" \
    "${HP_RESOURCES}/china_ip4.txt" \
    "${HP_RESOURCES}/china_ip6.ver" \
    "${HP_RESOURCES}/china_ip6.txt" \
    "${HP_RESOURCES}/china_list.ver" \
    "${HP_RESOURCES}/china_list.txt" \
    "${HP_RESOURCES}/gfw_list.ver" \
    "${HP_RESOURCES}/gfw_list.txt"

# ------------------------------------------------------------
# 安装规则
# ------------------------------------------------------------

cp -f "./${HP_RULE}/china_ip4.ver" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/china_ip4.txt" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/china_ip6.ver" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/china_ip6.txt" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/china_list.ver" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/china_list.txt" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/gfw_list.ver" \
    "${HP_RESOURCES}/"

cp -f "./${HP_RULE}/gfw_list.txt" \
    "${HP_RESOURCES}/"

rm -rf "./${HP_RULE}"

echo "✅ HomeProxy 规则已更新"

# ============================================================
# HomeProxy 检查
# ============================================================

echo
echo "========================================"
echo "检查 HomeProxy..."
echo "========================================"

echo "HomeProxy 路径："
echo "${HOMEPROXY_DIR}"

echo
echo "HomeProxy Makefile："
grep -E \
    'PKG_NAME|LUCI_TITLE|LUCI_DEPENDS' \
    "${HOMEPROXY_DIR}/Makefile" || true

echo
echo "HomeProxy DNS："
grep -E \
    "option (dns_server|china_dns_server)" \
    "${DNS_CONFIG_FILE}" || true

echo
echo "HomeProxy 规则："
ls -lh "${HP_RESOURCES}/" || true

# ============================================================
# 更新 feeds
# ============================================================

echo
echo "========================================"
echo "更新 OpenWrt feeds..."
echo "========================================"

./scripts/feeds update -a

./scripts/feeds install -a

echo "✅ feeds 更新完成"

# ============================================================
# 检查 HomeProxy 是否被识别
# ============================================================

echo
echo "========================================"
echo "检查 luci-app-homeproxy..."
echo "========================================"

if [ -d "package/luci-app-homeproxy" ]; then
    echo "✅ package/luci-app-homeproxy 存在"
else
    echo "错误：package/luci-app-homeproxy 不存在！"
    exit 1
fi

# ============================================================
# 完成
# ============================================================

echo
echo "========================================"
echo "HomeProxy 处理完成！"
echo "初始化设置执行成功!"
echo "========================================"







# ==== 以下内容追加到 init-settings.sh 末尾 ====
# 在编译主机上直接生成 uci-defaults 脚本并赋权，
# 不依赖仓库里 files/ 目录携带的文件权限位（避免因 git/编辑器丢失可执行位导致脚本被跳过）

echo "开始生成 wifi 自动启用脚本..."
mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-enable-wifi << 'WIFIEOF'
#!/bin/sh
# 首次开机自动启用无线；若未检测到任何 wifi-device 段，先强制重新探测硬件

logger -t enable-wifi "start"

if ! uci -q show wireless | grep -q "=wifi-device"; then
	logger -t enable-wifi "no wifi-device section, forcing 'wifi config' re-detect"
	wifi config
	sleep 2
fi

if ! uci -q show wireless | grep -q "=wifi-device"; then
	logger -t enable-wifi "still no wireless hardware detected after re-detect - check lspci/dmesg on this device"
	exit 0
fi

. /lib/functions.sh
COUNTRY="CN"

enable_device() {
	local cfg="$1"
	uci set wireless.${cfg}.disabled='0'
	uci set wireless.${cfg}.country="${COUNTRY}"
}

enable_iface() {
	local cfg="$1"
	[ -n "$(uci -q get wireless.${cfg}.disabled)" ] && \
		uci set wireless.${cfg}.disabled='0'
}

config_load wireless
config_foreach enable_device wifi-device
config_foreach enable_iface wifi-iface
uci commit wireless

( sleep 1; wifi reload >/dev/null 2>&1 ) &

logger -t enable-wifi "done, wireless enabled"
exit 0
WIFIEOF

chmod +x files/etc/uci-defaults/99-enable-wifi
ls -la files/etc/uci-defaults/99-enable-wifi
echo "wifi 自动启用脚本已生成并赋权"
# ==== 追加内容结束 ====


# 修复系统kernel内核md5校验码不正确的问题
# https://downloads.openwrt.org/releases/24.10.5/targets/rockchip/armv8/kmods/
# https://archive.openwrt.org/releases/24.10.5/targets/rockchip/armv8/kmods/
# https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/24.10.5/targets/rockchip/armv8/kmods/
# https://mirrors.cqupt.edu.cn/openwrt/releases/24.10.5/targets/rockchip/armv8/kmods/
# https://mirrors.ustc.edu.cn/openwrt/releases/24.10.5/targets/rockchip/armv8/kmods/

hash_value=""
Releases_version=$(cat include/version.mk | sed -n 's|.*releases/\([^)]*\)).*|\1|p')

if [ -z "$Releases_version" ]; then
    Releases_version=$(cat package/base-files/image-config.in | sed -n 's|.*releases/\([^"]*\)".*|\1|p')
fi

http_value=$(wget -qO- "https://downloads.openwrt.org/releases/${Releases_version}/targets/rockchip/armv8/kmods/")
hash_value=$(echo "$http_value" | sed -n 's/^.*-\([0-9a-f]\{32\}\)\/.*/\1/p' | head -1)

if [ -z "$hash_value" ]; then
    http_value=$(wget -qO- "https://archive.openwrt.org/releases/${Releases_version}/targets/rockchip/armv8/kmods/")
    hash_value=$(echo "$http_value" | sed -n 's/^.*-\([0-9a-f]\{32\}\)\/.*/\1/p' | head -1)
fi

if [ -z "$hash_value" ]; then
    http_value=$(wget -qO- "https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/${Releases_version}/targets/rockchip/armv8/kmods/")
    hash_value=$(echo "$http_value" | sed -n 's/^.*-\([0-9a-f]\{32\}\)\/.*/\1/p' | head -1)
fi

if [ -z "$hash_value" ]; then
    http_value=$(wget -qO- "https://mirrors.cqupt.edu.cn/openwrt/releases/${Releases_version}/targets/rockchip/armv8/kmods/")
    hash_value=$(echo "$http_value" | sed -n 's/^.*-\([0-9a-f]\{32\}\)\/.*/\1/p' | head -1)
fi

if [ -z "$hash_value" ]; then
    http_value=$(wget -qO- "https://mirrors.ustc.edu.cn/openwrt/releases/${Releases_version}/targets/rockchip/armv8/kmods/")
    hash_value=$(echo "$http_value" | sed -n 's/^.*-\([0-9a-f]\{32\}\)\/.*/\1/p' | head -1)
fi

hash_value=${hash_value:-$(echo "$http_value" | sed -n 's/.*\([0-9a-f]\{32\}\)\/.*/\1/p' | head -1)}
if [ -n "$hash_value" ] && [[ "$hash_value" =~ ^[0-9a-f]{32}$ ]]; then
    echo "$hash_value" > .vermagic
    echo "kernel内核md5校验码：$hash_value"
else
    echo "警告：请求所有链接均未获取到有效校验码，请修复！"
    exit 1
fi

# 修改版本为编译日期，数字类型。
date_version=$(date +"%Y%m%d%H")
echo $date_version > version



#!/usr/bin/env bash
#
# fix-geoview-go.sh
#
# 解决 OpenWrt/ImmortalWrt 编译报错：
#   go: ../../go.mod requires go >= 1.25.0 (running go 1.23.12; GOTOOLCHAIN=local)
#   ERROR: package/feeds/small/geoview failed to build.
#
# 用法（在仓库根目录，即包含 Makefile / feeds.conf.default 的目录下执行）：
#   1) ./scripts/feeds update -a
#   2) ./scripts/feeds install -a
#   3) bash fix-geoview-go.sh
#   4) make -j$(nproc) 或原来的 make 命令
#
# 可选参数：
#   --disable-geoview   如果不需要联网下载新 go 工具链（比如离线构建环境），
#                        直接在 .config 里关闭 geoview 及依赖它的插件，
#                        跳过这个包而不是修复它。
#
set -euo pipefail

ROOT_DIR="$(pwd)"
DISABLE_GEOVIEW=0

for arg in "$@"; do
  case "$arg" in
    --disable-geoview)
      DISABLE_GEOVIEW=1
      ;;
    *)
      echo "未知参数: $arg" >&2
      exit 1
      ;;
  esac
done

if [ ! -d "$ROOT_DIR/feeds" ] && [ ! -d "$ROOT_DIR/package" ]; then
  echo "错误：请在 OpenWrt 源码根目录下运行本脚本（需要能看到 feeds/ 或 package/ 目录）。" >&2
  exit 1
fi

echo "==> [1/3] 搜索硬编码的 GOTOOLCHAIN=local ..."
HITS=$(grep -rlE 'GOTOOLCHAIN[[:space:]]*[:?]?=[[:space:]]*local' \
  --include="*.mk" --include="Makefile" \
  feeds package include tools toolchain 2>/dev/null || true)

if [ -n "$HITS" ]; then
  echo "$HITS" | while IFS= read -r f; do
    [ -z "$f" ] && continue
    echo "    patch: $f"
    cp "$f" "$f.bak.$(date +%s)"
    sed -i -E 's/(GOTOOLCHAIN[[:space:]]*[:?]?=[[:space:]]*)local/\1auto/g' "$f"
  done
else
  echo "    未找到硬编码位置（可能是通过环境变量传递的），继续用环境变量兜底。"
fi

echo "==> [2/3] 设置 GOTOOLCHAIN=auto 环境变量（本次 shell 及后续 CI step 生效）..."
export GOTOOLCHAIN=auto
export GOFLAGS="${GOFLAGS:-} -mod=mod"
if [ -n "${GITHUB_ENV:-}" ]; then
  {
    echo "GOTOOLCHAIN=auto"
  } >> "$GITHUB_ENV"
  echo "    已写入 \$GITHUB_ENV，后续 workflow step 会继续携带 GOTOOLCHAIN=auto。"
fi

if [ "$DISABLE_GEOVIEW" -eq 1 ]; then
  echo "==> [3/3] --disable-geoview 已指定，尝试在 .config 中关闭 geoview 及相关插件 ..."
  if [ -f "$ROOT_DIR/.config" ]; then
    cp "$ROOT_DIR/.config" "$ROOT_DIR/.config.bak.$(date +%s)"
    # 关闭 geoview 本身
    sed -i -E 's/^CONFIG_PACKAGE_geoview=y/# CONFIG_PACKAGE_geoview is not set/' "$ROOT_DIR/.config"
    # 常见依赖 geoview 的插件也一并提示/关闭（passwall2 / homeproxy 系列）
    for pkg in luci-app-passwall2 luci-i18n-passwall2-zh-cn luci-app-homeproxy luci-i18n-homeproxy-zh-cn; do
      if grep -q "^CONFIG_PACKAGE_${pkg}=y" "$ROOT_DIR/.config" 2>/dev/null; then
        echo "    警告：检测到 $pkg 依赖 geoview，一并关闭。若需要该功能，请改用修复方案而非本选项。"
        sed -i -E "s/^CONFIG_PACKAGE_${pkg}=y/# CONFIG_PACKAGE_${pkg} is not set/" "$ROOT_DIR/.config"
      fi
    done
    echo "    已更新 .config（原文件已备份为 .config.bak.*）。建议重新跑一次 'make defconfig' 确认依赖关系。"
  else
    echo "    未找到 .config，跳过自动关闭步骤，请手动执行 'make menuconfig' 关闭 geoview。"
  fi
else
  echo "==> [3/3] 跳过 --disable-geoview（未指定该参数）。"
fi

echo ""
echo "完成。接下来直接重新执行你的 make 命令即可，例如："
echo "    make -j\$(nproc) V=s"
echo ""
echo "如果 CI 环境无法访问 go 官方下载源导致 GOTOOLCHAIN=auto 仍然失败，"
echo "请改用：bash fix-geoview-go.sh --disable-geoview"



# 为iStoreOS固件版本加上编译作者
# author="xiaomeng9597"
# sed -i "s/DISTRIB_DESCRIPTION.*/DISTRIB_DESCRIPTION='%D %V ${date_version} by ${author}'/g" package/base-files/files/etc/openwrt_release
# sed -i "s/OPENWRT_RELEASE.*/OPENWRT_RELEASE=\"%D %V ${date_version} by ${author}\"/g" package/base-files/files/usr/lib/os-release
