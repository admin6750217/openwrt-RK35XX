#!/bin/bash
#===============================================
# Description: DIY script
# File name: diy-script.sh
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#===============================================

# 修改uhttpd配置文件，启用nginx
# sed -i "/.*uhttpd.*/d" .config
# sed -i '/.*\/etc\/init.d.*/d' package/network/services/uhttpd/Makefile
# sed -i '/.*.\/files\/uhttpd.init.*/d' package/network/services/uhttpd/Makefile
sed -i "s/:80/:81/g" package/network/services/uhttpd/files/uhttpd.config
sed -i "s/:443/:4443/g" package/network/services/uhttpd/files/uhttpd.config
cp -a $GITHUB_WORKSPACE/configfiles/etc/* package/base-files/files/etc/
# ls package/base-files/files/etc/


# 追加自定义内核配置项
echo "CONFIG_PSI=y
CONFIG_KPROBES=y" >> target/linux/rockchip/armv8/config-6.6


# 集成CPU性能跑分脚本
cp -f $GITHUB_WORKSPACE/configfiles/coremark/coremark-arm64 package/base-files/files/bin/coremark-arm64
cp -f $GITHUB_WORKSPACE/configfiles/coremark/coremark-arm64.sh package/base-files/files/bin/coremark.sh
chmod 755 package/base-files/files/bin/coremark-arm64
chmod 755 package/base-files/files/bin/coremark.sh


# 复制dts设备树文件到指定目录下
# cp -a $GITHUB_WORKSPACE/configfiles/dts/rk3588/* target/linux/rockchip/dts/rk3588/

# 删除feeds中的插件
rm -rf ./feeds/packages/net/{geoview,chinadns-ng,hysteria,mosdns,v2ray-geodata,lucky}
rm -rf ./feeds/packages/net/{shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev}
rm -rf ./feeds/packages/net/{sing-box,v2ray-geodata,v2ray-plugin,xray-core,smartdns}

rm -rf ./feeds/luci/applications/{luci-app-passwall,luci-app-passwall2,luci-app-openclash,luci-app-homeproxy}
rm -rf ./feeds/luci/applications/{luci-app-lucky,luci-app-smartdns,luci-app-timecontrol,luci-app-mosdns}
rm -rf ./feeds/luci/applications/{luci-app-nikki,luci-app-momo,luci-app-daed}

# 克隆依赖插件
git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git package/pwpage
# git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang


# 克隆的源码放在small文件夹
mkdir package/small
pushd package/small

# luci-theme-aurora
git clone -b master --depth 1 https://github.com/eamonxg/luci-theme-aurora.git

# luci-app-nft-timecontrol
git clone -b main --depth 1 https://github.com/sirpdboy/luci-app-timecontrol.git

# adguardhome
# git clone -b 2024.09.05 --depth 1 https://github.com/XiaoBinin/luci-app-adguardhome.git

# homeproxy
git clone -b master --depth 1 https://github.com/immortalwrt/homeproxy.git

# lucky
git clone -b main --depth 1 https://github.com/gdy666/luci-app-lucky.git

# smartdns
git clone -b master --depth 1 https://github.com/pymumu/luci-app-smartdns.git
git clone -b master --depth 1 https://github.com/pymumu/smartdns.git
sed -i 's@include ../../lang/rust/rust-package.mk@include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk@g' smartdns/package/openwrt/Makefile
sed -n '33p' smartdns/package/openwrt/Makefile

# ssrp
# git clone -b master --depth 1 https://github.com/fw876/helloworld.git

# VIKINGYFY/packages
git clone -b main --depth 1 https://github.com/VIKINGYFY/packages.git

# passwall
git clone -b main --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall.git

# passwall2
git clone -b main --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall2.git

# mosdns
git clone -b v5 --depth 1 https://github.com/sbwml/luci-app-mosdns.git

# luci-app-netspeedtest
git clone -b master --depth 1 https://github.com/sirpdboy/luci-app-netspeedtest.git

# openclash
git clone -b master --depth 1 https://github.com/vernesong/OpenClash.git

# OpenWrt-nikki
git clone -b main --depth 1 https://github.com/nikkinikki-org/OpenWrt-nikki.git

# OpenWrt-momo
git clone -b main --depth 1 https://github.com/nikkinikki-org/OpenWrt-momo.git

# daed
git clone -b master --depth 1 https://github.com/QiuSimons/luci-app-daed.git

#modem
# git clone -b main --depth 1 https://github.com/FUjr/modem_feeds.git

popd

echo "packages executed successfully!"





# iStoreOS-settings
git clone --depth=1 -b main https://github.com/xiaomeng9597/istoreos-settings package/default-settings


# 定时限速插件
git clone --depth=1 https://github.com/sirpdboy/luci-app-eqosplus package/luci-app-eqosplus


# ============================================================
# 修复 geoview 等 go 包因宿主 go 工具链版本过低导致的编译失败
#   go: ../../go.mod requires go >= 1.25.0 (running go 1.23.12; GOTOOLCHAIN=local)
#
# 放在 diy-part2 末尾执行，此时两次 feeds update/install 都已跑完，
# 不会再被 feeds update 覆盖掉这里打的补丁。
#
# 如果不想联网下载新 go 工具链（比如担心网络不稳定），
# 可以在 workflow env 里加一行 DISABLE_GEOVIEW: "true" 来跳过 geoview，
# 而不是修复它。
# ============================================================

echo
echo "========================================"
echo "修复 geoview go 版本冲突..."
echo "========================================"

echo "==> 搜索硬编码的 GOTOOLCHAIN=local ..."
GOTOOLCHAIN_HITS=$(grep -rlE 'GOTOOLCHAIN[[:space:]]*[:?]?=[[:space:]]*local' \
  --include="*.mk" --include="Makefile" \
  feeds package include tools toolchain 2>/dev/null || true)

if [ -n "${GOTOOLCHAIN_HITS}" ]; then
    echo "${GOTOOLCHAIN_HITS}" | while IFS= read -r f; do
        [ -z "$f" ] && continue
        echo "    patch: $f"
        sed -i -E 's/(GOTOOLCHAIN[[:space:]]*[:?]?=[[:space:]]*)local/\1auto/g' "$f"
    done
else
    echo "    未找到硬编码位置，继续用环境变量兜底。"
fi

# make defconfig / make download / make compile 是各自独立的 workflow step，
# 必须写入 GITHUB_ENV 才能让 GOTOOLCHAIN=auto 传递到后面的编译 step。
if [ -n "${GITHUB_ENV:-}" ]; then
    {
        echo "GOTOOLCHAIN=auto"
        echo "GOFLAGS=-mod=mod"
        echo "GOPROXY=https://goproxy.cn,direct"
    } >> "$GITHUB_ENV"
    echo "    已写入 GOTOOLCHAIN=auto / GOPROXY 镜像加速到 \$GITHUB_ENV"
fi

if [ "${DISABLE_GEOVIEW:-false}" = "true" ]; then
    echo "==> DISABLE_GEOVIEW=true，改为在 .config 中关闭 geoview 及相关插件..."
    if [ -f ".config" ]; then
        sed -i -E 's/^CONFIG_PACKAGE_geoview=y/# CONFIG_PACKAGE_geoview is not set/' .config
        for pkg in luci-app-passwall luci-app-passwall2 luci-app-homeproxy; do
            if grep -q "^CONFIG_PACKAGE_${pkg}=y" .config 2>/dev/null; then
                echo "    警告：$pkg 依赖 geoview，一并关闭。"
                sed -i -E "s/^CONFIG_PACKAGE_${pkg}=y/# CONFIG_PACKAGE_${pkg} is not set/" .config
            fi
        done
    else
        echo "    .config 尚未生成（在 make defconfig 之前），跳过，改由 GOTOOLCHAIN=auto 兜底。"
    fi
fi

echo "✅ geoview go 版本修复处理完成"
