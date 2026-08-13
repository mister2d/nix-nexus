#!/usr/bin/env bash
# signoff.sh — the only writer of closure sign-off records.
#
# Usage:
#   signoff.sh --slug <kebab-slug> [options] < narrative.md
#   signoff.sh --bootstrap
#
#   --slug <kebab>   required (except --bootstrap); becomes the entry filename
#   --title "<text>" entry heading; default: slug with dashes turned to spaces
#   --base <rev>     default: .signed_off_through from .agents/baseline.json
#   --head <rev>     default: HEAD
#   --verdict <v>    signed-off | blocked; default: signed-off
#   --bootstrap      record current state only — no entry file, no stdin
#   --dry-run        print everything, write nothing
#
# Writes two things:
#   .agents/signoff/<UTC-date>-<slug>.md   one immutable entry per sign-off
#   .agents/baseline.json                  current per-config state (replaced)
#
# The caller supplies judgment prose on stdin; this script generates the
# filename, timestamp, revs, commit list, drift table, hashes and verdict
# header. Callers must never hand-write a store hash — that is this script's
# job, and hand-authored entries are how the previous SIGNOFF.md format
# drifted into four incompatible conventions.
#
# Only .agents/baseline.json carries full /nix/store/...drv paths; entry
# tables carry the 32-char store hash. Baseline history is git history —
# there is deliberately no history array.
#
# Evaluation is lib.sh's drv_at_rev (clean git+file?rev= eval, never the
# dirty working tree). A config that is unevaluable on this arch (rk3588 on
# non-aarch64) records status "na"; a genuine eval error aborts the whole
# run rather than recording a bad baseline.
#
# Exit codes: 0 wrote entry (+ baseline when signed-off); 2 argument error;
# 3 dirty working tree; 4 empty stdin; 5 entry file already exists;
# 10 EVAL_FAILURE for at least one config (nothing written).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"

BASELINE_FILE=".agents/baseline.json"
SIGNOFF_DIR=".agents/signoff"

SLUG=""
TITLE=""
BASE_REV=""
HEAD_REV="HEAD"
VERDICT="signed-off"
BOOTSTRAP=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug)
      SLUG="$2"
      shift 2
      ;;
    --title)
      TITLE="$2"
      shift 2
      ;;
    --base)
      BASE_REV="$2"
      shift 2
      ;;
    --head)
      HEAD_REV="$2"
      shift 2
      ;;
    --verdict)
      VERDICT="$2"
      shift 2
      ;;
    --bootstrap)
      BOOTSTRAP=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      echo "signoff.sh: unknown argument '$1'" >&2
      echo "Usage: signoff.sh --slug <kebab-slug> [--title T] [--base REV] [--head REV] [--verdict signed-off|blocked] [--dry-run] < narrative.md" >&2
      echo "       signoff.sh --bootstrap [--dry-run]" >&2
      exit 2
      ;;
  esac
done

case "$VERDICT" in
  signed-off | blocked) ;;
  *)
    echo "signoff.sh: --verdict must be 'signed-off' or 'blocked', got '$VERDICT'" >&2
    exit 2
    ;;
esac

if [[ "$BOOTSTRAP" -eq 0 && -z "$SLUG" ]]; then
  echo "signoff.sh: --slug is required (or use --bootstrap)" >&2
  exit 2
fi

if [[ ! "$SLUG" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ && -n "$SLUG" ]]; then
  echo "signoff.sh: --slug must be kebab-case ([a-z0-9-]), got '$SLUG'" >&2
  exit 2
fi

# Read judgment prose before doing anything slow — an empty narrative should
# fail in milliseconds, not after seven evaluations. A tty on stdin means no
# redirect was given, which is the same as empty.
NARRATIVE=""
if [[ "$BOOTSTRAP" -eq 0 ]]; then
  if [[ ! -t 0 ]]; then
    NARRATIVE="$(cat)"
  fi
  if [[ -z "${NARRATIVE//[[:space:]]/}" ]]; then
    echo "signoff.sh: no judgment supplied on stdin — an entry without judgment is not a sign-off" >&2
    exit 4
  fi
fi

# drv_at_rev evaluates git+file:${PWD}, so the repo root must be the cwd.
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "signoff.sh: working tree is dirty — baselines must come from a clean committed rev" >&2
  exit 3
fi

