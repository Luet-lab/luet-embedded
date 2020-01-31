#!/bin/bash
# Author: mudler mudler@sabayon.org
# Based off from https://www.kali.org/docs/development/custom-raspberry-pi-image/
set -ex

mkdir workdir || true
pushd workdir

IMAGE_NAME="${IMAGE_NAME:-luet_os.img}"
LUET_PACKAGES="${LUET_PACKAGES:-}"
LUET_BIN="${LUET_BIN:-../luet}"
LUET_CONFIG="${LUET_CONFIG:-../conf/luet.yaml}"

dd if=/dev/zero of="${IMAGE_NAME}" bs=1MB count=7000

parted "${IMAGE_NAME}" --script -- mklabel msdos
parted "${IMAGE_NAME}" --script -- mkpart primary fat32 0 64
parted "${IMAGE_NAME}" --script -- mkpart primary ext4 64 -1

loopdevice=`losetup -f --show "${IMAGE_NAME}"`
device=`kpartx -va $loopdevice| sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`
device="/dev/mapper/${device}"
bootp=${device}p1
rootp=${device}p2


mkfs.vfat $bootp
mkfs.ext4 $rootp
mkdir -p root
mount $rootp root

### Chrooting

pushd root
mkdir -p boot
mount $bootp boot

mkdir -p var/lock
mkdir -p var/cache/luet
mkdir -p etc/luet
mkdir -p dev
mkdir -p sys
mkdir -p proc
mkdir -p tmp
mkdir -p dev/pts
cp -rfv "${LUET_CONFIG}" etc/luet/.luet.yaml
cp -rfv "${LUET_BIN}" luet
sudo mount --bind /dev dev/
sudo mount --bind /sys sys/
sudo mount --bind /proc proc/
sudo mount --bind /dev/pts dev/pts

sudo chroot . /luet install $LUET_PACKAGES

# Cleanup/umount
sudo rm -rf luet
sudo umount dev/pts
sudo umount dev
sudo umount proc
sudo umount sys
rm -rfv tmp/*
popd

ls -liah root/

umount $bootp
umount $rootp
kpartx -dv $loopdevice
losetup -d $loopdevice

sync

echo "$IMAGE_NAME ready!"

