#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/rm13-ribasim-smoke-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM13_RIBASIM_SMOKE_FAIL $*" >&2; exit 1; }

RIBASIM_ROOT="$ROOT/.ribasim-product-release"
MODEL_DIR="$RIBASIM_ROOT/generated_testmodels/swap5_rm13"
(
 cd "$RIBASIM_ROOT"
 pixi run python "$ROOT/tests/ribasim-management/generate_rm13_real_ribasim.py" "$MODEL_DIR"
)

ZIP="$BUILD/ribasim_linux.zip"
REL="$BUILD/release"
curl -L --fail --retry 3 https://github.com/Deltares/Ribasim/releases/download/v2026.1.1/ribasim_linux.zip -o "$ZIP"
echo "2ebff0f4ed600660640b5828bffee861380a7f41468bff75124ef7a831815139  $ZIP" | sha256sum -c -
mkdir -p "$REL"
unzip -q "$ZIP" -d "$REL"
LIB="$REL/ribasim/lib/libribasim.so"
test -f "$LIB" || fail "missing libribasim"
test -d "$REL/ribasim/lib/julia" || fail "missing bundled Julia runtime"
RIBASIM_LD_PATH="$REL/ribasim/lib:$REL/ribasim/lib/julia"

(
 cd "$RIBASIM_ROOT"
 LD_LIBRARY_PATH="$RIBASIM_LD_PATH:${LD_LIBRARY_PATH:-}" \
 RM13_RIBASIM_ROOT="$RIBASIM_ROOT" RM13_RIBASIM_MODEL="$MODEL_DIR/ribasim.toml" RM13_LIBRIBASIM="$LIB" \
 pixi run python "$ROOT/tests/ribasim-management/test_rm13_ribasim_release_loader.py"
)
