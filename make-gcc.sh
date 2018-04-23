#!/bin/bash
#
# Build the gcc compiler, the boost library and the gdb debugger together.
# For more information use the --help option.
#
# License: MIT Open Source
# Copyright (c) 2018 by Joe Linoff
PS4='$(printf "+ \033[38;5;245m%-16s\033[0m " "${BASH_SOURCE[0]}:${LINENO}:")'

# ================================================================
# Utility Functions
# Could be replaced with
# source PATH/libutils.sh
# ================================================================
function __msg() {
    local LineNo=$1
    local Type=$2
    local Code="$3"
    shift
    shift
    shift
    printf "$Code"
    printf "%-28s %-7s %5s: " "$(date +'%Y-%m-%d %H:%M:%S %z %Z')" "$Type" $LineNo
    echo "$*"
    printf "\033[0m"
}

# Print an info message to stdout.
function _info() {
    __msg ${BASH_LINENO[0]} "INFO" "\033[0m" $*
}

# Print an info message to stdout in green.
function _info_green() {
    __msg ${BASH_LINENO[0]} "INFO" "\033[32m" $*
}

# Print an info message to stdout in red.
function _info_red() {
    __msg ${BASH_LINENO[0]} "INFO" "\033[31m" $*
}

# Print an info message to stdout in bold.
function _info_bold() {
    __msg ${BASH_LINENO[0]} "INFO" "\033[1m" $*
}

# Print a warning message to stderr and exit.
function _warn() {
    __msg ${BASH_LINENO[0]} "WARNING" "\033[34m" $*
}

# Print an error message to stderr and exit.
function _err() {
    __msg ${BASH_LINENO[0]} "ERROR" "\033[31m" $* >&2
    exit 1
}

# Print an error message to stderr.
# Do not exit.
function _err_nox() {
    __msg ${BASH_LINENO[0]} "ERROR" "\033[31m" $* >&2
}

# Decorate a command and exit if the return code is not zero.
function _exec() {
    local Cmd="$*"
    __msg ${BASH_LINENO[0]} "INFO" "\033[1m" "cmd.cmd=$Cmd"
    eval "$Cmd"
    local Status=$?
    if (( $Status )) ; then
        __msg ${BASH_LINENO[0]} "INFO" "\033[31m" "cmd.code=$Status"
        __msg ${BASH_LINENO[0]} "ERROR" "\033[31m" "cmd.status=FAILED"
        exit 1
    else
         __msg ${BASH_LINENO[0]} "INFO" "\033[32m" "cmd.code=$Status"
         __msg ${BASH_LINENO[0]} "INFO" "\033[32m" "cmd.status=PASSED"
    fi
}

# Execute a command quietly.
# Only decorate if an error occurs.
function _exeq() {
    local Cmd="$*"
    eval "$Cmd"
    local Status=$?
    if (( $Status )) ; then
        __msg ${BASH_LINENO[0]} "INFO" "\033[1m" "cmd.cmd=$Cmd"
        __msg ${BASH_LINENO[0]} "INFO" "\033[31m" "cmd.code=$Status"
        __msg ${BASH_LINENO[0]} "ERROR" "\033[31m" "cmd.status=FAILED"
        exit 1
    fi
}

# Decorate a command. Do not exit if the return code is not zero.
function _exec_nox() {
    local Cmd="$*"
    __msg ${BASH_LINENO[0]} "INFO" "\033[1m" "cmd.cmd=$Cmd"
    eval "$Cmd"
    local Status=$?
    if (( $Status )) ; then
        __msg ${BASH_LINENO[0]} "INFO" "\033[31m" "cmd.code=$Status"
        __msg ${BASH_LINENO[0]} "ERROR" "\033[31m" "cmd.status=FAILED (IGNORED)"
    else
        __msg ${BASH_LINENO[0]} "INFO" "\033[32m" "cmd.code=$Status"
        __msg ${BASH_LINENO[0]} "INFO" "\033[32m" "cmd.status=PASSED"
    fi
    return $Status
}

