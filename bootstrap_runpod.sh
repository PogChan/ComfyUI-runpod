#!/usr/bin/env bash
set -euo pipefail

# RunPod comfyui-base paths
COMFY_DIR="/workspace/runpod-slim/ComfyUI"
REPO_DIR="${REPO_DIR:-/workspace/comfy-sync}"  # where you clone your repo
PYTHON_BIN="${PYTHON_BIN:-python}"

echo "== Using ComfyUI at: $COMFY_DIR =="
echo "== Using repo at:    $REPO_DIR =="

if [ ! -d "$COMFY_DIR" ]; then
  echo "ERROR: ComfyUI not found at $COMFY_DIR"
  exit 1
fi
if [ ! -d "$REPO_DIR" ]; then
  echo "ERROR: Repo not found at $REPO_DIR"
  exit 1
fi

echo "== Installing common system deps =="
sudo apt-get update
sudo apt-get install -y git ffmpeg wget unzip build-essential libgl1

echo "== Linking repo -> ComfyUI (user + custom_nodes) =="

# Back up existing folders once if they exist and are not symlinks
if [ -d "$COMFY_DIR/user" ] && [ ! -L "$COMFY_DIR/user" ]; then
  sudo mv "$COMFY_DIR/user" "$COMFY_DIR/user.bak.$(date +%Y%m%d_%H%M%S)"
fi
if [ -d "$COMFY_DIR/custom_nodes" ] && [ ! -L "$COMFY_DIR/custom_nodes" ]; then
  sudo mv "$COMFY_DIR/custom_nodes" "$COMFY_DIR/custom_nodes.bak.$(date +%Y%m%d_%H%M%S)"
fi

sudo ln -sfn "$REPO_DIR/user" "$COMFY_DIR/user"
sudo ln -sfn "$REPO_DIR/custom_nodes" "$COMFY_DIR/custom_nodes"

echo "== Upgrading pip =="
$PYTHON_BIN -m pip install --upgrade pip

# Install base ComfyUI requirements (template already does this usually, but safe)
if [ -f "$COMFY_DIR/requirements.txt" ]; then
  echo "== Installing ComfyUI base requirements =="
  $PYTHON_BIN -m pip install -r "$COMFY_DIR/requirements.txt"
fi

# Install any extra global requirements you define
if [ -f "$REPO_DIR/requirements-extra.txt" ]; then
  echo "== Installing your extra requirements =="
  $PYTHON_BIN -m pip install -r "$REPO_DIR/requirements-extra.txt"
fi

# Install each custom node's requirements.txt
echo "== Installing custom node requirements =="
for d in "$COMFY_DIR/custom_nodes"/*; do
  if [ -d "$d" ] && [ -f "$d/requirements.txt" ]; then
    echo "  -> $(basename "$d")"
    $PYTHON_BIN -m pip install -r "$d/requirements.txt"
  fi
done

echo "== Bootstrap complete =="
echo "Restart ComfyUI (or the pod) if a node needs a reload."