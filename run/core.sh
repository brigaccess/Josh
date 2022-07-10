SELF="$0"

function ash.core {
    local root
    root="$(dirname "$SELF")" || return "$?"
    if [ -z "$root" ] || [ ! -x "$root" ]; then
        printf " ** fail ($0): something went wrong: root isn't detected\n" >&2
        return 1
    fi

    source "$root/boot.sh"
    local retval="$?"
    if [ "$retval" -gt 0 ]; then
        printf " ** fail ($0): something went wrong: boot state=$retval\n" >&2
        return 1
    fi
    export ASH="$(fs.realpath "$root/../")"
}


function ash.install {
    local branch cwd changes

    cwd="$PWD"
    function rollback() {
        builtin cd "$cwd"
        term "$1" "something went wrong, state=$2"
        return "$2"
    }

    ash.core || return "$?"
    [ ! -x "$ASH" ] && return 1
    source "$ASH/run/units/compat.sh" && compat.compliance || return "$(rollback "$0" "$?")"

    builtin cd "$ASH"

    changes="$(git status --porcelain=v1 &>>/dev/null | wc -l)" || return "$(rollback "$0" "$?")"
    if [ "$changes" -gt 0 ]; then
        warn "$0" "we have changes in $changes files, skip fetch & pull"

    else

        branch="$(git rev-parse --quiet --abbrev-ref HEAD)" || return "$(rollback "$0" "$?")"
        if [ "$branch" = "HEAD" ] || [ -z "$branch" ]; then
            warn "$0" "can't update from '$branch'"
        else
            info "$0" "update '$branch' into '$ASH'"

            git pull --ff-only --no-edit --no-commit origin "$branch" || return "$(rollback "$0" "$?")"

            git update-index --refresh 1>/dev/null 2>/dev/null || return "$(rollback "$0" "$?")"
        fi
    fi

    if [ -x "$(which git-restore-mtime)" ]; then
        git-restore-mtime --skip-missing --quiet 2>/dev/null
    fi

    info "$0" "our home directory is '$PWD'"

    source "$ASH/run/units/oh-my-zsh.sh" && \
    source "$ASH/run/units/binaries.sh" && \
    source "$ASH/run/units/configs.sh" && \
    source "$ASH/lib/python.sh" && \
    source "$ASH/lib/rust.sh" || rollback "$0" "$?"

    # TODO: export ASH_VERBOSITY="1"

    pip.install $PIP_REQ_PACKAGES && \
    cfg.install && \
    bin.install && \
    omz.install && omz.plugins
    cargo.deploy $CARGO_REQ_PACKAGES
    local result="$?"

    cfg.install
    builtin cd "$cwd"
    return "$result"
}


if [[ -n ${(M)zsh_eval_context:#file} ]]; then
    ash.core
else
    ash.install
fi
