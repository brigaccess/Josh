[ -z "$SOURCES_CACHE" ] && declare -aUg SOURCES_CACHE=() && SOURCES_CACHE+=($0)

local THIS_SOURCE="$(fs.gethash "$0")"
if [ -n "$THIS_SOURCE" ] && [[ "${SOURCES_CACHE[(Ie)$THIS_SOURCE]}" -eq 0 ]]; then
    SOURCES_CACHE+=("$THIS_SOURCE")

    local FZF_JUMPS='0123456789abcdefghijklmnopqrstuvwxyz'
    local FZF="fzf --ansi --extended --info='inline' --no-mouse --marker='+' --pointer='>' --margin='0,0,0,0' --padding='0,0,0,0' --tiebreak=length,index --jump-labels=\"$FZF_JUMPS\" --bind='alt-space:jump-accept' --bind='alt-w:toggle-preview-wrap' --bind='ctrl-c:abort' --bind='ctrl-q:abort' --bind='end:preview-down' --bind='esc:cancel' --bind='home:preview-up' --bind='pgdn:preview-page-down' --bind='pgup:preview-page-up' --bind='shift-down:half-page-down' --bind='shift-up:half-page-up'"
    [ $FZF_THEME ] && local FZF="$FZF --color=\"$FZF_THEME\""

    local UNIQUE_SORT="runiq - | proximity-sort ."
    local LINES_TO_LINE="sd '\n' ' ' | awk '{\$1=\$1};1'"


    function misc.cpu.count {
        if [ "$JOSH_OS" = 'BSD' ]; then
            local cores="$(sysctl kern.smp.cores | grep -Po '\d$')"
        else
            local cores="$(grep --count -Po 'processor\s+:\s*\d+\s*$' /proc/cpuinfo)"
        fi

        if [ ! "$cores" -gt 0 ]; then
            echo "1"
        else
            echo "$cores"
        fi
    }

    function misc.preview.width {
        let width="$COLUMNS - ($COLUMNS / 3 + 10)"
        [ $width -lt 84 ] && local width=84

        echo "$width"
        export JOSH_WIDTH="$width"
    }

    function mkcd {
        [ -z "$1" ] && return 1
        mkdir -p "$*" && cd "$*"
    }

    function run_show {
        local cmd="$*"
        [ -z "$cmd" ] && return 1
        echo " -> $cmd" 1>&2
        eval ${cmd} 1>&2
    }

    function run_silent {
        local cmd="$*"
        [ -z "$cmd" ] && return 1
        echo " -> $cmd" 1>&2
        eval ${cmd} 1>/dev/null 2>/dev/null
    }

    function run_to_stdout {
        local cmd="$*"
        [ -z "$cmd" ] && return 1
        eval ${cmd} 2>&1
    }

    function run_hide {
        local cmd="$*"
        [ -z "$cmd" ] && return 1
        eval ${cmd} 1>/dev/null 2>/dev/null
    }

    function fs.lm {
        local args="$*"
        [ -x "$1" ] && local args="$(fs.realpath "$1") ${@:2}"
        local cmd="find $args -printf \"%T@ %p\n\" | sort -n | tail -n 1"
        eval ${cmd}
    }

    function fs.lm.dirs {
        local args="$*"
        [ -x "$1" ] && local args="$(fs.realpath "$1") ${@:2}"
        local cmd="find $args -type d -not -path '*/.git*' -printf \"%T@ %p\n\" | sort -n | tail -n 1 | grep -Po '\d+' | head -n 1"
        eval ${cmd}
    }
fi
