HOSTNAME=$1
VG_NAME='vg0'

export TERM=xterm-color
apt-get update && apt-get install -y makedev lvm2 mc apt-transport-https ca-certificates curl gnupg2 software-properties-common \
sudo make gcc git iptraf openssl wget psmisc net-tools python python3 python-pip python3-pip bash-completion jq qemu-guest-agent \
ethtool locales linux-image-amd64
mount none /proc -t proc
cd /dev
MAKEDEV generic
vgmknodes
cat <<EOF> /etc/fstab
/dev/mapper/${VG_NAME}-root / ext4 errors=remount-ro 0 1
/dev/mapper/${VG_NAME}-boot /boot ext2 defaults 0 2
/dev/mapper/${VG_NAME}-root / ext4 defaults 0 2
/dev/mapper/${VG_NAME}-swap none swap sw 0 0
EOF
mount -a
cat <<EOF> /etc/adjtime
0.0 0 0.0
0
UTC
EOF

NETWORK_INTERFACE=`ip -f link -4 -o link | awk '/lo/ {next} match ($2, /[a-z0-9]+/) {print substr($2, RSTART, RLENGTH)}'`
cat <<EOF> /etc/network/interfaces
auto lo
iface lo inet loopback

auto ${NETWORK_INTERFACE}
allow-hotplug ${NETWORK_INTERFACE}
iface ${NETWORK_INTERFACE} inet dhcp
EOF

cat <<EOF> /etc/resolv.conf
nameserver 192.168.80.254
nameserver 192.168.80.253
EOF
cat <<EOF> /etc/hostname
${HOSTNAME}
EOF
cat <<EOF> /etc/hosts
127.0.0.1 localhost
127.0.1.1 ${HOSTNAME}
EOF
cat <<EOF>> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sysctl -p
cat <<EOF>> /etc/apt/sources.list
deb-src http://ftp.us.debian.org/debian stretch main non-free contrib
deb http://security.debian.org/ stretch/updates main
deb-src http://security.debian.org/ stretch/updates main
EOF
echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-get
export DEBIAN_FRONTEND=noninteractive
apt-get install -y grub-pc
grub-install /dev/sda
update-grub
