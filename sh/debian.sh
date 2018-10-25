HOSTNAME='badsysadm'
BOOTSTRAP_LINK='http://ftp.us.debian.org/debian'
BOOTSTRAP_DEB='http://ftp.debian.org/debian/pool/main/d/debootstrap/debootstrap_1.0.67+deb8u1_all.deb'
VG_NAME='vg0'
BOOT_SIZE='200M'
SWAP_SIZE=`free -m | awk 'match($1, /[Mm]em/) {print $2}'`
DISKS=($(fdisk -l | awk 'match($2, /\/dev\/sd./ ) {print substr($2, RSTART, RLENGTH)}'))

apt update -y && apt install -y lvm2 binutils wget

mount -l | awk '/'${VG_NAME}'-root/ {next}  /\/dev\/mapper\/vg/ {print $1}' | xargs umount
umount /dev/mapper/${VG_NAME}-root
dd if=/dev/zero of=/dev/${VG_NAME}/boot bs=1M count=1
dd if=/dev/zero of=/dev/${VG_NAME}/root bs=1M count=1
dd if=/dev/zero of=/dev/${VG_NAME}/swap bs=1M count=1
rm -rfv /mnt/debootstrap
swapoff -a


lvdisplay | awk '/LV Path/ {print $3}' | xargs lvremove -vf
vgs | awk 'match($0, /vg.[ ]*[0-9]+[ ]*[0-9]+/) {print $1}' | xargs vgremove
pvs | awk 'match($0, /\/dev\/sd.[0-1]+/) {print $1}' | xargs pvremove
lvdisplay

vg_string=''
for disk in ${DISKS[@]}; do
  vg_string=$vg_string' '$disk'1'
  parted $disk -s mklabel msdos
  parted $disk -s unit mib mkpart primary 1 100%
  pvcreate $disk'1'
done
vgcreate ${VG_NAME} ${vg_string}
lvcreate -L ${BOOT_SIZE} ${VG_NAME} -n boot
lvcreate -L ${SWAP_SIZE} ${VG_NAME} -n swap
lvcreate -l 100%FREE ${VG_NAME} -n root
mkfs.ext2 /dev/${VG_NAME}/boot
mkfs.ext4 /dev/${VG_NAME}/root
mkswap /dev/${VG_NAME}/swap
sync
swapon /dev/${VG_NAME}/swap

mkdir -p /mnt/debootstrap
mount /dev/${VG_NAME}/root /mnt/debootstrap
mkdir -p /mnt/debootstrap/boot
mount /dev/${VG_NAME}/boot /mnt/debootstrap/boot
wget ${BOOTSTRAP_DEB} -O /tmp/bootstrap.deb
dpkg -i /tmp/bootstrap.deb
debootstrap --arch amd64 stretch /mnt/${HOSTNAME} ${BOOTSTRAP_LINK}
cp debootstrap.sh /mnt/badsysadm/debootstrap.sh
LANG=C.UTF-8 chroot /mnt/debootstrap bash debootstrap.sh ${HOSTNAME}
