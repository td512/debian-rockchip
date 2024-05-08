# shellcheck shell=bash

export RELASE_NAME="Debian GNU/Linux 13 (trixie)"
export RELEASE_VERSION="trixie"
if [ -z "${KERNEL_TARGET}" ]; then
    export KERNEL_TARGET="rockchip-6.1"
fi
