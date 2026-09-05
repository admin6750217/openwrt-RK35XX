#!/bin/bash
#===============================================
# Description: DIY script
# File name: diy-script.sh
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#===============================================

cp -a $GITHUB_WORKSPACE/configfiles/etc/* package/base-files/files/etc/
git clone --depth=1 -b main https://github.com/xiaomeng9597/istoreos-settings package/default-settings
git clone --depth=1 https://github.com/sirpdboy/luci-app-eqosplus package/luci-app-eqosplus
cp -f $GITHUB_WORKSPACE/configfiles/init.sh target/linux/rockchip/armv8/base-files/lib/board/init.sh
cp -f $GITHUB_WORKSPACE/configfiles/02_network target/linux/rockchip/armv8/base-files/etc/board.d/02_network
cp -f $GITHUB_WORKSPACE/configfiles/01_leds target/linux/rockchip/armv8/base-files/etc/board.d/01_leds
