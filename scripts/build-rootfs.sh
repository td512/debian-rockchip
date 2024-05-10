#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

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

if [[ -f debian-${RELEASE_VERSION}-preinstalled-${PROJECT}-arm64.rootfs.tar.xz || -f debian-${DESKTOP}-${RELEASE_VERSION}-preinstalled-${PROJECT}-arm64.rootfs.tar.xz ]]; then
    exit 0
fi

git clone https://github.com/td512/debian-live-build.git
cd debian-live-build
mv ../os.tar .
tar xf os.tar
if [[ ${USE_CACHE} == "Y" ]]; then
    bash ./build-with-cache.sh "--${PROJECT}" "--${RELEASE}" -de "${DESKTOP}"
else
    bash ./build.sh "--${PROJECT}" "--${RELEASE}" -de "${DESKTOP}"
fi
