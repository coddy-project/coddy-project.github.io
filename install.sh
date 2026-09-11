#!/usr/bin/env bash
# Install Coddy from GitHub Releases into ~/.local/bin and bootstrap ~/.coddy.
# Usage:
#   curl -fsSL https://coddy.dev/install.sh | bash
#   ./install.sh [--version X.Y.Z] [--install-dir DIR] [--home DIR] [-y]
set -euo pipefail

CODDY_REPO="${CODDY_REPO:-coddy-project/coddy-agent}"
CODDY_API="${CODDY_API:-https://api.github.com}"
CODDY_INSTALL_SCRIPT_URL="${CODDY_INSTALL_SCRIPT_URL:-https://coddy.dev/install.sh}"
CODDY_DOWNLOAD_BASE="${CODDY_DOWNLOAD_BASE:-https://github.com}"
CODDY_INSTALL_DIR="${CODDY_INSTALL_DIR:-}"
CODDY_DATA_DIR="${CODDY_DATA_DIR:-}"
CODDY_HOME="${CODDY_HOME:-}"
CODDY_VERSION="${CODDY_VERSION:-}"
CODDY_NO_SHELL_SETUP="${CODDY_NO_SHELL_SETUP:-0}"
YES=0

usage() {
  cat <<EOF
Usage: install.sh [options]

Installs the release binary (http + ui + scheduler + memory), its man page and
its shell completions, and bootstraps \$CODDY_HOME (default ~/.coddy) with
config.yaml from config.example.yaml when the file is missing.

Unless --no-shell-setup is given, a user-level install also writes a small
guarded block to the rc file of your login shell so that a new terminal finds
the binary on PATH, "man coddy" finds the page, and Tab completion works.

Options:
  --version X.Y.Z   Install a specific release (default: latest)
  --install-dir D   Binary directory (default: ~/.local/bin)
  --data-dir D      Man page and completions (default: alongside the binary,
                    e.g. ~/.local/bin -> ~/.local/share)
  --home D          Agent state directory (default: ~/.coddy)
  --repo OWNER/NAME Override GitHub repo (default: coddy-project/coddy-agent)
  --no-shell-setup  Do not touch ~/.zshrc or ~/.bashrc
  -y, --yes         Non-interactive
  -h, --help        Show this help

Environment:
  CODDY_REPO, CODDY_VERSION, CODDY_INSTALL_DIR, CODDY_DATA_DIR, CODDY_HOME,
  CODDY_API, CODDY_DOWNLOAD_BASE, CODDY_NO_SHELL_SETUP

After install:
  source ~/.zshrc          # or open a new terminal
  coddy -v
  edit ~/.coddy/config.yaml and set your provider API key
  coddy serve   # web UI and REST API on http://127.0.0.1:12345/

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
    --data-dir) CODDY_DATA_DIR="${2:-}"; shift 2 ;;
    --no-shell-setup) CODDY_NO_SHELL_SETUP=1; shift ;;
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
# The man page and the completions belong beside the binary, in the "share"
# directory of the same prefix: ~/.local/bin -> ~/.local/share, and
# /usr/local/bin -> /usr/local/share.
if [ -z "$CODDY_DATA_DIR" ]; then
  case "$CODDY_INSTALL_DIR" in
    */bin) CODDY_DATA_DIR="${CODDY_INSTALL_DIR%/bin}/share" ;;
    *) CODDY_DATA_DIR="${HOME}/.local/share" ;;
  esac
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
DOWNLOAD_URL="${CODDY_DOWNLOAD_BASE%/}/${CODDY_REPO}/releases/download/${TAG}/${ASSET}"

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

# The archive carries the man page and the shell completions beside the binary.
# Releases published before that change have only the binary, so every file is
# optional and its absence is a note, not an error.
MAN_PAGE="${CODDY_DATA_DIR}/man/man1/coddy.1"
BASH_COMPLETION="${CODDY_DATA_DIR}/bash-completion/completions/coddy"
ZSH_COMPLETION="${CODDY_DATA_DIR}/zsh/site-functions/_coddy"

install_extra() {
  src="$1"
  dst="$2"
  [ -f "$src" ] || return 1
  mkdir -p "$(dirname "$dst")"
  install -m 0644 "$src" "$dst"
  return 0
}

EXTRAS=0
install_extra "${TMP}/coddy.1" "$MAN_PAGE" && EXTRAS=1
install_extra "${TMP}/coddy.bash" "$BASH_COMPLETION" && EXTRAS=1
install_extra "${TMP}/coddy.zsh" "$ZSH_COMPLETION" && EXTRAS=1

