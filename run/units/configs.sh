#!/bin/zsh

if [[ -n ${(M)zsh_eval_context:#file} ]]; then
    if [ -z "$JOSH" ] && [ -z "$JOSH_BASE" ]; then
        source "$(dirname $0)/../boot.sh"
    fi

    CONFIG_DIR="$HOME/.config"
    [ ! -d "$CONFIG_DIR" ] && mkdir -p "$CONFIG_DIR"

    if [ -n "$JOSH_DEST" ]; then
        BASE="$JOSH_BASE"
        if [ -z "$CONFIG_ROOT" ]; then
            info $0 "copy template configs to '$CONFIG_DIR'"
        fi
    else
        BASE="$JOSH"
    fi
fi

CONFIG_ROOT="$BASE/usr/share"

function backup_file {
    if [ -f "$1" ]; then
        local dst="$1+`date "+%Y%m%d%H%M%S"`"
        if [ ! -f "$dst" ]; then
            info $0 "backup $1 -> $dst"
            cp -fa "$1" "$dst"
        fi
        return $?
    fi
}

function copy_config {
    local dst="$2"
    if [ -f "$dst" ] && [ ! "$JOSH_RENEW_CONFIGS" ] && [ ! "$JOSH_FORCE_CONFIGS" ]; then
        return 0
    fi

    local src="$1"
    if [ ! -f "$src" ]; then
        fail $0 "copy config failed, source '$src' doesn't exists"
        return 1
    fi

    if [ -f "$dst" ]; then
        diff --ignore-blank-lines --strip-trailing-cr --brief "$src" "$dst" 1>/dev/null
        if [ $? -eq 0 ]; then
            return 0
        fi
    fi

    [ -f "$dst" ] && backup_file "$dst" && unlink "$dst"
    [ ! -d "$(fs_dirname $dst)" ] && mkdir -p "$(fs_dirname $dst)";

    if [ "$JOSH_RENEW_CONFIGS" ] && [ "$JOSH_OS" != "BSD" ]; then
        info $0 "${3:-"renew: $src -> $dst"}"
        cp -nu "$src" "$dst"
    else
        info $0 "${3:-"copy: $src -> $dst"}"
        cp -n "$src" "$dst"
    fi
    return $?
}

function config_git {
    copy_config "$BASE/usr/share/.gitignore" "$HOME/.gitignore"

    if [ -f "$HOME/.gitignore" ] && [ ! -L "$HOME/.agignore" ]; then
        ln -s "$HOME/.gitignore" "$HOME/.agignore"
    fi

    if [ -f "$HOME/.gitignore" ] && [ ! -L "$HOME/.ignore" ]; then
        ln -s "$HOME/.gitignore" "$HOME/.ignore"
    fi

    function set_style() {
        git config --global core.pager "delta --commit-style='yellow ul' --commit-decoration-style='' --file-style='cyan ul' --file-decoration-style='' --hunk-header-decoration-style='' --zero-style='dim syntax' --24-bit-color='always' --minus-style='syntax #330000' --plus-style='syntax #002200' --file-modified-label='M' --file-removed-label='D' --file-added-label='A' --file-renamed-label='R' --line-numbers-left-format='{nm:^4}' --line-numbers-minus-style='#aa2222' --line-numbers-zero-style='#505055' --line-numbers-plus-style='#229922' --line-numbers --navigate"
    }

    if [ -z "`git config --global core.pager | grep -P '^(delta)'`" ]; then
        backup_file "$HOME/.gitconfig" && \
        git config --global color.branch auto && \
        git config --global color.decorate auto && \
        git config --global color.diff auto && \
        git config --global color.grep auto && \
        git config --global color.interactive auto && \
        git config --global color.pager true && \
        git config --global color.showbranch auto && \
        git config --global color.status auto && \
        git config --global color.ui auto && \
        set_style
    fi

    if [ -n "$(git config --global core.pager | grep 'hunk-style normal')" ]; then
        set_style
    fi

    if [ -z "$(git config --global sequence.editor)" ] && [ -x "$(which interactive-rebase-tool)" ]; then
        backup_file "$HOME/.gitconfig" && \
        git config --global sequence.editor interactive-rebase-tool
    fi
}

function nano_syntax_compile {
    if [ ! -f "$HOME/.nanorc" ]; then
        # https://github.com/scopatz/nanorc

        if [ -d /usr/share/nano/ ]; then
            # linux
            find /usr/share/nano/ -iname "*.nanorc" -exec ec2ho include {} \; >> $HOME/.nanorc

        elif [ -d /usr/local/share/nano/ ]; then
            # freebsd
            find /usr/local/share/nano/ -iname "*.nanorc" -exec ec2ho include {} \; >> $HOME/.nanorc

        fi
        [ -f "$HOME/.nanorc" ] && info $0 "nano syntax highlight profile generated to $HOME/.nanorc"
    fi
    return 0
}

function zero_configuration {
    config_git
    nano_syntax_compile

    copy_config "$CONFIG_ROOT/cargo.toml" "$HOME/.cargo/config.toml"
    copy_config "$CONFIG_ROOT/lsd.yaml" "$CONFIG_DIR/lsd/config.yaml"
    copy_config "$CONFIG_ROOT/mycli.conf" "$HOME/.myclirc"
    copy_config "$CONFIG_ROOT/nodeenv.conf" "$HOME/.nodeenvrc"
    copy_config "$CONFIG_ROOT/ondir.rc" "$HOME/.ondirrc"
    copy_config "$CONFIG_ROOT/pgcli.conf" "$CONFIG_DIR/pgcli/config"
    copy_config "$CONFIG_ROOT/pip.conf" "$CONFIG_DIR/pip/pip.conf"
    copy_config "$CONFIG_ROOT/tmux.conf" "$HOME/.tmux.conf"
    copy_config "$CONFIG_ROOT/logout.zsh" "$HOME/.zlogout"
}
