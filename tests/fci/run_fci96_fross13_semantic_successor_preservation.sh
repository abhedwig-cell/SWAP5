#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

STATUS_A_AUTH=50346642bd565f79134ea17d5462e544b354998c
FROSS12_AUTH=786fe5bf59e616dcfa9a86b16b58c67ac0b3b97d
P2E05_QUALIFIED_HEAD=ff89a93bf5b49795db5cb04be0c7325c7b060f5c
FROSS13_PRODUCTION=0fdba1a603ffd54eff7ee92a3cd7001f2b802678

SW=src/solver/mod_soil_water_solver_contract.f90
REF_ADAPTER=src/adapter/mod_reference_richards_legacy_binding.f90
ROSS_ADAPTER=src/solver/mod_rossfast_d3r_soil_water_solver.f90
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
SELECTION=src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
POLICY=src/runtime/mod_rossfast_d3r_execution_policy.f90
KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90
MODEL=src/runtime/mod_rossfast_d3r_model_binding.f90
PROVIDER=src/solver/mod_rossfast_d3r_table_provider.f90

fail() { echo "FCI96_FROSS13_SEMANTIC_SUCCESSOR_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$STATUS_A_AUTH" HEAD || fail 'Status-A authority not ancestor'
git merge-base --is-ancestor "$FROSS12_AUTH" HEAD || fail 'F-ROSS12 authority not ancestor'
git merge-base --is-ancestor "$P2E05_QUALIFIED_HEAD" HEAD || fail 'qualified P2E05 successor not ancestor'
git merge-base --is-ancestor "$FROSS13_PRODUCTION" HEAD || fail 'qualified F-ROSS13 production commit not ancestor'

# Preserve all solver/runtime authorities outside the explicitly qualified
# F-ROSS13 model-catalog/provider widening.
test "$(git rev-parse HEAD:$SW)" = 40a1ddc05fb8e2c1822763de645fd07a094568a3 || fail 'typed solver-contract drift'
test "$(git rev-parse HEAD:$REF_ADAPTER)" = 4b545c6fb260e81cd6c8f4d2d65f2beee7281e53 || fail 'typed Reference adapter drift'
test "$(git rev-parse HEAD:$ROSS_ADAPTER)" = dbb441f3529be179d64fb57f9c44336d3d20c540 || fail 'RossFast adapter drift'
test "$(git rev-parse HEAD:$BACKEND)" = 19d07cac9285142d14a6e9c53706fb73d016d5ad || fail 'serialized backend drift'
test "$(git rev-parse HEAD:$SELECTION)" = cca61af52bde3eed12b756547277cc2776589648 || fail 'solver selection binding drift'
test "$(git rev-parse HEAD:$POLICY)" = a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9 || fail 'RossFast execution policy drift'
test "$(git rev-parse HEAD:$KERNEL)" = 034136c193b287bcf9a953a9b89df2a8fb0c97cc || fail 'RossFast table kernel drift'

# The only admitted F-ROSS13 production-source successors are these exact blobs.
test "$(git rev-parse HEAD:$MODEL)" = 5442fd7e7a2f392c9b796cd17c76b17977259f22 || fail 'F-ROSS13 model-binding postimage mismatch'
test "$(git rev-parse HEAD:$PROVIDER)" = ac997bf06c56a37080d1c8db69b6d4208f4b75ca || fail 'F-ROSS13 provider postimage mismatch'
test "$(git rev-parse HEAD:reference)" = "$(git rev-parse "$FROSS13_PRODUCTION:reference")" || fail 'reference tree changed since qualified F-ROSS13 production commit'

source_delta="$(git diff --name-only "$FROSS13_PRODUCTION^" "$FROSS13_PRODUCTION" -- src)"
test "$source_delta" = $'src/runtime/mod_rossfast_d3r_model_binding.f90\nsrc/solver/mod_rossfast_d3r_table_provider.f90' || fail 'qualified F-ROSS13 production source delta is not exact two-file widening'
echo 'FCI96_FROSS13_SOURCE_SCOPE_EXACT=PASS'

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci96-fross13-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

bash tests/ross/run_ross13_36_material_production_envelope.sh > "$BUILD/ross13-provider.txt"
grep -Fq 'F_ROSS13_36_MATERIAL_PRODUCTION_ENVELOPE=PASS' "$BUILD/ross13-provider.txt" || fail '36-material production envelope replay missing PASS'

bash tests/ross/run_ross13_ross12_semantic_successor_preservation.sh > "$BUILD/ross12-successor.txt"
grep -Fq 'F_ROSS13_ROSS12_UNIT_SEMANTIC_SUCCESSOR_PRESERVATION=PASS' "$BUILD/ross12-successor.txt" || fail 'Ross12 semantic-successor replay missing PASS'

bash tests/ross/run_ross12_serialized_production_wiring.sh > "$BUILD/serialized.txt"
grep -Fq 'F_ROSS12_SERIALIZED_PRODUCTION_WIRING=PASS' "$BUILD/serialized.txt" || fail 'serialized production replay missing PASS'

bash tests/publication/run_pub_p2e01_e0_paired_pilot.sh > "$BUILD/p2e01.txt"
grep -Fq 'PUB_P2E01_E0_SOLVER_SEAM_PAIRED_PILOT=PASS' "$BUILD/p2e01.txt" || fail 'P2E01 paired replay missing PASS'
grep -Fq 'PUB_P2E05_TYPED_RESIDUAL_CONTRACT=PASS' "$BUILD/p2e01.txt" || fail 'typed residual contract marker missing'
grep -Fq 'PUB_P2E01_SCIENTIFIC_ADMISSIBILITY_NOT_EVALUATED=TRUE' "$BUILD/p2e01.txt" || fail 'scientific-admissibility boundary missing'

cat "$BUILD/ross13-provider.txt"
cat "$BUILD/ross12-successor.txt"
cat "$BUILD/serialized.txt"
cat "$BUILD/p2e01.txt"

cat "$BUILD/ross13-provider.txt" "$BUILD/ross12-successor.txt" "$BUILD/serialized.txt" "$BUILD/p2e01.txt" > "$BUILD/combined.txt"
echo "FCI96_FROSS13_SEMANTIC_SUCCESSOR_SHA256=$(sha256sum "$BUILD/combined.txt" | awk '{print $1}')"
echo 'FCI96_FROSS12_HISTORICAL_AUTHORITY_PRESERVED=TRUE'
echo 'FCI96_P2E05_TYPED_RESIDUAL_SUCCESSOR=PASS'
echo 'FCI96_FROSS13_36_MATERIAL_SUCCESSOR=PASS'
echo 'FCI96_FROSS13_SEMANTIC_SUCCESSOR_PRESERVATION=PASS'
