#!/bin/bash
# Laeuft in einer Helfer-VM (Debian 13) als root. Eingabe: /var/tmp/orig.qcow2 (offizielles Debian-Cloud-Image)
# Ausgabe: /var/tmp/debian-btrfs.qcow2  (Root = btrfs, gleiche UUID/PARTUUID, Bootloader unveraendert)
set -eux
cd /var/tmp
apt-get install -y -qq qemu-utils rsync btrfs-progs >/dev/null
rm -f base.raw; qemu-img convert -O raw orig.qcow2 base.raw
LOOP=$(losetup -fP --show base.raw); P1=${LOOP}p1; P15=${LOOP}p15
UUID=$(blkid -o value -s UUID $P1)
mkdir -p /mnt/old /mnt/new stage
mount $P1 /mnt/old; rsync -aAXH --numeric-ids /mnt/old/ stage/; umount /mnt/old
mkfs.btrfs -f -L root -U "$UUID" $P1
mount -o compress=zstd:3,noatime $P1 /mnt/new
rsync -aAXH --numeric-ids stage/ /mnt/new/
mount $P15 /mnt/new/boot/efi
sed -i 's#^\(PARTUUID=[^ ]*\) / ext4 .*#\1 / btrfs compress=zstd:3,noatime,discard=async 0 0#' /mnt/new/etc/fstab
cat /mnt/new/etc/fstab
for d in dev proc sys run; do mount --rbind /$d /mnt/new/$d; mount --make-rslave /mnt/new/$d; done
chroot /mnt/new bash -c 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq btrfs-progs && apt-get clean && rm -rf /var/lib/apt/lists/* && update-initramfs -u -k all'
lsinitramfs /mnt/new/boot/initrd.img-* | grep -E 'btrfs|crc32c|xor|raid6' | head
for d in dev proc sys run; do umount -R /mnt/new/$d; done
umount /mnt/new/boot/efi; umount /mnt/new
losetup -d $LOOP
rm -rf stage
qemu-img convert -c -O qcow2 base.raw debian-btrfs.qcow2
ls -la debian-btrfs.qcow2
