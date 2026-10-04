#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
data="${XDG_DATA_HOME:-$HOME/.local/share}"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
command -v /usr/bin/flea >/dev/null
command -v /usr/bin/node >/dev/null
command -v ffmpeg >/dev/null
"$root/scripts/build.sh"
mkdir -p "$data/flea-omadesign/plugin" "$data/thumbnailers" "$HOME/.local/bin" "$config/environment.d"
cp -r "$root/scripts" "$root/ui" "$data/flea-omadesign/plugin/"
sudo install -Dm755 "$root/.build/target/release/oma-preview" /usr/local/bin/oma-preview
sudo install -Dm644 "$root/packaging/omadesign.xml" /usr/share/mime/packages/flea-omadesign.xml
sudo update-mime-database /usr/share/mime
install -m755 "$root/scripts/flea" "$HOME/.local/bin/flea"
cat > "$data/thumbnailers/omadesign.thumbnailer" <<'ENTRY'
[Thumbnailer Entry]
TryExec=/usr/local/bin/oma-preview
Exec=/usr/local/bin/oma-preview thumbnail --input %i --output %o --size %s
MimeType=application/x-omadesign;
ENTRY
rm -f "$data/flea-omadesign/ui.stamp"
"$data/flea-omadesign/plugin/scripts/refresh.sh"
printf 'FLEA_UI=%s\nFLEA_BIN=%s\n' "$data/flea-omadesign/ui" "$HOME/.local/bin/flea" > "$config/environment.d/90-flea-omadesign.conf"
systemctl --user set-environment "FLEA_UI=$data/flea-omadesign/ui" "FLEA_BIN=$HOME/.local/bin/flea"
dbus-update-activation-environment --systemd "FLEA_UI=$data/flea-omadesign/ui" "FLEA_BIN=$HOME/.local/bin/flea"
update-desktop-database "$data/applications"
echo 'Omadesign thumbnails, column previews, and Space Quick Look are installed.'
