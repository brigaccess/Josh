. $JOSH/lib/shared.sh

# ———

local THIS_DIR=`dirname "$($JOSH_READLINK -f "$0")"`
local INCLUDE_DIR="`realpath $THIS_DIR/pip`"

local PIP_LIST_ALL="$INCLUDE_DIR/pip_list_all.sh"
local PIP_LIST_TOP="$INCLUDE_DIR/pip_list_top_level.sh"
local PIP_PKG_INFO="$INCLUDE_DIR/pip_pkg_info.sh"

# ———

function virtualenv_path_activate() {
    local venv="`realpath ${VIRTUAL_ENV:-$1}`"
    if [ ! -d "$venv" ]; then
        return 1
    elif [ "$VIRTUAL_ENV" = "$venv" ]; then
        source $venv/bin/activate
    elif [ "$VIRTUAL_ENV" ]; then
        virtualenv_deactivate; source $venv/bin/activate
    else
        source $venv/bin/activate
    fi
}

function virtualenv_deactivate {
    if [ "$VIRTUAL_ENV" != "" ]; then
        source $VIRTUAL_ENV/bin/activate && deactivate
    fi
}

function virtualenv_node_deploy {
    . $JOSH/lib/python.sh
    pip_init || return 1

    local venv="${VIRTUAL_ENV:-''}"
    if [ ! -d "$venv" ]; then
        echo " - fatal: venv must be activated"
        return 1
    fi
    local venvname=`basename "$venv"`

    echo " + using venv: $venvname ($venv)"
    virtualenv_path_activate "$venv"

    local pip="`which -p pip`"
    if [ ! -f "$pip" ]; then
        echo " - fatal: pip in venv \`$VIRTUAL_ENV\` isn't found"
        return 2
    fi
    echo " + using pip: $pip"

    local pip="$pip --no-python-version-warning --disable-pip-version-check --no-input --quiet"
    if [ `$SHELL -c "$pip freeze | grep nodeenv | wc -l"` -eq 0 ]; then
        run_show "$pip install nodeenv" && virtualenv_path_activate "$venv"
    fi

    local nodeenv="`which -p nodeenv`"
    if [ ! -f "$nodeenv" ]; then
        echo " - fatal: nodeenv in venv \`$VIRTUAL_ENV\` isn't found"
        return 3
    fi
    echo " + using nodeenv: $nodeenv"

    if [[ "$1" =~ ^[0-9] ]]; then
        # TODO: need: 14.5 -> 14.5.0 and versionlist too
        local version="$1"
    else
        local version="$($SHELL -c "
            nodeenv --list 2>&1 | sd '\n' ' ' | sd '\s+' '\n' | sort -rV \
            | $FZF \
                --ansi --extended --info='inline' \
                --no-mouse --marker='+' --pointer='>' --margin='0,0,0,0' \
                --tiebreak=index --jump-labels="$FZF_JUMPS" \
                --bind='alt-w:toggle-preview-wrap' \
                --bind='ctrl-c:abort' \
                --bind='ctrl-q:abort' \
                --bind='end:preview-down' \
                --bind='esc:abort' \
                --bind='home:preview-up' \
                --bind='pgdn:preview-page-down' \
                --bind='pgup:preview-page-up' \
                --bind='shift-down:half-page-down' \
                --bind='shift-up:half-page-up' \
                --bind='alt-space:jump-accept' \
                --color="$FZF_THEME" \
                --reverse --min-height='11' --height='11' \
                --prompt='select node version for $venvname > ' \
                -i --select-1 --filepath-word
        ")"
    fi

    if [ "$version" != "" ]; then
        echo " + deploy node v$version"
        run_show "nodeenv --python-virtualenv --node=$version"
    fi

    return 0
}

function get_virtualenv_path {
    if [ "$1" ]; then
        if [ -f "$JOSH_PIP_ENV_PERSISTENT/$1/bin/activate" ]; then
            echo "$JOSH_PIP_ENV_PERSISTENT/$1"
        else
            local temp="`get_tempdir`"
            if [ -f "$temp/env/$1/bin/activate" ]; then
                echo "$temp/env/$1"
            else
                echo " - venv \`$1\` isn't found" >&2
            fi
        fi

    elif [ "$VIRTUAL_ENV" ]; then
        echo "$VIRTUAL_ENV"
    fi
}

function virtualenv_create {
    local cwd="`pwd`"
    local packages="$*"

    if [[ "$1" =~ ^[0-9]\.[0-9]$ ]]; then
        local exe="`which -p python$1`"
        local packages="${@:2}"

    elif [ "$1" = "3" ]; then
        if [ ! -f "$PYTHON3" ]; then
            . $JOSH/lib/python.sh && python_init
            if [ $? -gt 0 ]; then
                echo " - when detect python something wrong, stop" 1>&2
            fi
        fi
        if [ ! -f "$PYTHON3" ]; then
            echo " - default \$PYTHON3=\`$PYTHON3\` isn't accessible" 1>&2
            return 1
        fi
        local exe="$PYTHON3"
        local packages="${@:2}"

    elif [[ "$1" =~ ^[0-9] ]]; then
        echo " - couldn't autodetect python for version \`$1\`" 1>&2
        return 2

    else
        local exe="`which -p python2.7`"
    fi

    virtualenv_deactivate
    if [ ! -f "$exe" ]; then
        echo " - couldn't search selected python for \`$@\`" 1>&2
        return 1
    fi

    if [ ! -f "`which -p virtualenv`" ]; then
        . $JOSH/lib/python.sh && pip_init
        if [ $? -gt 0 ]; then
            echo " - when init virtualenv something wrong, stop" 1>&2
        fi
    fi

    local name="$(dirname `mktemp -duq`)/env/`petname -s . -w 3 -a`"
    mkdir -p "$name" && \
        builtin cd "`realpath $name/../`" && \
        rm -rf "$name" && \
    virtualenv --python=$exe "$name" && \
        source $name/bin/activate && builtin cd $cwd && \
        $SHELL -c "pip install pipdeptree $packages"
}

