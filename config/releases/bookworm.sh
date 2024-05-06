# shellcheck shell=bash

export RELASE_NAME="Debian GNU/Linux 12 (bookworm)"
export RELASE_VERSION="12"
if [ -z "${KERNEL_TARGET}" ]; then
    export KERNEL_TARGET="rockchip-5.10"
fi
