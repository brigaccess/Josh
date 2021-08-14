#!/bin/sh

MIN_PYTHON_VERSION=3.6  # minimal version for modern pip

PIP_REQ_PACKAGES=(
    pip        # python package manager, first
    httpie     # super http client, just try: http head anything.com
    pipdeptree # simple, but powerful tool to manage python requirements
    setuptools
    sshuttle   # swiss knife for ssh tunneling & management
    virtualenv # virtual environments for python packaging
    wheel
)

PIP_OPT_PACKAGES=(
)

function set_defaults() {
    if [ "$JOSH" ] && [ -d "$JOSH" ]; then
        export SOURCE_ROOT="`realpath $JOSH`"

    elif [ ! "$SOURCE_ROOT" ]; then
        if [ ! -f "`which -p realpath`" ]; then
            export SOURCE_ROOT="`dirname $0`/../"
        else
            export SOURCE_ROOT=$(sh -c "realpath `dirname $0`/../")
        fi

        if [ ! -d "$SOURCE_ROOT" ]; then
            echo " - fatal: source root $SOURCE_ROOT isn't correctly defined"
        else
            echo " + init from $SOURCE_ROOT"
            . $SOURCE_ROOT/run/init.sh
        fi
    fi

    if [ ! "$REAL" ]; then
        echo " - fatal: init failed, REAL empty"
        return 255
    fi
    if [ ! "$HTTP_GET" ]; then
        echo " - fatal: init failed, HTTP_GET empty"
        return 255
    fi
    return 0
}

function python_init() {
    set_defaults

    if [ "$SOURCE_ROOT" ] && [ -d "$SOURCE_ROOT" ]; then
        local root="`realpath $SOURCE_ROOT`"

    elif [ "$JOSH" ] && [ -d "$JOSH" ]; then
        local root="`realpath $JOSH`"

    else
        echo " - fatal: source root isn't exists, JOSH:\`$JOSH\`, SOURCE_ROOT:\`$SOURCE_ROOT\`"
        return 255
    fi

    . $root/src/compat.zsh
    . $root/run/units/compat.sh

    if [ -f "$PYTHON3" ]; then
        version_not_compatible \
            $MIN_PYTHON_VERSION \
            `$PYTHON3 --version 2>&1 | $JOSH_GREP -Po '([\d\.]+)$'` || return 0
    fi

    for dir in $(sh -c "echo "$PATH" | sed 's#:#\n#g' | sort -su"); do
        for exe in $(find $dir -type f -name 'python*' 2>/dev/null | sort -Vr); do
            local version=$($exe --version 2>&1 | $JOSH_GREP -Po '([\d\.]+)$')
            version_not_compatible $MIN_PYTHON_VERSION $version || local result="$exe"
            [ "$result" ] && break
        done
        [ "$result" ] && break
    done

    if [ "$result" ]; then
        local python="`realpath $result`"
        if [ -f "$python" ]; then
            export PYTHON3="$python"
            return 0
        fi
    fi
    return 1
}

function pip_init() {
    python_init
    if [ ! -f "$PYTHON3" ]; then
        echo " - fatal: python>=3.6 required!"
        return 1
    fi

    set_defaults
    export PIP_EXE="$REAL/.local/bin/pip"

    url="https://bootstrap.pypa.io/get-pip.py"
    if [ ! -f "$PIP_EXE" ]; then
        local pip_file="/tmp/get-pip.py"

        $SHELL -c "$HTTP_GET $url > $pip_file" && \
            PIP_REQUIRE_VIRTUALENV=false $PYTHON3 $pip_file \
            --no-warn-script-location --user pip

        local retval=$?
        [ -f "$pip_file" ] && unlink "$pip_file"

        if [ "$retval" -gt 0 ]; then
            echo " - fatal: pip deploy failed!"
            return 1
        fi

        if [ ! -f "$PIP_EXE" ]; then
            echo " - fatal: pip isn't installed ($PIP_EXE)"
            return 255
        fi
    fi
    return 0
}

function pip_deploy() {
    local cwd="`pwd`"
    local venv="$VIRTUAL_ENV"

    if [ "$venv" != "" ]; then
        cd $venv/bin && source activate && deactivate; cd $cwd
    fi

    pip_init || return $?
    if [ ! -f "$PIP_EXE" ]; then
        echo " - fatal: pip executive $PIP_EXE isn't found!"
        return 1
    fi

    for line in $@; do
        $SHELL -c "PIP_REQUIRE_VIRTUALENV=false $PIP_EXE install --user --upgrade --upgrade-strategy=eager $line"
    done

    if [ "$venv" != "" ]; then
        cd $venv/bin && source activate
    fi
    return 0
}

function pip_extras() {
    pip_deploy "$PIP_REQ_PACKAGES $PIP_OPT_PACKAGES"
    return 0
}
