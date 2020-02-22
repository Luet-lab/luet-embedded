#!/bin/bash

# https://github.com/Tomas-M/linux-live.git
# http://minimal.linux-bg.org/#home

export IMAGE_NAME="${IMAGE_NAME:-luet_os.iso}"
export LUET_PACKAGES="${LUET_PACKAGES:-}"
export LUET_BIN="${LUET_BIN:-../luet}"
export LUET_CONFIG="${LUET_CONFIG:-../conf/luet-local.yaml}"
export WORKDIR="$ROOT_DIR/isowork"
export OVERLAY="${OVERLAY:-false}"
export FIRMWARE_TYPE="${FIRMWARE_TYPE:-both}"

export ARCH="${ARCH:-x86_64}"
export ISOIMAGE_PACKAGES="${ISOIMAGE_PACKAGES:-live/syslinux system/sabayon-live-boot}"
export UEFI_PACKAGES="${UEFI_PACKAGES:-live/systemd-boot system/sabayon-live-boot}"

#export BOOT_DIR="$WORKDIR/boot"
export ROOTFS_DIR="$WORKDIR/rootfs"
export OVERLAY_DIR="$WORKDIR/overlay"
export ISOIMAGE="$WORKDIR/isoimage"

export KERNEL_INSTALLED=$WORKDIR/kernel/kernel_installed

export FIRST_STAGE="${FIRST_STAGE:-distro/seed}"

export GEN_ROOTFS="${GEN_ROOTFS:-true}"


umount_rootfs() {
  local rootfs=$1
  #sudo umount -l $rootfs/boot
  sudo umount -l $rootfs/dev/pts

  sudo umount -l $rootfs/dev/
  sudo umount -l $rootfs/sys/
  sudo umount -l $rootfs/proc/
}

luet_install() {

  local rootfs=$1
  local packages="$2"

  ## Initial rootfs
  pushd "$rootfs"
 # mkdir -p boot
 # mount --bind $BOOT_DIR boot
  mkdir -p var/lock
  mkdir -p run/lock
  mkdir -p var/cache/luet
  mkdir -p var/luet
  mkdir -p etc/luet

  # Required to connect to remote repositories
  echo "nameserver 8.8.8.8" > etc/resolv.conf
  mkdir -p etc/ssl/certs
  cp -rfv /etc/ssl/certs/ca-certificates.crt etc/ssl/certs

  mkdir -p dev
  mkdir -p sys
  mkdir -p proc
  mkdir -p tmp
  mkdir -p dev/pts
  cp -rfv "${LUET_CONFIG}" etc/luet/.luet.yaml
  cp -rfv "${LUET_BIN}" luet
  sudo mount --bind /dev $rootfs/dev/
  sudo mount --bind /sys $rootfs/sys/
  sudo mount --bind /proc $rootfs/proc/
  sudo mount --bind /dev/pts $rootfs/dev/pts

  sudo chroot . /luet install ${packages}
  sudo chroot . /luet cleanup

      # Cleanup/umount
  umount_rootfs $rootfs || true

  sudo rm -rf luet
  popd

}

trap cleanup 1 2 3 6

cleanup()
{
   umount_rootfs  "$ROOTFS_DIR"
   umount_rootfs  "$OVERLAY_DIR"
}



if [[ "$GEN_ROOTFS" == true ]]; then

mkdir -p $WORKDIR

rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"

rm -rf "$OVERLAY_DIR"
mkdir -p "$OVERLAY_DIR"

echo "Initial root:"
ls -liah  "$ROOTFS_DIR"
ls -liah  "$OVERLAY_DIR"


set -ex


  if [[ "$OVERLAY" == true ]]; then
  echo "Building overlay"
    luet_install "$ROOTFS_DIR" "${FIRST_STAGE}"
    luet_install "$OVERLAY_DIR" "${LUET_PACKAGES}" || true
  else
    luet_install "$ROOTFS_DIR" "${LUET_PACKAGES}" || true
  fi

fi

set +x

for script in $(ls scripts/iso | grep '^[0-9]*_.*.sh'); do
  echo "Executing script '$script'."
  ./scripts/iso/$script
done

#bash build_minimal_linux_live.sh
