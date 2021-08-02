GIT_ROOT='git rev-parse --quiet --show-toplevel'
GIT_BRANCH='git rev-parse --quiet --abbrev-ref HEAD 2>/dev/null'
GIT_BRANCH2='git name-rev --name-only HEAD | cut -d "~" -f 1'
GIT_HASH='git rev-parse --quiet --verify HEAD'
GIT_LATEST='git log --all -n 1 --pretty="%H"'

# https://git-scm.com/docs/git-status - file statuses
# https://stackoverflow.com/questions/53298546/git-file-statuses-of-files

local THIS_DIR=`dirname "$(readlink -f "$0")"`
local GIT_LIST_NEW="$THIS_DIR/scripts/git_list_new.sh"
local GIT_DIFF_FROM_TAG="$THIS_DIR/scripts/git_diff_from_tag.sh"
local GIT_HASH_FROM_TAG="$THIS_DIR/scripts/git_hash_from_tag.sh"
local GIT_LIST_BRANCHES_EXCEPT_THIS="$THIS_DIR/scripts/git_list_branches_except_this.sh"
local GIT_LIST_BRANCHES="$THIS_DIR/scripts/git_list_branches.sh"
local GIT_LIST_BRANCH_FILES="$THIS_DIR/scripts/git_list_branch_files.sh"
local GIT_TAG_FROM_STR="$THIS_DIR/scripts/git_tag_from_str.sh"
local GIT_TAG_FROM_STR="$THIS_DIR/scripts/git_tag_from_str.sh"
local GIT_SEARCH_SETUPCFG="$THIS_DIR/scripts/git_search_setupcfg.sh"

local GIT_LIST_TAGS="$THIS_DIR/scripts/git_list_tags.sh"
local GIT_LIST_CHANGED='git ls-files --modified `git rev-parse --show-toplevel`'



git_add_created() {
    local cmd="$LISTER_FILE --paging='always' {}"
    while true; do
        # TODO: абсолютные пути в отличии от add_changed
        local files="$(zsh "$GIT_LIST_NEW" | sort | uniq | \
            fzf \
                --multi --color="$FZF_THEME" \
                --prompt="add new:" \
                --info='inline' --ansi --extended --filepath-word --no-mouse \
                --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                --bind='esc:cancel' \
                --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                --bind='home:preview-up' --bind='end:preview-down' \
                --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                --bind='alt-w:toggle-preview-wrap' \
                --bind="alt-bs:toggle-preview" \
                --preview-window="right:89:noborder" \
                --preview="$cmd" \
            | sort | sed -z 's/\n/ /g' | awk '{$1=$1};1'
        )"

        if [[ "$BUFFER" != "" ]]; then
            local prefix="$BUFFER && git"
        else
            local prefix="git"
        fi

        if [[ "$files" != "" ]]; then
            local branch="${1:-`sh -c "$GIT_BRANCH"`}"
            LBUFFER="$prefix add $files && gmm "
            LBUFFER+='"'
            LBUFFER+="$branch: "
            RBUFFER='"'
            local ret=$?
            zle redisplay
            typeset -f zle-line-init >/dev/null && zle zle-line-init
            return $ret
        else
            zle reset-prompt
            return 0
        fi
    done
}
zle -N git_add_created


git_add_changed() {
    # https://github.com/junegunn/fzf/blob/master/man/man1/fzf.1
    local differ="git diff --color=always -- {} | $DELTA"
    while true; do
        local files="$(echo "$GIT_LIST_CHANGED" | zsh | sort | uniq | \
            fzf \
                --multi --color="$FZF_THEME" \
                --prompt="add changed:" \
                --info='inline' --ansi --extended --filepath-word --no-mouse \
                --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                --bind='esc:cancel' \
                --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                --bind='home:preview-up' --bind='end:preview-down' \
                --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                --bind='alt-w:toggle-preview-wrap' \
                --bind="alt-bs:toggle-preview" \
                --preview-window="right:89:noborder" \
                --preview="$differ" \
            | sort | sed -z 's/\n/ /g' | awk '{$1=$1};1'
        )"

        if [[ "$BUFFER" != "" ]]; then
            local prefix="$BUFFER && git"
        else
            local prefix="git"
        fi

        if [[ "$files" != "" ]]; then
            local branch="${1:-`sh -c "$GIT_BRANCH"`}"
            LBUFFER="$prefix add $files && gmm "
            LBUFFER+='"'
            LBUFFER+="$branch: "
            RBUFFER='"'
            local ret=$?
            zle redisplay
            typeset -f zle-line-init >/dev/null && zle zle-line-init
            return $ret
        else
            zle reset-prompt
            return 0
        fi
    done
}
zle -N git_add_changed


