#!/bin/zsh

REQUIRED_BINARIES=(
    cc
    make
    pkg-config
    git
    jq
    pv
    python3
    tree
    zsh
)
REQUIRED_LIBRARIES=(
    openssl
)
# python-dev libpq-dev libevent-dev for pgcli

function check_executables() {
    local missing=""
    for exe in $@; do
        if [ ! -x "`lookup $exe`" ]; then
            local missing="$missing $exe"
        fi
    done
    if [ "$missing" ]; then
        echo " + missing required packages:$missing"
        return 1
    fi
    return 0
}


function check_libraries() {
    local missing=""
    for lib in $@; do
        $SHELL -c "pkg-config --libs --cflags $lib" 1&>/dev/null 2&>/dev/null
        if [ "$?" -gt 0 ]; then
            if [ "$lib" = "openssl" ]; then
                if [ "$JOSH_OS" = "MAC" ]; then
                    local lookup_path="/usr/local/opt/"
                elif [ "$JOSH_OS" = "LINUX" ]; then
                    local lookup_path="/usr/lib/"
                elif [ "$JOSH_OS" = "BSD" ]; then
                    local lookup_path="/usr/local/"
                else
                    local missing="$missing $lib"
                    continue
                fi
                echo " * warning: pkg-config $lib failed, we try to lookup openssl.pc in $lookup_path"

                local openssl_path="$(dirname `find $lookup_path -type f -name "openssl.pc" -follow 2>/dev/null | head -n 1`)"
                if [ ! -d "$openssl_path" ]; then
                    echo " * warning: pkg-config $lib: nothing about openssl.pc in $lookup_path"
                    local missing="$missing $lib"
                    continue
                fi
                echo " * warning: retry pkg-config $lib: openssl.pc found in $openssl_path"

                export PKG_CONFIG_PATH="$openssl_path"
                $SHELL -c "pkg-config --libs --cflags $lib" 1&>/dev/null 2&>/dev/null
                if [ "$?" -gt 0 ]; then
                    echo " * warning: pkg-config $lib: nothing about openssl.pc in $PKG_CONFIG_PATH"
                    local missing="$missing $lib"
                    continue
                fi
                echo " * warning: pkg-config $lib: all ok, continue"

            else
                local missing="$missing $lib"
            fi
        fi
    done
    if [ "$missing" ]; then
        echo " + missing required libraries:$missing"
        return 1
    fi
    return 0
}


function version_not_compatible() {
    local grep=${JOSH_GREP:-"`lookup grep`"}
    if [ "$1" != "$2" ]; then
        local choice=$(sh -c "printf '%s\n%s\n' "$1" "$2" | sort --version-sort | tail -n 1")
        [ $(sh -c "printf '%s' "$choice" | $grep -Pv '^($2)$'") ] && return 0
    fi
    return 1
}


function check_compliance() {
    if [ -n "$(uname | grep -i freebsd)" ]; then
        echo " + os: freebsd `uname -srv`"
        export JOSH_OS="BSD"

        local cmd="sudo pkg install -y"
        local pkg="zsh git coreutils gnugrep gnuls gsed jq openssl pkgconf pv python39"
        REQURED_SYSTEM_BINARIES=(
            pkg
            /usr/local/bin/gnuls
            /usr/local/bin/greadlink
            /usr/local/bin/grealpath
            /usr/local/bin/grep
            /usr/local/bin/gsed
        )

    elif [ -n "$(uname | grep -i darwin)" ]; then
        echo " + os: macos `uname -srv`"
        export JOSH_OS="MAC"

        if [ ! -x "`lookup brew`" ]; then
            echo ' - brew for MacOS strictly required, just run: curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | zsh"'
        fi

        local cmd="brew update && brew install"
        local pkg="zsh git coreutils grep gsed jq openssl pkg-config pv python@3 tree"
        REQURED_SYSTEM_BINARIES=(
            brew
            /usr/local/bin/ggrep
            /usr/local/bin/gls
            /usr/local/bin/greadlink
            /usr/local/bin/grealpath
            /usr/local/bin/gsed
        )

    elif [ -n "$(uname -v | grep -Pi '(debian|ubuntu)')" ]; then
        echo " + os: debian-based `uname -srv`"
        export JOSH_OS="LINUX"

        [ -x "`lookup apt`" ] && local bin="apt" || local bin="apt-get"
        local cmd="(sudo $bin update --yes --quiet || true) && sudo $bin install --yes --quiet --no-remove"
        local pkg="zsh git jq pv clang make pkg-config python3 python3-distutils tree libssl-dev python-dev libpq-dev libevent-dev"
        REQURED_SYSTEM_BINARIES=(
            apt
        )

    elif [ -n "$(uname -srv | grep -i gentoo)" ]; then
        echo " + os: gentoo: `uname -srv`"
        export JOSH_OS="LINUX"


    elif [ -n "$(uname -srv | grep -i microsoft)" ] && [ -n "$(uname | grep -i linux)" ]; then
        [ -x "`lookup apt`" ] && local bin="apt" || local bin="apt-get"
        export JOSH_OS="LINUX"
        local cmd="for debian based just run: sudo $bin install --yes --quiet --no-remove"
        local pkg="zsh git jq pv clang make pkg-config python3 python3-distutils tree libssl-dev python-dev libpq-dev libevent-dev"

        if [ -n "$(uname -srv | grep -i microsoft)" ]; then
            echo " + os: windows linux subsystem: `uname -srv`"
        elif [ -n "$(uname | grep -i linux)" ]; then
            echo " - unknown linux: `uname -srv`"
        fi

    else
        echo " - unknown os: `uname -srv`"
        export JOSH_OS="UNKNOWN"
    fi

    check_executables $REQUIRED_BINARIES $REQURED_SYSTEM_BINARIES && \
        check_libraries $REQUIRED_LIBRARIES

    if [ $? -gt 0 ]; then
        local msg=" - please, install required packages and try again"
        [ "$cmd" ] && local msg="$msg: $cmd $pkg"
        if [ ! "$JOSH_SKIP_REQUIREMENTS_CHECK" ]; then
            echo "$msg" && return 1
        else
            echo "$msg"
        fi
    else
        echo " + all requirements exists: $REQUIRED_BINARIES $REQUIRED_LIBRARIES $REQURED_SYSTEM_BINARIES"
    fi
    return 0
}
