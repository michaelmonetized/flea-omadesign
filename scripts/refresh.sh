#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
state="${XDG_DATA_HOME:-$HOME/.local/share}/flea-omadesign"
mkdir -p "$state"
exec 9>"$state/refresh.lock"
flock 9
stamp=$(stat -c '%Y:%s:%Z' /usr/bin/flea /usr/share/flea/ui/Preview.qml)
if [[ -f "$state/ui.stamp" && $(cat "$state/ui.stamp") == "$stamp" && -f "$state/ui/boot/shell.qml" ]]; then
  exit 0
fi
stage="$state/ui.new"
rm -rf -- "$stage"
/usr/bin/node "$root/scripts/overlay.mjs" /usr/share/flea/ui "$stage" "$root"
rm -rf -- "$state/ui.old"
[[ ! -d "$state/ui" ]] || mv "$state/ui" "$state/ui.old"
mv "$stage" "$state/ui"
printf '%s\n' "$stamp" > "$state/ui.stamp"
rm -rf -- "$state/ui.old"
