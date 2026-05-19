#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

REPO="androidly/opencode-termux"
ARCH=$(uname -m)

if [ "$ARCH" != "aarch64" ]; then
    echo "Unsupported architecture: $ARCH (only aarch64 is supported)"
    exit 1
fi

CURRENT=$(opencode --version 2>/dev/null || echo "not-installed")

echo "Current version: $CURRENT"
echo "Checking latest release..."

LATEST_TAG=$(gh release list --repo "$REPO" --limit 1 -L 1 --json tagName -q '.[0].tagName' 2>/dev/null) || {
    LATEST_TAG=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" | python3 -c "import json,sys; print(json.load(sys.stdin)['tag_name'])")
}

if [ -z "$LATEST_TAG" ]; then
    echo "Failed to determine latest release version."
    exit 1
fi

LATEST="${LATEST_TAG#v}"

echo "Latest version:  $LATEST"

if [ "$CURRENT" = "$LATEST" ]; then
    echo "Already up to date."
    exit 0
fi

if [ "$CURRENT" = "not-installed" ]; then
    echo "opencode is not installed. Run install.sh first."
    exit 1
fi

echo "Upgrading $CURRENT -> $LATEST ..."

DEB_NAME="opencode_${LATEST}_aarch64.deb"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/${DEB_NAME}"

TMPFILE=$(mktemp "${TMPDIR:-/data/data/com.termux/files/usr/tmp}/opencode-upgrade.XXXXXX.deb")
trap 'rm -f "$TMPFILE"' EXIT

wget -O "$TMPFILE" "$DOWNLOAD_URL"
dpkg -i "$TMPFILE" || apt-get install -f -y

echo ""
echo "Upgrade complete."
opencode --version