git_restore_changed() {
    local cmd="git diff --color=always -- {} | $DELTA"
    while true; do
        local files="$(echo "$GIT_LIST_CHANGED" | zsh | sort | uniq | \
            fzf \
                --multi --color="$FZF_THEME" \
                --prompt="reset:" \
                --info='inline' --ansi --extended --filepath-word --no-mouse \
                --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                --bind='esc:cancel' \
                --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                --bind='home:preview-up' --bind='end:preview-down' \
                --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                --bind='alt-w:toggle-preview-wrap' \
                --bind="alt-bs:toggle-preview" \
                --preview-window="right:89:noborder" \
                --preview="$cmd" \
            | sort | sed -z 's/\n/ /g' | awk '{$1=$1};1'
        )"

        if [[ "$BUFFER" != "" ]]; then
            local prefix="$BUFFER && git"
        else
            local prefix="git"
        fi

        if [[ "$files" != "" ]]; then
            # LBUFFER="git restore $files"
            LBUFFER="$prefix checkout -- $files"
            local ret=$?
            zle redisplay
            typeset -f zle-line-init >/dev/null && zle zle-line-init
            return $ret
        else
            zle reset-prompt
            return 0
        fi
    done
}
zle -N git_restore_changed


show_all_files() {
    local cmd="$LISTER_FILE --paging='always' {}"
    eval "fd \
        --color always \
        --type file --follow --hidden \
        --exclude .git/ \
        --exclude '*.pyc' \
        --exclude node_modules/ \
        --glob \"*\" . " | \
    fzf \
        --color="$FZF_THEME" \
        --prompt="preview:" \
        --info='inline' --ansi --extended --filepath-word --no-mouse \
        --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
        --bind='esc:cancel' \
        --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
        --bind='home:preview-up' --bind='end:preview-down' \
        --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
        --bind='alt-w:toggle-preview-wrap' \
        --bind="alt-bs:toggle-preview" \
        --preview-window="right:89:noborder" \
        --preview="$LISTER_FILE --terminal-width=\$FZF_PREVIEW_COLUMNS {}" \
        --bind="enter:execute($cmd)"

    local ret=$?
    zle redisplay
    typeset -f zle-line-init >/dev/null && zle zle-line-init
    return $ret
}
zle -N show_all_files

git_branch_history() {
    # https://git-scm.com/docs/git-show
    # https://git-scm.com/docs/pretty-formats

    local branch="$(echo "$GIT_BRANCH" | zsh)"

    if [ "`git rev-parse --quiet --show-toplevel 2>/dev/null`" ]; then
        if [ $OS_TYPE = "BSD" ]; then
            local cmd="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I% git show --diff-algorithm=histogram % | $DELTA --width $COLUMNS| less -R"
        else
            local cmd="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I% git show --diff-algorithm=histogram % | $DELTA --paging='always'"
        fi
        eval "git log --color=always --format='%C(auto)%h%d %s %C(black)%C(bold)%ae %cr' --first-parent $branch" | awk '{print NR,$0}' | \
            fzf \
                --color="$FZF_THEME" \
                --prompt="$branch:" \
                --info='inline' --ansi --extended --filepath-word --no-mouse \
                --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                --bind='esc:cancel' \
                --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                --bind='home:preview-up' --bind='end:preview-down' \
                --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                --bind='alt-w:toggle-preview-wrap' \
                --bind="alt-bs:toggle-preview" \
                --preview-window="right:89:noborder" \
                --preview=$cmd \
                --bind="enter:execute($cmd)"
        local ret=$?
        zle redisplay
        typeset -f zle-line-init >/dev/null && zle zle-line-init
        return $ret
    fi
}
zle -N git_branch_history


