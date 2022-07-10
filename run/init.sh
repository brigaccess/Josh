[ -z "$SOURCES_CACHE" ] && declare -aUg SOURCES_CACHE=() && SOURCES_CACHE+=($0)

local THIS_SOURCE="$(fs.gethash "$0")"
if [ -n "$THIS_SOURCE" ] && [[ "${SOURCES_CACHE[(Ie)$THIS_SOURCE]}" -eq 0 ]]; then
    SOURCES_CACHE+=("$THIS_SOURCE")

    function __log.spaces {
        if [ -z "$1" ] || [ ! "$1" -gt 0 ]; then
            return

        elif [ "$1" -gt 0 ]; then
            for i in {1..$1}; do
                printf "\n"
            done
        fi
    }

    if [ "$commands[pastel]" ]; then
        alias draw="pastel -m 8bit paint -n"
        function __log.draw {
            __log.spaces "$PRE"
            local msg="$(echo "${@:6}" | sd '[\$"]' '\\$0')"
            printf "$(eval "draw $2 ' $1 $4 ($5):'")$(eval "draw $3 \" $msg\"")"
            __log.spaces "${POST:-1}"
        }
        function depr { __log.draw '~~' 'indigo' 'deeppink' $0 $* >&2 }
        function info { __log.draw '--' 'limegreen' 'gray' $0 $* >&2 }
        function warn { __log.draw '++' 'yellow' 'gray' $0 $* >&2 }
        function fail { __log.draw '==' 'red --bold' 'white --bold' $0 $* >&2 }
        function term { __log.draw '**' 'white --on red --bold' 'white --bold' $0 $* >&2 }

    else
        function __log.draw {
            __log.spaces "$PRE"

            if [ -x "$commands[sd]" ]; then
                local msg="$(echo "${@:6}" | sd '[\$"]' '\\$0')"
            else
                local msg="${@:6}"
            fi

            printf "$2 $1 $4 ($5):$3 $msg\033[0m" >&2
            __log.spaces "${POST:-1}"
        }
        function depr { __log.draw '~~' '\033[0;35m' '\033[0;34m' $0 $* >&2 }
        function info { __log.draw '--' '\033[0;32m' '\033[0m' $0 $* >&2 }
        function warn { __log.draw '++' '\033[0;33m' '\033[0m' $0 $* >&2 }
        function fail { __log.draw '==' '\033[1;31m' '\033[0m' $0 $* >&2 }
        function term { __log.draw '**' '\033[42m\033[0;101m' '\033[0m' $0 $* >&2 }
    fi


    if [ -x "$commands[fetch]" ]; then
        export HTTP_GET="$commands[fetch] -qo - "
        [ "$VERBOSE" -eq 1 ] && \
        info $0 "using fetch: $HTTP_GET"

    elif [ -x "$commands[wget]" ]; then
        export HTTP_GET="$commands[wget] -qO -"
        [ "$VERBOSE" -eq 1 ] && \
        info $0 "using wget `wget --version | head -n 1 | awk '{print $3}'`: $HTTP_GET"

    elif [ -x "$commands[http]" ]; then
        export HTTP_GET="$commands[http] -FISb"
        [ "$VERBOSE" -eq 1 ] && \
        info $0 "using httpie `http --version`: $HTTP_GET"

    elif [ -x "$commands[curl]" ]; then
        export HTTP_GET="$commands[curl] -fsSL"
        [ "$VERBOSE" -eq 1 ] && \
        info $0 "using curl `curl --version | head -n 1 | awk '{print $2}'`: $HTTP_GET"

    else
        fail $0 "curl, wget, fetch or httpie doesn't exists"
        return 127
    fi


    if [ -x "$commands[zstd]" ]; then
        export ASH_PAQ="$commands[zstd] -0 -T0"
        export ASH_QAP="$commands[zstd] -qd"

    elif [ -x "$commands[lz4]" ]; then
        export ASH_PAQ="$commands[lz4] -1 - -"
        export ASH_QAP="$commands[lz4] -d - -"

    elif [ -x "$commands[xz]" ] && [ -x "$commands[xzcat]" ]; then
        export ASH_PAQ="$commands[xz] -0 -T0"
        export ASH_QAP="$commands[xzcat]"

    elif [ -x "$commands[gzip]" ] && [ -x "$commands[zcat]" ]; then
        export ASH_PAQ="$commands[gzip] -1"
        export ASH_QAP="$commands[zcat]"

    else
        unset ASH_PAQ
        unset ASH_QAP
    fi

    local osname="$(uname)"

    setopt no_case_match

    if [[ "$osname" -regex-match 'freebsd' ]]; then
        export ASH_OS="BSD"
        fs.link 'ls'    '/usr/local/bin/gnuls' >/dev/null
        fs.link 'grep'  '/usr/local/bin/grep'  >/dev/null

    elif [[ "$osname" -regex-match 'darwin' ]]; then
        export ASH_OS="MAC"
        fs.link 'ls'    '/usr/local/bin/gls'   >/dev/null
        fs.link 'grep'  '/usr/local/bin/ggrep' >/dev/null

        dirs=(
            bin
            sbin
            usr/bin
            usr/sbin
            usr/local/bin
            usr/local/sbin
        )

        for dir in $dirs; do
            if [ -d "/Library/Apple/$dir" ]; then
                export PATH="$PATH:/Library/Apple/$dir"
            fi
        done

    else
        if [[ "$osname" -regex-match 'linux' ]]; then
            export ASH_OS="LINUX"
        else
            fail $0 "unsupported OS '$(uname -srv)'"
            export ASH_OS="UNKNOWN"
        fi

        dirs=(
            bin
            sbin
            usr/bin
            usr/sbin
            usr/local/bin
            usr/local/sbin
        )

        for dir in $dirs; do
            if [ -d "/snap/$dir" ]; then
                export PATH="$PATH:/snap/$dir"
            fi
        done
    fi

    if [ "$ASH_OS" = 'BSD' ] || [ "$ASH_OS" = 'MAC' ]; then
        fs.link 'cut'       '/usr/local/bin/gcut'      >/dev/null
        fs.link 'find'      '/usr/local/bin/gfind'     >/dev/null
        fs.link 'head'      '/usr/local/bin/ghead'     >/dev/null
        fs.link 'readlink'  '/usr/local/bin/greadlink' >/dev/null
        fs.link 'realpath'  '/usr/local/bin/grealpath' >/dev/null
        fs.link 'sed'       '/usr/local/bin/gsed'      >/dev/null
        fs.link 'tail'      '/usr/local/bin/gtail'     >/dev/null
        fs.link 'tar'       '/usr/local/bin/gtar'      >/dev/null
        fs.link 'xargs'     '/usr/local/bin/gxargs'    >/dev/null
        export ASH_MD5_PIPE="$(which md5)"
    else
        export ASH_MD5_PIPE="$(which md5sum) | $(which cut) -c -32"
    fi

    source "$(fs.dirname $0)/hier.sh"
fi
