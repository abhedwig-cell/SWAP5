#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

STATUS_A_AUTH=50346642bd565f79134ea17d5462e544b354998c
FROSS12_AUTH=786fe5bf59e616dcfa9a86b16b58c67ac0b3b97d
P2E05_BASE=dd394f33b8687e457c4d40e9765551b58fe11b6c

SW=src/solver/mod_soil_water_solver_contract.f90
REF_ADAPTER=src/adapter/mod_reference_richards_legacy_binding.f90
ROSS_ADAPTER=src/solver/mod_rossfast_d3r_soil_water_solver.f90
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
SELECTION=src/runtime/mod_fmr_rossfast_solver_selection_binding.f90

SW_P2E05=40a1ddc05fb8e2c1822763de645fd07a094568a3
REF_ADAPTER_P2E05=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
ROSS_ADAPTER_P2E05=dbb441f3529be179d64fb57f9c44336d3d20c540

BACKEND_FROSS12=19d07cac9285142d14a6e9c53706fb73d016d5ad
SELECTION_FROSS12=cca61af52bde3eed12b756547277cc2776589648
ROSS_ADAPTER_FROSS12=6d6f66273483c19c1d2318dad518c537186a0ae7

fail() { echo "FCI96_P2E05_SEMANTIC_SUCCESSOR_FAIL $*" >&2; exit 1; }

# Historical authorities remain immutable ancestors. This runner qualifies only
# the explicitly preregistered P2E05 typed-diagnostic successor on the current
# tree; it does not replace or rewrite the historical F-ROSS12 evidence.
git merge-base --is-ancestor "$STATUS_A_AUTH" HEAD || fail 'Status-A authority not ancestor'
git merge-base --is-ancestor "$FROSS12_AUTH" HEAD || fail 'F-ROSS12 authority not ancestor'
git merge-base --is-ancestor "$P2E05_BASE" HEAD || fail 'P2E05 base canonical not ancestor'

test "$(git rev-parse "$FROSS12_AUTH:$BACKEND")" = "$BACKEND_FROSS12" || fail 'historical backend authority mismatch'
test "$(git rev-parse "$FROSS12_AUTH:$SELECTION")" = "$SELECTION_FROSS12" || fail 'historical selection authority mismatch'
test "$(git rev-parse "$FROSS12_AUTH:$ROSS_ADAPTER")" = "$ROSS_ADAPTER_FROSS12" || fail 'historical adapter authority mismatch'

# Exactly three production/source surfaces may differ for this successor.
test "$(git rev-parse HEAD:$SW)" = "$SW_P2E05" || fail 'typed solver-contract blob mismatch'
test "$(git rev-parse HEAD:$REF_ADAPTER)" = "$REF_ADAPTER_P2E05" || fail 'typed Reference adapter blob mismatch'
test "$(git rev-parse HEAD:$ROSS_ADAPTER)" = "$ROSS_ADAPTER_P2E05" || fail 'typed RossFast adapter blob mismatch'
test "$(git rev-parse HEAD:$BACKEND)" = "$BACKEND_FROSS12" || fail 'serialized backend drift outside P2E05 scope'
test "$(git rev-parse HEAD:$SELECTION)" = "$SELECTION_FROSS12" || fail 'selection binding drift outside P2E05 scope'
test "$(git rev-parse HEAD:reference)" = "$(git rev-parse "$P2E05_BASE:reference")" || fail 'reference tree changed in P2E05'

# Fail closed on any file outside the preregistered P2E05 decision surface.
changed="$({ git diff --name-only "$P2E05_BASE"...HEAD || true; })"
for required in "$SW" "$REF_ADAPTER" "$ROSS_ADAPTER"; do
  grep -Fxq "$required" <<<"$changed" || fail "required successor delta absent: $required"
done
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    docs/publication/P2E05_SOLVER_RESIDUAL_CONTRACT_PREREGISTRATION.json|\
    docs/publication/P2E05_SOLVER_RESIDUAL_CONTRACT_RESULT.json|\
    src/solver/mod_soil_water_solver_contract.f90|\
    src/adapter/mod_reference_richards_legacy_binding.f90|\
    src/solver/mod_rossfast_d3r_soil_water_solver.f90|\
    tests/publication/test_pub_p2e01_solver_seam_paired_pilot.f90|\
    tests/ross/run_ross12_soil_water_solver_adapter.sh|\
    tests/ross/run_ross12_solver_selection_binding.sh|\
    tests/fci/run_fci96_p2e05_semantic_successor_preservation.sh|\
    .github/workflows/fci96-fross12-postimage-preservation.yml)
      ;;
    *) fail "out-of-scope P2E05 mutation: $path" ;;
  esac
done <<<"$changed"

git diff --check "$P2E05_BASE"...HEAD

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci96-p2e05-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

# Requalify the exact current RossFast seam, production composition and the
# publication paired extraction against the typed residual contract.
bash tests/ross/run_ross12_soil_water_solver_adapter.sh > "$BUILD/adapter.txt"
grep -Fq 'F_ROSS12_SOLVER_ADAPTER=PASS' "$BUILD/adapter.txt" || fail 'adapter semantic replay missing PASS'

bash tests/ross/run_ross12_solver_selection_binding.sh > "$BUILD/selection.txt"
grep -Fq 'F_ROSS12_SOLVER_SELECTION_BINDING=PASS' "$BUILD/selection.txt" || fail 'selection semantic replay missing PASS'

bash tests/ross/run_ross12_serialized_production_wiring.sh > "$BUILD/production.txt"
grep -Fq 'F_ROSS12_SERIALIZED_PRODUCTION_WIRING=PASS' "$BUILD/production.txt" || fail 'production semantic replay missing PASS'

bash tests/publication/run_pub_p2e01_e0_paired_pilot.sh > "$BUILD/p2e01.txt"
grep -Fq 'PUB_P2E01_E0_SOLVER_SEAM_PAIRED_PILOT=PASS' "$BUILD/p2e01.txt" || fail 'P2E01 paired replay missing PASS'
grep -Fq 'PUB_P2E05_TYPED_RESIDUAL_CONTRACT=PASS' "$BUILD/p2e01.txt" || fail 'typed residual contract marker missing'
grep -Fq 'PUB_P2E01_SCIENTIFIC_ADMISSIBILITY_NOT_EVALUATED=TRUE' "$BUILD/p2e01.txt" || fail 'scientific-admissibility boundary missing'

cat "$BUILD/adapter.txt"
cat "$BUILD/selection.txt"
cat "$BUILD/production.txt"
cat "$BUILD/p2e01.txt"

cat "$BUILD/adapter.txt" "$BUILD/selection.txt" "$BUILD/production.txt" "$BUILD/p2e01.txt" > "$BUILD/combined.txt"
echo "FCI96_P2E05_SEMANTIC_SUCCESSOR_SHA256=$(sha256sum "$BUILD/combined.txt" | awk '{print $1}')"
echo 'FCI96_FROSS12_HISTORICAL_AUTHORITY_PRESERVED=TRUE'
echo 'FCI96_P2E05_SOURCE_SCOPE_EXACT=PASS'
echo 'FCI96_P2E05_TYPED_RESIDUAL_SUCCESSOR=PASS'
echo 'FCI96_FROSS12_SEMANTIC_SUCCESSOR_PRESERVATION=PASS'