git_all_history() {
    # https://git-scm.com/docs/git-show
    # https://git-scm.com/docs/pretty-formats

    if [ "`git rev-parse --quiet --show-toplevel 2>/dev/null`" ]; then
        if [ $OS_TYPE = "BSD" ]; then
            local cmd="echo {} | cut -d ' ' -f 1 | $DELTA --width $COLUMNS | less -R"
        else
            local cmd="echo {} | cut -d ' ' -f 1 | xargs -I% git diff % | $DELTA --paging='always'"
        fi

        while true; do
            local branch="$(zsh $GIT_LIST_BRANCHES | sort | \
                fzf \
                    --multi --color="$FZF_THEME" \
                    --prompt="log:" \
                    --info='inline' --ansi --extended --filepath-word --no-mouse \
                    --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                    --bind='esc:cancel' \
                    --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                    --bind='home:preview-up' --bind='end:preview-down' \
                    --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                    --bind='alt-w:toggle-preview-wrap' \
                    --bind="alt-bs:toggle-preview" \
                    --preview-window="right:89:noborder" \
                    --preview="$cmd" | cut -d ' ' -f 1
            )"
            if [[ "$branch" == "" ]]; then
                zle redisplay
                zle reset-prompt
                typeset -f zle-line-init >/dev/null && zle zle-line-init
                return 0
            fi

            if [ $OS_TYPE = "BSD" ]; then
                local cmd="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I% git show --diff-algorithm=histogram % | $DELTA --width $COLUMNS| less -R"
            else
                local cmd="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I% git show --diff-algorithm=histogram % | $DELTA --paging='always'"
            fi
            eval "git log --color=always --format='%C(auto)%h%d %s %C(black)%C(bold)%ae %cr' $branch" | grep -P '([0-9a-f]{6,})' | awk '{print NR,$0}' | \
                fzf \
                    --color="$FZF_THEME" \
                    --prompt="$branch:" \
                    --info='inline' --ansi --extended --filepath-word --no-mouse \
                    --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                    --bind='esc:cancel' \
                    --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                    --bind='home:preview-up' --bind='end:preview-down' \
                    --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                    --bind='alt-w:toggle-preview-wrap' \
                    --bind="alt-bs:toggle-preview" \
                    --preview-window="right:89:noborder" \
                    --preview=$cmd \
                    --bind="enter:execute($cmd)"
            local ret=$?
            if [[ "$ret" != "130" ]]; then
                zle redisplay
                typeset -f zle-line-init >/dev/null && zle zle-line-init
                return $ret
            fi
        done
    fi
}
zle -N git_all_history


git_file_history() {
    local branch="$(echo "$GIT_BRANCH" | zsh)"
    local diff_file="'git show --diff-algorithm=histogram --format=\"%C(yellow)%h %ad %an <%ae>%n%s%C(black)%C(bold) %cr\" \$0 --"
    if [ "`git rev-parse --quiet --show-toplevel 2>/dev/null`" ]; then
        while true; do
            local file="$(git ls-files | \
                fzf \
                    --color="$FZF_THEME" \
                    --prompt="$branch:file:" \
                    --info='inline' --ansi --extended --filepath-word --no-mouse \
                    --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                    --bind='esc:cancel' \
                    --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                    --bind='home:preview-up' --bind='end:preview-down' \
                    --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                    --bind='alt-w:toggle-preview-wrap' \
                    --bind="alt-bs:toggle-preview" \
                    --preview-window="right:89:noborder" \
                    --preview="$LISTER_FILE --terminal-width=\$FZF_PREVIEW_COLUMNS {}" \
                | sort | sed -z 's/\n/ /g' | awk '{$1=$1};1'
            )"

            if [[ "$file" == "" ]]; then
                zle redisplay
                zle reset-prompt
                typeset -f zle-line-init >/dev/null && zle zle-line-init
                return 0
            fi

            local ext="$(echo "$file" | xargs -I% basename % | grep --color=never -Po '(?<=.\.)([^\.]+)$')"

            if [ $OS_TYPE = "BSD" ]; then
                local diff_view="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -l bash -c $diff_file $file' | $DELTA --width $COLUMNS | less -R"
            else
                local diff_view="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -l bash -c $diff_file $file' | $DELTA --paging='always'"
            fi

            if [ $OS_TYPE = "BSD" ]; then
                local file_view="echo {} | cut -d ' ' -f 1 | $DELTA --width $COLUMNS | less -R"
            else
                local file_view="echo {} | cut -d ' ' -f 1 | xargs -I^^ git show ^^:./$file | $LISTER_FILE --paging=always"
                if [ $ext != "" ]; then
                    local file_view="$file_view --language $ext"
                fi
            fi

            eval "git log --color=always --format='%C(auto)%h%d %s %C(black)%C(bold)%ae %cr' $branch -- $file"  | sed -r 's%^(\*\s+)%%g' | \
                fzf \
                    --color="$FZF_THEME" \
                    --prompt="$branch:$file:" \
                    --info='inline' --ansi --extended --filepath-word --no-mouse \
                    --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                    --bind='esc:cancel' \
                    --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                    --bind='home:preview-up' --bind='end:preview-down' \
                    --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                    --bind='alt-w:toggle-preview-wrap' \
                    --bind="alt-bs:toggle-preview" \
                    --preview-window="right:89:noborder" \
                    --preview=$diff_view \
                    --bind="enter:execute($file_view)"
        done
    fi
}
zle -N git_file_history


