set -e

set -u

# hat-tips:
# - http://codeghar.wordpress.com/2011/12/14/automated-customized-debian-installation-using-preseed/
# - the gist

# required packages (apt-get install)
# xorriso
# syslinux

ISOFILE=debian-netinst.iso
ISOFILE_FINAL=debian-netinst-mod.iso
ISODIR=debian-iso
ISODIR_WRITE=$ISODIR-rw

# download ISO:
# wget -nc -O $ISOFILE http://cdimage.debian.org/cdimage/wheezy_di_rc3/amd64/iso-cd/debian-wheezy-DI-rc3-amd64-netinst.iso || true
#wget -nc -O $ISOFILE https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/current/amd64/iso-cd/firmware-9.5.0-amd64-netinst.iso || true
#wget -nc -O $ISOFILE https://cdimage.debian.org/cdimage/release/current/amd64/iso-cd/debian-9.5.0-amd64-netinst.iso || true
wget -nc -O $ISOFILE https://cdimage.debian.org/cdimage/release/current/amd64/iso-cd/debian-10.3.0-amd64-netinst.iso || true

echo 'mounting ISO9660 filesystem...'
# source: http://wiki.debian.org/DebianInstaller/ed/EditIso
[ -d $ISODIR ] || mkdir -p $ISODIR
ls -lah
mount -o loop $ISOFILE $ISODIR

echo 'coping to writable dir...'
rm -rf $ISODIR_WRITE || true
[ -d $ISODIR_WRITE ] || mkdir -p $ISODIR_WRITE
rsync -a -H --exclude=TRANS.TBL $ISODIR/ $ISODIR_WRITE

echo 'unmount iso dir'
umount $ISODIR

echo 'correcting permissions...'
chmod 755 -R $ISODIR_WRITE

echo 'copying preseed file...'
cp -v preseed.final $ISODIR_WRITE/preseed.cfg
mkdir -p $ISODIR_WRITE/extra 
cp -v roles.sh $ISODIR_WRITE/extra
chmod 760 $ISODIR_WRITE/extra/roles.sh

echo 'edit isolinux/txt.cfg...'
sed 's/initrd.gz/initrd.gz file=\/cdrom\/preseed.cfg/' -i $ISODIR_WRITE/isolinux/txt.cfg

mkdir irmod
cd irmod
gzip -d < ../$ISODIR_WRITE/install.amd/initrd.gz | \
cpio --extract --make-directories --no-absolute-filenames
cp ../preseed.final preseed.cfg
chown root:root preseed.cfg
chmod o+w ../$ISODIR_WRITE/install.amd/initrd.gz
find . | cpio -H newc --create | \
        gzip -9 > ../$ISODIR_WRITE/install.amd/initrd.gz
chmod o-w ../$ISODIR_WRITE/install.amd/initrd.gz
cd ../
rm -fr irmod/

echo 'fixing MD5 checksums...'
pushd $ISODIR_WRITE
  md5sum $(find -type f) > md5sum.txt
popd

echo 'making ISO...'
# genisoimage -o $ISOFILE_FINAL \
#   -r -J -no-emul-boot -boot-load-size 4 \
#   -boot-info-table \
#   -b isolinux/isolinux.bin \
#   -c isolinux/boot.cat ./$ISODIR_WRITE

dd if=$ISOFILE bs=512 count=1 of=isohdpfx.bin
echo 'making hybrid ISO...'
xorriso -as mkisofs \
  -r -J -V "jessie" \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot \
  -partition_offset 16 \
  -boot-load-size 4 \
  -boot-info-table \
  -isohybrid-mbr "isohdpfx.bin" \
  -o /iso/$ISOFILE_FINAL \
  ./$ISODIR_WRITE

#ls -lah /iso | grep $ISOFILE_FINAL

# and if that doesn't work:
# http://askubuntu.com/questions/6684/preseeding-ubuntu-server