if [ "$EXTRAS" -eq 1 ]; then
  log "installed man page and shell completions under ${CODDY_DATA_DIR}"
else
  log "release ${TAG} ships no man page or completions yet; installed the binary only"
fi

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

# ---------------------------------------------------------------------------
# Shell setup
#
# A binary in ~/.local/bin is invisible to a shell that has never heard of that
# directory, and a completion in ~/.local/share is invisible to zsh, whose fpath
# lists system directories only. Both are fixed in the rc file of the login
# shell, inside one guarded block that is rewritten rather than appended to on
# every run. A system prefix needs none of this: its bin, man and
# zsh/site-functions directories are already searched.
# ---------------------------------------------------------------------------

BEGIN_MARK="# >>> coddy installer >>>"
END_MARK="# <<< coddy installer <<<"

case "$CODDY_DATA_DIR" in
  /usr/*|/opt/*) SYSTEM_PREFIX=1 ;;
  *) SYSTEM_PREFIX=0 ;;
esac

login_shell="$(basename "${SHELL:-sh}")"

rc_file_for() {
  case "$1" in
    zsh) printf '%s\n' "${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash)
      # A macOS Terminal starts bash as a login shell, which reads
      # .bash_profile and never .bashrc unless that file sources it.
      if [ "$GOOS" = darwin ] && [ -f "${HOME}/.bash_profile" ]; then
        printf '%s\n' "${HOME}/.bash_profile"
      else
        printf '%s\n' "${HOME}/.bashrc"
      fi
      ;;
    *) printf '%s\n' "" ;;
  esac
}

shell_block() {
  cat <<BLOCK
case ":\$PATH:" in
  *":${CODDY_INSTALL_DIR}:"*) ;;
  *) export PATH="${CODDY_INSTALL_DIR}:\$PATH" ;;
esac
case ":\${MANPATH-}:" in
  *":${CODDY_DATA_DIR}/man:"*) ;;
  *) export MANPATH="${CODDY_DATA_DIR}/man:\${MANPATH-}" ;;
esac
BLOCK
  case "$1" in
    zsh)
      # compdef exists once compinit has run. Registering the one function is
      # cheaper than a second compinit, and correct wherever this block lands
      # in the file; without compinit the block runs it.
      cat <<'BLOCK'
fpath=("__DATA__/zsh/site-functions" $fpath)
if (( $+functions[compdef] )); then
  autoload -Uz _coddy && compdef _coddy coddy
else
  autoload -Uz compinit && compinit
fi
BLOCK
      ;;
    bash)
      # Sourced directly rather than left to bash-completion, which may not be
      # installed and only reads XDG_DATA_HOME when it is.
      cat <<'BLOCK'
[ -r "__DATA__/bash-completion/completions/coddy" ] && . "__DATA__/bash-completion/completions/coddy"
BLOCK
      ;;
  esac
}

write_shell_block() {
  rc="$1"
  shell_name="$2"
  mkdir -p "$(dirname "$rc")"
  [ -f "$rc" ] || : > "$rc"
  block_tmp="${TMP}/rc"
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0 == b { skip = 1 }
    skip == 0 { print }
    $0 == e { skip = 0 }
  ' "$rc" > "$block_tmp"
  {
    printf '%s\n' "$BEGIN_MARK"
    shell_block "$shell_name" | sed "s|__DATA__|${CODDY_DATA_DIR}|g"
    printf '%s\n' "$END_MARK"
  } >> "$block_tmp"
  # Overwrite in place so the rc file keeps its inode and permissions.
  cat "$block_tmp" > "$rc"
  rm -f "$block_tmp"
}

RC_FILE=""
if [ "$CODDY_NO_SHELL_SETUP" = "1" ]; then
  log "skipping shell setup (--no-shell-setup)"
elif [ "$SYSTEM_PREFIX" -eq 1 ]; then
  log "system prefix ${CODDY_DATA_DIR}; PATH, MANPATH and fpath already cover it"
else
  RC_FILE="$(rc_file_for "$login_shell")"
  if [ -n "$RC_FILE" ]; then
    write_shell_block "$RC_FILE" "$login_shell"
    log "shell setup written to ${RC_FILE}"
  else
    log "unknown login shell ${login_shell}; add ${CODDY_INSTALL_DIR} to PATH yourself"
  fi
fi

log "done: $("$DEST" -v 2>/dev/null || echo "coddy installed")"
if [ -n "$RC_FILE" ]; then
  log "next: source ${RC_FILE} (or open a new terminal), set API keys in ${CONFIG}, then: coddy serve"
else
  log "next: set API keys in ${CONFIG}, then: coddy serve"
fi
