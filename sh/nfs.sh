apt-get update && apt-get upgrade -y
apt-get install -y ntp ntpdate nfs-kernel-server
apt autoremove -y
update-rc.d -f nfs-kernel-server remove
update-rc.d -f nfs-common remove
systemctl disable nfs-kernel-server
systemctl disable nfs-common

cat > /etc/exports <<EOF
/data/export/ 192.168.0.0/255.255.255.0(rw,no_root_squash,no_all_squash,sync)
EOF

apt-get install kernel-headers-2.6.8-2-386 drbd0.7-module-source drbd0.7-utils
cd /usr/src/
tar xvfz drbd0.7.tar.gz
cd modules/drbd/drbd
make
make install

cat > /etc/drbd.conf <<EOF
resource r0 {
 protocol C;
 incon-degr-cmd "halt -f";
 startup {
    degr-wfc-timeout 120;    # 2 minutes.
  }
  disk {
    on-io-error   detach;
  }
  net {

  }
  syncer {
    rate 10M;
    group 1;
    al-extents 257;
  }

 on server1 {                # ** EDIT ** the hostname of server 1 (uname -n)
   device     /dev/drbd0;        #
   disk       /dev/sda8;         # ** EDIT ** data partition on server 1
   address    192.168.0.172:7788; # ** EDIT ** IP address on server 1
   meta-disk  /dev/sda7[0];      # ** EDIT ** 128MB partition for DRBD on server 1
  }

 on server2 {                # ** EDIT ** the hostname of server 2 (uname -n)
   device    /dev/drbd0;         #
   disk      /dev/sda8;          # ** EDIT ** data partition on server 2
   address   192.168.0.173:7788;  # ** EDIT ** IP address on server 2
   meta-disk /dev/sda7[0];       # ** EDIT ** 128MB partition for DRBD on server 2
  }

}
EOF

modprobe drbd
drbdadm up all
cat /proc/drbd

#SERVER1
drbdadm -- --do-what-I-say primary all
drbdadm -- connect all
cat /proc/drbd
while true; do
  if grep -q finish /proc/drbd; then
    echo "Sync is going"
    sleep 2
  else
    echo "Sync ready"
    break
  fi
done

mkdir /data
mount -t ext3 /dev/drbd0 /data
mv /var/lib/nfs/ /data/
ln -s /data/nfs/ /var/lib/nfs
mkdir /data/export
umount /data

#SERVER2
rm -fr /var/lib/nfs/
ln -s /data/nfs/ /var/lib/nfs

#Heartbeat
apt-get install heartbeat -y

cat > /etc/heartbeat/ha.cf << EOF
logfacility     local0
keepalive 2
#deadtime 30 # USE THIS!!!
deadtime 10
bcast   eth0
node server1 server2
EOF

cat > /etc/heartbeat/haresources << EOF
server1  IPaddr::192.168.0.174/24/eth0 drbddisk::r0 Filesystem::/dev/drbd0::/data::ext3 nfs-kernel-server
EOF

cat > /etc/heartbeat/authkeys << EOF
auth 3
3 md5 somerandomstring
EOF

chmod 600 /etc/heartbeat/authkeys
/etc/init.d/drbd start
/etc/init.d/heartbeat start

ifconfig
df -h
touch /data/export/test1
ls -l /data/export

#NFS Common
apt-get install nfs-common -y
mkdir /data
mount 192.168.0.174:/data/export /data
echo "192.168.0.174:/data/export  /data    nfs          rw            0    0" >> /etc/fstab

