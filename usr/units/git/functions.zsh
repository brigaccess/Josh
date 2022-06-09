local GET_ROOT='git rev-parse --quiet --show-toplevel'
local GET_HASH='git rev-parse --quiet --verify HEAD 2>/dev/null'
local GET_BRANCH='git rev-parse --quiet --abbrev-ref HEAD 2>/dev/null'

# command line batch generators

function git.cmd.checkout {
    if [ -z "$1" ]; then
        fail $0 "\$1 - branch required"
        return 1

    elif [[ "$1" =~ '^[0-9]+' ]]; then
        if [ -n "$JOSH_BRANCH_PREFIX" ]; then
            local branch="$JOSH_BRANCH_PREFIX-$1"
        else
            fail $0 "branch name can't starts by digit"
            return 2
        fi
    else
        local branch="$1"
    fi
    echo "git checkout -b \"$branch\" 2>/dev/null || git switch \"$branch\""
}

function git.cmd.fetch {
    local branch
    branch="$(git.this.branch)"
    if [ "$?" -gt 0 ] || [ -z "$branch" ]; then
        return 1
    fi

    local function __temp() {
        echo "git fetch origin \"$1\":\"$1\" 2>&1"
    }

    local cmd=''
    for arg in $@; do
        if [ "$arg" = "$branch" ]; then
            continue
        elif [ -n "$cmd" ]; then
            local cmd="$cmd && `__temp $arg`"
        else
            local cmd="`__temp $arg`"
        fi
    done
    unset __temp

    if [ -n "$cmd" ]; then
        local cmd="$cmd && git fetch --tags"
    else
        local cmd="git fetch --tags"
    fi
    echo "$cmd"
}

function git.cmd.pull {
    local branch
    branch="${1:-$(git.this.branch)}"
    if [ "$?" -gt 0 ] || [ -z "$branch" ]; then
        return 1
    fi
    echo "git pull --ff-only --no-edit --no-commit origin $branch"
}

function git.cmd.pullmerge {
    local branch
    branch="${1:-$(git.this.branch)}"
    if [ "$?" -gt 0 ] || [ -z "$branch" ]; then
        return 1
    fi
    echo "git pull --no-edit --no-commit origin $branch"
}

# core functions

function git.this.root {
    local result
    if [ -z "$1" ]; then
        result="$(fs_realpath `eval "$GET_ROOT 2>/dev/null"`)"
        local retval="$?"
    else
        if [ -d "$1" ]; then
            local cwd="$PWD"
            builtin cd "$1"
            result="$(git.this.root)"
            local retval="$?"
            builtin cd "$cwd"

        else
            fail $0 "path '$1' isn't acessible"
            return 1
        fi
    fi

    if [ "$retval" -eq 0 ] && [ -d "$result" ]; then
        echo "$result"
    else
        return "$retval"
    fi
}

function git.this.hash {
    local result
    result="$(eval "$GET_HASH")"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    fi
}

function git.this.branch {
    local result
    result="$(eval $GET_BRANCH)"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1

    elif [ "$result" = "HEAD" ]; then
        if [ -z "$(git name-rev --name-only HEAD 2>&1 | grep -Pv '^(Could not get sha1)')" ]; then
            warn $0 "empty repository $(git.this.root) without any commits?"
            local result="$(git symbolic-ref --short HEAD)"
        else
            fail $0 "something went wrong"
            return 2
        fi
    fi
    echo "$result"
}

function git.this.state {
    local root
    root="$(git.this.root 2>/dev/null)"
    if [ "$?" -gt 0 ] || [ -z "$root" ]; then
        return 1
    fi

    if [ -d "$root/.git/rebase-merge" ] || [ -d "$root/.git/rebase-apply" ]; then
        local state="rebase"

    elif [ -f "$root/.git/CHERRY_PICK_HEAD" ]; then
        local state="cherry-pick"

    elif [ -f "$root/.git/MERGE_HEAD" ]; then
        local state="merge"
    fi

    [ -z "$state" ] && return 1
    echo "$state"
}

