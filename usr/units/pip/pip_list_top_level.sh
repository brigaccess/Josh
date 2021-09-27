local command="pipdeptree --all --warn silence --exclude pip,pipdeptree,setuptools,pkg_resources,wheel --reverse"
[ ! -d "$VIRTUAL_ENV" ] && local command="$command --user-only"

$SHELL -c "$command" \
    | ${JOSH_GREP:-'grep'} -Pv '(\s{3,})' \
    | sd '^([^\s-]+\n\s{2}-[^\n]+)' '' \
    | ${JOSH_GREP:-'grep'} -Po '^([^\s]+)' \
    | sd '^(.+)==(.+)$' '$2\t$1' \
    | sort -k 2 | column -t
