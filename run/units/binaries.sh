#!/bin/zsh

if [[ -n ${(M)zsh_eval_context:#file} ]]; then
    [ -z "$HTTP_GET" ] && source "`dirname $0`/../boot.sh"

    BINARY_DEST="$HOME/.local/bin"
    [ ! -d "$BINARY_DEST" ] && mkdir -p "$BINARY_DEST"

    if [ -n "$JOSH_DEST" ]; then
        echo " + compile binaries to \`$BINARY_DEST\`"
        BASE="$JOSH_BASE"
    else
        BASE="$JOSH"
    fi
fi

# ——— ondir events runner

function compile_ondir() {
    if [ -x "$BINARY_DEST/ondir" ]; then
        return 0
    fi

    [ -z "$OMZ_PLUGIN_DIR" ] && source "`dirname $0`/oh-my-zsh.sh"

    if [ ! "$OMZ_PLUGIN_DIR" ]; then
        echo " - warning by ondir: plugins dir isn't detected, BINARY_DEST:\`$BINARY_DEST\`"
        return 1

    elif [ ! -d "$OMZ_PLUGIN_DIR/ondir" ]; then
        git clone --depth 1 "https://github.com/alecthomas/ondir.git" "$OMZ_PLUGIN_DIR/ondir"

    fi

    local cwd="`pwd`"
    echo " + deploy ondir to $BINARY_DEST/ondir"
    builtin cd "$OMZ_PLUGIN_DIR/ondir" && make clean && make && mv ondir "$BINARY_DEST/ondir" && make clean

    local retval="$?"
    [ "$retval" -gt 0 ] && echo " - warning: failed ondir $BINARY_DEST/ondir"

    builtin cd "$cwd"
    return "$retval"
}

# ——— fzf search

function compile_fzf() {
    url='https://github.com/junegunn/fzf.git'
    clone="`which git` clone --depth 1"
    [ ! -d "$BINARY_DEST" ] && mkdir -p "$BINARY_DEST"

    if [ -x "$BINARY_DEST/fzf" ]; then
        [ -f "$BINARY_DEST/fzf.bak" ] && rm "$BINARY_DEST/fzf.bak"

        if [ "`find $BINARY_DEST/fzf -mmin +129600 2>/dev/null | grep fzf`" ]; then
            mv "$BINARY_DEST/fzf" "$BINARY_DEST/fzf.bak"
        fi
    fi

    if [ ! -f "$BINARY_DEST/fzf" ]; then
        echo " + deploy fzf to $BINARY_DEST/fzf"

        local tempdir="$(dirname `mktemp -duq`)/fzf"
        [ -d "$tempdir" ] && rm -rf "$tempdir"

        $SHELL -c "$clone $url $tempdir && $tempdir/install --completion --key-bindings --update-rc --bin && cp -f $tempdir/bin/fzf $BINARY_DEST/fzf && rm -rf $tempdir"
        [ $? -gt 0 ] && echo " - warning: failed fzf $BINARY_DEST/fzf"
    fi

    if [ -f "$BINARY_DEST/fzf.bak" ]; then
        if [ -f "$BINARY_DEST/fzf" ]; then
            rm "$BINARY_DEST/fzf.bak"
        else
            mv "$BINARY_DEST/fzf.bak" "$BINARY_DEST/fzf"
        fi
    fi
    return 0
}

# ——— micro editor

function deploy_micro() {
    url='https://getmic.ro'
    [ ! -d "$BINARY_DEST" ] && mkdir -p "$BINARY_DEST"

    if [ ! -x "$BINARY_DEST/micro" ]; then
        # $BINARY_DEST/micro --version | head -n 1 | awk '{print $2}'

        local cwd="`pwd`"
        echo " + deploy micro: $BINARY_DEST/micro"
        cd "$BINARY_DEST" && $SHELL -c "$HTTP_GET $url | $SHELL"

        [ $? -gt 0 ] && echo " + warning: failed micro $BINARY_DEST/micro"
        $SHELL -c "$BINARY_DEST/micro -plugin install fzf wc detectindent bounce editorconfig quickfix"
        builtin cd "$cwd"
    fi
    source "$BASE/run/units/configs.sh" && copy_config "$CONFIG_ROOT/micro.json" "$CONFIG_DIR/micro/settings.json"
    return 0
}


function deploy_binaries() {
    compile_fzf && \
    deploy_micro && \
    compile_ondir
    return "$?"
}
