#!/bin/bash
#===============================================
# Description: DIY script
# File name: diy-script.sh
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#===============================================


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

# 为iStoreOS固件版本加上编译作者
# author="xiaomeng9597"
# sed -i "s/DISTRIB_DESCRIPTION.*/DISTRIB_DESCRIPTION='%D %V ${date_version} by ${author}'/g" package/base-files/files/etc/openwrt_release
# sed -i "s/OPENWRT_RELEASE.*/OPENWRT_RELEASE=\"%D %V ${date_version} by ${author}\"/g" package/base-files/files/usr/lib/os-release
