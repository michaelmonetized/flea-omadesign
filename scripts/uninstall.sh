#!/usr/bin/env bash
set -euo pipefail
data="${XDG_DATA_HOME:-$HOME/.local/share}"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
rm -f "$HOME/.local/bin/flea" "$data/thumbnailers/omadesign.thumbnailer" "$config/environment.d/90-flea-omadesign.conf"
systemctl --user unset-environment FLEA_UI FLEA_BIN
dbus-update-activation-environment --systemd FLEA_UI= FLEA_BIN=
sudo rm -f /usr/local/bin/oma-preview
sudo rm -f /usr/share/mime/packages/flea-omadesign.xml
sudo update-mime-database /usr/share/mime
rm -rf -- "$data/flea-omadesign"
echo 'The Omadesign adapter is removed; Flea remains the default file manager.'
