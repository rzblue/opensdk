#! /usr/bin/env bash

# Always ensure proper path
cd "$(dirname "$0")" || exit

ROOT_DIR="${PWD}"

if [ "$#" != "2" ]; then
    exit 1
fi

HOST_CFG="$(readlink -f "$1")"
TOOLCHAIN_CFG="$(readlink -f "$2")"
TOOLCHAIN_NAME="$(basename "$TOOLCHAIN_CFG")"

if ! [ -f "$HOST_CFG" ]; then
    echo "Cannot find selected host at $HOST_CFG"
    exit 1
fi

if ! [ -f "$TOOLCHAIN_CFG/version.env" ]; then
    echo "$TOOLCHAIN_CFG is not a supported toolchain"
    exit 1
fi

# shellcheck source=hosts/linux_x86_64.env
source "$HOST_CFG"

cat << EOF
Host System Info
    OS: ${WPITARGET}
    Tuple: ${WPIHOSTTARGET}
Toolchain Info:
    Name: ${TOOLCHAIN_NAME}
EOF

bash scripts/check_sys_compiler.sh || exit

export CC="${WPIHOSTTARGET}-gcc"
export CXX="${WPIHOSTTARGET}-g++"

bash ./makes/src/test/test.sh

DOWNLOAD_DIR="${ROOT_DIR}/downloads/${TOOLCHAIN_NAME}/"
REPACK_DIR="${ROOT_DIR}/repack/${TOOLCHAIN_NAME}/"

# Prep builds
mkdir -p "${DOWNLOAD_DIR}" "${REPACK_DIR}"
pushd "${DOWNLOAD_DIR}" || exit
    bash "${TOOLCHAIN_CFG}/download.sh"
    bash "${TOOLCHAIN_CFG}/repack.sh" "${REPACK_DIR}/"
popd || exit
