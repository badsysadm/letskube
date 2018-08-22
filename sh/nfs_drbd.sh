IS_PRIMARY='no'
ARRAY_VOL=('NFS|100G')
LV_GROUP='vg0'

if [ ${IS_PRIMARY} == 'true' ] || [ ${IS_PRIMARY} == 'yes' ] || [ ${IS_PRIMARY} == '1' ]; then
  NFS_HOST01='cs44762'
  NFS_HOST02='cs44753'
  VLAN='10'
  WVLAN='80'
  IP1='199'
  IP2='198'
  VIP='197'
  echo 'Master node: '${NFS_HOST01}' on 192.168.'${WVLAN}.${IP1}' with virtual ip:'${VIP}
else
  NFS_HOST01='cs44753'
  NFS_HOST02='cs44762'
  VLAN='10'
  WVLAN='80'
  IP1='198'
  IP2='199'
  VIP='197'
  echo 'Slave node: '${NFS_HOST01}' on 192.168.'${WVLAN}.${IP1}' with virtual ip:'${VIP}
fi

arr_check=(192.168.$WVLAN.$IP1 192.168.$WVLAN.$IP2 192.168.$WVLAN.$VIP)
for HOST in "${arr_check[@]}"; do
  ping -c1 $HOST 1>/dev/null 2>/dev/null
  SUCCESS=$?

  if [ $SUCCESS -eq 0 ]
  then
    echo "$HOST already exist"
    echo "abort"
    exit 1
  else
    echo "$HOST didn't reply"
    echo "Accept "$HOST
  fi

done
  
echo "Start deploy on host (${NFS_HOST01}; ${NFS_HOST02})"
echo "Update by apt-get"
apt-get update > /dev/null && apt-get upgrade -y > /dev/null

echo "Install NFS-server"
apt-get install -y ntp ntpdate nfs-kernel-server > /dev/null
systemctl stop nfs-kernel-server
systemctl stop nfs-common
update-rc.d -f nfs-kernel-server remove
update-rc.d -f nfs-common remove
systemctl disable nfs-kernel-server
systemctl disable nfs-common

echo "Configuring HOSTS file"

cat > /etc/hosts <<EOF
127.0.0.1       localhost

::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

192.168.${VLAN}.${IP1}  ${NFS_HOST01}
192.168.${VLAN}.${IP2}  ${NFS_HOST02}
EOF

###DRBD

echo "Install DRBD and HEARBEAT"

apt-get install -y drbd8-utils heartbeat > /dev/null
modprobe drbd

echo "Get 10Gb interface for cluster"

IFACES=($(ip a | grep -G ^[0-9]*: | awk '{print $2}' | sed -s 's/://g' | grep -v 'lo' | grep -v 'vlan' | grep -v 'br' | grep -v 'ovs' ))
for i in "${IFACES[@]}"; do
 LINK=`ethtool $i | grep 'Link detected' | sed -s 's/^.*Link detected: //' | awk '{print $0}'`
 GGB=`ethtool $i | grep -G 'Speed: [0-9]*Mb/s' | sed -s 's/^.*Speed: //' | awk '{print $0}'`
 if [ $LINK = "yes" ]; then
  if [ $GGB = '10000Mb/s' ]; then
   NET_CONN=$i
   echo "|__10Gb interfase is: "$NET_CONN
  else
   WNET_CONN=$i
   echo "|__1Gb interfase is: "$WNET_CONN
  fi
 fi
done

echo "Configuring heartbeat ha.cf config file"

cat > /etc/heartbeat/ha.cf << EOF
logfacility     local0
keepalive 2
deadtime 30
warntime 5
deadtime 15
initdead 60
bcast ${WNET_CONN}
node ${NFS_HOST01} ${NFS_HOST02}
EOF
echo "|__broadast by ${WNET_CONN} 1Gb interface"

echo "Configuring heartbeat authkeys config file"

cat > /etc/heartbeat/authkeys << EOF
auth 3
3 md5 iMbbqSkMf4y2dctD1xlnweYO
EOF
chmod 600 /etc/heartbeat/authkeys

