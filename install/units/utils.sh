#!/bin/sh

if [ ! "$HTTP_GET" ]; then
    echo " - fatal: init failed, HTTP_GET empty"
    exit 255
fi
if [ ! "$MERGE_DIR" ]; then
    echo " - fatal: init failed, MERGE_DIR empty"
    exit 255
fi

CUSTOM_BIN_DIR="$MERGE_DIR/custom/bin"

# ——— starship prompt

function deploy_starship() {
    url='https://starship.rs/install.sh'
    [ ! -d "$CUSTOM_BIN_DIR" ] && mkdir -p "$CUSTOM_BIN_DIR"

    if [ ! -f "$CUSTOM_BIN_DIR/starship" ]; then
        # static binary from official installer not found, ok
        if [ -f "`which starship`" ]; then
            echo " + use installed starship from `which starship`"
        else
            # and binary not found in system -> download
            echo " + deploy starship to $CUSTOM_BIN_DIR/starship"
            $SHELL -c "$HTTP_GET $url" | BIN_DIR=$CUSTOM_BIN_DIR FORCE=1 $SHELL
            [ $? -gt 0 ] && echo " - failed starship"
        fi
    fi
    return 0
}

# ——— fzf search

function deploy_fzf() {
    url='https://github.com/junegunn/fzf.git'
    clone="`which git` clone --depth 1"
    [ ! -d "$CUSTOM_BIN_DIR" ] && mkdir -p "$CUSTOM_BIN_DIR"

    if [ ! -f "$CUSTOM_BIN_DIR/fzf" ]; then
        # $CUSTOM_BIN_DIR/fzf --version | head -n 1 | awk '{print $1}'
        echo " + deploy fzf to $CUSTOM_BIN_DIR/fzf"
        tempdir="`mktemp -d`"
        rm -rf "$tempdir"
        $SHELL -c "$clone $url $tempdir && $tempdir/install --completion --key-bindings --update-rc --bin && cp -f $tempdir/bin/fzf $CUSTOM_BIN_DIR/fzf && rm -rf $tempdir"
        [ $? -gt 0 ] && echo " - failed fzf"
    fi
    return 0
}

# ——— micro editor

function deploy_micro() {
    url='https://getmic.ro'
    [ ! -d "$CUSTOM_BIN_DIR" ] && mkdir -p "$CUSTOM_BIN_DIR"

    if [ ! -f "$CUSTOM_BIN_DIR/micro" ]; then
        # $CUSTOM_BIN_DIR/micro --version | head -n 1 | awk '{print $2}'
        echo " + deploy micro: $CUSTOM_BIN_DIR/micro"
        cd "$CUSTOM_BIN_DIR" && $SHELL -c "$HTTP_GET $url | $SHELL"
        [ $? -gt 0 ] && echo " + failed micro: $CUSTOM_BIN_DIR/micro"
        $SHELL -c "$CUSTOM_BIN_DIR/micro -plugin install fzf wc detectindent bounce editorconfig quickfix"
    fi
    return 0
}