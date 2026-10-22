#!/bin/bash
# One command: install the enrollment tool, register the arubadp:// handler, open the portal.
#   ./install.sh            install + open the enrollment portal
#   ./install.sh --remove   uninstall (certs and NM profile are kept)
set -e

PORTAL="https://uswest4.cloudguest.central.arubanetworks.com/portal/scope.cust-52e107d4ed9b11ec8b7e52e2ed9a47ed/cda-user-portal/passpoint"
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"

if [ "$1" = "--remove" ]; then
    rm -f "$BIN/aruba-native-enroll" "$APPS/aruba-native-enroll.desktop"
    update-desktop-database "$APPS" 2>/dev/null || true
    echo "Removed. ~/.aruba-onboard and the NetworkManager profile were left in place."
    exit 0
fi

missing=""
for tool in python3 openssl nmcli; do
    command -v "$tool" >/dev/null || missing="$missing $tool"
done
if [ -n "$missing" ]; then
    echo "ERROR: missing:$missing" >&2
    echo "  Fedora: sudo dnf install python3 openssl NetworkManager" >&2
    echo "  Debian/Ubuntu: sudo apt install python3 openssl network-manager" >&2
    echo "  Arch: sudo pacman -S python openssl networkmanager" >&2
    exit 1
fi
if systemctl is-active --quiet iwd 2>/dev/null; then
    echo "WARNING: iwd is running. It cannot do EAP-TLS with Aruba; use NetworkManager + wpa_supplicant." >&2
fi

mkdir -p "$BIN" "$APPS"
install -m755 "$DIR/aruba-native-enroll" "$BIN/aruba-native-enroll"

# Terminal=true so progress and errors are visible when the browser launches it
cat > "$APPS/aruba-native-enroll.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Aruba Onboard (native enrollment)
Exec=$BIN/aruba-native-enroll %u
Terminal=true
NoDisplay=true
MimeType=x-scheme-handler/arubadp;
DESKTOP
update-desktop-database "$APPS" 2>/dev/null || true
xdg-mime default aruba-native-enroll.desktop x-scheme-handler/arubadp

cat <<MSG
Installed.

Next (needs internet, e.g. a phone hotspot; you don't need to be on campus):
  1. In the portal click "Yes, I already have HPE Aruba Networking Onboard"
  2. Click "Install using HPE Aruba Networking Onboard app" and allow the browser to open the link
  3. A terminal runs the enrollment. Then connect on campus:
       nmcli connection up "UVG CAMPUS CENTRAL"
MSG
xdg-open "$PORTAL" >/dev/null 2>&1 || echo "Open this URL manually: $PORTAL"