if [[ -z "$BASE_REV" ]]; then
  if [[ "$BOOTSTRAP" -eq 1 ]]; then
    BASE_REV="$HEAD_REV"
  elif [[ -f "$BASELINE_FILE" ]]; then
    BASE_REV="$(jq -r '.signed_off_through // empty' "$BASELINE_FILE")"
    if [[ -z "$BASE_REV" ]]; then
      echo "signoff.sh: $BASELINE_FILE has no .signed_off_through; pass --base explicitly" >&2
      exit 2
    fi
  else
    echo "signoff.sh: no $BASELINE_FILE and no --base; run --bootstrap first" >&2
    exit 2
  fi
fi

BASE_SHA="$(git rev-parse "$BASE_REV")"
HEAD_SHA="$(git rev-parse "$HEAD_REV")"
BASE_SHORT="$(git rev-parse --short "$BASE_SHA")"
HEAD_SHORT="$(git rev-parse --short "$HEAD_SHA")"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TODAY="$(date -u +%F)"
ARCH="$(uname -m)"

ENTRY_FILE=""
if [[ "$BOOTSTRAP" -eq 0 ]]; then
  ENTRY_FILE="${SIGNOFF_DIR}/${TODAY}-${SLUG}.md"
  if [[ -e "$ENTRY_FILE" ]]; then
    echo "signoff.sh: $ENTRY_FILE already exists — entries are immutable, pick another slug" >&2
    exit 5
  fi
  [[ -z "$TITLE" ]] && TITLE="${SLUG//-/ }"
fi

