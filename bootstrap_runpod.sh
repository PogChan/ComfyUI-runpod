#!/usr/bin/env bash
set -euo pipefail

COMFY_DIR="${COMFY_DIR:-/workspace/runpod-slim/ComfyUI}"
REPO_DIR="${REPO_DIR:-/workspace/ComfyUI-runpod}"
PYTHON_BIN="${PYTHON_BIN:-python}"

# Prefer sudo if not root and sudo exists
SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

echo "== Using ComfyUI at: $COMFY_DIR =="
echo "== Using repo at:    $REPO_DIR =="
echo "== Python:           $($PYTHON_BIN --version 2>/dev/null || echo "$PYTHON_BIN") =="

# Sanity checks
if [ ! -d "$COMFY_DIR" ]; then
  echo "ERROR: ComfyUI not found at $COMFY_DIR"
  exit 1
fi
if [ ! -d "$REPO_DIR" ]; then
  echo "ERROR: Repo not found at $REPO_DIR"
  exit 1
fi
if [ ! -d "$REPO_DIR/user" ]; then
  echo "ERROR: Repo missing '$REPO_DIR/user'"
  exit 1
fi
if [ ! -d "$REPO_DIR/custom_nodes" ]; then
  echo "ERROR: Repo missing '$REPO_DIR/custom_nodes'"
  exit 1
fi

echo "== Installing common system deps =="
$SUDO apt-get update -y
$SUDO apt-get install -y git ffmpeg wget unzip build-essential libgl1 ca-certificates

echo "== Linking repo -> ComfyUI (user + custom_nodes) =="

# Backup real folders if present; remove symlinks if present
backup_dir() {
  local path="$1"
  if [ -L "$path" ]; then
    echo "  - Removing existing symlink: $path"
    $SUDO rm -f "$path"
  elif [ -d "$path" ]; then
    local bak="${path}.bak.$(date +%Y%m%d_%H%M%S)"
    echo "  - Backing up existing folder: $path -> $bak"
    $SUDO mv "$path" "$bak"
  fi
}

backup_dir "$COMFY_DIR/user"
backup_dir "$COMFY_DIR/custom_nodes"

$SUDO ln -s "$REPO_DIR/user" "$COMFY_DIR/user"
$SUDO ln -s "$REPO_DIR/custom_nodes" "$COMFY_DIR/custom_nodes"

echo "== Upgrading pip (safe) =="
$PYTHON_BIN -m pip install --upgrade pip

# Base requirements (usually already handled by template, but harmless)
if [ -f "$COMFY_DIR/requirements.txt" ]; then
  echo "== Installing ComfyUI base requirements =="
  $PYTHON_BIN -m pip install -r "$COMFY_DIR/requirements.txt"
fi

# Optional: your global extras (your repo)
if [ -f "$REPO_DIR/requirements-extra.txt" ]; then
  echo "== Installing your extra requirements (repo) =="
  $PYTHON_BIN -m pip install -r "$REPO_DIR/requirements-extra.txt"
fi

echo "== Installing custom node requirements =="
for d in "$COMFY_DIR/custom_nodes"/*; do
  [ -d "$d" ] || continue

  # Standard node requirements
  if [ -f "$d/requirements.txt" ]; then
    echo "  -> $(basename "$d") (requirements.txt)"
    $PYTHON_BIN -m pip install -r "$d/requirements.txt"
  fi

  # Optional conventions some repos use
  if [ -f "$d/pip-packages.txt" ]; then
    echo "  -> $(basename "$d") (pip-packages.txt)"
    $PYTHON_BIN -m pip install -r "$d/pip-packages.txt"
  fi

  if [ -f "$d/apt-packages.txt" ]; then
    echo "  -> $(basename "$d") (apt-packages.txt)"
    $SUDO xargs -a "$d/apt-packages.txt" apt-get install -y
  fi
done

echo "== Done. =="
echo "If new nodes don't appear, restart the ComfyUI service/pod."