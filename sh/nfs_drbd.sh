IS_PRIMARY='yes'
LV_NAME='NFS'
LV_GROUP='vg0'
DRBD_NAME='drbd_'${LV_NAME}
DRBD_FPORT='17220'
NFS_HOST01='cs44762'
NFS_HOST02='cs44753'
VLAN='10'
ARRAY_VOL=('27|10M' '28|10M')

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

192.168.10.199  ${NFS_HOST01}
192.168.10.198  ${NFS_HOST02}
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
3 md5 somerandomstring1
EOF

chmod 600 /etc/heartbeat/authkeys

echo "Configuring drbd ports started from ${DRBD_FPORT}"
DRBD_PORT=$((${DRBD_FPORT}+1))
for cvol in "${ARRAY_VOL[@]}"; do
  ITERATION=`echo $cvol | sed -s 's/|.*$//g'`
  SIZE=`echo $cvol | sed -s 's/^.*|//g'`
  echo "|_Create volume ${LV_NAME}${ITERATION}"
  lvcreate -L ${SIZE} -n ${LV_NAME}${ITERATION} ${LV_GROUP}
  echo "|_Created LV volume ${LV_NAME}${ITERATION} with size ${SIZE} on ${LV_GROUP}"

  DRBD_PORT=$((${DRBD_PORT}+1))
  echo "|__DRBD_PORT is ${DRBD_PORT}"

  echo "cs44762  IPaddr::192.168.80.197/24/${NET_CONN} drbddisk::${DRBD_NAME}${ITERATION} Filesystem::/dev/${LV_GROUP}/${LV_NAME}${ITERATION}::/data/${LV_NAME}${ITERATION}/::ext4 nfs-kernel-server" >> /etc/heartbeat/haresources
  echo "|__Added heartbeat endpoint"
  echo "|___cs44762  IPaddr::192.168.80.197/24/${NET_CONN} drbddisk::${DRBD_NAME}${ITERATION} Filesystem::/dev/${LV_GROUP}/${LV_NAME}${ITERATION}::/data/${LV_NAME}${ITERATION}/::ext4 nfs-kernel-server"

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
    address 192.168.${VLAN}.199:${DRBD_PORT};
  }
  on ${NFS_HOST02} {
    address 192.168.${VLAN}.198:${DRBD_PORT};
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
