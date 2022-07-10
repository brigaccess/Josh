#!/bin/zsh


export LOCAL_BIN="$HOME/.local/bin"
[ ! -d "$LOCAL_BIN" ] && mkdir -p "$LOCAL_BIN"
[ -z "$PLUGINS_ROOT" ] && source "$(fs.dirname $0)/oh-my-zsh.sh"


# ——— ondir events runner

function bin.compile_ondir {
    if [ -x "$LOCAL_BIN/ondir" ]; then
        return 0
    fi

    if [ -z "$PLUGINS_ROOT" ]; then
        info $0 "plugins dir isn't set"
        return 1

    elif [ ! -d "$PLUGINS_ROOT/ondir" ]; then
        git clone --depth 1 "https://github.com/alecthomas/ondir.git" "$PLUGINS_ROOT/ondir"
    fi

    local cwd="$PWD"
    info $0 "compile ondir in '$PLUGINS_ROOT' -> '$LOCAL_BIN'"
    builtin cd "$PLUGINS_ROOT/ondir" && make clean && make && mv ondir "$LOCAL_BIN/ondir" && make clean

    local retval="$?"
    [ "$retval" -gt 0 ] && fail $0 "something went wrong"

    builtin cd "$cwd"
    return "$retval"
}

# ——— fzf search

function bin.compile_fzf {
    local url='https://github.com/junegunn/fzf.git'
    local clone="$(which git) clone --depth 1"

    [ ! -d "$LOCAL_BIN" ] && mkdir -p "$LOCAL_BIN"
    if [ ! -d "$LOCAL_BIN" ]; then
        fail $0 "binary dir doesn't exist, LOCAL_BIN '$LOCAL_BIN'"
        return 1

    elif [ -x "$LOCAL_BIN/fzf" ]; then
        [ -f "$LOCAL_BIN/fzf.bak" ] && rm "$LOCAL_BIN/fzf.bak"

        if [ "$(find $LOCAL_BIN/fzf -mmin +129600 2>/dev/null | grep fzf)" ]; then
            mv "$LOCAL_BIN/fzf" "$LOCAL_BIN/fzf.bak"
        fi
    fi

    if [ ! -f "$LOCAL_BIN/fzf" ]; then
        info $0 "deploy fzf to $LOCAL_BIN/fzf"

        local tempdir="$(fs.dirname `mktemp -duq`)/fzf"
        [ -d "$tempdir" ] && rm -rf "$tempdir"

        $SHELL -c "$clone $url $tempdir && $tempdir/install --completion --key-bindings --update-rc --bin && cp -f $tempdir/bin/fzf $LOCAL_BIN/fzf && rm -rf $tempdir"
        [ "$?" -gt 0 ] && fail $0 "something went wrong"
    fi

    if [ -f "$LOCAL_BIN/fzf.bak" ]; then
        if [ -f "$LOCAL_BIN/fzf" ]; then
            rm "$LOCAL_BIN/fzf.bak"
        else
            mv "$LOCAL_BIN/fzf.bak" "$LOCAL_BIN/fzf"
        fi
    fi
}

# ——— micro editor

function bin.deploy_micro {
    local url='https://getmic.ro'

    if [ -z "$HTTP_GET" ]; then
        fail $0 "HTTP_GET isn't set"
        return 1

    elif [ ! -x "$LOCAL_BIN/micro" ]; then
        # $LOCAL_BIN/micro --version | head -n 1 | awk '{print $2}'

        local cwd="$PWD"
        info $0 "deploy micro: $LOCAL_BIN/micro"
        builtin cd "$LOCAL_BIN" && $SHELL -c "$HTTP_GET $url | $SHELL"

        [ "$?" -gt 0 ] && fail $0 "something went wrong"
        $SHELL -c "$LOCAL_BIN/micro -plugin install fzf wc detectindent bounce editorconfig quickfix"
        builtin cd "$cwd"
    fi
    source "$ASH/run/units/configs.sh"
    cfg.copy "$ASH/usr/share/micro_config.json" "$CONFIG_DIR/micro/settings.json"
    cfg.copy "$ASH/usr/share/micro_binds.json" "$CONFIG_DIR/micro/bindings.json"
}

# ——— tmux plugin manager

function bin.deploy_tmux_plugins {
    local TMUX_DEST="$HOME/.tmux/plugins"

    [ ! -d "$TMUX_DEST" ] && mkdir -p "$TMUX_DEST"
    if [ ! -d "$TMUX_DEST" ]; then
        fail $0 "binary dir isn't exist, TMUX_DEST '$TMUX_DEST'"
        return 1

    elif [ ! -x "$TMUX_DEST/tpm" ]; then
        git clone --depth 1 "https://github.com/tmux-plugins/tpm" "$TMUX_DEST/tpm"
        [ "$?" -gt 0 ] && return 2
    fi

    if [ -x "$HOME/.tmux/plugins/tpm/tpm" ]; then
        export TMUX_PLUGIN_MANAGER_PATH="$HOME/.tmux/plugins"
    fi

    if [ -x "$(which bash)" ]; then
        bash "$HOME/.tmux/plugins/tpm/scripts/install_plugins.sh"
    else
        warn $0 "it's funny, but tmux plugin manager required bash for installation bootstrap"
    fi
}


function bin.link_fpp {
    local src="$PLUGINS_ROOT/fpp"

    if [ -z "$PLUGINS_ROOT" ]; then
        fail $0 "plugins dir isn't set"
        return 1

    elif [ ! -d "$src" ]; then
        info $0 "deploy to '$PLUGINS_ROOT'"
        git clone --depth 1 "https://github.com/facebook/PathPicker.git" "$src"
        local retval="$?"
    fi

    if [ -x "$src/fpp" ]; then
        local dst="$(fs.link "$src/fpp")"
        if [ -z "$dst" ]; then
            local retval="127"
        else
            info $0 "fpp -> $dst"
        fi
    fi

    [ "$retval" -gt 0 ] && fail $0 "something went wrong"
    return "$retval"
}

function bin.link_git_tools {
    local src="$PLUGINS_ROOT/git-tools"

    if [ -z "$PLUGINS_ROOT" ]; then
        fail $0 "plugins dir isn't set"
        return 1

    elif [ ! -d "$src" ]; then
        info $0 "deploy '$PLUGINS_ROOT'"
        git clone --depth 1 "https://github.com/MestreLion/git-tools.git" "$src"
        local retval="$?"
    fi

    if [ -d "$src" ]; then
        find "$src" -maxdepth 1 -type f -executable | while read exe
        do
            if [ -x "$exe" ]; then
                local dst="$(fs.link "$exe")"
                if [ -z "$dst" ]; then
                    local retval="127"
                else
                    info $0 "'$(fs.basename "$dst")' -> '$dst'"
                fi
            fi
        done
    fi

    [ "$retval" -gt 0 ] && fail $0 "something went wrong"
    return "$retval"
}

function bin.install {
    if [ ! -x "$ASH" ]; then
        term $0 "something went wrong, ASH path empty"
        return 1
    fi

    bin.compile_fzf
    bin.deploy_micro
    bin.deploy_tmux_plugins
    bin.compile_ondir
    bin.link_fpp
    bin.link_git_tools
}
