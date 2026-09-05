#!/bin/sh

. /lib/functions.sh

NPROCS="$(grep -c "^processor.*:" /proc/cpuinfo)"
PROC_MASK="$(( (1 << $NPROCS) - 1 ))"
PROC_MASK="$(printf %x "$PROC_MASK")"

rename_iface() {
	ip link set $1 down && ip link set $1 name $2
}

get_iface_device() {
	basename $(readlink /sys/class/net/$1/device)
}

set_iface_cpumask() {
	local core_mask="$1"
	local interface="$2"
	local device="$3"
	local irq
	local seconds
	local queue_mask="$4"

	if [[ -z "$queue_mask" ]]; then
		queue_mask=$(( 0x${PROC_MASK} ^ 0x${core_mask} ))
		queue_mask="$(printf %x "$queue_mask")"
	fi

	[[ -d "/sys/class/net/${interface}" ]] || return 1
	[[ -n "${device}" && "${device}" = "${interface}-*" ]] && ip link set dev "${interface}" up
	[[ -z "${device}" ]] && device="$interface"

	for seconds in $(seq 0 1); do
		[[ ${seconds} = 0 ]] || sleep 1
		irq=$(grep -Em1 " ${device}\$" /proc/interrupts | sed -n -e 's/^ *\([^ :]\+\):.*$/\1/p')
		if [[ -n "${irq}" ]]; then
			echo "${core_mask}" > /proc/irq/${irq}/smp_affinity
			echo "${queue_mask}" > /sys/class/net/$interface/queues/rx-0/rps_cpus
			return 0
		fi
	done
	return 1
}

board_fixup_iface_name() {
	local device
	case $(board_name) in
	hinlink,opc-h68k)
		device="$(get_iface_device eth1)"
		if [[ "$device" = "fe010000.ethernet" ]]; then
			rename_iface eth0 wan
			rename_iface eth1 eth0
			rename_iface wan eth1
		fi
		device="$(get_iface_device eth3)"
		if [[ "$device" = "0001:*1:00.0" ]]; then
			rename_iface eth2 lan3
			rename_iface eth3 eth2
			rename_iface lan3 eth3
		fi
		;;
	esac
}

board_set_iface_smp_affinity() {
	case $(board_name) in
	hinlink,opc-h68k)
		set_iface_cpumask 3 "eth0" "" c
		set_iface_cpumask 3 "eth1" "" c
		if ethtool -i eth2 | grep -Fq 'driver: r8169'; then
			set_iface_cpumask 2 "eth2"
			set_iface_cpumask 1 "eth3"
		else
			set_iface_cpumask 2 "eth2" "eth2-0" && \
			set_iface_cpumask 2 "eth2" "eth2-16" && \
			set_iface_cpumask 4 "eth2" "eth2-18"
			set_iface_cpumask 1 "eth3" "eth3-0" && \
			set_iface_cpumask 1 "eth3" "eth3-18" && \
			set_iface_cpumask 8 "eth3" "eth3-16"
		fi
		;;
	esac
}

board_wait_wifi() {
	local seconds
	[[ -f "/etc/uci-defaults/01-rk35xx-wifi" ]] || return 0
	case $(board_name) in
	hinlink,opc-h68k)
		for seconds in $(seq 0 30); do
			[[ -s /etc/config/wireless ]] && break
			sleep 1
		done
		sleep 1
		;;
	esac
}

board_fixup_iface_name
board_set_iface_smp_affinity
board_wait_wifi