git_checkout_tag() {
    local latest="$(echo "$GIT_LATEST" | zsh)"

    if [ "`git rev-parse --quiet --show-toplevel 2>/dev/null`" ]; then
        if [ $OS_TYPE = "BSD" ]; then
            local cmd="echo {} | zsh $GIT_DIFF_FROM_TAG | $DELTA --width $COLUMNS | less -R"
        else
            local cmd="echo {} | zsh $GIT_DIFF_FROM_TAG | $DELTA --paging='always'"
        fi

        local commit="$(echo "$latest" | zsh $GIT_LIST_TAGS | \
            fzf \
                --color="$FZF_THEME" \
                --prompt="-> tag:" \
                --info='inline' --ansi --extended --filepath-word --no-mouse \
                --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                --bind='esc:cancel' \
                --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                --bind='home:preview-up' --bind='end:preview-down' \
                --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                --bind='alt-w:toggle-preview-wrap' \
                --bind="alt-bs:toggle-preview" \
                --preview-window="right:89:noborder" \
                --preview=$cmd | zsh $GIT_TAG_FROM_STR
        )"

        if [[ "$commit" == "" ]]; then
            zle reset-prompt
            return 0
        else
            if [[ "$BUFFER" != "" ]]; then
                LBUFFER="$BUFFER && git checkout $commit"
                local ret=$?
                zle redisplay
                typeset -f zle-line-init >/dev/null && zle zle-line-init
                return $ret
            else
                git checkout $commit 2>/dev/null 1>/dev/null
                zle reset-prompt
                return 0
            fi
        fi
    fi
}
zle -N git_checkout_tag


git_fetch_branch() {
    if [ "`git rev-parse --quiet --show-toplevel 2>/dev/null`" ]; then
        if [ $OS_TYPE = "BSD" ]; then
            local cmd="echo {} | zsh $GIT_DIFF_FROM_TAG | $DELTA --width $COLUMNS | less -R"
        else
            local cmd="echo {} | zsh $GIT_DIFF_FROM_TAG | $DELTA --paging='always'"
        fi

        local branches="$(git ls-remote -h origin | sed -r 's%^[a-f0-9]{40}\s+refs/heads/%%g' | sort | \
            fzf \
                --multi --color="$FZF_THEME" \
                --prompt="fetch:" --tac \
                --info='inline' --ansi --extended --filepath-word --no-mouse \
                --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                --bind='esc:cancel' \
                --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g'
        )"
        local track="git branch -f --track $(echo "$branches" | sed -r "s% % \&\& git branch -f --track %g")"

        if [[ "$branches" == "" ]]; then
            zle reset-prompt
            return 0
        else
            local cmd="$track && git fetch origin $branches"

            if [[ "$BUFFER" != "" ]]; then
                LBUFFER="$BUFFER && $cmd"
                local ret=$?
                zle redisplay
                typeset -f zle-line-init >/dev/null && zle zle-line-init
                return $ret
            else
                run_show "$cmd"
                zle reset-prompt
                return 0
            fi
        fi
    fi
}
zle -N git_fetch_branch


