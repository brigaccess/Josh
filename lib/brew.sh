#!/bin/zsh

if [[ -n ${(M)zsh_eval_context:#file} ]]; then
    if [ -z "$HTTP_GET" ]; then
        source "`dirname $0`/../run/boot.sh"
    fi

    JOSH_CACHE_DIR="$HOME/.cache/josh"
    if [ ! -d "$JOSH_CACHE_DIR" ]; then
        mkdir -p "$JOSH_CACHE_DIR"
        echo " * make Josh cache directory \`$JOSH_CACHE_DIR\`"
    fi

    if [ -n "$JOSH_DEST" ]; then
        BASE="$JOSH_BASE"
    else
        BASE="$JOSH"
    fi
fi


BREW_REС_PACKAGES=(
    ag    # silver searcher, another one fast source grep on golang
    jq    # JSON swiss-knife, format, highlight, traversal and query tool
    pv    # contatenate pipes with monitoring
    tmux  # terminal multiplexer
    tree  # hierarchy explore tool
)


function brew_root() {
    if [ "$JOSH_OS" = "BSD" ]; then
        echo " - $0 fatal: brew not supported for detected \`$JOSH_OS\`: `uname -srv`" >&2
        return 1

    elif [ "$JOSH_OS" = "MAC" ]; then
        echo " - $0 fatal: brew not supported for detected \`$JOSH_OS\`: `uname -srv`" >&2
        return 1

    else
        echo "$HOME/${JOSH_BREW_HOME:-".brew"}"
    fi
}

function brew_bin() {
    local root="`brew_root`"
    [ -z "$root" ] && return 1

    local bin="$root/bin/brew"
    if [ ! -x "$bin" ]; then
        echo " - $0 fatal: brew binary \`$root/bin/brew\` isn't found" >&2
        return 2
    fi

    echo "$bin"
    return 0
}

function brew_deploy() {
    local root="`brew_root`"
    [ -z "$root" ] && return 1

    if [ -d "$root" ]; then
        echo " - $0 fatal: brew path \`$root\` exists" >&2
        return 2

    elif [ ! -d "`fs_dirname $root`" ]; then
        echo " - $0 fatal: brew path \`$root\` subroot isn't found" >&2
        return 3
    fi

    git clone --depth 1 "https://github.com/Homebrew/brew" "$root" && \
    eval $($root/bin/brew shellenv) && \
    rehash

    local bin="`brew_bin`"
    [ ! -x "$bin" ] && return 4
    $bin update --force

    return "$?"
}

function brew_init() {
    local root="`brew_root`"
    [ -z "$root" ] && return 1

    if [ ! -x "$root/bin/brew" ]; then
        echo " - $0 fatal: brew binary \`$root/bin/brew\` isn't found, deploy now" >&2
        brew_deploy || return 2
    fi

    brew_env
}

function brew_install() {
    brew_init || return 1

    if [ -z "$*" ]; then
        echo " - $0 fatal: nothing to do" >&2
        return 2
    fi

    local bin="`brew_bin`"
    [ ! -x "$bin" ] && return 3
    $bin install $*

    for row in $*; do
        local exe="`fs_basename $row`"
        if [ -z "$exe" ]; then
            echo " - $0 fatal: basename for \`$row\` empty" >&2
            continue
        fi

        local bin="$HOMEBREW_PREFIX/bin/$exe"
        if [ -x "$bin" ]; then
            shortcut "$bin" >/dev/null
            echo " + $0 info: $exe -> `which $exe`" >&2
        fi
    done
}

function brew_extras() {
    run_show "brew_install $BREW_REС_PACKAGES"
    return 0
}

function brew_update() {
    brew_env || return 1

    local bin="`brew_bin`"
    [ ! -x "$bin" ] && return 2
    $bin update && $bin upgrade
}

function brew_env() {
    local root="`brew_root 2>/dev/null`"
    [ -z "$root" ] && return 1
    [ ! -x "$root/bin/brew" ] && return 2

    eval $($root/bin/brew shellenv)
    HOMEBREW_CELLAR="$root/Cellar"
    HOMEBREW_PREFIX="$root"
    HOMEBREW_REPOSITORY="$root"
    HOMEBREW_SHELLENV_PREFIX="$root"
    rehash
}