# Banner.
function _banner() {
    echo
    echo "# ================================================================"
    echo "# $*"
    echo "# ================================================================"
}

# ========================================================================
# Functions
# ========================================================================
function _help() {
    local B="$(printf '\033[1m')"
    local R="$(printf '\033[0m')"

    cat <<EOF
USAGE
    $B$BASENAME$R [OPTIONS] GCC_VERSION BOOST_VERSION GDB_VERSION

DESCRIPTION
    Builds a specified version of the gcc compiler, boost library
    and gdb debugger.

    To use it after the installation, the LD_LIBRARY_PATH, PATH and
    MANPATH variables must be set properly. It generates a tool named
    gcc-enable to set them for you. It also generates a tool named
    gcc-disable to disable them.

    For each run a log is created in /tmp/$BASENAME-DTS.log where
    DTS is the date-time stamp of the run. The log location can
    be controlled by setting the LOGDIR environment variable.

ARGUMENTS

    GCC_VERSION     The version of gcc to build.
                    Examples would be 6.4.0 and 7.3.0.

    BOOST_VERSION   The version of boost to build.
                    Examples would be 1.66.0 and 1.67.0.

    GDB_VERSION     The version of gdb to build.
                    An example would be 8.1.

OPTIONS
    -c, --clean     Clean before building.

    -f FLAVOR, --boost-flavor
                    The boost C++ standard to build to.
                    Examples are c++11, c++14, and gnu++14.
                    Default: c++11

    -h, --help      Help message.

    -o DIR, --out DIR
                    Explicitly specify the output directory
                    path. This overrides the prefix so
                    platform and version information are
                    lost.

    -p PREFIX, --prefix PREFIX
                    Prefix of the build location.
                    The output location will be
                    PREFIX/$PLATFORM/VERSIONS.

                    This is overridden by -o.

    -V, --version   Print the program version and exit.

EXAMPLES
    # Example 1: help
    \$ $B$BASENAME$R -h

    # Example 2: build in current directory
    \$ $B$BASENAME$R 6.4.0 1.66.0 8.1

    # Example 3. build in /opt/gcc/6.4.0-1.66.0-8.1
    \$ $B$BASENAME$R -p /opt/gcc

    # Example 4: build in current directory, c++14
    \$ $B$BASENAME$R -f c++14 6.4.0 1.66.0 8.1

    # Example 5: explicitly define the output path.
    \$ $B$BASENAME$R -o /opt/mytools -f c++14 6.4.0 1.66.0 8.1

EOF
    exit 0
}

# Print the program version and exit.
function _version() {
    echo "$BASENAME $VERSION"
    exit 0
}

