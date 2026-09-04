#!/bin/bash
#===============================================
# Description: DIY script
# File name: diy-script.sh
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#===============================================

# 修改 uhttpd 配置文件，启用 nginx 端口避让
sed -i "s/:80/:81/g" package/network/services/uhttpd/files/uhttpd.config
sed -i "s/:443/:4443/g" package/network/services/uhttpd/files/uhttpd.config

# 安全复制自定义文件（避免目录不存在时中断编译）
if [ -d "$GITHUB_WORKSPACE/configfiles" ]; then
    [ -d "$GITHUB_WORKSPACE/configfiles/etc" ] && cp -a $GITHUB_WORKSPACE/configfiles/etc/* package/base-files/files/etc/
    if [ -f "$GITHUB_WORKSPACE/configfiles/coremark/coremark-arm64" ]; then
        cp -f $GITHUB_WORKSPACE/configfiles/coremark/coremark-arm64 package/base-files/files/bin/coremark-arm64
        cp -f $GITHUB_WORKSPACE/configfiles/coremark/coremark-arm64.sh package/base-files/files/bin/coremark.sh
        chmod 755 package/base-files/files/bin/coremark-arm64
        chmod 755 package/base-files/files/bin/coremark.sh
    fi
else
    echo "⚠️ 警告：未找到 $GITHUB_WORKSPACE/configfiles 目录，跳过自定义配置文件复制"
fi

# 追加自定义内核配置项
echo "CONFIG_PSI=y
CONFIG_KPROBES=y" >> target/linux/rockchip/armv8/config-6.6

# 删除 feeds 中的重复/冲突插件
rm -rf ./feeds/packages/net/{geoview,chinadns-ng,hysteria,mosdns,v2ray-geodata,lucky}
rm -rf ./feeds/packages/net/{shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev}
rm -rf ./feeds/packages/net/{sing-box,v2ray-geodata,v2ray-plugin,xray-core,smartdns}

rm -rf ./feeds/luci/applications/{luci-app-passwall,luci-app-passwall2,luci-app-openclash,luci-app-homeproxy}
rm -rf ./feeds/luci/applications/{luci-app-lucky,luci-app-smartdns,luci-app-timecontrol,luci-app-mosdns}
rm -rf ./feeds/luci/applications/{luci-app-nikki,luci-app-momo,luci-app-daed}

# 克隆依赖插件到 package/pwpage
git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git package/pwpage

# 创建自定义插件存放目录
mkdir -p package/small

# 克隆自定义插件（直接指定目标路径，避免 pushd/popd 导致目录错乱）
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

echo "packages executed successfully!"

# iStoreOS-settings
git clone --depth=1 -b main https://github.com/xiaomeng9597/istoreos-settings package/default-settings

# 定时限速插件
git clone --depth=1 https://github.com/sirpdboy/luci-app-eqosplus package/luci-app-eqosplus

# ============================================================
# 修复 geoview 等 go 包因宿主 go 工具链版本过低导致的编译失败
# ============================================================

echo
echo "========================================"
echo "升级 golang feed 到 kenzok8/golang (1.25 分支)..."
echo "========================================"

rm -rf feeds/packages/lang/golang
if git clone --depth=1 -b 1.25 https://github.com/kenzok8/golang feeds/packages/lang/golang; then
    echo "✅ golang feed 已替换为 kenzok8/golang 1.25 分支"
else
    echo "⚠️ kenzok8/golang 1.25 分支克隆失败，回退到 GOTOOLCHAIN=auto 兜底方案"
fi

echo "==> 搜索仍然硬编码 GOTOOLCHAIN=local 的位置作为兜底..."
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

if [ -n "${GITHUB_ENV:-}" ]; then
    {
        echo "GOTOOLCHAIN=auto"
        echo "GOFLAGS=-mod=mod"
        echo "GOPROXY=https://goproxy.cn,direct"
    } >> "$GITHUB_ENV"
    echo "    已写入 GOTOOLCHAIN=auto / GOPROXY 镜像加速到 \$GITHUB_ENV（兜底用）"
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
