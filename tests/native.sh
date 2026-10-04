#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
fixtures=${1:?Pass a folder containing motion documents first and a static document last}
ui="$root/artifacts/native-test-ui"
mkdir -p "$root/artifacts"
rm -rf -- "$ui"
/usr/bin/node "$root/scripts/overlay.mjs" /usr/share/flea/ui "$ui" "$root"
/usr/bin/node "$root/tests/native-driver.mjs" "$ui/Ipc.qml"
FLEA_UI="$ui" /usr/bin/flea --gui "$fixtures" > "$root/artifacts/native-test.log" 2>&1 &
manager=$!
trap 'kill "$manager" 2>/dev/null || true' EXIT
ipc() { qs ipc -p "$ui/boot/shell.qml" call "$@"; }
snapshot() {
  geometry=$(hyprctl -j clients | jq -r '[.[] | select(.class == "com.thisisgm.flea")] | last | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
  grim -g "$geometry" "$root/artifacts/$1.png"
}
ready=0
for attempt in {1..100}; do
  if ipc flea ready >/dev/null 2>&1; then ready=1; break; fi
  sleep 0.1
done
[[ "$ready" == 1 ]]
[[ $(ipc flea total) == 3 ]]
for view in list grid columns; do
  ipc omaVerification view "$view" >/dev/null
  for index in 0 1 2; do
    found=0
    for attempt in {1..100}; do
      thumbnail=$(ipc flea omaThumbnailFile "$index")
      if [[ -f "$thumbnail" ]]; then found=1; break; fi
      sleep 0.1
    done
    [[ "$found" == 1 ]] || { ipc flea omaThumbnailState "$index"; exit 1; }
    [[ $(ipc flea rowThumbReady "$index") == true ]]
  done
  printf '%s thumbnails decoded\n' "$view"
  [[ "$view" != grid ]] || snapshot grid-thumbnails
done
ipc omaVerification look 2 >/dev/null
for attempt in {1..100}; do
  static=$(ipc flea omaPreviewState)
  [[ $(jq -r .status <<< "$static") != image ]] || break
  sleep 0.1
done
[[ $(jq -r .status <<< "$static") == image ]]
printf '%s\n' "$static" > "$root/artifacts/native-static.json"
snapshot static-quicklook
ipc omaVerification closeLook >/dev/null
ipc omaVerification look 1 >/dev/null
for attempt in {1..200}; do
  motion=$(ipc flea omaPreviewState)
  [[ $(jq -r .position <<< "$motion") =~ ^[1-9][0-9]*$ ]] && break
  sleep 0.1
done
[[ $(jq -r .status <<< "$motion") == playing ]]
[[ $(jq -r .duration <<< "$motion") == 2000 ]]
printf '%s\n' "$motion" > "$root/artifacts/native-motion.json"
ipc omaVerification pause >/dev/null
sleep 0.1
paused=$(ipc flea omaPreviewState)
[[ $(jq -r .status <<< "$paused") == paused ]]
ipc omaVerification seek 1200 >/dev/null
sleep 0.2
seek=$(ipc flea omaPreviewState)
[[ $(jq -r .position <<< "$seek") -ge 1100 ]]
snapshot motion-quicklook
ipc omaVerification closeLook >/dev/null
[[ $(ipc flea previewOpen) == false ]]
ipc omaVerification pick 1 >/dev/null
for attempt in {1..100}; do
  column=$(ipc flea omaColumnState)
  [[ $(jq -r .duration <<< "$column") == 2000 ]] && break
  sleep 0.1
done
[[ $(jq -r .status <<< "$column") == paused ]]
printf '%s\n' "$column" > "$root/artifacts/native-column.json"
snapshot column-preview
if rg -n 'WARN scene:|ERROR:' "$root/artifacts/native-test.log"; then exit 1; fi
printf 'Static Quick Look, motion playback, pause, seek, close, and column preview passed.\n'