function virtualenv_temporary_create {
    local cwd="`pwd`"
    local packages="$*"

    if [[ "$1" =~ ^[0-9]\.[0-9]$ ]]; then
        local exe="`which -p python$1`"
        local packages="${@:2}"

    elif [ "$1" = "3" ]; then
        if [ ! -f "$PYTHON3" ]; then
            . $JOSH/lib/python.sh && python_init
            if [ $? -gt 0 ]; then
                echo " - when detect python something wrong, stop" 1>&2
            fi
        fi
        if [ ! -f "$PYTHON3" ]; then
            echo " - default \$PYTHON3=\`$PYTHON3\` isn't accessible" 1>&2
            return 1
        fi
        local exe="$PYTHON3"
        local packages="${@:2}"

    elif [[ "$1" =~ ^[0-9] ]]; then
        echo " - couldn't autodetect python for version \`$1\`" 1>&2
        return 2

    else
        local exe="`which -p python2.7`"
    fi

    virtualenv_deactivate
    if [ ! -f "$exe" ]; then
        echo " - couldn't search selected python for \`$@\`" 1>&2
        return 1
    fi

    if [ ! -f "`which -p virtualenv`" ]; then
        . $JOSH/lib/python.sh && pip_init
        if [ $? -gt 0 ]; then
            echo " - when init virtualenv something wrong, stop" 1>&2
        fi
    fi

    local name="$(dirname `mktemp -duq`)/env/`petname -s . -w 3 -a`"
    mkdir -p "$name" && \
        builtin cd "`realpath $name/../`" && \
        rm -rf "$name" && \
    virtualenv --python=$exe "$name" && \
        source $name/bin/activate && builtin cd $cwd && \
        $SHELL -c "pip install pipdeptree $packages"
}

function chdir_to_virtualenv {
    local venv="`get_virtualenv_path $*`"
    if [ "$venv" ] && [ -d "$venv" ]; then
        builtin cd $venv
        return 0
    fi
    return 1
}

function chdir_to_virtualenv_stdlib {
    local cwd="`pwd`"
    chdir_to_virtualenv $* || ([ $? -gt 0 ] && return 1)

    local env_site=`find lib/ -maxdepth 1 -type d -name 'python*'`
    if [ -d "$env_site/site-packages" ]; then
        builtin cd "$env_site/site-packages"
        [ "${@:2}" ] && builtin cd ${@:2}
    else
        echo " - something wrong for \`$env_path\`, path: \`$env_site\`"
        builtin cd $cwd
    fi
}

function virtualenv_activate {
    local venv="`get_virtualenv_path $*`"
    if [ "$venv" ] && [ -d "$venv" ]; then
        virtualenv_deactivate && source $venv/bin/activate
    fi
}

function virtualenv_temporary_destroy {
    local cwd="`pwd`"
    chdir_to_virtualenv $* || ([ $? -gt 0 ] && return 1)

    local vwd="`pwd`"
    local temp="`get_tempdir`"

    if [[ ! $vwd =~ "^$temp/env" ]]; then
        echo " * can't remove \`$vwd\` because isn't temporary"
        builtin cd $cwd
        return 1
    fi

    if [ "$VIRTUAL_ENV" = "$vwd" ]; then
        run_show "builtin cd $VIRTUAL_ENV/bin && source activate && deactivate && builtin cd .."
    fi
    run_show "rm -rf $vwd 2>/dev/null; builtin cd $cwd || builtin cd ~"
}

# ———

pip_visual_freeze() {
    . $JOSH/lib/python.sh
    pip_init || return 1

    local venv="`basename ${VIRTUAL_ENV:-''}`"
    local preview="echo {2} | xargs -n 1 $SHELL $PIP_PKG_INFO"
    local value="$($SHELL -c "
        $SHELL $PIP_LIST_TOP \
        | $FZF \
            --multi \
            --nth=2 \
            --tiebreak='index' \
            --layout=reverse-list \
            --preview='$preview' \
            --prompt='packages $venv > ' \
            --preview-window="left:`get_preview_width`:noborder" \
            --bind='ctrl-s:reload($SHELL $PIP_LIST_ALL),ctrl-d:reload($SHELL $PIP_LIST_TOP)' \
        | tabulate -i 2 | $UNIQUE_SORT | $LINES_TO_LINE
    ")"

    if [ "$value" != "" ]; then
        if [ "$BUFFER" != "" ]; then
            local command="$BUFFER "
        else
            local command=""
        fi
        LBUFFER="$command$value"
        RBUFFER=''
    fi

    zle reset-prompt
    return 0
}
zle -N pip_visual_freeze

# ———

if [ -d "$VIRTUAL_ENV" ]; then
    virtualenv_path_activate $VIRTUAL_ENV
fi