ITERATION=1
for cvol in "${ARRAY_VOL[@]}"; do
  LV_NAME=`echo $cvol | sed -s 's/|.*$//g'`
  DRBD_NAME='drbd_'${LV_NAME}
  CUR_I=`lvdisplay | grep 'LV Name' | awk '{print $3}' | grep 'NFS' | sed -s 's/^[A-Z a-z]*//g' | sort -nr | head -n1`
  if [ ${ITERATION} -le ${CUR_I} ]; then
    ITERATION=$((CUR_I + 1))
  else
    ITERATION=$((ITERATION + 1))
  fi

  SIZE=`echo $cvol | sed -s 's/^.*|//g'`
  echo "|_Create volume ${LV_NAME}${ITERATION}"
  lvcreate -L ${SIZE} -n ${LV_NAME}${ITERATION} ${LV_GROUP}
  echo "|_Created LV volume ${LV_NAME}${ITERATION} with size ${SIZE} on ${LV_GROUP}"


  DRBD_PORT=$((ITERATION + 17200))
  echo "|__DRBD_PORT is ${DRBD_PORT}"

  echo "|__Add heartbeat endpoint"
  echo "|___cs44762  IPaddr::192.168.${WVLAN}.${VIP}/24/vlan${WVLAN} drbddisk::${DRBD_NAME}${ITERATION} Filesystem::/dev/drbd${ITERATION}::/data/${LV_NAME}${ITERATION}/::ext4 nfs-kernel-server"
  echo "cs44762  IPaddr::192.168.${WVLAN}.${VIP}/24/vlan${WVLAN} drbddisk::${DRBD_NAME}${ITERATION} Filesystem::/dev/drbd${ITERATION}::/data/${LV_NAME}${ITERATION}/::ext4 nfs-kernel-server" >> /etc/heartbeat/haresources
  
  echo "|__Configuring drbd resourse file ${DRBD_NAME}${ITERATION}.res"
  cat <<EOF > /etc/drbd.d/${DRBD_NAME}${ITERATION}.res
resource ${DRBD_NAME}${ITERATION} {
  meta-disk internal;
  device /dev/drbd${ITERATION};
  disk /dev/${LV_GROUP}/${LV_NAME}${ITERATION};
  syncer {
    verify-alg sha1;
  }
  net {
  }
  on ${NFS_HOST01} {
    address 192.168.${VLAN}.${IP1}:${DRBD_PORT};
  }
  on ${NFS_HOST02} {
    address 192.168.${VLAN}.${IP2}:${DRBD_PORT};
  }
}
EOF

  echo "|__Perform dd on new LVM VOLUME"
  dd if=/dev/zero of=/dev/${LV_GROUP}/${LV_NAME}${ITERATION} bs=1M count=1
  echo "|__Create and start ${DRBD_NAME}${ITERATION}"
  drbdadm create-md ${DRBD_NAME}${ITERATION}
  drbdadm up ${DRBD_NAME}${ITERATION}

  echo "|__Create catalog /data/${LV_NAME}${ITERATION}"
  mkdir -p /data/${LV_NAME}${ITERATION}
  echo "/data/${LV_NAME}${ITERATION}/ 192.168.0.0/255.255.0.0(rw,no_root_squash,no_all_squash,sync)" >> /etc/exports
  echo "/data/${LV_NAME}${ITERATION}/ 192.168.0.0/255.255.0.0(rw,no_root_squash,no_all_squash,sync)"

  if [ "${IS_PRIMARY}" == "yes" ]; then
    echo "This is MASTER!"

	/etc/init.d/drbd restart
	/etc/init.d/heartbeat restart
	drbdadm -- --overwrite-data-of-peer primary ${DRBD_NAME}${ITERATION}

	echo "Make EXT4 file system"
	mkfs.ext4 /dev/drbd${ITERATION}
	echo "Mount /dev/drbd${ITERATION} device to /data/${LV_NAME}${ITERATION}/"
	mount /dev/drbd${ITERATION} /data/${LV_NAME}${ITERATION}/
  fi
  unset ITERATION
  unset SIZE
done
cat /proc/drbd
