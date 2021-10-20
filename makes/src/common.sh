#! /usr/bin/env bash
# shellcheck disable=SC2155

function die() {
    echo "[FATAL]: $1" >&2
    exit 1
}

function xpushd() {
    pushd "$1" >/dev/null || die "pushd failed: $1"
}

function xpopd() {
    popd >/dev/null || die "popd failed"
}

function xcd() {
    cd "$1" >/dev/null || die "cd failed"
}

function process_background() {
    local spin=("-" "\\" "|" "/")
    local msg="$1"; shift
    local rand="$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 10 | head -n 1)"
    mkdir -p "/tmp/toolchain_builder/"
    local prefix
    if [ "$msg" ]; then
        prefix="[RUNNING]: $msg"
    else
        prefix="[RUNNING]: Background task '${*}'"
    fi
    ("${@}") >"/tmp/toolchain_builder/${rand}.log" 2>&1 &
    local pid="$!"
    if [ "$CI" != "true" ]; then
        while (ps a | awk '{print $1}' | grep -q "$pid"); do
            for i in "${spin[@]}"; do
                echo -ne "\r$prefix $i"
                sleep 0.1
            done
        done
        echo -e "\r$prefix  "
    else
        echo "$prefix"
    fi
    wait "$pid"
    local retval="$?"
    if [ "$retval" -ne 0 ]; then
        cat "/tmp/toolchain_builder/${rand}.log"
    fi
    rm "/tmp/toolchain_builder/${rand}.log"
    return "$retval"
}

# If these fail, then others are bad aswell
[ "${V_BIN:-fail}" != fail ] || die "V_BIN"
[ "${V_GDB:-fail}" != fail ] || die "V_GDB"
[ "${V_GCC:-fail}" != fail ] || die "V_GCC"
[ "${WPI_HOST_PREFIX:-fail}" != fail ] || die "prefix dir"
[ "${DOWNLOAD_DIR:-fail}" != fail ] || die "Download Dir"

BUILD_TUPLE="$(sh "${DOWNLOAD_DIR}"/config.guess)"
if [ -n "${WPI_HOST_TUPLE}" ]; then
    HOST_TUPLE="$(sh "${DOWNLOAD_DIR}"/config.sub "${WPI_HOST_TUPLE}")"
else
    HOST_TUPLE="${BUILD_TUPLE}"
fi
SYSROOT_PATH="${WPI_HOST_PREFIX}/${TARGET_TUPLE}/sysroot"
SYSROOT_BUILD_PATH="$BUILD_DIR/sysroot-install/${TARGET_TUPLE}/sysroot"

CONFIGURE_COMMON_LITE=(
    "--build=${BUILD_TUPLE}"
    "--host=${HOST_TUPLE}"
    "--prefix=${WPI_HOST_PREFIX}"
    "--program-prefix=${TARGET_PREFIX}"
    "--enable-lto"
    "--disable-nls"
    "--disable-werror"
    "--disable-dependency-tracking"
)

CONFIGURE_COMMON=(
    "${CONFIGURE_COMMON_LITE[@]}"
    "--target=${TARGET_TUPLE}"
    "--libdir=${WPI_HOST_PREFIX}/${TARGET_TUPLE}/lib" \
    "--libexecdir=${WPI_HOST_PREFIX}/${TARGET_TUPLE}/libexec"
    "--with-sysroot=${SYSROOT_PATH}"
)

if [ "${PREBUILD_CANADIAN}" != "true" ]; then
    # Normally use our in-tree sysroot unless we are on the second stage build
    CONFIGURE_COMMON+=("--with-build-sysroot=${SYSROOT_BUILD_PATH}")
else
    CONFIGURE_COMMON+=("--with-build-sysroot=/opt/frc/${TARGET_TUPLE}/sysroot")
fi

export PATH="/opt/frc/bin:${PATH}"
export CONFIGURE_COMMON_LITE CONFIGURE_COMMON
if [ "${PREBUILD_CANADIAN}" = "true" ]; then
    if ! [[ -x "/opt/frc/bin/${TARGET_TUPLE}-gcc" ]]; then
        echo "[DEBUG]: Cannot find ${TARGET_TUPLE}-gcc in /opt/frc/bin"
        die "Stage 1 Canadian toolchain not found in expected location"
    fi
    # Don't use HOST_TUPLE as it can get changed with config.sub
    if [ "${WPI_HOST_TUPLE}" = "${TARGET_TUPLE}" ]; then
        # Manually tell autoconf what tools to use as the host and target
        # compilers may be intended for different systems even though they have
        # the same prefix due to the tuple matching.
        AR="/usr/bin/${WPI_HOST_TUPLE}-ar"
        export AR
        AS="/usr/bin/${WPI_HOST_TUPLE}-as"
        export AS
        LD="/usr/bin/${WPI_HOST_TUPLE}-ld"
        export LD
        NM="/usr/bin/${WPI_HOST_TUPLE}-nm"
        export NM
        RANLIB="/usr/bin/${WPI_HOST_TUPLE}-ranlib"
        export RANLIB
        STRIP="/usr/bin/${WPI_HOST_TUPLE}-strip"
        export STRIP
        OBJCOPY="/usr/bin/${WPI_HOST_TUPLE}-objcopy"
        export OBJCOPY
        OBJDUMP="/usr/bin/${WPI_HOST_TUPLE}-objdump"
        export OBJDUMP
        READELF="/usr/bin/${WPI_HOST_TUPLE}-readelf"
        export READELF
        CC="/usr/bin/${WPI_HOST_TUPLE}-gcc"
        export CC
        CXX="/usr/bin/${WPI_HOST_TUPLE}-g++"
        export CXX

        AR_FOR_TARGET="/opt/frc/bin/${WPI_HOST_TUPLE}-ar"
        export AR_FOR_TARGET
        AS_FOR_TARGET="/opt/frc/bin/${WPI_HOST_TUPLE}-as"
        export AS_FOR_TARGET
        LD_FOR_TARGET="/opt/frc/bin/${WPI_HOST_TUPLE}-ld"
        export LD_FOR_TARGET
        NM_FOR_TARGET="/opt/frc/bin/${WPI_HOST_TUPLE}-nm"
        export NM_FOR_TARGET
        RANLIB_FOR_TARGET="/opt/frc/bin/${WPI_HOST_TUPLE}-ranlib"
        export RANLIB_FOR_TARGET
        STRIP_FOR_TARGET="/opt/frc/bin/${WPI_HOST_TUPLE}-strip"
        export STRIP_FOR_TARGET
        OBJCOPY_FOR_TARGET="/opt/frc/bin/${WPI_HOST_TUPLE}-objcopy"
        export OBJCOPY_FOR_TARGET
        OBJDUMP_FOR_TARGET="/opt/frc/bin/${WPI_HOST_TUPLE}-objdump"
        export OBJDUMP_FOR_TARGET
        READELF_FOR_TARGET="/opt/frc/bin/${WPI_HOST_TUPLE}-readelf"
        export READELF_FOR_TARGET
        CC_FOR_TARGET="/opt/frc/bin/${WPI_HOST_TUPLE}-gcc"
        export CC_FOR_TARGET
        GCC_FOR_TARGET="${CC_FOR_TARGET}"
        export GCC_FOR_TARGET
        CXX_FOR_TARGET="/opt/frc/bin/${WPI_HOST_TUPLE}-g++"
        export CXX_FOR_TARGET
        GFORTRAN_FOR_TARGET="/opt/frc/bin/${WPI_HOST_TUPLE}-gfortran"
        export GFORTRAN_FOR_TARGET
    fi
fi
