#!/bin/bash
#===============================================
# Description: DIY script 1 for iStoreOS
# Lisence: MIT
#===============================================

set -e

echo "========================================"
echo "开始执行 iStoreOS 初始化设置..."
echo "========================================"

# 修改默认 LAN IP 为 192.168.8.1
if [ -f "package/base-files/files/bin/config_generate" ]; then
    sed -i 's/192\.168\.1\.1/192.168.8.1/g' package/base-files/files/bin/config_generate
fi

if [ -f "package/base-files/luci/bin/config_generate" ]; then
    sed -i 's/192\.168\.1\.1/192.168.8.1/g' package/base-files/luci/bin/config_generate
fi

# 设置 config 文件的安全权限
if [ -d "files/etc/config" ]; then
    chmod 644 files/etc/config/* 2>/dev/null || true
fi

# HomeProxy 处理逻辑
HOMEPROXY_DIR="./package/luci-app-homeproxy"
HOMEPROXY_REPO="https://github.com/immortalwrt/homeproxy.git"
HOMEPROXY_BRANCH="master"

if [ -d "${HOMEPROXY_DIR}" ]; then
    rm -rf "${HOMEPROXY_DIR}"
fi

git clone --depth=1 --single-branch --branch "${HOMEPROXY_BRANCH}" "${HOMEPROXY_REPO}" "${HOMEPROXY_DIR}"

DNS_CONFIG_FILE="${HOMEPROXY_DIR}/root/etc/config/homeproxy"
HP_PATH="root/etc/homeproxy"
HP_RESOURCES="${HOMEPROXY_DIR}/${HP_PATH}/resources"
mkdir -p "${HP_RESOURCES}"

if [ -f "${DNS_CONFIG_FILE}" ]; then
    sed -i "s#option dns_server '8\.8\.8\.8'#option dns_server 'https://1.1.1.1/dns-query'#g" "${DNS_CONFIG_FILE}" || true
    sed -i "s#option china_dns_server '223\.5\.5\.5'#option china_dns_server 'https://223.5.5.5/dns-query'#g" "${DNS_CONFIG_FILE}" || true
fi

# 安全获取 Surge Rules，增加兜底，防止因为抓取为空触发 exit 1
HP_RULE="surge"
RULE_REPO="https://github.com/Loyalsoldier/surge-rules.git"
rm -rf "./${HP_RULE}"

if git clone -q --depth=1 --single-branch --branch "release" "${RULE_REPO}" "./${HP_RULE}"; then
    cd "./${HP_RULE}"
    
    RES_VER="$(git log -1 --pretty=format:'%s' 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)"
    [ -z "${RES_VER}" ] && RES_VER="$(date +%Y%m%d)"
    
    printf '%s\n' "${RES_VER}" > china_ip4.ver
    printf '%s\n' "${RES_VER}" > china_ip6.ver
    printf '%s\n' "${RES_VER}" > china_list.ver
    printf '%s\n' "${RES_VER}" > gfw_list.ver

    if [ -f "cncidr.txt" ]; then
        awk -F, '/^IP-CIDR,/ {print $2}' cncidr.txt > china_ip4.txt || true
        awk -F, '/^IP-CIDR6,/ {print $2}' cncidr.txt > china_ip6.txt || true
    else
        : > china_ip4.txt
        : > china_ip6.txt
    fi

    if [ -f "direct.txt" ]; then
        sed 's/^\.//g' direct.txt > china_list.txt
    else
        : > china_list.txt
    fi

    if [ -f "gfw.txt" ]; then
        sed 's/^\.//g' gfw.txt > gfw_list.txt
    else
        : > gfw_list.txt
    fi

    cd ..

    cp -f ./${HP_RULE}/*.ver "${HP_RESOURCES}/" 2>/dev/null || true
    cp -f ./${HP_RULE}/*.txt "${HP_RESOURCES}/" 2>/dev/null || true
    rm -rf "./${HP_RULE}"
fi

# 更新并安装 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 自动开启 Wi-Fi 脚本
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-enable-wifi << 'WIFIEOF'
#!/bin/sh
logger -t enable-wifi "start"
if ! uci -q show wireless | grep -q "=wifi-device"; then
	wifi config
	sleep 2
fi
if ! uci -q show wireless | grep -q "=wifi-device"; then
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
	[ -n "$(uci -q get wireless.${cfg}.disabled)" ] && uci set wireless.${cfg}.disabled='0'
}
config_load wireless
config_foreach enable_device wifi-device
config_foreach enable_iface wifi-iface
uci commit wireless
( sleep 1; wifi reload >/dev/null 2>&1 ) &
exit 0
WIFIEOF
chmod +x files/etc/uci-defaults/99-enable-wifi

# 获取内核 vermagic 校验码
Releases_version=$(cat include/version.mk 2>/dev/null | sed -n 's|.*releases/\([^)]*\)).*|\1|p' || true)
if [ -z "$Releases_version" ]; then
    Releases_version=$(cat package/base-files/image-config.in 2>/dev/null | sed -n 's|.*releases/\([^"]*\)".*|\1|p' || true)
fi

[ -z "$Releases_version" ] && Releases_version="24.10.0"

http_value=$(wget -qO- "https://downloads.openwrt.org/releases/${Releases_version}/targets/rockchip/armv8/kmods/" || true)
hash_value=$(echo "$http_value" | sed -n 's/^.*-\([0-9a-f]\{32\}\)\/.*/\1/p' | head -1 || true)

if [ -n "$hash_value" ] && [[ "$hash_value" =~ ^[0-9a-f]{32}$ ]]; then
    echo "$hash_value" > .vermagic
    echo "kernel内核md5校验码：$hash_value"
fi

date_version=$(date +"%Y%m%d%H")
echo $date_version > version

echo "========================================"
echo "iStoreOS 初始化设置成功完成!"
echo "========================================"