git_delete_branch() {
    if [ "`git rev-parse --quiet --show-toplevel 2>/dev/null`" ]; then
        if [ $OS_TYPE = "BSD" ]; then
            local cmd="echo {} | zsh $GIT_DIFF_FROM_TAG | $DELTA --width $COLUMNS | less -R"
        else
            local cmd="echo {} | zsh $GIT_DIFF_FROM_TAG | $DELTA --paging='always'"
        fi

        local branches="$(git ls-remote -h origin | sed -r 's%^[a-f0-9]{40}\s+refs/heads/%%g' | sort | \
            fzf \
                --multi --color="$FZF_THEME" \
                --prompt="rm:" \
                --info='inline' --ansi --extended --filepath-word --no-mouse \
                --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                --bind='esc:cancel' \
                --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g'
        )"

        if [[ "$branches" == "" ]]; then
            zle reset-prompt
            return 0
        else
            local cmd="git push origin --delete $branches && git branch -D $branches"

            if [[ "$BUFFER" != "" ]]; then
                LBUFFER="$BUFFER && $cmd"
                local ret=$?
                zle redisplay
                typeset -f zle-line-init >/dev/null && zle zle-line-init
                return $ret
            else
                LBUFFER="$cmd"
                zle reset-prompt
                return 0
            fi
        fi
    fi
}
zle -N git_delete_branch


git_checkout_branch() {
    if [ "`git rev-parse --quiet --show-toplevel 2>/dev/null`" ]; then
        if [ $OS_TYPE = "BSD" ]; then
            local cmd="echo {} | cut -d ' ' -f 1 | $DELTA --width $COLUMNS | less -R"
        else
            local cmd="echo {} | cut -d ' ' -f 1 | xargs -I% git diff % | $DELTA --paging='always'"
        fi

        local branch="$(zsh $GIT_LIST_BRANCHES_EXCEPT_THIS | \
            fzf \
                --multi --color="$FZF_THEME" \
                --prompt="-> branch:" \
                --info='inline' --ansi --extended --filepath-word --no-mouse \
                --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                --bind='esc:cancel' \
                --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                --bind='home:preview-up' --bind='end:preview-down' \
                --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                --bind='alt-w:toggle-preview-wrap' \
                --bind="alt-bs:toggle-preview" \
                --preview-window="right:89:noborder" \
                --preview="$cmd" | cut -d ' ' -f 1
        )"

        if [[ "$branch" == "" ]]; then
            zle reset-prompt
            return 0
        else
            if [[ "$BUFFER" != "" ]]; then
                LBUFFER="$BUFFER && git checkout $branch"
                local ret=$?
                zle redisplay
                typeset -f zle-line-init >/dev/null && zle zle-line-init
                return $ret
            else
                git checkout $branch 2>/dev/null 1>/dev/null
                zle reset-prompt
                return 0
            fi
        fi
    fi
}
zle -N git_checkout_branch


git_checkout_commit() {
    local branch="$(echo "$GIT_BRANCH" | zsh)"

    if [ "`git rev-parse --quiet --show-toplevel 2>/dev/null`" ]; then
        if [ $OS_TYPE = "BSD" ]; then
            local cmd="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I% git show --diff-algorithm=histogram % | $DELTA --width $COLUMNS| less -R"
        else
            local cmd="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I% git show --diff-algorithm=histogram % | $DELTA --paging='always'"
        fi

        local result="$(git log --color=always --format='%C(auto)%h%d %s %C(black)%C(bold)%ae %cr' --first-parent $branch | \
            fzf \
                --color="$FZF_THEME" \
                --prompt="-> hash:" \
                --info='inline' --ansi --extended --filepath-word --no-mouse \
                --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                --bind='esc:cancel' \
                --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                --bind='home:preview-up' --bind='end:preview-down' \
                --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                --margin=0,0,0,0 \
                --bind='alt-w:toggle-preview-wrap' \
                --bind="alt-bs:toggle-preview" \
                --preview-window="right:89:noborder" \
                --preview=$cmd | cut -d ' ' -f 1
        )"

        if [[ "$result" == "" ]]; then
            zle reset-prompt
            return 0
        else
            if [[ "$BUFFER" != "" ]]; then
                LBUFFER="$BUFFER && git checkout $result"
                local ret=$?
                zle redisplay
                typeset -f zle-line-init >/dev/null && zle zle-line-init
                return $ret
            else
                git checkout $result 2>/dev/null
                zle reset-prompt
                return 0
            fi
        fi
    fi
}
zle -N git_checkout_commit

