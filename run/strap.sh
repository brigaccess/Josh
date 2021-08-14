#!/bin/sh

export SOURCE_ROOT=$(sh -c "realpath `dirname $0`/../")

if [ ! "$REAL" ]; then
    echo " + init from $SOURCE_ROOT" 1>&2
    . $SOURCE_ROOT/run/init.sh

    if [ ! "$REAL" ]; then
        echo " - fatal: init failed" 1>&2
        return 255
    fi
fi

if [ ! "$HTTP_GET" ]; then
    echo " - fatal: curl, wget, fetch or httpie doesn't exists" 1>&2
    exit 255
else
    echo " * http backend: $HTTP_GET" 1>&2
fi

export CONFIG_DIR="$REAL/.config"
export MERGE_DIR="$REAL/josh.base"


function check_requirements() {
    . $SOURCE_ROOT/run/units/compat.sh
    check_compliance && return 255
    return 0
}

function prepare_and_deploy() {
    cd "$SOURCE_ROOT" &&
    git pull origin master && \
    . $SOURCE_ROOT/run/units/oh-my-zsh.sh && \
    . $SOURCE_ROOT/run/units/binaries.sh && \
    . $SOURCE_ROOT/run/units/configs.sh && \
    . $SOURCE_ROOT/lib/python.sh && \
    . $SOURCE_ROOT/lib/rust.sh

    [ $? -gt 0 ] && return 1

    (pip_deploy $PIP_REQ_PACKAGES || \
        echo " - python related functionality has been disabled" 1>&2) && \
    deploy_ohmyzsh && \
    deploy_extensions && \
    deploy_binaries && \
    cargo_deploy $CARGO_REQ_PACKAGES && \
    zero_configuration

    [ $? -gt 0 ] && return 2

    return 0
}

function replace_existing_installation() {
    if [ "$ZSH" != "$SOURCE_ROOT" ]; then
        merge_josh_ohmyzsh && \
        save_previous_installation && \
        rename_and_link

        [ $? -gt 0 ] && return 3

        cd $REAL && echo ' + oh my josh!' 1>&2
    fi
}