#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${BOARD} ]]; then
    echo "Error: BOARD is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/boards/${BOARD}.sh"

if [[ -z ${KERNEL_TARGET} ]]; then
    echo "Error: KERNEL_TARGET is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/kernels/${KERNEL_TARGET}.conf"

if [[ -z ${RELEASE} ]]; then
    echo "Error: RELEASE is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/releases/${RELEASE}.sh"

if [[ -z ${PROJECT} ]]; then
    echo "Error: PROJECT is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/projects/${PROJECT}.sh"

if [[ -z ${DESKTOP} ]]; then
    echo "Error: DESKTOP is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/desktops/${DESKTOP}.sh"

setup_mountpoint() {
    local mountpoint="$1"

    if [ ! -c /dev/mem ]; then
        mknod -m 660 /dev/mem c 1 1
        chown root:kmem /dev/mem
    fi

    mount dev-live -t devtmpfs "$mountpoint/dev"
    mount devpts-live -t devpts -o nodev,nosuid "$mountpoint/dev/pts"
    mount proc-live -t proc "$mountpoint/proc"
    mount sysfs-live -t sysfs "$mountpoint/sys"
    mount securityfs -t securityfs "$mountpoint/sys/kernel/security"
    # Provide more up to date apparmor features, matching target kernel
    # cgroup2 mount for LP: 1944004
    mount -t cgroup2 none "$mountpoint/sys/fs/cgroup"
    mount -t tmpfs none "$mountpoint/tmp"
    mount -t tmpfs none "$mountpoint/var/lib/apt/lists"
    mount -t tmpfs none "$mountpoint/var/cache/apt"
    mv "$mountpoint/etc/resolv.conf" resolv.conf.tmp
    cp /etc/resolv.conf "$mountpoint/etc/resolv.conf"
    mv "$mountpoint/etc/nsswitch.conf" nsswitch.conf.tmp
    sed 's/systemd//g' nsswitch.conf.tmp > "$mountpoint/etc/nsswitch.conf"
}

teardown_mountpoint() {
    # Reverse the operations from setup_mountpoint
    local mountpoint=$(realpath "$1")

    # ensure we have exactly one trailing slash, and escape all slashes for awk
    mountpoint_match=$(echo "$mountpoint" | sed -e's,/$,,; s,/,\\/,g;')'\/'
    # sort -r ensures that deeper mountpoints are unmounted first
    awk </proc/self/mounts "\$2 ~ /$mountpoint_match/ { print \$2 }" | LC_ALL=C sort -r | while IFS= read -r submount; do
        mount --make-private "$submount"
        umount "$submount"
    done
    mv resolv.conf.tmp "$mountpoint/etc/resolv.conf"
    mv nsswitch.conf.tmp "$mountpoint/etc/nsswitch.conf"
}

# Prevent dpkg interactive dialogues
export DEBIAN_FRONTEND=noninteractive

# Override localisation settings to address a perl warning
export LC_ALL=C

# Debootstrap options
chroot_dir=rootfs
overlay_dir=../overlay

# Extract the compressed root filesystem
rm -rf ${chroot_dir} && mkdir -p ${chroot_dir}

if [[ "$PROJECT" == "server" ]]; then
    DESTNAME="debian-${RELEASE_VERSION}-preinstalled-${PROJECT}-arm64.rootfs"
else
    DESTNAME="debian-${RELEASE_VERSION}-${DESKTOP}-preinstalled-${PROJECT}-arm64.rootfs"
fi

tar -xpJf "${DESTNAME}/${DESTNAME}.tar.xz" -C ${chroot_dir}

# Mount the root filesystem
setup_mountpoint $chroot_dir

# Update packages
chroot $chroot_dir apt-get update
chroot $chroot_dir apt-get -y upgrade
    
# Run config hook to handle board specific changes
if [[ $(type -t config_image_hook__"${BOARD}") == function ]]; then
    config_image_hook__"${BOARD}" "${chroot_dir}" "${overlay_dir}"
fi 

# Download and install U-Boot
chroot ${chroot_dir} apt-get -y install "u-boot-${BOARD}"

# Update the initramfs
chroot ${chroot_dir} update-initramfs -u

# Remove packages
chroot ${chroot_dir} apt-get -y clean
chroot ${chroot_dir} apt-get -y autoclean
chroot ${chroot_dir} apt-get -y autoremove

# Umount the root filesystem
teardown_mountpoint $chroot_dir

# Compress the root filesystem and then build a disk image
cd ${chroot_dir} && tar -cpf "../${DESTNAME}.tar" . && cd .. && rm -rf ${chroot_dir}
../scripts/build-image.sh "${DESTNAME}.tar"
rm -f "${DESTNAME}.tar"
