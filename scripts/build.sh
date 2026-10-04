#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
source_dir="$root/.build/omadesign"
mkdir -p "$root/artifacts/tmp" "$root/.build"
export TMPDIR="$root/artifacts/tmp"
export CARGO_TARGET_DIR="$root/.build/target"
export CARGO_HOME="${CARGO_HOME:-$root/.build/cargo-home}"
if [[ ! -d "$source_dir/.git" ]]; then
  git clone --depth 1 --branch v0.6.3 https://github.com/michaelmonetized/omadesign.git "$source_dir"
fi
[[ $(git -C "$source_dir" rev-parse HEAD) == 5f3958b3b088ec8168ec6b5e77aa97d7e19be7ef ]] || { echo 'Use the pinned Omadesign v0.6.3 source.' >&2; exit 1; }
mkdir -p "$source_dir/src/bin/oma_preview"
cp "$root/renderer/oma-preview.rs" "$source_dir/src/bin/oma-preview.rs"
cp "$root/renderer/oma_preview/cache.rs" "$source_dir/src/bin/oma_preview/cache.rs"
cargo build --manifest-path "$source_dir/Cargo.toml" --release --locked --bin oma-preview