git_file_history_full() {
    local diff_file="'git show --diff-algorithm=histogram --format=\"%C(yellow)%h %ad %an <%ae>%n%s%C(black)%C(bold) %cr\" \$0 --"
    if [ "`git rev-parse --quiet --show-toplevel 2>/dev/null`" ]; then
        if [ $OS_TYPE = "BSD" ]; then
            local cmd="echo {} | cut -d ' ' -f 1 | $DELTA --width $COLUMNS | less -R"
        else
            local cmd="echo {} | cut -d ' ' -f 1 | xargs -I% git diff % | $DELTA --paging='always'"
        fi

        local branch="$(zsh $GIT_LIST_BRANCHES | sort | \
            fzf \
                --multi --color="$FZF_THEME" \
                --prompt="branch:file:" \
                --info='inline' --ansi --extended --filepath-word --no-mouse \
                --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                --bind='esc:cancel' \
                --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                --bind='home:preview-up' --bind='end:preview-down' \
                --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                --bind='alt-w:toggle-preview-wrap' \
                --bind="alt-bs:toggle-preview" \
                --preview-window="right:89:noborder" \
                --preview="$cmd" | cut -d ' ' -f 1
        )"
        if [[ "$branch" == "" ]]; then
            zle redisplay
            zle reset-prompt
            typeset -f zle-line-init >/dev/null && zle zle-line-init
            return 0
        fi

        while true; do
            local file="$(echo "$branch" | zsh $GIT_LIST_BRANCH_FILES | \
                fzf \
                    --color="$FZF_THEME" \
                    --prompt="$branch:file:" \
                    --info='inline' --ansi --extended --filepath-word --no-mouse \
                    --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                    --bind='esc:cancel' \
                    --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                    --bind='home:preview-up' --bind='end:preview-down' \
                    --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                    --bind='alt-w:toggle-preview-wrap' \
                    --bind="alt-bs:toggle-preview" \
                    --preview-window="right:89:noborder" \
                    --preview="$LISTER_FILE --terminal-width=\$FZF_PREVIEW_COLUMNS {}" \
                | sort | sed -z 's/\n/ /g' | awk '{$1=$1};1'
            )"

            if [[ "$file" == "" ]]; then
                zle redisplay
                zle reset-prompt
                typeset -f zle-line-init >/dev/null && zle zle-line-init
                return 0
            fi

            local ext="$(echo "$file" | xargs -I% basename % | grep --color=never -Po '(?<=.\.)([^\.]+)$')"

            if [ $OS_TYPE = "BSD" ]; then
                local diff_view="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -l bash -c $diff_file $file' | $DELTA --width $COLUMNS | less -R"
            else
                local diff_view="echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -l bash -c $diff_file $file' | $DELTA --paging='always'"
            fi

            if [ $OS_TYPE = "BSD" ]; then
                local file_view="echo {} | cut -d ' ' -f 1 | $DELTA --width $COLUMNS | less -R"
            else
                local file_view="echo {} | cut -d ' ' -f 1 | xargs -I^^ git show ^^:./$file | $LISTER_FILE --paging=always"
                if [ $ext != "" ]; then
                    local file_view="$file_view --language $ext"
                fi
            fi

            eval "git log --color=always --format='%C(auto)%h%d %s %C(black)%C(bold)%ae %cr' $branch -- $file" | \
                fzf \
                    --color="$FZF_THEME" \
                    --prompt="$branch:$file:" \
                    --info='inline' --ansi --extended --filepath-word --no-mouse \
                    --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                    --bind='esc:cancel' \
                    --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                    --bind='home:preview-up' --bind='end:preview-down' \
                    --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                    --bind='alt-w:toggle-preview-wrap' \
                    --bind="alt-bs:toggle-preview" \
                    --preview-window="right:89:noborder" \
                    --preview=$diff_view \
                    --bind="enter:execute($file_view)"
        done
    fi
}
zle -N git_file_history_full


