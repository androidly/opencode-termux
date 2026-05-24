#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_REPO="${UPSTREAM_REPO:-anomalyco/opencode}"
TARGET_REPO="${TARGET_REPO:-androidly/opencode-termux}"
PKG="${PKG:-both}"
ODIR="${ODIR:-$ROOT_DIR/packing/release}"
PACKAGER_NAME="${PACKAGER_NAME:-Hope2333(幽零小喵) <u0catmiao@proton.me>}"
RELEASE_NOTES_FILE="${RELEASE_NOTES_FILE:-}"
GH_BIN="${GH_BIN:-gh}"
MAKE_BIN="${MAKE_BIN:-make}"
NPM_BIN="${NPM_BIN:-npm}"
SKIP_SELFCHECK="${SKIP_SELFCHECK:-0}"

log() { printf '[release-latest] %s\n' "$*"; }
die() {
	printf '[release-latest] ERROR: %s\n' "$*" >&2
	exit 1
}
need() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

usage() {
	cat <<'EOF'
用法:
  ./tools/release-latest.sh

行为:
  1. 查询上游 anomalyco/opencode 最新 release tag
  2. 查询当前仓库 androidly/opencode-termux 最新 release tag
  3. 如果版本相同，直接跳过
  4. 如果上游更新，自动打包并发布 deb + pacman

可选环境变量:
  UPSTREAM_REPO        上游仓库，默认 anomalyco/opencode
  TARGET_REPO          目标仓库，默认 androidly/opencode-termux
  PKG                  打包类型: deb / pacman / both，默认 both
  ODIR                 构建输出目录，默认 packing/release
  PACKAGER_NAME        打包者信息
  RELEASE_NOTES_FILE   自定义 release 说明文件路径
  GH_BIN               gh 命令名，默认 gh
  MAKE_BIN             make 命令名，默认 make
  SKIP_SELFCHECK       设为 1 时跳过 make selfcheck
EOF
}

normalize_tag() {
	local tag="${1:-}"
	tag="${tag#refs/tags/}"
	tag="${tag#v}"
	printf '%s' "$tag"
}

resolve_latest_tag() {
	local repo="$1"
	"$GH_BIN" release list --repo "$repo" --limit 1 --json tagName,isLatest --jq '.[] | select(.isLatest == true) | .tagName' 2>/dev/null
}

resolve_latest_tag_fallback() {
	local repo="$1"
	"$GH_BIN" api "repos/$repo/releases/latest" --jq '.tag_name'
}

resolve_tag() {
	local repo="$1"
	local tag=""
	tag="$(resolve_latest_tag "$repo" || true)"
	if [[ -z "$tag" ]]; then
		tag="$(resolve_latest_tag_fallback "$repo" || true)"
	fi
	[[ -n "$tag" ]] || die "unable to resolve latest release tag for $repo"
	printf '%s' "$tag"
}

resolve_npm_version() {
	"$NPM_BIN" view opencode-linux-arm64 version 2>/dev/null || true
}

collect_assets() {
	local pattern
	local deb_glob="opencode_${version}_*.deb"
	local pacman_glob="opencode-${version}-*.pkg.*"
	shopt -s nullglob
	case "$PKG" in
	deb)
		for pattern in "$ODIR"/deb/"$deb_glob" "$ODIR"/"$deb_glob"; do
			[[ -f "$pattern" ]] && RELEASE_ASSETS+=("$pattern")
		done
		;;
	pacman)
		for pattern in "$ODIR"/pacman/"$pacman_glob" "$ODIR"/"$pacman_glob"; do
			[[ -f "$pattern" ]] && RELEASE_ASSETS+=("$pattern")
		done
		;;
	both)
		for pattern in \
			"$ODIR"/deb/"$deb_glob" \
			"$ODIR"/pacman/"$pacman_glob" \
			"$ODIR"/"$deb_glob" \
			"$ODIR"/"$pacman_glob"; do
			[[ -f "$pattern" ]] && RELEASE_ASSETS+=("$pattern")
		done
		;;
	*)
		die "unsupported PKG=$PKG, expected deb/pacman/both"
		;;
	esac
	shopt -u nullglob
	[[ "${#RELEASE_ASSETS[@]}" -gt 0 ]] || die "no release assets found under $ODIR"
}

render_release_notes() {
	local version="$1"
	local upstream_tag="$2"
	local tmp_file="$3"
	if [[ -n "$RELEASE_NOTES_FILE" ]]; then
		[[ -f "$RELEASE_NOTES_FILE" ]] || die "release notes file not found: $RELEASE_NOTES_FILE"
		cp "$RELEASE_NOTES_FILE" "$tmp_file"
		return 0
	fi

	cat >"$tmp_file" <<EOF
OpenCode Termux 打包发布：$upstream_tag

- 上游仓库：$UPSTREAM_REPO
- 上游版本：$version
- 构建方式：真实 Termux 本地打包
- 包类型：$PKG

产物说明：
- Debian 包：适用于 Termux apt/dpkg 安装路径
- Pacman 包：适用于 Termux pacman 安装路径
EOF
}

need "$GH_BIN"
need "$MAKE_BIN"
need "$NPM_BIN"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

if [[ ! -d "$ROOT_DIR/.git" ]]; then
	die "must run inside repo root checkout"
fi

upstream_npm_version="$(resolve_npm_version)"
upstream_tag="$(resolve_tag "$UPSTREAM_REPO")"
target_tag="$(resolve_tag "$TARGET_REPO" || true)"
version="$(normalize_tag "$upstream_tag")"
current_version="$(normalize_tag "$target_tag")"

if [[ -n "$upstream_npm_version" ]]; then
	log "upstream latest npm version: $upstream_npm_version"
	if [[ "$upstream_npm_version" != "$version" ]]; then
		log "npm version and GitHub release tag differ, prefer npm version"
		version="$upstream_npm_version"
		upstream_tag="v$version"
	fi
else
	log "upstream latest npm version: <unavailable>"
fi

log "upstream latest tag: $upstream_tag"
if [[ -n "$target_tag" ]]; then
	log "target latest tag: $target_tag"
else
	log "target latest tag: <none>"
fi

if [[ -n "$current_version" && "$current_version" == "$version" ]]; then
	log "target repo already released version $version, skipping"
	exit 0
fi

mkdir -p "$ODIR"

log "building version $version with PKG=$PKG"
"$MAKE_BIN" all "VER=$version" "PKG=$PKG" "PACKAGER_NAME=$PACKAGER_NAME" "ODIR=$ODIR"

if [[ "$SKIP_SELFCHECK" != "1" ]]; then
	log "running selfcheck"
	"$MAKE_BIN" selfcheck
fi

declare -a RELEASE_ASSETS=()
collect_assets

tmp_notes="$(mktemp)"
trap 'rm -f "$tmp_notes"' EXIT
render_release_notes "$version" "$upstream_tag" "$tmp_notes"

log "assets:"
printf '  %s\n' "${RELEASE_ASSETS[@]}"

if "$GH_BIN" release view "$upstream_tag" --repo "$TARGET_REPO" >/dev/null 2>&1; then
	log "release $upstream_tag already exists, uploading assets"
	"$GH_BIN" release upload "$upstream_tag" "${RELEASE_ASSETS[@]}" --repo "$TARGET_REPO" --clobber
else
	log "creating release $upstream_tag"
	"$GH_BIN" release create "$upstream_tag" "${RELEASE_ASSETS[@]}" \
		--repo "$TARGET_REPO" \
		--title "$upstream_tag" \
		--notes-file "$tmp_notes"
fi

log "release completed: $TARGET_REPO $upstream_tag"
