#!/usr/bin/env bash
# push-image.sh — build a flake OCI-image package and push it to the
# Novuscotia registry.
#
# Usage: push-image.sh <package> <image-name>
#   package     flake package attribute under packages.<system>, e.g.
#               print-server-image
#   image-name  registry image name (pushed under novuscotia-ops/), e.g.
#               print-server
#
# Tag is the short HEAD sha (git rev-parse --short HEAD). Refuses to run
# against a dirty working tree. Builds with `nix build --impure`, then pushes
# both "<tag>" and "latest" to code.novuscotia.com/novuscotia-ops/<image-name>
# via `skopeo copy docker-archive:<result> docker://...`. Prints the pushed
# digest via `skopeo inspect`.
#
# Credentials come only from the operator's own `skopeo login` (containers
# auth.json, typically ~/.config/containers/auth.json). This script never
# reads, prints, or requires a token itself. Copies pass --insecure-policy:
# the source is a locally built archive, so no signature policy.json applies.
#
# Exit codes: 0 = success, 1 = dirty tree, 2 = build failed, 3 = push failed,
# 4 = argument error.

set -euo pipefail

REGISTRY="code.novuscotia.com/novuscotia-ops"

if [[ $# -lt 2 ]]; then
  echo "Usage: push-image.sh <package> <image-name>" >&2
  exit 4
fi

PACKAGE="$1"
IMAGE_NAME="$2"

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "push-image: working tree is dirty. Commit or stash before pushing an image." >&2
  exit 1
fi

TAG="$(git rev-parse --short HEAD)"

echo "== push-image: building .#${PACKAGE} (tag ${TAG}) =="
if ! OUT_PATH=$(nix build --impure ".#${PACKAGE}" --no-link --print-out-paths); then
  echo "push-image: build failed." >&2
  exit 2
fi
echo "build: OK, ${OUT_PATH}"

DEST_TAGGED="docker://${REGISTRY}/${IMAGE_NAME}:${TAG}"
DEST_LATEST="docker://${REGISTRY}/${IMAGE_NAME}:latest"

echo "-- stage: push ${TAG} --"
if ! nix run nixpkgs#skopeo -- --insecure-policy copy "docker-archive:${OUT_PATH}" "$DEST_TAGGED"; then
  echo "push-image: push of ${DEST_TAGGED} failed." >&2
  exit 3
fi

echo "-- stage: push latest --"
if ! nix run nixpkgs#skopeo -- --insecure-policy copy "docker-archive:${OUT_PATH}" "$DEST_LATEST"; then
  echo "push-image: push of ${DEST_LATEST} failed." >&2
  exit 3
fi

DIGEST="$(nix run nixpkgs#skopeo -- inspect --format '{{.Digest}}' "$DEST_TAGGED")"

echo "push-image: ${REGISTRY}/${IMAGE_NAME}:${TAG} pushed."
echo "  digest: ${DIGEST}"
