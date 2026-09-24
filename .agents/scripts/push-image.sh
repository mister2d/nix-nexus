#!/usr/bin/env bash
# push-image.sh — build one or more flake OCI-image packages and publish a
# (multi-arch) image to the Novuscotia registry.
#
# Usage: push-image.sh <image-name> <package> [<package>...]
#   image-name  registry image name (pushed under novuscotia-ops/), e.g.
#               print-server
#   package     one or more flake package attributes under packages.<system>,
#               e.g. print-server-image-amd64 print-server-image-arm64
#
# Tag is the short HEAD sha (git rev-parse --short HEAD). Refuses to run
# against a dirty working tree.
#
# For each package: builds with `nix build --impure`, reads the built
# image's platform from its config (`skopeo inspect --format
# '{{.Architecture}}'`), and pushes it to
# code.novuscotia.com/novuscotia-ops/<image-name>:<tag>-<arch> via `skopeo
# copy docker-archive:<result> docker://...`.
#
# With two or more packages, this also assembles an OCI index (manifest
# list) at "<tag>" referencing every pushed per-arch image (`regctl index
# create` + `regctl index add`, from the nixpkgs `regclient` package), then
# retags it "latest" (`regctl image copy`, which retags the whole index).
# With exactly one package, "<tag>" and "latest" are pushed directly as
# plain single-arch images instead — no index is created.
#
# Credentials come only from the operator's own `skopeo login` (containers
# auth.json, typically $XDG_RUNTIME_DIR/containers/auth.json). This script
# never reads, prints, or requires a token itself. skopeo copies pass
# --insecure-policy: the source is a locally built archive, so no signature
# policy.json applies. regctl (used only to assemble the index) does not
# understand the containers auth.json lookup path; it is pointed at the
# same file via DOCKER_CONFIG, by symlinking it into a scratch directory as
# config.json. This script never opens or copies the file itself.
#
# Exit codes: 0 = success, 1 = dirty tree, 2 = build failed, 3 = push
# failed, 4 = argument error, 5 = index assembly failed.

set -euo pipefail

REGISTRY="code.novuscotia.com/novuscotia-ops"
CONTAINERS_AUTH="${REGISTRY_AUTH_FILE:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/containers/auth.json}"

if [[ $# -lt 2 ]]; then
  echo "Usage: push-image.sh <image-name> <package> [<package>...]" >&2
  exit 4
fi

IMAGE_NAME="$1"
shift
PACKAGES=("$@")

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "push-image: working tree is dirty. Commit or stash before pushing an image." >&2
  exit 1
fi

TAG="$(git rev-parse --short HEAD)"

ARCH_TAGS=()

for PACKAGE in "${PACKAGES[@]}"; do
  echo "== push-image: building .#${PACKAGE} (tag ${TAG}) =="
  if ! OUT_PATH=$(nix build --impure ".#${PACKAGE}" --no-link --print-out-paths); then
    echo "push-image: build of ${PACKAGE} failed." >&2
    exit 2
  fi
  echo "build: OK, ${OUT_PATH}"

  ARCH="$(nix run --impure nixpkgs#skopeo -- inspect --format '{{.Architecture}}' "docker-archive:${OUT_PATH}")"
  if [[ -z "$ARCH" ]]; then
    echo "push-image: could not read the architecture of ${PACKAGE}." >&2
    exit 2
  fi
  echo "arch: ${ARCH}"

  DEST_ARCH="docker://${REGISTRY}/${IMAGE_NAME}:${TAG}-${ARCH}"
  echo "-- stage: push ${TAG}-${ARCH} --"
  if ! nix run --impure nixpkgs#skopeo -- --insecure-policy copy "docker-archive:${OUT_PATH}" "$DEST_ARCH"; then
    echo "push-image: push of ${DEST_ARCH} failed." >&2
    exit 3
  fi
  DIGEST_ARCH="$(nix run --impure nixpkgs#skopeo -- inspect --format '{{.Digest}}' "$DEST_ARCH")"
  echo "  digest: ${DIGEST_ARCH}"

  ARCH_TAGS+=("${TAG}-${ARCH}")
done

if [[ ${#ARCH_TAGS[@]} -eq 1 ]]; then
  echo "-- stage: single-arch publish (no index) --"
  DEST_TAGGED="docker://${REGISTRY}/${IMAGE_NAME}:${TAG}"
  DEST_LATEST="docker://${REGISTRY}/${IMAGE_NAME}:latest"
  SRC="docker://${REGISTRY}/${IMAGE_NAME}:${ARCH_TAGS[0]}"

  if ! nix run --impure nixpkgs#skopeo -- --insecure-policy copy "$SRC" "$DEST_TAGGED"; then
    echo "push-image: push of ${DEST_TAGGED} failed." >&2
    exit 3
  fi
  if ! nix run --impure nixpkgs#skopeo -- --insecure-policy copy "$SRC" "$DEST_LATEST"; then
    echo "push-image: push of ${DEST_LATEST} failed." >&2
    exit 3
  fi

  DIGEST="$(nix run --impure nixpkgs#skopeo -- inspect --format '{{.Digest}}' "$DEST_TAGGED")"
  echo "push-image: ${REGISTRY}/${IMAGE_NAME}:${TAG} pushed (single-arch)."
  echo "  digest: ${DIGEST}"
  exit 0
fi

echo "-- stage: assemble multi-arch index --"
DOCKER_CONFIG_DIR="$(mktemp -d)"
trap 'rm -rf "$DOCKER_CONFIG_DIR"' EXIT
ln -s "$CONTAINERS_AUTH" "$DOCKER_CONFIG_DIR/config.json"
export DOCKER_CONFIG="$DOCKER_CONFIG_DIR"

INDEX_TAGGED="${REGISTRY}/${IMAGE_NAME}:${TAG}"
INDEX_LATEST="${REGISTRY}/${IMAGE_NAME}:latest"

if ! nix shell --impure nixpkgs#regclient.regctl -c regctl index create "$INDEX_TAGGED"; then
  echo "push-image: index create of ${INDEX_TAGGED} failed." >&2
  exit 5
fi

for ARCH_TAG in "${ARCH_TAGS[@]}"; do
  if ! nix shell --impure nixpkgs#regclient.regctl -c regctl index add "$INDEX_TAGGED" \
    --ref "${REGISTRY}/${IMAGE_NAME}:${ARCH_TAG}"; then
    echo "push-image: index add of ${ARCH_TAG} to ${INDEX_TAGGED} failed." >&2
    exit 5
  fi
done

if ! nix shell --impure nixpkgs#regclient.regctl -c regctl image copy "$INDEX_TAGGED" "$INDEX_LATEST"; then
  echo "push-image: retag of ${INDEX_TAGGED} to latest failed." >&2
  exit 5
fi

INDEX_DIGEST="$(nix shell --impure nixpkgs#regclient.regctl -c regctl manifest digest "$INDEX_TAGGED")"
echo "push-image: ${INDEX_TAGGED} (index) pushed, also tagged latest."
echo "  index digest: ${INDEX_DIGEST}"