# store_hash <drv-path> — the 32-char store hash, or "" for a non-path marker
store_hash() {
  local drv="$1"
  case "$drv" in
    /nix/store/*)
      drv="${drv#/nix/store/}"
      echo "${drv%%-*}"
      ;;
    *) echo "" ;;
  esac
}

# Evaluate every config at both revs. Collect into parallel arrays; abort the
# whole run on EVAL_FAILURE rather than recording a broken baseline.
CFG_NAMES=()
CFG_KINDS=()
CFG_BASE=()
CFG_HEAD=()
CFG_STATUS=()

echo "signoff: evaluating ${BASE_SHORT}..${HEAD_SHORT} (7 configs)" >&2

for cfg in $NIXOS_HOSTS $HM_CONFIGS; do
  kind="nixos"
  [[ "$cfg" == *"@"* ]] && kind="hm"

  head_drv="$(drv_at_rev "$HEAD_SHA" "$cfg")"
  if [[ "$head_drv" == "EVAL_FAILURE" ]]; then
    echo "signoff.sh: EVAL_FAILURE for $cfg at $HEAD_SHORT — nothing written" >&2
    exit 10
  fi

  if [[ "$BOOTSTRAP" -eq 1 || "$BASE_SHA" == "$HEAD_SHA" ]]; then
    base_drv="$head_drv"
  else
    base_drv="$(drv_at_rev "$BASE_SHA" "$cfg")"
    if [[ "$base_drv" == "EVAL_FAILURE" ]]; then
      echo "signoff.sh: EVAL_FAILURE for $cfg at $BASE_SHORT — nothing written" >&2
      exit 10
    fi
  fi

  if [[ "$head_drv" == "N/A" ]]; then
    status="N/A"
  elif [[ "$base_drv" == "$head_drv" ]]; then
    status="none"
  else
    status="DRIFT"
  fi

  CFG_NAMES+=("$cfg")
  CFG_KINDS+=("$kind")
  CFG_BASE+=("$base_drv")
  CFG_HEAD+=("$head_drv")
  CFG_STATUS+=("$status")
done

N_DRIFT=0
N_NONE=0
N_NA=0
for s in "${CFG_STATUS[@]}"; do
  case "$s" in
    DRIFT) N_DRIFT=$((N_DRIFT + 1)) ;;
    none) N_NONE=$((N_NONE + 1)) ;;
    "N/A") N_NA=$((N_NA + 1)) ;;
  esac
done

# --- render the entry ------------------------------------------------------

render_entry() {
  local verdict_label="SIGNED OFF"
  [[ "$VERDICT" == "blocked" ]] && verdict_label="BLOCKED"

  echo "# ${TITLE}"
  echo ""
  echo "<!-- generated by .agents/scripts/signoff.sh -- do not hand-edit above \"## Judgment\" -->"
  echo ""
  echo "- **recorded:** ${NOW}"
  echo "- **base:** \`${BASE_SHORT}\` $(git log -1 --format='%s' "$BASE_SHA")"
  echo "- **head:** \`${HEAD_SHORT}\` $(git log -1 --format='%s' "$HEAD_SHA")"
  echo "- **verdict:** ${verdict_label}"
  echo ""
  echo "## Commits in range"
  echo ""
  if [[ "$BASE_SHA" == "$HEAD_SHA" ]]; then
    echo "_(none — base and head are the same commit)_"
  else
    git log --reverse --format='- `%h` %s' "${BASE_SHA}..${HEAD_SHA}"
  fi
  echo ""
  echo "## Closure drift"
  echo ""
  echo "| Config | ${BASE_SHORT} | ${HEAD_SHORT} | Result |"
  echo "|---|---|---|---|"
  local i
  for i in "${!CFG_NAMES[@]}"; do
    local bh hh bcell hcell rcell
    bh="$(store_hash "${CFG_BASE[$i]}")"
    hh="$(store_hash "${CFG_HEAD[$i]}")"
    bcell="—"
    hcell="—"
    [[ -n "$bh" ]] && bcell="\`${bh}\`"
    [[ -n "$hh" ]] && hcell="\`${hh}\`"
    rcell="${CFG_STATUS[$i]}"
    [[ "$rcell" == "N/A" ]] && rcell="N/A (not evaluable on ${ARCH})"
    echo "| ${CFG_NAMES[$i]} | ${bcell} | ${hcell} | ${rcell} |"
  done
  echo ""
  echo "DRIFT ${N_DRIFT} · none ${N_NONE} · N/A ${N_NA}"
  echo ""
  echo "## Judgment"
  echo ""
  echo "${NARRATIVE}"
}

# --- render baseline.json --------------------------------------------------

render_baseline() {
  local configs i
  configs="$(
    for i in "${!CFG_NAMES[@]}"; do
      if [[ "${CFG_HEAD[$i]}" == "N/A" ]]; then
        jq -n -c \
          --arg name "${CFG_NAMES[$i]}" \
          --arg kind "${CFG_KINDS[$i]}" \
          --arg reason "not evaluable on ${ARCH}" \
          '{key: $name, value: {kind: $kind, status: "na", drv: null, reason: $reason}}'
      else
        jq -n -c \
          --arg name "${CFG_NAMES[$i]}" \
          --arg kind "${CFG_KINDS[$i]}" \
          --arg drv "${CFG_HEAD[$i]}" \
          '{key: $name, value: {kind: $kind, status: "ok", drv: $drv}}'
      fi
    done | jq -s 'from_entries'
  )"

  jq -n -S \
    --arg through "$HEAD_SHA" \
    --arg signoff "${ENTRY_FILE:-}" \
    --arg recorded "$NOW" \
    --arg arch "$ARCH" \
    --argjson configs "$configs" \
    '{
      schema: 1,
      signed_off_through: $through,
      signoff: (if $signoff == "" then null else $signoff end),
      recorded: $recorded,
      recorded_on: $arch,
      configs: $configs
    }'
}

# --- write -----------------------------------------------------------------

if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ "$BOOTSTRAP" -eq 0 ]]; then
    echo "--- would write ${ENTRY_FILE} ---"
    render_entry
    echo ""
  fi
  echo "--- would write ${BASELINE_FILE} ---"
  render_baseline
  exit 0
fi

if [[ "$BOOTSTRAP" -eq 0 ]]; then
  mkdir -p "$SIGNOFF_DIR"
  render_entry > "$ENTRY_FILE"
  echo "signoff: wrote ${ENTRY_FILE}"
fi

if [[ "$BOOTSTRAP" -eq 1 || "$VERDICT" == "signed-off" ]]; then
  TMP="$(mktemp "${BASELINE_FILE}.XXXXXX")"
  render_baseline > "$TMP"
  mv "$TMP" "$BASELINE_FILE"
  echo "signoff: baseline recorded through ${HEAD_SHORT}"
else
  echo "signoff: verdict is blocked — baseline left unchanged"
fi

printf '%-16s %s\n' "Config" "Result"
for i in "${!CFG_NAMES[@]}"; do
  printf '%-16s %s\n' "${CFG_NAMES[$i]}" "${CFG_STATUS[$i]}"
done
echo "DRIFT ${N_DRIFT} · none ${N_NONE} · N/A ${N_NA}"
