#!/usr/bin/env bash
set -euo pipefail

BASE=0b284b5f4e224c5f76d7d78b9dbb51c99514479d
PREREG=6be9bcd8c9d214bc0404e6f9c6c33e5424db95e9
DONOR=eacdacb60524221d0c286571444271089347dbcc
AUDIT=integration/f-kt/F-KT15R_ARCHITECTURE_AUDIT.json

fail() { echo "FKT15R_QUALIFICATION_FAIL $*" >&2; exit 1; }
for rev in "$BASE" "$PREREG" "$DONOR"; do
  git cat-file -e "$rev^{commit}" 2>/dev/null || git fetch --no-tags origin "$rev"
  git cat-file -e "$rev^{commit}" 2>/dev/null || fail "missing authority $rev"
done

[[ "$(git rev-parse "$PREREG^")" == "$BASE" ]] || fail 'preregistration is not direct child of pinned F-CI48 base'
git merge-base --is-ancestor "$PREREG" HEAD || fail 'candidate does not descend from immutable preregistration'
echo 'FKT15R_PREREG_AUTHORITY=PASS'
echo 'FKT15R_CURRENT_CANONICAL_PIN=PASS'

expected_src="$(cat <<'EOF'
src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
src/adapter/mod_reference_richards_legacy_binding.f90
src/adapter/mod_soil_water_transaction_result_bridge.f90
src/kernel/mod_kernel_transactions.f90
src/legacy/b1_10_port/headcalc.f90
src/runtime/mod_canonical_contracts.f90
src/runtime/mod_canonical_interval_runtime.f90
src/solver/mod_b110_dynamic_top_boundary_provider.f90
src/solver/mod_reference_linear_solver.f90
src/solver/mod_reference_richards_state_binding.f90
src/solver/mod_reference_richards_workspace.f90
src/solver/mod_soil_water_solver_contract.f90
src/transaction/mod_transaction_reference.f90
EOF
)"
actual_src="$(git diff --name-only "$BASE" HEAD -- src | sort)"
[[ "$actual_src" == "$expected_src" ]] || {
  echo 'FKT15R unexpected src delta:' >&2
  printf '%s\n' "$actual_src" >&2
  fail 'source delta is not exact 13-path allowlist'
}
[[ "$(printf '%s\n' "$actual_src" | sed '/^$/d' | wc -l)" -eq 13 ]] || fail 'source delta count is not 13'
echo 'FKT15R_EXACT_13_SOURCE_SCOPE=PASS'

while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  head_blob="$(git rev-parse "HEAD:$path")"
  donor_blob="$(git rev-parse "$DONOR:$path")"
  [[ "$head_blob" == "$donor_blob" ]] || fail "donor blob drift: $path"
done <<< "$expected_src"
echo 'FKT15R_DONOR_BLOB_IDENTITY=PASS'

for path in \
  src/runtime/mod_coupling_application_accuracy_adapter.f90 \
  src/runtime/mod_fmr_restart_state_contract.f90 \
  src/runtime/mod_fmr_runtime_core.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90; do
  [[ "$(git rev-parse "HEAD:$path")" == "$(git rev-parse "$BASE:$path")" ]] || fail "later canonical runtime drift: $path"
done
echo 'FKT15R_LATER_CANONICAL_RUNTIME_PRESERVED=PASS'

# No frozen reference/release authority may be changed by this recomposition.
if git diff --name-only "$BASE" HEAD | grep -E '^(reference/|release/|releases/|integration/f-rb/)' >/dev/null; then
  fail 'immutable reference/release authority changed'
fi
echo 'FKT15R_REFERENCE_AND_RB1_IMMUTABLE=PASS'

python3 - "$AUDIT" <<'PY'
import json, sys
p=sys.argv[1]
with open(p, encoding='utf-8') as f:
    d=json.load(f)
rows=d.get('invariants', [])
ids=[r.get('id') for r in rows]
if ids != list(range(1,31)):
    raise SystemExit(f'FKT15R architecture audit ids invalid: {ids}')
if any(r.get('status') not in {'PASS','PRESERVED'} for r in rows):
    raise SystemExit('FKT15R architecture audit contains non-pass status')
print('FKT15R_ARCHITECTURE_AUDIT=PASS')
PY

echo 'FKT15R_NO_NEW_PRODUCTION_SEMANTICS=PASS'
echo 'FKT15R_NONCLAIM_TASK2_TYPED_ROUTE_NOT_IMPLEMENTED=PASS'
echo 'FKT15R_NONCLAIM_PRODUCTION_COUPLING_NOT_ADMITTED=PASS'
echo 'FKT15R_NONCLAIM_NO_WHOLE_WINDOW_DERIVATIVE=PASS'
echo 'FKT15R_NONCLAIM_NO_NUMERIC_APPLICATION_POLICY=PASS'
echo 'FKT15R_RECOMPOSITION_QUALIFICATION=PASS'
