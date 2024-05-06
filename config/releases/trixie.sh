# shellcheck shell=bash

export RELASE_NAME="Debian GNU/Linux 13 (trixie)"
export RELASE_VERSION="13"
if [ -z "${KERNEL_TARGET}" ]; then
    export KERNEL_TARGET="rockchip-6.1"
fi
