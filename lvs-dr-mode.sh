#!/bin/bash

sysconf="/etc/sysctl.conf"
netconf="/etc/sysconfig/network-scripts/ifcfg-"


_add_sub_iface() {
    vmask=${vip/*\//}
    if [ "$vip" = "$vmask" ];then
        vmask="NETMASK=255.255.255.255"
    else
        vmask="PREFIX=$vmask"
    fi
    [ "${vif/:*/}" = lo ] && viface=loopback || viface=${vif/:*/}
    cat > ${netconf}$vif <<EOF
DEVICE=$vif
IPADDR=$vip
$vmask
ONBOOT=yes
NAME=$viface
EOF
    systemctl restart network
}

_add_sysctl_rules() {
    conf=$sysconf
    for i in ${vif/:*/} all; do
        grep -q "${i}.arp_ignore" $conf && \
              sed -i "s,\(${i}\.arp_ignore=\).*,\1${1:-1}," $conf || \
              echo "net.ipv4.conf.${i}.arp_ignore=${1:-1}" >> $conf
        grep -q "${i}.arp_announce" $conf && \
              sed -i "s,\(${i}\.arp_announce=\).*,\1${1:-2}," $conf || \
              echo "net.ipv4.conf.${i}.arp_announce=${1:-2}" >> $conf
    done
    sysctl -p &>/dev/null
}

for i in `seq 5`; do
case $1 in 
    -vip=*)
        vip=${1/-vip=/}
        shift 1
        ;;
    -vif=*)
        vif=${1/-vif=/}
        shift 1
        ;;
    start)
        vif=${vif:-lo:0}
        _add_sub_iface
        _add_sysctl_rules
        echo "此节点的LVS-DR配置已完成."
        exit 0
        ;;
    stop)
        vif=${vif:-lo:0}
        vmask="/${vip/*\//}"
        [ "$vmask" = "/$vip" ] && vmask="/32"
        ip addr del dev $vif ${vip}${vmask}
        rm -f $netconf$vif
        _add_sysctl_rules 0
        echo "此节点的LVS-DR配置已删除."
        exit 0
        ;;
    *)
        echo "Usage: $0 [-vip=<Virutal IP> | [-vif=<Virutal Interface|default:lo:0> ]|start |stop]"
        exit 0
        ;;
esac
done