# just functions

function git.branch.delete.force {
    if [ -z "$1" ]; then
        fail $0 "\$1 - branch required"
        return 1
    fi
    printf " => git branch -D $1 && git push origin --delete $1\n"
    return $?
}

function git.branch.rename {
    if [ -n "$2" ]; then
        if [ "$1" = "$2" ]; then
            fail $0 "source and target branch names must be different"
            return 1
        fi
        local src="$1"
        local dst="$2"

    elif [ -n "$1" ]; then
        local dst="$1"
        local src
        src="$(git.this.branch)"
        if [ "$?" -gt 0 ] || [ -z "$src" ]; then
            return 2
        fi
    else
        fail $0 "old_name new_name or just new_name (rename current) "
        return 3
    fi
    printf " => git branch -m $src $dst && git push origin :$src $dst\n"
}

function git.checkout.actual {
    local result
    result="$(git.this.branch)"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    fi
    git.pull.reset "$result" || return "$?"
    git.checkout.current $*
}

function git.checkout.current {
    local result
    result="$(git.cmd.checkout $*)"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    fi
    run_show "$result"
    return "$?"
}

function git.fetch {
    local result
    result="$(git.cmd.fetch $@)"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    fi
    run_show "$result" 2>&1 | grep -v 'up to date'
    return "$?"
}

function git.fetch.merge {
    local result
    result="${1:-$(git.this.branch)}"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    fi

    git.fetch "$result"
    [ "$?" -gt 0 ] && return 2

    run_show "git merge origin/$result"
    return "$?"
}

function git.branch.select {
    [ -z "$1" ] && return 1

    local result="$(git.this.branch)"

    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    elif [ "$1" = "$result" ]; then
        return 2
    fi

    [ -z "$(git.this.root)" ] && return 3

    local cmd="git fetch origin \"$1\":\"$1\" && git.is_clean && git checkout --force --quiet $1 && git reset --hard $1 && git pull origin $1"
    run_show "$cmd"
    return "$?"
}

function git.branch.tag {
    if [ -z "$1" ]; then
        fail $0 "tag required"
        return 1

    elif [ -n "$2" ]; then
        local tag="$2"
        local branch="$1"

    else
        local tag="$1"
        local branch
        branch="$(git.this.branch)"
        if [ "$?" -gt 0 ] || [ -z "$branch" ]; then
            fail $0 "branch couldn't detected"
            return 2
        fi
    fi

    info $0 "$branch/$tag"

    git.is_clean           || return "$?"
    git checkout "$branch" || return "$?"
    git.pull "$branch"     || return "$?"
    git.tag.set "$tag"
    return "$?"
}

function git.pull {
    local result
    result="$(git.cmd.pull $@)"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    fi

    run_show "$result" 2>&1 | grep -v 'up to date'
    local retval="$?"
    git.mtime.set 2>&1
    return "$retval"
}

function git.pull.merge {
    local result
    result="$(git.cmd.pullmerge $@)"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    fi

    run_show "$result" 2>&1 | grep -v 'up to date'
    local retval="$?"
    git.mtime.set 2>&1
    return "$retval"
}

function git.pull.reset {
    local result
    result="${1:-$(git.this.branch)}"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    fi

    git.is_clean                               || return "$?"
    git.fetch "$result"                        || return "$?"
    run_show "git reset --hard origin/$result" || return "$?"
    git.pull $result
    return "$?"
}

function git.push {
    local result
    result="${1:-$(git.this.branch)}"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    fi
    run_show "git push origin $result"
    return "$?"
}

function git.push.force {
    local result
    result="${1:-$(git.this.branch)}"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    fi
    run_show "git push --force origin $result"
    return $?
}