git_merge_branch() {
    if [ "`git rev-parse --quiet --show-toplevel 2>/dev/null`" ]; then
        if [ $OS_TYPE = "BSD" ]; then
            local cmd="echo {} | cut -d ' ' -f 1 | $DELTA --width $COLUMNS | less -R"
        else
            local cmd="echo {} | cut -d ' ' -f 1 | xargs -I% git diff % | $DELTA --paging='always'"
        fi

        local branch="$(zsh $GIT_LIST_BRANCHES | \
            fzf \
                --multi --color="$FZF_THEME" \
                --prompt="merge:" \
                --info='inline' --ansi --extended --filepath-word --no-mouse \
                --tiebreak=length,index --pointer=">" --marker="+" --margin=0,0,0,0 \
                --bind='esc:cancel' \
                --bind='pgup:preview-page-up' --bind='pgdn:preview-page-down'\
                --bind='home:preview-up' --bind='end:preview-down' \
                --bind='shift-up:half-page-up' --bind='shift-down:half-page-down' \
                --bind='alt-w:toggle-preview-wrap' \
                --bind="alt-bs:toggle-preview" \
                --preview-window="right:89:noborder" \
                --preview="$cmd" | cut -d ' ' -f 1
        )"

        if [[ "$branch" == "" ]]; then
            zle reset-prompt
            return 0
        else
            if [[ "$BUFFER" != "" ]]; then
                LBUFFER="$BUFFER $branch"
                local ret=$?
                zle redisplay
                typeset -f zle-line-init >/dev/null && zle zle-line-init
                return $ret
            else
                run_show "git fetch origin $branch 2>/dev/null 1>/dev/null && git merge origin/$branch"
                zle reset-prompt
                return 0
            fi
        fi
    fi
}
zle -N git_merge_branch

function spll() {
    local branch="${1:-`sh -c "$GIT_BRANCH"`}"
    if [ "$branch" = "" ]; then
        return 1
    fi
    run_show "git pull origin $branch"
}

function sfet() {
    local branch="${1:-`sh -c "$GIT_BRANCH"`}"
    if [ "$branch" = "" ]; then
        return 1
    fi
    run_show "git fetch origin $branch && git fetch --tags --all"
}

function sall() {
    local branch="${1:-`sh -c "$GIT_BRANCH"`}"
    if [ "$branch" = "" ]; then
        echo " - Branch required." 1>&2
        return 1
    fi

    is_repository_clean
    if [ $? -gt 0 ]; then
        return 1
    fi

    sfet $branch 2>/dev/null
    if [ $? -gt 0 ]; then
        return 1
    fi

    run_show "git reset --hard origin/$branch"
    if [ $? -gt 0 ]; then
        return 1
    fi
    spll $branch
}

function spsh() {
    local branch="${1:-`sh -c "$GIT_BRANCH"`}"
    run_show "git push origin $branch"
}

function sfm() {
    local branch="${1:-`sh -c "$GIT_BRANCH"`}"
    sfet $branch 2>/dev/null
    if [ $? -gt 0 ]; then
        return 1
    fi

    run_show "git merge origin/$branch"
}

function sbrm() {
    if [ "$1" = "" ]; then
        echo " - Branch name required." 1>&2
        return 1
    fi
    run_show "git branch -D $1 && git push origin --delete $1"
}

function sbmv() {
    if [ "$1" = "" ]; then
        echo " - Branch name required." 1>&2
        return 1
    fi
    local branch="${2:-`sh -c "$GIT_BRANCH"`}"
    run_show "git branch -m $branch $1 && git push origin :$branch $1"
}

function stag() {
    if [ "$1" = "" ]; then
        echo " - Tag required." 1>&2
        return 1
    fi
    run_show "git tag -a $1 -m \"$1\" && git push --tags && git fetch --tags"
}

function smtag() {
    if [ "$1" = "" ]; then
        echo " - Tag required." 1>&2
        return 1
    fi

    is_repository_clean
    if [ $? -gt 0 ]; then
        return 1
    fi

    gcm
    if [ $? -gt 0 ]; then
        return 1
    fi

    spll
    if [ $? -gt 0 ]; then
        return 1
    fi
    stag $1
}

function stag-() {
    if [ "$1" = "" ]; then
        echo " - Tag required." 1>&2
        return 1
    fi
    run_show "git tag -d \"$1\" && git push --delete origin \"$1\""
}

function sck() {
    if [ "$1" = "" ]; then
        echo " ! task name needed" 1>&2
        return 1
    fi
    local match=`echo "$1" | grep -Po '^([0-9])'`
    if [ "$1" = "" ]; then
        local branch="$1"
    else
        echo " - Branch name cannot be starting with digit." 1>&2
        return 1
    fi
    run_show "git checkout -b $branch 2> /dev/null || git checkout $branch"
}

