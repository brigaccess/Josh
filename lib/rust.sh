#!/bin/sh

CARGO_REQ_PACKAGES=(
    bat            # modern replace for cat with syntax highlight
    broot          # lightweight embeddable file manager
    cargo-update   # packages for auto-update installed crates
    csview         # for commas, tabs, etc
    exa            # fast replace for ls
    fd-find        # fd, fast replace for find for humans
    git-delta      # fast replace for git delta with steroids
    lsd            # another ls replacement tool
    mdcat          # Markdown files rendered viewer
    petname        # generate human readable strings
    proximity-sort # path sorter
    rcrawl         # very fast file by pattern in directory
    ripgrep        # rg, fast replace for grep -ri for humans
    rm-improved    # rip, powerful rm replacement with trashcan
    runiq          # fast uniq replacement
    scotty         # directory crawling statistics with search
    sd             # fast sed replacement for humans
    starship       # shell prompt
    tabulate       # autodetect columns in stdin and tabulate
    viu            # print images into terminal
    vivid          # ls colors themes selections system
)  # TODO: checks for missing binaries!

CARGO_OPT_PACKAGES=(
    atuin            # another yet history manager
    bandwhich        # network bandwhich meter
    bingrep          # extract and grep strings from binaries
    bump-bin         # versions with semver specification
    choose           # awk for humans
    colorizer        # logs colorizer
    dirstat-rs       # ds, du replace, summary tree
    du-dust          # dust, du replace, verbose tree
    dull             # strip any ANSI (color) sequences from pipe
    dupe-krill       # replace similar (by hash) files with hardlinks
    durt             # du replace, just sum
    feroxbuster      # agressively website dumper
    ffsend           # sharing files tool
    fw               # workspaces manager
    gfold            # git reps in directory branches status
    git-hist         # git history for selected file
    git-local-ignore # local (without .gitignore) git ignore wrapper
    gitui            # terminal UI for git
    hors             # stack overflow answers in terminal
    hyperfine        # full featured time replacement and benchmark tool
    jira-terminal    # Jira client, really
    jql              # select values by path from JSON input for humans
    just             # comfortable system for per project frequently used commands like make test, etc
    logtail          # graphical tail logs in termial
    lolcate-rs       # blazing fast filesystem database
    mrh              # recursively search git reps and return status (detached, tagged, etc)
    onefetch         # graphical statistics for git repository
    paper-terminal   # another yet Markdown printer, naturally like newpaper
    procs            # ps aux replacement for humans
    pueue            # powerful tool to running and management background tasks
    rhit             # very fast nginx log analyzer with graphical stats
    rmesg            # modern dmesg replacement
    scriptisto       # powerful tool, convert every source to executable with build instructions in same file
    so               # stack overflow answers in terminal
    streampager
    tokei            # repository stats
    x8               # websites scan tool
    ytop             # simple htop
    # coreutils        # rust reimplementation for GNU tools
    watchexec-cli    # watchdog for filesystem and runs callback on hit
    python-launcher
    rustscan
    bropages
    qrrs
    connchk
    credit
    skim
    git-trim
    vergit
    what-bump
    git-branchless
    loadem
    gitall
    autocshell
    tickrs
    investments
    kras
    ssup
    git-bonsai
    multi-tunnel
    elephantry-cli
    ntimes
    estunnel
    xkpwgen  # like pet name
    pipecolor
    git-state
    hexdmp
    git-who
    git-warp-time
    ff-find
    pingkeeper
    filetreelist
    limber  # elk import export
    jfmt
    # file-sniffer
    dssim
    bottom
    zoxide
    minify-html
    doh-proxy
    xplr
    miniserve
    code-minimap
    requestty
    mandown
    encrypted-dns
    hx
    silicon
    diffsitter
    parallel-disk-usage
    fblog
    ruplacer
    hunter
    blockish
    fcp
    checkpwn
    tab
    fclones
    xcompress
    tidy-viewer
    amber
    menyoki
    terminal-menu
    songrec
    sheldon
    termscp
    cli-timer
    hors
    sic
    sbyte
    t-rec
    lino
    gbump
    ipgeo
    jex
    jen
    yj
    rhit
    b0x
    mprober
    thwack
    lms
    gip
    chit
    genact
    diffr
    doh-client
    gitweb
    prose
    lolcrab
    binary-security-check
    copycat
    imdl
    cw
    pgen
    jsonfmt
    repgrep
    dtool
    git-hist
    rjo
    runscript
    quickdash
    git-hooks-dispatch
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

function cargo_init() {
    set_defaults

    export CARGO_DIR="$REAL/.cargo/bin"
    [ ! -d "$CARGO_DIR" ] && mkdir -p "$CARGO_DIR"
    export PATH="$CARGO_DIR:$PATH"

    local CACHE_EXE="$CARGO_DIR/sccache"
    export CARGO_EXE="$CARGO_DIR/cargo"

    if [ ! -f "$CARGO_EXE" ]; then
        export RUSTC_WRAPPER=""
        unset RUSTC_WRAPPER
        url='https://sh.rustup.rs'

        $SHELL -c "$HTTP_GET $url" | RUSTUP_HOME=~/.rustup CARGO_HOME=~/.cargo RUSTUP_INIT_SKIP_PATH_CHECK=yes $SHELL -s - --profile minimal --no-modify-path --quiet -y
        if [ $? -gt 0 ]; then
            $SHELL -c "$HTTP_GET $url" | RUSTUP_HOME=~/.rustup CARGO_HOME=~/.cargo RUSTUP_INIT_SKIP_PATH_CHECK=yes $SHELL -s - --profile minimal --no-modify-path --verbose -y
            echo " - fatal: cargo deploy failed!"
            return 1
        fi
        if [ ! -f "$CARGO_EXE" ]; then
            echo " - fatal: cargo isn't installed ($CARGO_EXE)"
            return 255
        fi
    fi

    if [ ! -f "$CACHE_EXE" ]; then
        $CARGO_EXE install sccache
        if [ ! -f "$CACHE_EXE" ]; then
            echo " - warning: sccache isn't compiled ($CACHE_EXE)"
        fi
    fi

    if [ -f "$CACHE_EXE" ]; then
        export RUSTC_WRAPPER="$CACHE_EXE"
    elif [ -f "`which -p sccache`" ]; then
        export RUSTC_WRAPPER="`which -p sccache`"
    else
        export RUSTC_WRAPPER=""
        unset RUSTC_WRAPPER
        echo " - warning: sccache doesn't exists"
    fi

    local UPDATE_EXE="$CARGO_DIR/cargo-install-update"
    if [ ! -f "$UPDATE_EXE" ]; then
        $CARGO_EXE install cargo-update
        if [ ! -f "$UPDATE_EXE" ]; then
            echo " - warning: cargo-update isn't compiled ($UPDATE_EXE)"
        fi
    fi

    return 0
}

function cargo_deploy() {
    cargo_init || return $?
    if [ ! -f "$CARGO_EXE" ]; then
        echo " - fatal: cargo exe $CARGO_EXE isn't found!"
        return 1
    fi

    $SHELL -c "`realpath $CARGO_DIR/rustup` update"

    local retval=0
    for pkg in $@; do
        $CARGO_EXE install $pkg
        if [ "$?" -gt 0 ]; then
            local retval=1
        fi
    done
    cargo_update
    return "$retval"
}

function cargo_extras() {
    cargo_deploy $CARGO_REQ_PACKAGES $CARGO_OPT_PACKAGES
    return 0
}

function cargo_recompile() {
    cargo_init || return $?
    if [ ! -f "$CARGO_EXE" ]; then
        echo " - fatal: cargo exe $CARGO_EXE isn't found!"
        return 1
    fi

    local packages="$($CARGO_EXE install --list | egrep '^[a-z0-9_-]+ v[0-9.]+:$' | cut -f1 -d' ' | sed -z 's:\n: :g')"
    if [ "$packages" ]; then
        $SHELL -c "$CARGO_EXE install --force $packages"
    fi
}

function cargo_update() {
    cargo_init || return $?
    if [ ! -f "$CARGO_EXE" ]; then
        echo " - fatal: cargo exe $CARGO_EXE isn't found!"
        return 1
    fi

    local UPDATE_EXE="$CARGO_DIR/cargo-install-update"
    if [ ! -f "$UPDATE_EXE" ]; then
        echo " - fatal: cargo-update exe $UPDATE_EXE isn't found!"
        return 1
    fi

    $CARGO_EXE install-update -a
    return "$?"
}

function rust_env() {
    cargo_init
}