function git.mtime.set {
    local result
    if [ -x "$(which git-restore-mtime)" ]; then
        result="${1:-$(git.this.root 2>/dev/null)}"
        if [ "$?" -gt 0 ] || [ -z "$result" ]; then
            return 1
        fi

        git-restore-mtime --skip-missing --work-tree "$result/" --git-dir "$result/.git/" "$result/"
        return "$?"
    fi
    return 2
}

function git.is_clean {
    local result
    if [ -z "$1" ]; then
        result="$(git.this.root)"
    else
        result="$(git.this.root "$1")"
    fi

    if [ "$?" -eq 2 ] && [ -z "$result" ]; then
        return 0
    fi

    local modified='echo $(git ls-files --modified `git rev-parse --show-toplevel`)$(git ls-files --deleted --others --exclude-standard `git rev-parse --show-toplevel`)'
    if [ -n "$($SHELL -c "$modified")" ]; then
        warn $0 "$root isn't clean"
        return 1
    fi
}

function git.tag.set {
    if [ -z "$1" ]; then
        fail $0 "\$1 - tag required"
        return 1
    fi
    run_show "git tag -a $1 -m \"$1\" && git push --tags && git fetch --tags"
    return "$?"
}

function git.tag.unset {
    if [ -z "$1" ]; then
        fail $0 "\$1 - tag required"
        return 1
    fi
    run_show "git tag -d \"$1\" && git push --delete origin \"$1\""
    return "$?"
}

# user helpers

function git.branch.delete {
    local result
    result="${1:-$(git.this.branch)}"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    fi

    if [ "$result" = "master" ] || [ "$result" = "develop" ]; then
        fail $0 "'$result' is protected"
        return 2
    fi

    git.is_clean || return "$?"

    run_show "git reset --hard && (git checkout develop 2>/dev/null 1>/dev/null 2> /dev/null || git checkout master 2>/dev/null 1>/dev/null) && git branch -D \"$result\" && git remote prune origin"
    printf " => git push origin --delete $result\n" >&2
    return "$?"
}

function git.branch.DELETE.REMOTE {
    local result
    branch="${1:-$(git.this.branch)}"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    fi

    if [ "$branch" = "master" ] || [ "$branch" = "develop" ]; then
        fail $0 "'$branch' is protected"
        return 2
    fi

    git.is_clean || return "$?"

    run_show "git reset --hard && (git checkout develop 2>/dev/null 1>/dev/null 2> /dev/null || git checkout master 2>/dev/null 1>/dev/null) && git branch -D \"$branch\" && git push origin --delete \"$branch\" || true && git remote prune origin"
    return "$?"
}

function git.squash.pushed {
    local result
    result="${1:-$(git.this.branch)}"
    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 1
    fi

    result="$(
        git show-branch | grep '*' | \
        grep -v "`git rev-parse --abbrev-ref HEAD`" | \
        head -n 1 | sd '^(.+)\[' '' | tabulate -d '] ' -i 1)"

    if [ "$?" -gt 0 ] || [ -z "$result" ]; then
        return 2
    fi
    run_show "git rebase --interactive --no-autosquash --no-autostash --strategy=recursive --strategy-option=ours --strategy-option=diff-algorithm=histogram \"$result\""
}

