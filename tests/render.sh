#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
static=${1:?Pass a static .oma file}
motion=${2:?Pass a motion .oma file}
bin=${OMA_PREVIEW_BIN:-/usr/local/bin/oma-preview}
work="$root/artifacts/render-tests"
mkdir -p "$work"
source_hash=$(sha256sum "$static" "$motion")
cp "$static" "$work/Card # one.OMA"
thumbnail=$($bin thumbnail-cached --input "$work/Card # one.OMA" --size 256 | jq -r .file)
[[ -f "$thumbnail" ]]
[[ $(identify -format '%w' "$thumbnail") -le 256 ]]
[[ $(identify -format '%h' "$thumbnail") -le 256 ]]
[[ $($bin thumbnail-cached --input "$work/Card # one.OMA" --size 256 | jq -r .file) == "$thumbnail" ]]
touch -r "$work/Card # one.OMA" "$work/timestamp"
/usr/bin/node - "$work/Card # one.OMA" <<'JS'
const fs = require('fs');
const file = process.argv[2];
const text = fs.readFileSync(file, 'utf8');
const doc = JSON.parse(text);
const name = doc.doc.name;
fs.writeFileSync(file, text.replace(JSON.stringify(name), JSON.stringify((name[0] === 'X' ? 'Y' : 'X') + name.slice(1))));
JS
touch -r "$work/timestamp" "$work/Card # one.OMA"
changed=$($bin thumbnail-cached --input "$work/Card # one.OMA" --size 256 | jq -r .file)
[[ "$changed" != "$thumbnail" ]]
printf 'Cache reuse and same-size, same-time content invalidation passed.\n'
cp "$static" "$work/Malformed.oma"
printf '{broken' > "$work/Malformed.oma"
if $bin preview --input "$work/Malformed.oma" > "$work/malformed.json" 2> "$work/malformed.log"; then exit 1; fi
jq -e .error "$work/malformed.json" >/dev/null
if $bin thumbnail --input "$work/Card # one.OMA" --output "$work/Card # one.OMA" --size 256 > /dev/null 2>&1; then exit 1; fi
movie=$($bin preview --input "$motion" --size 640 | jq -r .file)
duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of csv=p=0 "$movie")
expected=$(jq -r .doc.motion.duration "$motion")
awk -v actual="$duration" -v expected="$expected" 'BEGIN { delta=actual-expected; if(delta<0)delta=-delta; exit(delta>0.04) }'
ffmpeg -v error -i "$movie" -f null -
ffmpeg -v error -i "$movie" -vf fps=3 -f framemd5 -y "$work/motion-frames.md5"
[[ $(awk -F, '!/^#/ {print $NF}' "$work/motion-frames.md5" | sort -u | wc -l) -gt 1 ]]
[[ $(sha256sum "$static" "$motion") == "$source_hash" ]]
printf 'Malformed input, source preservation, full-duration motion, and changing decoded frames passed.\n'
