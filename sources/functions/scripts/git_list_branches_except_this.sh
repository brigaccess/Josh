git for-each-ref --sort=-committerdate refs/heads/ --color=always --format='%(HEAD) %(color:yellow bold)%(refname:short)%(color:reset) %(contents:subject) %(color:black bold)%(authoremail) %(committerdate:relative)' | awk '{$1=$1};1' | grep -Pv '^(\*\s+)'
