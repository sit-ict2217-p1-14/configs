#!/bin/sh
set -eu
set -o pipefail

render () {
    filename="$1"
    if [ "$(git check-ignore "$filename")" ]; then
        continue
    fi
    vars="$(cat ./partials/vars.sh)"
    filename_plain="$(echo $filename | sed s/....$//)"
    esh -o "$filename_plain" "$filename" $vars
    printf "%s > %s\n" "$filename" "$filename_plain"
}

tag_output () {
    awk -v tag="$filename" '{ print "[" tag "] " $0; fflush() }'
}

color()(
    set -o pipefail
    "$@" 2>&1>&3 |
        awk '{ print "[ERROR] " $0; fflush() }' |
        tag_output |
        awk '{ print "\033[31m " $0 "&\033[m"; fflush() }' >&2)3>&1

while IFS= read -r filename; do
    color render "$filename" | tag_output &
done <<EOF
$(find -iname '*.esh')
EOF
wait
