#!/bin/sh
# DSA 模式下，接口名通常是 lan1, lan2, ... 等
# 我解释一下为什么这么做因为iStoreOS现阶段对于裕太微芯片不兼容，现在的dsa驱动下行没问题，下行满速，上行满速会造成交换机挂死，那样只能物理拔电源重启系统才能恢复了，限制上行速度也是没有办法的事情。

INTERFACES="lan1 lan2 lan3 lan4 lan5 lan6 lan7 lan8"

RATE="700mbit"
CEIL="800mbit"
BURST="32kb"

board_name() {
    [ -e /tmp/sysinfo/board_name ] && cat /tmp/sysinfo/board_name || echo "generic"
}

board=$(board_name)
if [ "$board" = "bdy,g98-nas" ]; then
    for IFACE in $INTERFACES; do

        if [ ! -d /sys/class/net/$IFACE ]; then
            echo "接口 $IFACE 不存在，跳过"
            continue
        fi

        echo "正在配置接口: $IFACE"

        tc qdisc del dev $IFACE root 2>/dev/null
        tc qdisc add dev $IFACE root handle 1: htb default 10
        tc class add dev $IFACE parent 1: classid 1:1 htb rate $CEIL ceil $CEIL
        tc class add dev $IFACE parent 1:1 classid 1:10 htb rate $RATE ceil $CEIL burst $BURST prio 0
    done
    echo "配置完成！"
fi
