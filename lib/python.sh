#!/bin/sh

if [[ -n ${(M)zsh_eval_context:#file} ]]; then
    if [ -z "$HTTP_GET" ]; then
        source "$(dirname $0)/../run/boot.sh"
    fi

    JOSH_CACHE_DIR="$HOME/.cache/josh"
    if [ ! -d "$JOSH_CACHE_DIR" ]; then
        mkdir -p "$JOSH_CACHE_DIR"
        info $0 "make Josh cache directory '$JOSH_CACHE_DIR'"
    fi

    PYTHON_BINARIES="$HOME/.python"
    [ ! -d "$PYTHON_BINARIES" ] && mkdir -p "$PYTHON_BINARIES"

    if [ ! -d "$PYTHON_BINARIES" ]; then
        mkdir -p "$PYTHON_BINARIES"
        info $0 "make Python default directory '$PYTHON_BINARIES'"
    fi

    if [ -n "$JOSH_DEST" ]; then
        BASE="$JOSH_BASE"
    else
        BASE="$JOSH"
    fi
fi

[ -z "$SOURCES_CACHE" ] && declare -aUg SOURCES_CACHE=() && SOURCES_CACHE+=($0)

local THIS_SOURCE="$(fs.gethash "$0")"
if [ -n "$THIS_SOURCE" ] && [[ "${SOURCES_CACHE[(Ie)$THIS_SOURCE]}" -eq 0 ]]; then
    SOURCES_CACHE+=("$THIS_SOURCE")

    MIN_PYTHON_VERSION=3.6  # minimal version for modern pip

    PIP_REQ_PACKAGES=(
        pip        # python package manager, first
        httpie     # super http client, just try: http head anything.com
        pipdeptree # simple, but powerful tool to manage python requirements
        setuptools
        sshuttle   # swiss knife for ssh tunneling & management
        thefuck    # misspelling everyday helper
        virtualenv # virtual environments for python packaging
        wheel
    )

    PIP_OPT_PACKAGES=(
        asciinema  # shell movies recorder and player
        clickhouse-cli
        crudini    # ini configs parser
        mycli      # python-driver MySQL client
        nodeenv    # virtual environments for node packaging
        paramiko   # for ssh tunnels with mycli & pgcli
        sshtunnel  # too
        pgcli      # python-driver PostgreSQL client
        termtosvg  # write shell movie to animated SVG
        tmuxp      # tmux session manager
    )


    PIP_DEFAULT_KEYS=(
        --compile
        --disable-pip-version-check
        --no-input
        --no-python-version-warning
        --no-warn-conflicts
        --no-warn-script-location
        --prefer-binary
    )


    function python.library.is {
        if [ -z "$1" ]; then
            fail $0 "call without args, I need to do — what?"
            return 2
        fi

        if [ -x "$2" ]; then
            local bin="$(fs.realpath "$2")"
            if [ ! -x "$bin" ]; then
                fail $0 "cannot get real path for '$2'"
                return 3
            fi
        else
            local bin="$(python.exe)"
        fi

        if [ -z "$(echo "import $1 as x; print(x)" | $bin 2>/dev/null | grep '<module')" ]; then
            fail $0 "'$1' module doesn't exist for '$bin'"
            return 1
        fi
    }

    function python.version.full {
        if [ -z "$1" ]; then
            if [ -n "$PYTHON" ] && [ -x "$PYTHON/bin/python" ]; then
                local source="$PYTHON/bin/python"

            else
                fail $0 "call without args, I need to do — what?"
                return 1
            fi
        else
            local source="$1"
        fi

        if [ ! -x "$source" ]; then
            fail $0 "isn't valid executable '$source'"
            return 1
        fi
        echo "$($source --version 2>&1 | grep -Po '(\d+\.\d+\.\d+)')"
    }

    function python.version.uncached {
        local python="$(fs.realpath "$1" 2>/dev/null)"
        if [ ! -x "$python" ]; then
            fail $0 "isn't valid python '$python'"
            return 3
        fi

        local version="$(python.version.full "$python")"
        if [[ "$version" -regex-match '^[0-9]+\.[0-9]+' ]]; then
            echo "$MATCH"
        else
            fail $0 "python $python==$version missing minor version"
            return 1
        fi
    }

    function python.version {
        if [ -z "$1" ]; then
            if [ -n "$PYTHON" ] && [ -x "$PYTHON/bin/python" ]; then
                local source="$PYTHON/bin/python"
            else
                fail $0 "call without args, I need to do — what?"
                return 1
            fi
        else
            local source="$1"
        fi

        if [ ! -x "$source" ]; then
            fail $0 "isn't valid executable '$source'"
            return 2
        fi
        eval.cached "$(fs.mtime $source)" python.version.uncached "$source"
    }

    function python.home.from_version {
        if [ -z "$1" ]; then
            fail $0 "call without args, I need to do — what?"
            return 1
        fi

        local version="$(python.version "$1")"
        [ -z "$version" ] && return 1
        echo "$PYTHON_BINARIES/$version"
    }

    function python.exe.lookup {
        source $BASE/run/units/compat.sh

        if [ -n "$*" ]; then
            local dirs="$*"
        else
            local dirs="$path"
        fi

        for dir in $(echo "$dirs" | sed 's#:#\n#g'); do
            if [ ! -d "$dir" ]; then
                continue
            fi

            for python in $(find "$dir" -maxdepth 1 -type f -name 'python?.*' 2>/dev/null | sort -Vr); do
                [ ! -x "$python" ] || \
                [[ ! "$python" -regex-match '[0-9]$' ]] && continue

                local version="$(python.version.full $python)"
                [ "$?" -gt 0 ] || [ -z "$version" ] || \
                [[ ! "$version" -regex-match '^[0-9]+\.[0-9]+' ]] && continue

                unset result

                if ! version_not_compatible $MIN_PYTHON_VERSION $version; then
                    if python.library.is 'distutils' "$python"; then
                        local result="$python"
                    else
                        info $0 "python $python ($version) haven't distutils, skip"
                        continue
                    fi
                else
                    info $0 "python $python $version < $MIN_PYTHON_VERSION, skip"
                    continue
                fi
                [ "$result" ] && break
            done
        done
        if [ -n "$result" ]; then
            info $0 "python binary $result ($version)"
            echo "$result"
            return 0
        fi
        fail $0 "python binary not found"
        return 1
    }

    function python.exe {
        local version

        if [ -n "$PYTHON" ]; then
            local link="$PYTHON/bin/python"
            if [ -x "$link" ] && [ -e "$link" ]; then
                echo "$link"
                return 0
            fi
            unset PYTHON
        fi

        if ! function_exists "compat.executables"; then
            source "$BASE/run/units/compat.sh"

            if [ "$?" -gt 0 ]; then
                fail $0 "something wrong, BASE:'$BASE'"
                return 1
            fi
        fi

        local link="$PYTHON_BINARIES/default/bin/python"
        if [ -L "$link" ] && [ -x "$link" ] && [ -e "$link" ]; then
            version="$(python.version.full "$link")"
            if [ "$?" -eq 0 ] && [ -n "$version" ]; then

                version_not_compatible "$MIN_PYTHON_VERSION" "$version"

                if [ "$?" -gt 0 ]; then
                    if python.library.is 'distutils' "$link"; then
                        echo "$link"
                        return 0
                    fi
                fi
            fi
        fi

        local gsed="$commands[gsed]"
        if [ ! -x "$gsed" ]; then
            local gsed="$(which sed)"
            if [ ! -x "$gsed" ]; then
                fail $0 "GNU sed for '$JOSH_OS' don't found"
                return 2
            fi
        fi

        local dirs="$($SHELL -c "echo "$PATH" | sed 's#:#\n#g' | grep -v "$HOME" | sort -su | $gsed -z 's#\n#:#g' | awk '{\$1=\$1};1'")"
        if [ -z "$dirs" ]; then
            local dirs="$PATH"
        fi

        local result="$(
            eval.cached "`fs.lm.many $dirs $PYTHON_BINARIES`" python.exe.lookup $dirs)"

        if [ "$result" ]; then
            local python
            python="$(fs.realpath "$result")"
            if [ "$?" -eq 0 ] && [ -x "$python" ]; then
                echo "$python"
                return 0
            fi
        fi
        fail $0 "python doesn't exists in: '$dirs'"
        return 3
    }

    function python.home.uncached {
        local target
        local python="$1"

        if [ "$?" -gt 0 ] || [ ! -x "$python" ]; then
            fail $0 "python executable and home directory can't detected"
            return 1
        fi

        target="$(python.home.from_version "$python")"
        if [ "$?" -eq 0 ] && [ ! -x "$target/bin/python" ]; then
            mkdir -p "$target/bin"

            local version="$(python.version "$python")"
            if [ -z "$version" ]; then
                fail $0 "version not found for $python"
                return 1
            fi
            info $0 "link $python ($(python.version.full "$python")) -> $target/bin/"

            ln -s "$target" "$target/local" \
            ln -s "$python" "$target/bin/python" \
            ln -s "$python" "$target/bin/python${version[1]}" \
            ln -s "$python" "$target/bin/"  # finally /pythonX.Y.Z

            if [ ! -d "$PYTHON_BINARIES/default" ]; then
                ln -s "$target" "$PYTHON_BINARIES/default"
                info $0 "make default $python ($(python.version.full "$python"))"
            fi
            rehash
        fi
        echo "$target"
    }

    function python.home {
        local target
        if [ -z "$1" ]; then
            local python="$(python.exe)"
        else
            local python="$(which "$1")"
        fi
        target="$(eval.cached "$(fs.mtime $python)" python.home.uncached "$python")"
        local retval="$?"

        echo "$target"
        if [ -z "$1" ]; then
            export PYTHON="$target"
        fi
        [ -x "$PYTHON" ] && export PYTHONUSERBASE="$PYTHON"
        return "$retval"
    }

    function python.set {
        if [ -z "$1" ]; then

            if [ ! -x "$PYTHON_BINARIES/default/bin/python" ]; then
                fail "$0" "default python isn't installed, you call me without respect and arguments, I need to do— hat?"
                return 1
            else

                local source="$(fs.realpath "$PYTHON_BINARIES/default/bin/python")"
                if [ "$?" -gt 0 ] || [ ! -x "$source" ]; then
                    fail $0 "python default binary '$source' ($1) doesn't exists or something wrong"
                    return 2
                fi
            fi

        elif [[ "$1" -regex-match '^[0-9]+\.[0-9]+' ]]; then
            local source="$(fs.realpath `which "python$MATCH"`)"
            if [ "$?" -gt 0 ] || [ ! -x "$source" ]; then
                fail $0 "python binary '$source' ($1) doesn't exists or something wrong"
                return 3
            fi

        else
            local source="$(fs.realpath `which "$1"`)"
            if [ "$?" -gt 0 ] || [ ! -x "$source" ]; then
                fail $0 "python binary '$source' doesn't exists or something wrong"
                return 4
            fi
        fi

        local version="$(python.version.full "$source")"
        if [ -z "$version" ]; then
            fail $0 "python $source version fetch"
            return 5

        elif [ -n "$PYTHON" ] && [ "$version" = "$(python.version.full)" ]; then
            [ -x "$PYTHON" ] && export PYTHONUSERBASE="$PYTHON"
            return 0
        fi

        local target="$(python.home "$source")"
        if [ "$?" -gt 0 ] || [ ! -d "$target" ]; then
            fail $0 "python $source home directory isn't exist"
            return 6
        fi

        local base="$PYTHON"
        export PYTHON="$target"
        pip.lookup

        local python="$(python.exe)"
        if [ ! -x "$python" ]; then
            fail $0 "something wrong on setup python '$python' from source $source"
            [ -n "$base" ] && export PYTHON="$base"
            [ -x "$PYTHON" ] && export PYTHONUSERBASE="$PYTHON"
            return 7
        fi

        if [ ! "$version" = "$(python.version.full "$python")" ]; then
            fail $0 "source python $source ($version) != target $python ($(python.version.full "$python"))"
            [ -n "$base" ] && export PYTHON="$base"
            [ -x "$PYTHON" ] && export PYTHONUSERBASE="$PYTHON"
            return 8
        fi

        pip.deploy

        if [ -n "$1" ] || [ ! "$(python.version "$PYTHON_BINARIES/default/bin/python" 2>/dev/null)" = "$(python.version "$python" 2>/dev/null)" ]; then
            warn $0 "using python $target ($source=$version)"
        fi

        [ -x "$PYTHON" ] && export PYTHONUSERBASE="$PYTHON"
        josh_source run/boot.sh && path.rehash
    }

    function pip.lookup {
        if [ -x "$PYTHON_PIP" ]; then
            echo "$PYTHON_PIP"
            return 0
        fi
        local target="$(python.home)"
        if [ "$?" -gt 0 ] || [ ! -d "$target" ]; then
            fail $0 "python target dir:'$target'"
            return 1
        fi

        local pip="$target/bin/pip"
        if [ -x "$pip" ]; then
            export PYTHON_PIP="$pip"
            echo "$pip"
            return 0
        fi

        warn $0 "pip binary not found"
        return 2
    }

    function pip.deploy {
        if [ -z "$1" ]; then
            local python="$(python.exe)"
        else
            local python="$(which "$1")"
            if [ "$?" -gt 0 ] || [ ! -x "$python" ]; then
                fail $0 "python binary '$python' doesn't exists or something wrong"
                return 1
            fi
        fi

        local target="$(python.home "$python")"
        if [ "$?" -gt 0 ] || [ ! -d "$target" ]; then
            fail $0 "python $python home directory isn't exist"
            return 2
        fi

        if [ ! -x "$(pip.lookup)" ]; then
            local version="$(python.version "$python")"
            if [ -z "$version" ]; then
                fail $0 "python $python version fetch"
                return 3
            fi

            if [ "$version" = '2.7' ]; then
                local url='https://bootstrap.pypa.io/pip/2.7/get-pip.py'
            elif [ "$version" = '3.6' ]; then
                local url='https://bootstrap.pypa.io/pip/3.6/get-pip.py'
            else
                local url='https://bootstrap.pypa.io/get-pip.py'
            fi

            local pip_file="/tmp/get-pip.py"

            export PYTHON="$target"
            [ -x "$PYTHON" ] && export PYTHONUSERBASE="$PYTHON"

            info $0 "deploy pip with $python ($(python.version.full $python)) to $target"

            local flags="--disable-pip-version-check --no-input --no-python-version-warning --no-warn-conflicts --no-warn-script-location"

            if [ "$(josh_branch 2>/dev/null)" = "develop" ]; then
                local flags="$flags -vv"
            fi

            if [ "$USER" = 'root' ] || [ "$JOSH_OS" = 'BSD' ] || [ "$JOSH_OS" = 'MAC' ]; then
                local flags="--root='/' --prefix='$target' $flags"
            fi
            local command="PYTHONUSERBASE=\"$target\" PIP_REQUIRE_VIRTUALENV=false $python $pip_file $flags pip"

            warn $0 ": $command"

            $SHELL -c "$HTTP_GET $url > $pip_file" && eval ${command} >&2

            local retval=$?
            [ -f "$pip_file" ] && unlink "$pip_file"

            if [ "$retval" -gt 0 ]; then
                fail $0 "pip deploy"
                return 4
            fi

            if [ ! -x "$(pip.lookup)" ]; then
                fail $0 "pip doesn't exists in '$target'"
                return 5
            fi

            local packages="$(find $target/lib/ -maxdepth 1 -type d -name 'python*')"
            if [ -d "$packages/dist-packages" ] && [ ! -d "$packages/site-packages" ]; then
                ln -s "$packages/dist-packages" "$packages/site-packages"
            fi

            rehash
            pip.install "$PIP_REQ_PACKAGES"

        fi

        [ -z "$PYTHON" ] && export PYTHON="$target"
        [ -x "$PYTHON" ] && export PYTHONUSERBASE="$PYTHON"
    }

    function pip.exe.uncached {
        if [ -z "$1" ]; then
            local python="$(python.exe)"
        else
            local python="$(which "$1")"
            if [ "$?" -gt 0 ] || [ ! -x "$python" ]; then
                fail $0 "python binary '$python' doesn't exists or something wrong"
                return 1
            fi
        fi

        local target="$(python.home "$python")"
        if [ "$?" -gt 0 ] || [ ! -d "$target" ]; then
            fail $0 "python '$python' home directory isn't exist"
            return 2
        fi
        pip.deploy $*
        local retval="$?"
        echo "$target"
        return "$retval"
    }

    function pip.exe {
        local gsed="$commands[gsed]"
        if [ ! -x "$gsed" ]; then
            local gsed="$(which sed)"
            if [ ! -x "$gsed" ]; then
                fail $0 "GNU sed for '$JOSH_OS' don't found"
                return 2
            fi
        fi

        local dirs="$($SHELL -c "echo "$PATH" | sed 's#:#\n#g' | grep -v "$HOME" | sort -su | $gsed -z 's#\n#:#g' | awk '{\$1=\$1};1'")"
        if [ -z "$dirs" ]; then
            local dirs="$PATH"
        fi

        local result="$(
            eval.cached "`fs.lm.many $dirs $PYTHON_BINARIES`" pip.exe.uncached $*)"

        local retval="$?"
        if [ -x "$target/bin/pip" ]; then
            echo "$target/bin/pip"
        fi

        [ -z "$PYTHON" ] && export PYTHON="$target"
        [ -x "$PYTHON" ] && export PYTHONUSERBASE="$PYTHON"
        return "$retval"
    }

    function venv.deactivate {
        if [ -z "$VIRTUAL_ENV" ] || [ ! -f "$VIRTUAL_ENV/bin/activate" ]; then
            unset venv
            path.rehash 2>/dev/null
        else
            local venv="$VIRTUAL_ENV"
            source $venv/bin/activate && deactivate
            echo "$venv"
        fi
    }

    function pip.install {
        if [ -z "$1" ]; then
            fail $0 "call without args, I need to do — what?"
            return 1
        fi

        local venv="$(venv.deactivate)"

        local pip="$(pip.exe)"
        if [ "$?" -gt 0 ] || [ ! -x "$pip" ]; then
            [ -n "$venv" ] && source $venv/bin/activate
            return 2
        fi

        local target="$(python.home)"
        if [ "$?" -gt 0 ] || [ ! -d "$target" ]; then
            fail $0 "python target dir '$target'"
            [ -n "$venv" ] && source $venv/bin/activate
            return 3
        fi

        local flags="--upgrade --upgrade-strategy=eager"

        if [ "$(josh_branch 2>/dev/null)" != "develop" ]; then
            local flags="$flags -v"
        fi

        if [ "$USER" = 'root' ] || [ "$JOSH_OS" = 'BSD' ] || [ "$JOSH_OS" = 'MAC' ]; then
            local flags="--root='/' --prefix='$target' $flags"
        fi
        local command="PYTHONUSERBASE=\"$target\" PIP_REQUIRE_VIRTUALENV=false $(python.exe) -m pip install $flags $PIP_DEFAULT_KEYS"

        warn $0 "$command $*"

        local complete=''
        local failed=''
        for row in $@; do
            $SHELL -c "$command $row"
            if [ "$?" -eq 0 ]; then
                if [ -z "$complete" ]; then
                    local complete="$row"
                else
                    local complete="$complete $row"
                fi
            else
                warn $0 "$row fails"
                if [ -z "$failed" ]; then
                    local failed="$row"
                else
                    local failed="$failed $row"
                fi
            fi
            printf "\n" >&2
        done
        rehash

        local result=''
        if [ -n "$complete" ]; then
            local result="$complete - success!"
        fi
        if [ -n "$failed" ]; then
            if [ -z "$result" ]; then
                local result="failed: $failed"
            else
                local result="$result $failed - failed!"
            fi
        fi

        if [ -n "$result" ]; then
            info $0 "$result"
        fi

        [ -n "$venv" ] && source $venv/bin/activate
    }

    function pip.update {
        local python="$(python.exe)"
        if [ "$?" -gt 0 ] || [ ! -x "$python" ]; then
            return 1

        elif ! python.library.is 'pipdeptree' "$python"; then
            info $0 "pipdeptree isn't installed for $(python.version), proceed"
            pip.install pipdeptree

            if ! python.library.is 'pipdeptree' "$python"; then
                fail $0 "something went wrong"
                return 2
            fi
        fi

        local package="$1"
        if [ -z "$package" ]; then
            local package="$PIP_REQ_PACKAGES $PIP_OPT_PACKAGES"
        fi

        local venv="$(venv.deactivate)"
        local regex="$(
            echo "$package" | \
            sed 's:^:^:' | sed 's: *$:$:' | sed 's: :$|^:g')"

        local installed="$(
            $python -m pipdeptree --all --warn silence --reverse | \
            grep -Pv '\s+' | sd '^(.+)==(.+)$' '$1' | grep -Po "$regex" | sed -z 's:\n\b: :g'
        )"

        if [ -n "$1" ] && [ -z "$installed" ]; then
            echo "$regex"
            fail $0 "package '$1' isn't installed"
            return 3
        fi

        pip.install "$installed"
        local retval="$?"

        [ -n "$venv" ] && source $venv/bin/activate
        return $retval
    }

    function pip.extras {
        pip.install "$PIP_REQ_PACKAGES"
        local retval="$?"
        run_show "pip.install $PIP_OPT_PACKAGES"
        rehash

        if [ "$?" -gt 0 ] || [ "$retval" -gt 0 ]; then
            return 1
        fi
    }

    function python.env {
        pip.exe >/dev/null
    }

    function pip.compliance.check {
        local target="$(python.home)"
        if [ "$?" -gt 0 ] || [ ! -d "$target" ]; then
            fail $0 "python target dir '$target'"
            return 1
        fi

        local result=""
        local expire="$(fs.lm.many $PATH)"
        local system="/bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin"

        if [ -n "$SUDO_USER" ]; then
            local home="$(fs.home.eval "$SUDO_USER")"

            if [ "$?" -eq 0 ] && [ -n "$home" ]; then
                local system="$system $home"
                local real="$(fs.realpath "$home")"
                if [ "$?" -eq 0 ] && [ ! "$home" = "$real" ]; then
                    local system="$system $real"
                fi
            fi
        fi

        for bin in $(find "$target/bin" -maxdepth 1 -type f 2>/dev/null | sort -Vr); do
            local short="$(basename "$bin")"

            local src="$target/bin/$short"
            local src_size="$(fs_size "$src")"

            if [ -n "$short" ] && [ -x "$src" ]; then
                local shadows="$(lookup.copies.cached "$short" "$expire" "$target/bin" $system "$VIRTUAL_ENV")"
                if [ -n "$shadows" ]; then
                    for dst in $(echo "$shadows" | sed 's#:#\n#g'); do
                        local dst_size="$(fs_size "$dst")"

                        local msg="$src ($src_size bytes) -> $dst ($dst_size bytes)"
                        if [ -n "$JOSH_MD5_PIPE" ] && [ "$src_size" = "$dst_size" ]; then
                            local src_md5="$(cat "$src" | sh -c "$JOSH_MD5_PIPE")"
                            local dst_md5="$(cat "$dst" | sh -c "$JOSH_MD5_PIPE")"
                            if [ "$src_md5" = "$dst_md5" ]; then
                                local msg="$src ($src_size bytes) -> $dst (absolutely same, unlink last)"
                            fi
                        fi

                        if [ -z "$result" ]; then
                            local result="$msg"
                        else
                            local result="$result\n$msg"
                        fi
                    done
                fi
            fi
        done
        if [ -n "$result" ]; then
            warn $0 "one or many binaries may be shadowed"
            printf "$result\n" >&2
            warn $0 "disable execution by chmod a-x /file/path or unlink shadow from right side and run this test again by: $0"
        fi
    }
fi
