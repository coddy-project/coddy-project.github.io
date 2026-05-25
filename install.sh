#!/usr/bin/env bash
# Install Coddy from GitHub Releases into ~/.local/bin and bootstrap ~/.coddy.
# Usage:
#   curl -fsSL https://coddy.dev/install.sh | bash
#   ./install.sh [--version X.Y.Z] [--install-dir DIR] [--home DIR] [-y]
set -euo pipefail

CODDY_REPO="${CODDY_REPO:-coddy-project/coddy-agent}"
CODDY_API="${CODDY_API:-https://api.github.com}"
CODDY_INSTALL_SCRIPT_URL="${CODDY_INSTALL_SCRIPT_URL:-https://coddy.dev/install.sh}"
CODDY_INSTALL_DIR="${CODDY_INSTALL_DIR:-}"
CODDY_HOME="${CODDY_HOME:-}"
CODDY_VERSION="${CODDY_VERSION:-}"
YES=0

usage() {
  cat <<EOF
Usage: install.sh [options]

Installs the release binary (http + ui + scheduler + memory) and bootstraps
\$CODDY_HOME (default ~/.coddy) with config.yaml from config.example.yaml
when the file is missing.

Options:
  --version X.Y.Z   Install a specific release (default: latest)
  --install-dir D   Binary directory (default: ~/.local/bin)
  --home D          Agent state directory (default: ~/.coddy)
  --repo OWNER/NAME Override GitHub repo (default: coddy-project/coddy-agent)
  -y, --yes         Non-interactive
  -h, --help        Show this help

Environment:
  CODDY_REPO, CODDY_VERSION, CODDY_INSTALL_DIR, CODDY_HOME, CODDY_API

After install:
  export PATH="\$HOME/.local/bin:\$PATH"   # if needed
  coddy -v
  edit ~/.coddy/config.yaml and set your provider API key
  coddy http    # browser UI on http://127.0.0.1:12345/

Script URL: ${CODDY_INSTALL_SCRIPT_URL}
EOF
}

log() { printf 'coddy-install: %s\n' "$*"; }
die() { log "error: $*"; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --version) CODDY_VERSION="${2:-}"; shift 2 ;;
    --install-dir) CODDY_INSTALL_DIR="${2:-}"; shift 2 ;;
    --home) CODDY_HOME="${2:-}"; shift 2 ;;
    --repo) CODDY_REPO="${2:-}"; shift 2 ;;
    -y|--yes) YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

need_cmd uname
need_cmd curl
need_cmd tar
need_cmd install
need_cmd mktemp

OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
  Linux) GOOS=linux ;;
  Darwin) GOOS=darwin ;;
  *) die "unsupported OS: $OS (use install.ps1 on Windows)" ;;
esac
case "$ARCH" in
  x86_64|amd64) GOARCH=amd64 ;;
  aarch64|arm64) GOARCH=arm64 ;;
  *) die "unsupported CPU: $ARCH" ;;
esac

if [ -z "$CODDY_INSTALL_DIR" ]; then
  CODDY_INSTALL_DIR="${HOME}/.local/bin"
fi
if [ -z "$CODDY_HOME" ]; then
  CODDY_HOME="${HOME}/.coddy"
fi

mkdir -p "$CODDY_INSTALL_DIR" "$CODDY_HOME/sessions" "$CODDY_HOME/skills"

api_latest="${CODDY_API%/}/repos/${CODDY_REPO}/releases/latest"
api_tag=""
if [ -n "$CODDY_VERSION" ]; then
  ver="${CODDY_VERSION#v}"
  api_tag="${CODDY_API%/}/repos/${CODDY_REPO}/releases/tags/${ver}"
fi

fetch_release_json() {
  local url="$1"
  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "User-Agent: coddy-install" \
    "$url"
}

if [ -n "$api_tag" ]; then
  REL_JSON="$(fetch_release_json "$api_tag")" || die "release ${CODDY_VERSION} not found on ${CODDY_REPO}"
else
  REL_JSON="$(fetch_release_json "$api_latest")" || die "could not fetch latest release from ${CODDY_REPO}"
fi

TAG="$(printf '%s' "$REL_JSON" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
TAG="${TAG#v}"
[ -n "$TAG" ] || die "could not parse release tag from GitHub API"

ASSET="coddy_${TAG}_${GOOS}_${GOARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/${CODDY_REPO}/releases/download/${TAG}/${ASSET}"

DEST="${CODDY_INSTALL_DIR}/coddy"
if [ -f "$DEST" ] && [ "$YES" -eq 0 ]; then
  printf 'Replace existing %s with %s? [y/N] ' "$DEST" "$TAG"
  read -r ans || ans=""
  case "$ans" in
    y|Y|yes|YES) ;;
    *) log "cancelled"; exit 0 ;;
  esac
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

log "downloading ${ASSET} (${TAG})"
curl -fsSL -o "${TMP}/archive.tar.gz" "$DOWNLOAD_URL"
tar -xzf "${TMP}/archive.tar.gz" -C "$TMP"
[ -f "${TMP}/coddy" ] || die "archive missing coddy binary"
install -m 0755 "${TMP}/coddy" "$DEST"
log "installed ${DEST}"

CONFIG="${CODDY_HOME}/config.yaml"
if [ ! -f "$CONFIG" ]; then
  EXAMPLE_URL="https://raw.githubusercontent.com/${CODDY_REPO}/${TAG}/config.example.yaml"
  if curl -fsSL -o "$CONFIG" "$EXAMPLE_URL"; then
    log "created ${CONFIG} from release example"
  else
    die "could not download ${EXAMPLE_URL} (create ${CONFIG} manually)"
  fi
else
  log "kept existing ${CONFIG}"
fi

if ! printf '%s' "${PATH:-}" | tr ':' '\n' | grep -qx "$CODDY_INSTALL_DIR"; then
  log "add to PATH: export PATH=\"${CODDY_INSTALL_DIR}:\$PATH\""
fi

log "done: $("$DEST" -v 2>/dev/null || echo "coddy installed")"
log "next: set API keys in ${CONFIG}, then: coddy http"