# Get the CLI options
function _getopts() {
    # The OPT_CACHE is to cache short form options.
    local OPT_CACHE=()
    local OPT_TARGET
    while (( $# )) || (( ${#OPT_CACHE[@]} )) ; do
        if (( ${#OPT_CACHE[@]} > 0 )) ; then
            OPT="${OPT_CACHE[0]}"
            if (( ${#OPT_CACHE[@]} > 1 )) ; then
                OPT_CACHE=(${OPT_CACHE[@]:1})
            else
                OPT_CACHE=()
            fi
        else
            OPT="$1"
            shift
        fi
        case "$OPT" in
            # Handle the case of multiple short arguments in a single
            # string:
            #  -abc ==> -a -b -c
            -[!-][a-zA-Z0-9\-_]*)
                for (( i=1; i<${#OPT}; i++ )) ; do
                    # Note that the leading dash is added here.
                    CHAR=${OPT:$i:1}
                    OPT_CACHE+=("-$CHAR")
                done
                ;;
            -c|--clean)
                OPT_CLEAN=1
                ;;
            -f|--boost-flavor|--boost-flavor=*)
                OPT_BOOST_FLAVOR="$1"
                if [ -z "${OPT##*=*}" ] ; then
                    OPT_BOOST_FLAVOR="${OPT#*=}"
                else
                    OPT_BOOST_FLAVOR="$1"
                    shift
                fi
                [ -z "$OPT_BOOST_FLAVOR" ] && _err "Missing argument for '$OPT'."
                ;;
            -h|--help)
                _help
                ;;
            -o|--out|--out=*)
                OPT_OUT_DIR="$1"
                if [ -z "${OPT##*=*}" ] ; then
                    OPT_OUT_DIR="${OPT#*=}"
                else
                    OPT_OUT_DIR="$1"
                    shift
                fi
                [ -z "$OPT_OUT_DIR" ] && _err "Missing argument for '$OPT'."
                ;;
            -p|--prefix|--prefix=*)
                OPT_PREFIX_DIR="$1"
                if [ -z "${OPT##*=*}" ] ; then
                    OPT_PREFIX_DIR="${OPT#*=}"
                else
                    OPT_PREFIX_DIR="$1"
                    shift
                fi
                [ -z "$OPT_PREFIX_DIR" ] && _err "Missing argument for '$OPT'."
                ;;
            -V|--version)
                _version
                ;;
            -*)
                _err "Unrecognized option '$OPT'."
                ;;
            *)
                if [ -z "$OPT_GCC_VERSION" ] ; then
                    OPT_GCC_VERSION="$OPT"
                elif [ -z "$OPT_BOOST_VERSION" ] ; then
                    OPT_BOOST_VERSION="$OPT"
                elif [ -z "$OPT_GDB_VERSION" ] ; then
                    OPT_GDB_VERSION="$OPT"
                else
                    _err "Illegal option '$OPT'."
                fi
                ;;
        esac
    done
    # Make sure that we have all of the arguments.
    [ -z "$OPT_GCC_VERSION" ] && _err "Argument not specified: GCC_VERSION." || true
    [ -z "$OPT_BOOST_VERSION" ] && _err "Argument not specified: BOOST_VERSION." || true
    [ -z "$OPT_GDB_VERSION" ] && _err "Argument not specified: GDB_VERSION." || true
}

# Clean a string.
# Used by _platform.
function _platform_clean() {
    echo "$*" | tr -d '[ \t]' | tr 'A-Z' 'a-z'
}

# Get the platform (distro).
function _platform() {
    local OS_NAME='unknown'
    local OS_ARCH='unknown'
    local DISTRO_NAME='unknown'
    local DISTRO_VERSION='unknown'

    if uname >/dev/null 2>&1 ; then
        # If uname is present we are in good shape.
        # If it isn't present we have a problem.
        OS_NAME=$(uname 1>/dev/null 2>&1 && _platform_clean $(uname) || echo 'unknown')
        OS_ARCH=$(uname -m 1>/dev/null 2>&1 && _platform_clean $(uname -m) || echo 'unknown')
    fi

    case "$OS_NAME" in
        cygwin)
            # Not well tested.
            OS_NAME='linux'
            DISTRO_NAME=$(awk -F- '{print $1}')
            DISTRO_VERSION=$(awk -F- '{print $2}')
            OS_ARCH=$(awk -F- '{print $3}')
            ;;
        darwin)
            # Not well tested for older versions of Mac OS X.
            DISTRO_NAME=$(_platform_clean $(system_profiler SPSoftwareDataType | grep 'System Version:' | awk '{print $3}'))
            DISTRO_VERSION=$(_platform_clean $(system_profiler SPSoftwareDataType | grep 'System Version:' | awk '{print $4}'))
            ;;
        linux)
            if [ -f /etc/centos-release ] ; then
                # centos 6, 7
                DISTRO_NAME='centos'
                DISTRO_VERSION=$(awk '{for(i=1;i<=NF;i++){if($i ~ /^[0-9]/){print $i; break}}}' /etc/centos-release)
            elif [ -f /etc/fedora-release ] ; then
                DISTRO_NAME='fedora'
                DISTRO_VERSION=$(awk '{for(i=1;i<=NF;i++){if($i ~ /^[0-9]/){print $i; break}}}' /etc/fedora-release)
            elif [ -f /etc/redhat-release ] ; then
                # other flavors of redhat.
                DISTRO_NAME=$(_platform_clean $(awk '{print $1}' /etc/redhat-release))
                DISTRO_VERSION=$(awk '{for(i=1;i<=NF;i++){if($i ~ /^[0-9]/){print $i; break}}}' /etc/redhat-release)
            elif [ -f /etc/os-release ] ; then
                # Tested for recent versions of debian and ubuntu.
                if grep -q '^ID=' /etc/os-release ; then
                    DISTRO_NAME=$(_platform_clean $(awk -F= '/^ID=/{print $2}' /etc/os-release))
                    DISTRO_VERSION=$(_platform_clean $(awk -F= '/^VERSION=/{print $2}' /etc/os-release | \
                                                  sed -e 's/"//g' | \
                                                  awk '{print $1}'))
                fi
            fi
            ;;
        sunos)
            # Not well tested.
            OS_NAME='sunos'
            DISTRO_NAME=$(_platform_clean $(uname -v))
            DISTRO_VERSION=$(_platform_clean $(uname -r))
            ;;
        *)
            ;;
    esac
    printf '%s-%s-%s-%s\n' "$OS_NAME" "$DISTRO_NAME" "$DISTRO_VERSION" "$OS_ARCH"
}

