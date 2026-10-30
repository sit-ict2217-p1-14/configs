#!/bin/sh
set -eu
set -o pipefail

find -iname '*.esh' -exec /bin/sh -c '
render_file () {
    vars="$(cat ./partials/vars.sh)"
    filename="$1"
    filename_plain="$(echo $filename | sed s/....$//)"
    esh -o $filename_plain $filename $vars
    printf "%s > %s\n" "$filename" "$filename_plain"
}
render_file "{}"
' \;