function git.nested {
    local cwd="$PWD"
    local root="$(fs_realpath "${1:-.}")"

    if [ ! -d "$root" ]; then
        fail $0 "working path '$root' isn't accessible"
        return 1
    fi

    local header=""
    local mtime="$(which git-restore-mtime)"

    find "$root" -maxdepth 2 -type d -name .git | sort | while read git_directory
    do
        current_path="$(fs_dirname "$(fs_realpath $git_directory)")"

        if [ -z "$header" ] && [ "$root" != "$current_path" ]; then
            PRE=1 info $0 "update '$(fs_realpath "$root")'"
            if [ -x "$(which gfold)" ]; then
                gfold -d classic
            fi
            printf "\n" >&2
            local header="1"
        fi

        builtin cd "$current_path"
        local branch="`$SHELL -c "$GET_BRANCH"`"
        if [ "$?" -gt 0 ] || [ -z "$branch" ]; then
            warn $0 "something went wrong in '$current_path', skip"
            builtin cd "$cwd"
            continue
        fi

        POST=0 info $0 "$branch in '$current_path'.. "
        local cmd="git fetch origin master && git fetch --tags"

        if git.is_clean 2>/dev/null; then

            if [ "$branch" != "master" ]; then
                printf "fetch, reset and pull '$branch'.. " >&2
                local cmd="$cmd && git fetch origin \"$branch\" && git reset --hard \"origin/$branch\" && git pull origin \"$branch\""

            else
                printf "reset and pull '$branch'.. " >&2
                local cmd="$cmd && git reset --hard \"origin/$branch\" && git pull origin \"$branch\""
            fi

        else
            if [ "$branch" != "master" ]; then
                printf "unclean, just fetch '$branch'.. " >&2
                local cmd="$cmd && git fetch origin \"$branch\""
            else
                printf "unclean, just fetch '$branch'.. " >&2
            fi
        fi

        eval.retval "$cmd" 1>/dev/null 2>/dev/null
        if [ "$?" -eq 0 ]; then
            printf "ok\n" >&2
        else
            printf "err\n" >&2
        fi

        if [ -x "$mtime" ]; then
            git-restore-mtime --skip-missing 2>/dev/null
        fi

        builtin cd "$cwd"
    done
}


function_exists DROP_THIS_BRANCH_RIGHT_NOW && echo 'DROP_THIS_BRANCH_RIGHT_NOW'
function_exists DROP_THIS_BRANCH_RIGHT_NOW2 && echo 'DROP_THIS_BRANCH_RIGHT_NOW2'

JOSH_DEPRECATIONS[DROP_THIS_BRANCH_RIGHT_NOW]=git.branch.DELETE.REMOTE
JOSH_DEPRECATIONS[cmd_git_checkout]=git.cmd.checkout
JOSH_DEPRECATIONS[cmd_git_fetch]=git.cmd.fetch
JOSH_DEPRECATIONS[cmd_git_pull]=git.cmd.pull
JOSH_DEPRECATIONS[cmd_git_pull_merge]=git.cmd.pullmerge
JOSH_DEPRECATIONS[drop_this_branch_right_now]=git.branch.delete
JOSH_DEPRECATIONS[get_repository_state]=git.this.state
JOSH_DEPRECATIONS[git_branch_delete]=git.branch.delete.force
JOSH_DEPRECATIONS[git_branch_rename]=git.branch.rename
JOSH_DEPRECATIONS[git_checkout_from_actual]=git.checkout.actual
JOSH_DEPRECATIONS[git_checkout_from_current]=git.checkout.current
JOSH_DEPRECATIONS[git_current_branch]=git.this.branch
JOSH_DEPRECATIONS[git_current_hash]=git.this.hash
JOSH_DEPRECATIONS[git_fetch]=git.fetch
JOSH_DEPRECATIONS[git_fetch_checkout_branch]=git.branch.select
JOSH_DEPRECATIONS[git_fetch_merge]=git.fetch.merge
JOSH_DEPRECATIONS[git_pull]=git.pull
JOSH_DEPRECATIONS[git_pull_merge]=git.pull.merge
JOSH_DEPRECATIONS[git_pull_reset]=git.pull.reset
JOSH_DEPRECATIONS[git_push]=git.push
JOSH_DEPRECATIONS[git_push_force]=git.push.force
JOSH_DEPRECATIONS[git_repository_clean]=git.is_clean
JOSH_DEPRECATIONS[git_rewind_time]=git.mtime.set
JOSH_DEPRECATIONS[git_root]=git.this.root
JOSH_DEPRECATIONS[git_set_branch_tag]=git.branch.tag
JOSH_DEPRECATIONS[git_set_tag]=git.tag.set
JOSH_DEPRECATIONS[git_squash_already_pushed]=git.squash.pushed
JOSH_DEPRECATIONS[git_unset_tag]=git.tag.unset