# ========================================================================
# Build Functions
# Each function builds a specific package.
# It was designed this way so that special case handling and fixes
# could be localized.
# NOTES: http://cs.swan.ac.uk/~csoliver/ok-sat-library/internet_html/doc/doc/Gcc/4.6.4/html/gccinstall/prerequisites.html
# ========================================================================
function prerequisites() {
    _banner "Fct:${LINENO}:${FUNCNAME[0]}"
    if (( OPT_CLEAN )) ; then
        _exec sudo rm -rf $BLD_ROOT_DIR/*
    fi

    local Dirs=($BLD_ROOT_DIR $BLD_CACHE_DIR $BLD_PKG_DIR $BLD_REL_DIR/etc)
    for Dir in ${Dirs[@]} ; do
        if [ ! -d $Dir ] ; then
            _exec mkdir -p $Dir
        fi
    done

    if ! which curl >/dev/null 2>&1 ; then
        BLD_SYS_PKG_UPDATE=1
    fi

    if [ -f /usr/bin/dnf ] ; then
        _exec sudo dnf install -y \
              curl xz bxz tree time atop htop \
              gawk \
              binutils \
              gzip bzip2 \
              make \
              tar \
              perl \
              gcc gcc-c++

        # This is needed by gcc: contrib/download_prerequisites
        _exec sudo dnf install -y wget

        # This is needed by gdb.
        _exec sudo dnf install -y texinfo

        # Stuff needed for this script.
        _exec sudo dnf install -y which

    elif [ -f /usr/bin/yum ] ; then
        # https://gcc.gnu.org/install/prerequisites.html
        _exec sudo yum install -y \
              curl xz bxz tree time atop htop \
              gawk \
              binutils \
              gzip bzip2 \
              make \
              tar \
              perl \
              gcc gcc-c++

        # This is needed by gcc: contrib/download_prerequisites
        _exec sudo yum install -y wget

        # This is needed by gdb.
        _exec sudo yum install -y texinfo

        # Stuff needed for this script.
        _exec sudo yum install -y which

    elif [ -f /usr/bin/apt-get ] ; then
        _exec apt-get install -y \
              curl xz-utils tree time atop htop \
              gawk \
              binutils \
              gzip bzip2 \
              make \
              tar \
              perl \
              gcc g++

        # This is needed by gcc: contrib/download_prerequisites
        _exec sudo apt-get install -y wget

        # This is needed by gdb.
        _exec sudo apt-get install -y texinfo

        # Stuff needed for this script.
        _exec sudo apt-get install -y debianutils
    fi
}

# gcc
# URL: https://ftp.gnu.org/gnu/gcc
function build_gcc() {
    _banner "Fct:${LINENO}:${FUNCNAME[0]}"
    local Version="$OPT_GCC_VERSION"
    local LocalDir="gcc-$Version"
    local Semaphore="${BLD_PKG_DIR}/${LocalDir}/${BLD_DONE_SEMAPHORE}"

    # Force a rebuild for individual packages.
    (( OPT_FORCE_REBUILD )) && rm -rf $Semaphore || true

    # Build.
    if [ ! -f $Semaphore ] ; then
        _info "Building ${BLD_PKG_DIR}/$LocalDir."
        pushd $BLD_PKG_DIR
        [ -d $LocalDir ] && _exec rm -rf $LocalDir || true

        # Cache.
        local CachedPkg="${BLD_CACHE_DIR}/$LocalDir.tar"
        if [ ! -f $CachedPkg ] ; then
            _exec curl --fail -L https://ftp.gnu.org/gnu/gcc/$LocalDir/$LocalDir.tar.xz --out $CachedPkg
        fi

        # Extract and build.
        _exec mkdir $LocalDir
        _exec cd $LocalDir
        _exec tar xf $CachedPkg --strip-components=1
        _exec bash ./contrib/download_prerequisites
        _exec mkdir xbld
        _exec cd xbld
        _exec ../configure --help
        _exec ../configure \
              --prefix=$BLD_REL_DIR \
              --disable-multilib \
              --enable-languages='c,c++'
        _exec make clean
        _exec time make
        _exec time make install
        popd
        _exec touch $Semaphore
        (( BLD_PKG_COUNT++ ))
    fi
    _exec ls -l ${BLD_REL_DIR}/bin/gcc
    _exec ls -l ${BLD_REL_DIR}/bin/g++
}

# boost
# URL: https://dl.bintray.com/boostorg
function build_boost() {
    _banner "Fct:${LINENO}:${FUNCNAME[0]}"
    local Version="$OPT_BOOST_VERSION"
    local LocalDir="boost_$Version"
    local Semaphore="${BLD_PKG_DIR}/${LocalDir}/${BLD_DONE_SEMAPHORE}"

    # Force a rebuild for individual packages.
    (( OPT_FORCE_REBUILD )) && rm -rf $Semaphore || true

    if [ ! -f $Semaphore ] ; then
        _info "Building ${BLD_PKG_DIR}/$LocalDir."
        pushd $BLD_PKG_DIR
        [ -d $LocalDir ] && _exec rm -rf $LocalDir || true

        # Cache the package for faster performance.
        local CachedPkg="${BLD_CACHE_DIR}/$LocalDir.tar.gz"
        if [ ! -f $CachedPkg ] ; then
            # Change '.' to '_' (i.e. '1.6.0' --> '1_6_0')
            local Version_=$(echo "$Version" | tr '.' '_')
            _exec curl -L https://dl.bintray.com/boostorg/release/$Version/source/boost_$Version_.tar.gz -o $CachedPkg
        fi

        # Extract and build.
        _exec mkdir $LocalDir
        _exec cd $LocalDir
        _exec tar xf $CachedPkg --strip-components=1
        _exec g++ --version
        export CC=gcc
        export CXX=g++
        _exec ./bootstrap.sh \
              --prefix="${BLD_REL_DIR}" \
              toolset=gcc
        _exec ./b2 toolset=gcc \
              variant=release \
              link=shared,static \
              threading=multi \
              cxxflags="-std=$OPT_BOOST_FLAVOR" \
              install
        unset CC
        unset CXX
        popd
        _exec touch $Semaphore
        (( OPT_BUILD_COUNT++ ))
    else
        _info "Already built ${BLD_PKG_DIR}/$LocalDir."
    fi
    _exec ls -l ${BLD_REL_DIR}/include/boost/atomic.hpp
    _exec ls ${BLD_REL_DIR}/lib/libboost*.so
    _exec ls ${BLD_REL_DIR}/lib/libboost*.a
}

# gdb
# URL: https://www.gnu.org/software/gdb/download/
function build_gdb() {
    _banner "Fct:${LINENO}:${FUNCNAME[0]}"
    local Version="$OPT_GDB_VERSION"
    local LocalDir="gdb-$Version"
    local Semaphore="${BLD_PKG_DIR}/${LocalDir}/${BLD_DONE_SEMAPHORE}"

    # Force a rebuild for individual packages.
    (( OPT_FORCE_REBUILD )) && rm -rf $Semaphore || true

    if [ ! -f $Semaphore ] ; then
        _info "Building ${BLD_PKG_DIR}/$LocalDir."
        pushd $BLD_PKG_DIR
        [ -d $LocalDir ] && _exec rm -rf $LocalDir || true

        # Cache the package for faster performance.
        local CachedPkg="${BLD_CACHE_DIR}/$LocalDir.tar.gz"
        if [ ! -f $CachedPkg ] ; then
            _exec curl -L https://ftp.gnu.org/gnu/gdb/$LocalDir.tar.xz -o $CachedPkg
        fi

        # Extract and build.
        _exec tar xf $CachedPkg
        _exec cd $LocalDir
        _exec ./configure --help
        export CC=gcc
        export CXX=g++
        _exec ./configure \
              --prefix=$BLD_REL_DIR \
              CC=gcc \
              CXX=g++ \
              --prefix=$BLD_REL_DIR \
              --disable-multilib \
              --enable-languages='c,c++'
        _exec make
        _exec make install
        unset CC
        unset CXX
        popd
        _exec touch $Semaphore
        (( OPT_BUILD_COUNT++ ))
    else
        _info "Already built ${BLD_PKG_DIR}/$LocalDir."
    fi
    _exec ls -l ${BLD_REL_DIR}/bin/gdb
}

# enable/disable tools
function build_enable_disable() {
    _banner "Fct:${LINENO}:${FUNCNAME[0]}"
    set -e

    local EnableTool="$BLD_REL_DIR/bin/gcc-enable"
    _info "Creating enable: $EnableTool."
    cat >$EnableTool <<EOF
# Automatically generated.
export PATH="${BLD_REL_DIR}/bin:\${PATH}"
export LD_LIBRARY_PATH="${BLD_REL_DIR}/lib64:${BLD_REL_DIR}/lib:\${LD_LIBRARY_PATH}"
export MANPATH="$BLD_REL_DIR/share/man:\${MANPATH}"
export INFOPATH="$BLD_REL_DIR/share/info:\${INFOPATH}"
export MAKE_GCC_CONF="${OPT_GCC_VERSION}-${OPT_BOOST_VERSION}-${OPT_GDB_VERSION}"
EOF

    local DisableTool="$BLD_REL_DIR/bin/gcc-disable"
    _info "Creating disable: $DisableTool."
    cat >$DisableTool <<EOF
# Automatically generated.
export PATH="\$(echo \$PATH | sed -e 's@${BLD_REL_DIR}/bin:@@g')"
export LD_LIBRARY_PATH="\$(echo \$PATH | sed -e 's@${BLD_REL_DIR}/lib64:${BLD_REL_DIR}/lib:@@g')"
export MANPATH="\$(echo \$MANPATH | sed -e 's@${BLD_REL_DIR}/share/man:@@g')"
export INFOPATH="\$(echo \$INFOPATH | sed -e 's@${BLD_REL_DIR}/share/info:@@g')"
unset MAKE_GCC_CONF
EOF
    set +e
}

# post operations
function build_post() {
cat <<EOF

Build completed successfully.

The following tools are available for testing.

    gcc-$OPT_GCC_VERSION
    boost-$OPT_BOOST_VERSION
    gdb-$OPT_GDB_VERSION

To enable access in your environment:

    \$ source $BLD_REL_DIR/bin/gcc-enable
    \$ gcc --version
    \$ g++ --version
    \$ gdb --version

To disable access:

    \$ source $BLD_REL_DIR/bin/gcc-disable

EOF
}

# Build all of the packages.
function build_all() {
    _banner "Build all packages."
    build_gcc
    build_boost
    build_gdb
    build_enable_disable
    build_post
}

# ========================================================================
# Main
# ========================================================================
readonly BASENAME=$(basename -- $(readlink -m ${BASH_SOURCE[0]}))
readonly VERSION='0.8.0'
readonly PLATFORM=$(_platform)

# Start by logging everything.
: ${LOGDIR=/tmp}
readonly LOGFILE="$LOGDIR/$BASENAME-$VERSION-$(date +'%Y%m%dT%H%M%S%z.log')"
exec > >(tee -a $LOGFILE) 2>&1

_banner "$BASENAME-$VERSION $(date)"

OPT_FORCE_REBUILD=0
OPT_CLEAN=0
OPT_GCC_VERSION=
OPT_BOOST_VERSION=
OPT_BOOST_FLAVOR='c++11'
OPT_GDB_VERSION=
OPT_PREFIX_DIR=
OPT_OUT_DIR=
_getopts $*

# Set the build root, it must be an abs path.
if [ -z "$OPT_OUT_DIR" ] ; then
    BLD_ROOT_DIR="$PLATFORM/$OPT_GCC_VERSION-$OPT_BOOST_VERSION-$OPT_GDB_VERSION"
    [ -n "$OPT_PREFIX_DIR" ] && BLD_ROOT_DIR="$OPT_PREFIX_DIR/$BLD_ROOT_DIR" || true
    BLD_ROOT_DIR=$(readlink -m $BLD_ROOT_DIR)
else
    BLD_ROOT_DIR=$OPT_OUT_DIR
fi

BLD_CACHE_DIR=$BLD_ROOT_DIR/cache
BLD_PKG_DIR=$BLD_ROOT_DIR/bld/pkg
BLD_REL_DIR=$BLD_ROOT_DIR
BLD_DONE_SEMAPHORE="BUILD-DONE-SEMAPHORE"
BLD_PKG_COUNT=0

# Global settings.
export PATH="${BLD_REL_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${BLD_REL_DIR}/lib64:${BLD_REL_PATH}/lib:${PATH}"
export MANPATH="${BLD_REL_DIR}/man:${MANPATH}"
export INFOPATH="${BLD_REL_DIR}/info:${MANPATH}"

cat <<EOF

Setup Info

    Base     : $BASENAME
    BuildDir : $BLD_ROOT_DIR
    Date     : $(date)
    Host     : $(hostname)
    LogFile  : $LOGFILE
    Platform : $PLATFORM
    Pwd      : $(pwd)
    User     : $(whoami)
    Version  : $VERSION

    gcc version   : $OPT_GCC_VERSION
    boost version : $OPT_BOOST_VERSION
    boost flavor  : $OPT_BOOST_FLAVOR
    gdb version   : $OPT_GDB_VERSION
EOF

prerequisites

# Allow the user to specify individual build targets.
if (( ${#OPT_TARGETS[@]} == 0 )) ; then
    build_all
else
    OPT_FORCE_REBUILD=1
    for TargetList in ${OPT_TARGETS[@]} ; do
        Targets=($(echo "${TargetList}" | tr ',' ' '))
        for Target in ${Targets[@]} ; do
            $Target
        done
    done
fi

_info_green "Done"