function drop_this_branch_right_now() {
    is_repository_clean
    if [ $? -gt 0 ]; then
        return 1
    fi

    local branch="${1:-`sh -c "$GIT_BRANCH"`}"
    if [ "$branch" = "master" ]; then
        echo " ! Cannot delete MASTER branch" 1>&2
        return 1
    fi

    if [ "$branch" = "develop" ]; then
        echo " ! Cannot delete DEVELOP branch" 1>&2
        return 1
    fi

    run_show "git reset --hard && (git checkout develop 2>/dev/null 1>/dev/null 2> /dev/null || git checkout master 2>/dev/null 1>/dev/null) && git branch -D $branch"
    echo " => git push origin --delete $branch" 1>&2
}

function DROP_THIS_BRANCH_RIGHT_NOW() {
    is_repository_clean
    if [ $? -gt 0 ]; then
        return 1
    fi

    local branch="${1:-`sh -c "$GIT_BRANCH"`}"
    if [ "$branch" = "master" ]; then
        echo " ! Cannot delete MASTER branch" 1>&2
        return 1
    fi

    if [ "$branch" = "develop" ]; then
        echo " ! Cannot delete DEVELOP branch" 1>&2
        return 1
    fi

    local cmd="git reset --hard && (git checkout develop 2>/dev/null 1>/dev/null 2> /dev/null || git checkout master 2>/dev/null 1>/dev/null) && git branch -D $branch && git push origin --delete $branch"
    echo " -> $cmd" 1>&2
    eval ${cmd}
}

function is_repository_clean() {
    local modified='echo $(git ls-files --modified `git rev-parse --show-toplevel`)$(git ls-files --deleted --others --exclude-standard `git rev-parse --show-toplevel`)'
    if [ "`echo "$modified" | zsh`" != "" ]
    then
        local root="$(echo "$GIT_ROOT" | zsh)"
        echo " * isn't clean, found unstages changes: $root"
        return 1
    fi
}

function chdir_to_setupcfg {
    if [ ! -f 'setup.cfg' ]; then
        local root=`cat "$GIT_SEARCH_SETUPCFG" | zsh`
        if [ "$root" = "" ]; then
            echo " - setup.cfg not found in $cwd" 1>&2
            return 1
        fi
        cd $root
    fi
}

function gub() {
    cwd=`pwd`
    find . -maxdepth 3 -type d -name .git | while read git_directory
    do
        current_path=$(dirname "$git_directory")
        cd "${current_path}"
        local branch="`sh -c "$GIT_BRANCH"`"

        echo ""
        echo "    `pwd` <- $branch"
        run_silent "git fetch origin master && git fetch --tags --all"

        is_repository_clean
        if [ $? -gt 0 ]; then
            if [ "$branch" != "master" ]; then
                run_silent "git fetch origin $branch"
                echo "  - $branch modified, just fetch remote"
            fi
        else
            if [ "$branch" != "master" ]; then
                run_silent "git fetch origin $branch && git reset --hard origin/$branch && git pull origin $branch"
                echo "  + $branch fetch, reset and pull"
            else
                run_silent "git reset --hard origin/$branch && git pull origin $branch"
                echo "  + $branch reset and pull"
            fi
        fi
        cd "${cwd}"
    done
}

alias gmm='git commit -m'
alias gdd='git diff --name-only'
alias gdr='git ls-files --modified `git rev-parse --show-toplevel`'

# bindkey "^[^M" accept-and-hold # Esc-Enter

bindkey "^a"   git_add_created
bindkey "\ea"  git_add_changed
# bindkey "^[A"  git_restore_changed
bindkey "\e^a" git_restore_changed

bindkey "^s"   git_checkout_commit
bindkey "\es"  git_checkout_branch
bindkey "^[S"  git_merge_branch
bindkey "\e^s" git_checkout_tag

bindkey "\eq"  git_branch_history
bindkey "^[Q"  git_file_history
bindkey "^q"   git_all_history
bindkey "\e^q" git_file_history_full

bindkey "\ef"  git_fetch_branch
# bindkey "^[F"  git_delete_branch
bindkey "\e^f"  git_delete_branch
