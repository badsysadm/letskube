ARRAY_VLAN=(80 89 95 10)
IP_INTERNAL='199'

apt-get update > /dev/null && apt-get install -y ethtool net-tools tcpdump openvswitch-switch > /dev/null

function ADD_TO_SWITCH() {
  local interface=$1
  local vlans=("${@}")
#Определяем свитч
  local count=0
  for v in "${vlans[@]}"; do
   if [ $count -eq 0 ]; then
    local VLAN_RAW=`echo ${VLAN_RAW} $v`
    count=1
   else
    local VLAN_RAW=`echo ${VLAN_RAW} vlan$v`
   fi
  done
cat <<EOF > /etc/network/interfaces.d/ovs_bridge
allow-hotplug br1
auto br1

iface br1 inet manual
        ovs_type OVSBridge
        ovs_ports ${VLAN_RAW}
        mtu 1500
EOF
#Подключаем физический интерфейс в свитч
cat <<EOF > /etc/network/interfaces.d/ovs_${interface}
allow-hotplug ${interface}
auto ${interface}
allow-br1 ${interface}

iface ${interface} inet manual
        ovs_type OVSPort
        ovs_bridge br1
        mtu 1500
EOF
#Подключаем VLAN порты в свитч
}

function ADD_TO_VLAN() {
local vlan=$1
local ip=$2

#Маршруты для объединения VLAN'ов
if [ ${vlan} == 80 ]; then
  local ADD_ROUTE='post-up ip r a to 192.168.95.0/24 via 192.168.80.1 && ip r a to 192.168.90.0/24 via 192.168.80.1'
fi

cat <<EOF > /etc/network/interfaces.d/vlan${vlan}
allow-br1 vlan${vlan}
iface vlan${vlan} inet static
        address  192.168.${vlan}.${ip}
        netmask  255.255.255.0
        ovs_type OVSIntPort
        ovs_bridge br1
        ovs_options tag=${vlan}
        ovs_extra set interface \${IFACE} external-ids:iface-id=\$(hostname -s)-\${IFACE}-vif
        mtu 1500
        ${ADD_ROUTE}
EOF
}

IFACES=($(ip a | grep -G ^[0-9]*: | awk '{print $2}' | sed -s 's/://g' | grep -v 'lo' | grep -v 'vlan' | grep -v 'br' | grep -v 'ovs'))
printf '%s\n' "${IFACES[*]}"
for i in "${IFACES[@]}"; do
 ifconfig $i up
 echo "Current interface: "$i
 LINK=`ethtool $i | grep 'Link detected' | sed -s 's/^.*Link detected: //' | awk '{print $0}'`
 SPEED=`ethtool $i | grep -G 'Speed: [0-9]*Mb/s' | sed -s 's/^.*Speed: //' | awk '{print $0}'`
 if [ ${LINK} = "yes" ]; then
  echo "|__Link: "${LINK}
  echo "|__Speed: "${SPEED}
  if [ ${SPEED} = '10000Mb/s' ]; then
   ADD_TO_SWITCH $i "${ARRAY_VLAN[@]}"
   echo "|__Added to VLAN's:"
   for ii in "${ARRAY_VLAN[@]}"; do
    ADD_TO_VLAN $ii ${IP_INTERNAL}
    echo "|____Tag: "$ii
    echo "|____Ip: 192.168."$ii"."${IP_INTERNAL}
   done
  fi
  if [ $SPEED = '1000Mb/s' ]; then
   if cat /etc/network/interfaces | grep "auto ${i}" ; then
    echo "|__Already auto start interface"
   else
    echo "auto ${i}" >> /etc/network/interfaces
    echo "|__Enable auto start interface"
   fi
  fi
 else
  echo "|__Link: "${LINK}
 fi
done
echo "Restarting network service"
/etc/init.d/networking restart
echo "Done"
ovs-vsctl show
