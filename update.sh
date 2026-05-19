#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

REPO="androidly/opencode-termux"
ARCH=$(uname -m)

if [ "$ARCH" != "aarch64" ]; then
    echo "Unsupported architecture: $ARCH (only aarch64 is supported)"
    exit 1
fi

CURRENT=$(opencode --version 2>/dev/null || echo "not-installed")

echo "opencode-termux installer/updater"
echo "================================="
echo "Current version: ${CURRENT}"

echo ""
echo "[1/5] Updating package sources..."
pkg update -y 2>/dev/null || apt update -y

echo "[2/5] Installing dependencies..."
pkg install -y wget dpkg ca-certificates 2>/dev/null || apt install -y wget dpkg ca-certificates

if ! pkg list-installed 2>/dev/null | grep -q glibc-repo; then
    echo "[3/5] Adding glibc repository..."
    pkg install -y glibc-repo 2>/dev/null || apt install -y glibc-repo
    pkg update -y 2>/dev/null || apt update -y
else
    echo "[3/5] glibc repository already configured."
fi

pkg install -y glibc openssl-glibc 2>/dev/null || apt install -y glibc openssl-glibc

echo "[4/5] Fetching latest release info..."
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
    echo ""
    echo "Already up to date."
    exit 0
fi

if [ "$CURRENT" = "not-installed" ]; then
    echo ""
    echo "opencode not found, performing fresh install..."
else
    echo ""
    echo "Upgrading $CURRENT -> $LATEST ..."
fi

echo "[5/5] Downloading opencode_${LATEST}_aarch64.deb ..."
DEB_NAME="opencode_${LATEST}_aarch64.deb"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/${DEB_NAME}"

TMPFILE=$(mktemp "${TMPDIR:-/data/data/com.termux/files/usr/tmp}/opencode.XXXXXX.deb")
trap 'rm -f "$TMPFILE"' EXIT

wget -O "$TMPFILE" "$DOWNLOAD_URL"
dpkg -i "$TMPFILE" || apt-get install -f -y

echo ""
echo "Done."
opencode --version