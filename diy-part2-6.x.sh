#!/bin/bash
#===============================================
# Description: DIY script 2 for iStoreOS
# Lisence: MIT
#===============================================

# 修改 uhttpd 默认端口避让
sed -i "s/:80/:81/g" package/network/services/uhttpd/files/uhttpd.config
sed -i "s/:443/:4443/g" package/network/services/uhttpd/files/uhttpd.config

# 增加目录存在性校验，避免 cp 失败触发 set -e 中断
if [ -d "$GITHUB_WORKSPACE/configfiles" ]; then
    [ -d "$GITHUB_WORKSPACE/configfiles/etc" ] && cp -a $GITHUB_WORKSPACE/configfiles/etc/* package/base-files/files/etc/
    if [ -f "$GITHUB_WORKSPACE/configfiles/coremark/coremark-arm64" ]; then
        cp -f $GITHUB_WORKSPACE/configfiles/coremark/coremark-arm64 package/base-files/files/bin/coremark-arm64
        cp -f $GITHUB_WORKSPACE/configfiles/coremark/coremark-arm64.sh package/base-files/files/bin/coremark.sh
        chmod 755 package/base-files/files/bin/coremark-arm64
        chmod 755 package/base-files/files/bin/coremark.sh
    fi
else
    echo "⚠️ 未找到 $GITHUB_WORKSPACE/configfiles 目录，已跳过自定义配置复制"
fi

# 尝试追加 Kernel 配置，带容错机制
if [ -f "target/linux/rockchip/armv8/config-6.6" ]; then
    echo "CONFIG_PSI=y
CONFIG_KPROBES=y" >> target/linux/rockchip/armv8/config-6.6
fi

# 优先清理 feeds 中的冲突旧包
rm -rf ./feeds/packages/net/{geoview,chinadns-ng,hysteria,mosdns,v2ray-geodata,lucky}
rm -rf ./feeds/packages/net/{shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev}
rm -rf ./feeds/packages/net/{sing-box,v2ray-geodata,v2ray-plugin,xray-core,smartdns}

rm -rf ./feeds/luci/applications/{luci-app-passwall,luci-app-passwall2,luci-app-openclash,luci-app-homeproxy}
rm -rf ./feeds/luci/applications/{luci-app-lucky,luci-app-smartdns,luci-app-timecontrol,luci-app-mosdns}
rm -rf ./feeds/luci/applications/{luci-app-nikki,luci-app-momo,luci-app-daed}

# 统一创建 package/small 保存第三方包，路径明确，绝对不用 pushd/popd
mkdir -p package/small
git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git package/pwpage

git clone -b master --depth 1 https://github.com/eamonxg/luci-theme-aurora.git package/small/luci-theme-aurora
git clone -b main --depth 1 https://github.com/sirpdboy/luci-app-timecontrol.git package/small/luci-app-timecontrol
git clone -b master --depth 1 https://github.com/immortalwrt/homeproxy.git package/small/homeproxy
git clone -b main --depth 1 https://github.com/gdy666/luci-app-lucky.git package/small/lucky
git clone -b master --depth 1 https://github.com/pymumu/luci-app-smartdns.git package/small/luci-app-smartdns
git clone -b master --depth 1 https://github.com/pymumu/smartdns.git package/small/smartdns

if [ -f "package/small/smartdns/package/openwrt/Makefile" ]; then
    sed -i 's@include ../../lang/rust/rust-package.mk@include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk@g' package/small/smartdns/package/openwrt/Makefile
fi

git clone -b main --depth 1 https://github.com/VIKINGYFY/packages.git package/small/vikingyfy-packages
git clone -b main --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall.git package/small/openwrt-passwall
git clone -b main --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall2.git package/small/openwrt-passwall2
git clone -b v5 --depth 1 https://github.com/sbwml/luci-app-mosdns.git package/small/luci-app-mosdns
git clone -b master --depth 1 https://github.com/sirpdboy/luci-app-netspeedtest.git package/small/luci-app-netspeedtest
git clone -b master --depth 1 https://github.com/vernesong/OpenClash.git package/small/OpenClash
git clone -b main --depth 1 https://github.com/nikkinikki-org/OpenWrt-nikki.git package/small/OpenWrt-nikki
git clone -b main --depth 1 https://github.com/nikkinikki-org/OpenWrt-momo.git package/small/OpenWrt-momo
git clone -b master --depth 1 https://github.com/QiuSimons/luci-app-daed.git package/small/luci-app-daed

# iStoreOS 专属及扩展包
git clone --depth=1 -b main https://github.com/xiaomeng9597/istoreos-settings package/default-settings
git clone --depth=1 https://github.com/sirpdboy/luci-app-eqosplus package/luci-app-eqosplus

# Golang 补丁逻辑，确保 Go 编译不报错
rm -rf feeds/packages/lang/golang
if git clone --depth=1 -b 1.25 https://github.com/kenzok8/golang feeds/packages/lang/golang; then
    echo "✅ golang 依赖环境更新完毕"
fi

GOTOOLCHAIN_HITS=$(grep -rlE 'GOTOOLCHAIN[[:space:]]*[:?]?=[[:space:]]*local' \
  --include="*.mk" --include="Makefile" \
  feeds package include tools toolchain 2>/dev/null || true)

if [ -n "${GOTOOLCHAIN_HITS}" ]; then
    echo "${GOTOOLCHAIN_HITS}" | while IFS= read -r f; do
        [ -z "$f" ] && continue
        sed -i -E 's/(GOTOOLCHAIN[[:space:]]*[:?]?=[[:space:]]*)local/\1auto/g' "$f"
    done
fi

if [ -n "${GITHUB_ENV:-}" ]; then
    {
        echo "GOTOOLCHAIN=auto"
        echo "GOFLAGS=-mod=mod"
        echo "GOPROXY=https://goproxy.cn,direct"
    } >> "$GITHUB_ENV"
fi

echo "✅ diy-part2 脚本顺利执行完成完毕!"
