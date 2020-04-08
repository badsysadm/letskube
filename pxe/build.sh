rm -rfv /mnt/iso/debian-netinst-mod.iso
docker build . | grep "Successfully built" | awk '{print $3}' | xargs docker run --privileged -v /mnt/iso:/iso
#ssh root@pve-app02a.infra.cognita.ru rm -rfv /var/lib/iso/template/iso/debian-netinst-mod.iso
#scp /mnt/iso/debian-netinst-mod.iso root@pve-app02a.infra.cognita.ru:/var/lib/iso/template/iso
