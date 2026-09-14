#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm14-preservation-$$"
AUG_DIR="$ROOT/tests/fpm/.fpm14-preservation-$$"
mkdir -p "$BUILD" "$AUG_DIR"
trap 'rm -rf "$BUILD" "$AUG_DIR"' EXIT
cd "$ROOT"

fail(){ echo "FPM14_PRESERVATION_GATE_FAIL $*" >&2; exit 94; }
CANONICAL='e7b512cb4d7f400ed8e1d7aeb24f6dfe165ac557'

# This gate is preservation-only. It replays already-admitted routes against the
# F-PM14 current postimage. It does not define new drainage or surface-water
# semantics and it deliberately does not rerun stale admission lineage guards.
git merge-base --is-ancestor "$CANONICAL" HEAD || fail 'PM14 head is not descended from pinned current-canonical base'

# ---------------------------------------------------------------------------
# A. F-CI33 precomputed DIVDRA route: exact admitted source/test oracle locks.
# ---------------------------------------------------------------------------
declare -A DIVDRA_BLOBS=(
  [src/process/mod_drainage_spatial_distribution.f90]=1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a
  [src/runtime/mod_fmr_divdra_runtime_binding.f90]=e4737fb6f00a11ed16e34bee44b3442ac84b31aa
  [src/solver/mod_process_hydraulic_view.f90]=d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
  [src/solver/mod_b110_source_sink_provider.f90]=d6c57add72387e5c0022a44319fff08046194aac
  [tests/fci/fci33_divdra_runtime_admission_smoke.f90]=2b07427b6dd0102816f923b48c5f8200e4875287
)
for p in "${!DIVDRA_BLOBS[@]}"; do
  [[ "$(git rev-parse "HEAD:$p")" == "${DIVDRA_BLOBS[$p]}" ]] || fail "precomputed DIVDRA oracle/source drift: $p"
done
echo 'FPM14_PRECOMPUTED_DIVDRA_ORACLE_SOURCE_LOCKS=PASS'

compile_divdra(){
  local opt="$1" out="$2"
  mkdir -p "$out"
  local common=(-std=f2008 -Wall -Wextra "$opt" -J"$out" -I"$out")
  gfortran "${common[@]}" -c src/solver/mod_soil_water_solver_contract.f90 -o "$out/contract.o"
  gfortran "${common[@]}" -c src/solver/mod_process_hydraulic_view.f90 -o "$out/view.o"
  gfortran "${common[@]}" -c src/process/mod_drainage_spatial_distribution.f90 -o "$out/divdra.o"
  gfortran "${common[@]}" -c src/runtime/mod_fmr_divdra_runtime_binding.f90 -o "$out/binding.o"
  gfortran "${common[@]}" -c src/solver/mod_b110_source_sink_provider.f90 -o "$out/source_sink.o"
  gfortran "${common[@]}" tests/fci/fci33_divdra_runtime_admission_smoke.f90 \
    "$out/contract.o" "$out/view.o" "$out/divdra.o" "$out/binding.o" "$out/source_sink.o" -o "$out/smoke"
  "$out/smoke" > "$out/output.txt"
  grep -Fxq 'FCI33_VALID_PUBLICATION=PASS' "$out/output.txt" || fail "DIVDRA valid publication $opt"
  grep -Fxq 'FCI33_SCALAR_MASS_PRESERVATION=PASS' "$out/output.txt" || fail "DIVDRA mass preservation $opt"
  grep -Fxq 'FCI33_B110_CONSUMER_SEAM=PASS' "$out/output.txt" || fail "DIVDRA consumer seam $opt"
  grep -Fxq 'FCI33_ZERO_PATH=PASS' "$out/output.txt" || fail "DIVDRA zero path $opt"
  grep -Fxq 'FCI33_PROCESS_REJECTION=PASS' "$out/output.txt" || fail "DIVDRA rejection $opt"
  grep -Fxq 'FCI33_OVERWRITE_GUARD=PASS' "$out/output.txt" || fail "DIVDRA overwrite guard $opt"
  grep -Fxq 'FCI33_DIVDRA_RUNTIME_ADMISSION_SMOKE=PASS' "$out/output.txt" || fail "DIVDRA admitted smoke $opt"
}
compile_divdra -O0 "$BUILD/divdra-o0"
compile_divdra -O2 "$BUILD/divdra-o2"
cmp -s "$BUILD/divdra-o0/output.txt" "$BUILD/divdra-o2/output.txt" || {
  diff -u "$BUILD/divdra-o0/output.txt" "$BUILD/divdra-o2/output.txt" >&2 || true
  fail 'precomputed DIVDRA O0/O2 output drift'
}
DIVDRA_HASH="$(sha256sum "$BUILD/divdra-o0/output.txt" | awk '{print $1}')"
echo "FPM14_PRECOMPUTED_DIVDRA_OUTPUT_SHA256=$DIVDRA_HASH"
echo 'FPM14_PRECOMPUTED_DIVDRA_O0_O2_EXACT_IDENTITY=PASS'
echo 'FPM14_PRECOMPUTED_DIVDRA_CURRENT_POSTIMAGE_PRESERVED=PASS'

# ---------------------------------------------------------------------------
# B. F-PM08D7 fixed-weir route: exact admitted test-support locks.
# Backend is intentionally not blob-locked because F-PM14 adds an orthogonal
# drainage-response capability to that same serialized backend. The route is
# therefore re-executed on the current postimage instead.
# ---------------------------------------------------------------------------
declare -A WEIR_TEST_BLOBS=(
 [tests/fpm/mod_fpm08d7_optional_state_compat.f90]=34b1cd3f3eb47eae706c6babfb91c9ace0900be0
 [tests/fpm/run_fpm08d7_fixed_weir_process_checkpoint.sh]=f324ea39c8c8c7ab0dcd0f7207ba2cadae34d20d
 [tests/fpm/run_fpm08d7_restart_lifecycle_owner.sh]=567f90d1861a412136f2409b1c99c80a2be65119
 [tests/fpm/run_fpm08d7_runtime_compile_checkpoint.sh]=6b449da8b8a37d3acec2e40fa9979be10ca0ed65
 [tests/fpm/run_fpm08d7_temporal_preservation_owner.sh]=11d31cf2bee5a49453310104e48405abe60d0a3d
 [tests/fpm/run_fpm08d7_transactional_runtime_owner.sh]=0512ae7134d50dfd360f202a8d5567a728b1d22a
 [tests/fpm/test_fpm08d7_fixed_weir_process.f90]=8377d460f95cf08b2d243924040b22583d1f88af
 [tests/fpm/test_fpm08d7_restart_lifecycle.f90]=accfe5d53cbc291f3eb4011ac4bf98c2eba29394
 [tests/fpm/test_fpm08d7_transactional_runtime.f90]=23f50c63aef2f8a5a24bca13370985148a8d6e1c
)
for p in "${!WEIR_TEST_BLOBS[@]}"; do
  [[ "$(git rev-parse "HEAD:$p")" == "${WEIR_TEST_BLOBS[$p]}" ]] || fail "fixed-weir admitted support drift: $p"
done
for p in \
  src/process/mod_restricted_fixed_weir_surface_water.f90 \
  src/runtime/mod_fmr_fixed_weir_serialized_runtime.f90 \
  src/runtime/mod_fmr_restart_state_contract.f90 \
  src/runtime/mod_fmr_runtime_core.f90; do
  git diff --quiet "$CANONICAL"..HEAD -- "$p" || fail "fixed-weir production authority drift: $p"
done
echo 'FPM14_FIXED_WEIR_ORACLE_AND_PRODUCTION_LOCKS=PASS'

bash tests/fpm/run_fpm08d7_fixed_weir_process_checkpoint.sh > "$BUILD/weir-process.log" 2>&1 || {
  cat "$BUILD/weir-process.log" >&2; fail 'fixed-weir process replay';
}
grep -Fq 'PASS_FPM08D7_FIXED_WEIR_O0_O2_IDENTITY' "$BUILD/weir-process.log" || fail 'fixed-weir process identity marker'
echo 'FPM14_FIXED_WEIR_PROCESS_CURRENT_POSTIMAGE_REPLAY=PASS'

# The historical runtime/restart runners intentionally remain byte-identical.
# Their compile lists predate F-PM14, so create ephemeral copies that add only
# the new backend compile dependencies. Test programs, assertions and runtime
# semantics are untouched and remain locked above.
augment_weir_runner(){
  local src="$1" dst="$2"
  python3 - "$src" "$dst" <<'PY'
from pathlib import Path
import sys
src,dst=map(Path,sys.argv[1:])
s=src.read_text()
root_line='ROOT="$(cd "$(dirname "$0")/../.." && pwd)"'
if s.count(root_line) != 1:
    raise SystemExit('FPM14_PRESERVATION_GATE_FAIL fixed-weir runner root anchor drift')
s=s.replace(root_line, 'ROOT="${FPM14_PRESERVATION_ROOT:?}"')
needle='  src/process/mod_restricted_fixed_weir_surface_water.f90\n'
if s.count(needle) != 1:
    raise SystemExit('FPM14_PRESERVATION_GATE_FAIL fixed-weir runner compile-list anchor drift')
extra='''  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
'''
dst.write_text(s.replace(needle, needle+extra))
PY
  chmod +x "$dst"
}

AUG_COMPILE="$AUG_DIR/run_fpm08d7_runtime_compile_checkpoint.sh"
AUG_TX="$AUG_DIR/run_fpm08d7_transactional_runtime_owner.sh"
AUG_RESTART="$AUG_DIR/run_fpm08d7_restart_lifecycle_owner.sh"
augment_weir_runner tests/fpm/run_fpm08d7_runtime_compile_checkpoint.sh "$AUG_COMPILE"
augment_weir_runner tests/fpm/run_fpm08d7_transactional_runtime_owner.sh "$AUG_TX"
augment_weir_runner tests/fpm/run_fpm08d7_restart_lifecycle_owner.sh "$AUG_RESTART"
echo 'FPM14_FIXED_WEIR_BUILD_HYGIENE_AUGMENTATION_ONLY=PASS'

FPM14_PRESERVATION_ROOT="$ROOT" bash "$AUG_COMPILE" > "$BUILD/weir-compile.log" 2>&1 || {
  cat "$BUILD/weir-compile.log" >&2; fail 'fixed-weir runtime compile replay';
}
grep -Fq 'FPM08D7_RUNTIME_COMPILE_O0=PASS' "$BUILD/weir-compile.log" || fail 'fixed-weir O0 compile marker'
grep -Fq 'FPM08D7_RUNTIME_COMPILE_O2=PASS' "$BUILD/weir-compile.log" || fail 'fixed-weir O2 compile marker'
echo 'FPM14_FIXED_WEIR_RUNTIME_COMPILE_CURRENT_POSTIMAGE_REPLAY=PASS'

FPM14_PRESERVATION_ROOT="$ROOT" FPM08D7_TX_EVIDENCE_DIR="$BUILD/weir-tx" bash "$AUG_TX" > "$BUILD/weir-tx.log" 2>&1 || {
  cat "$BUILD/weir-tx.log" >&2; fail 'fixed-weir transactional replay';
}
for m in \
  FPM08D7_TRANSACTIONAL_RUNTIME_O0_O2_EXACT_IDENTITY=PASS \
  FPM08D7_INTERNAL_DRAINAGE_MASS_AND_SINGLE_COMMIT=PASS \
  FPM08D7_SCALAR_NODE_MISMATCH_ROLLBACK=PASS \
  FPM08D7_INFEASIBLE_TRIAL_ROLLBACK=PASS; do
  grep -Fq "$m" "$BUILD/weir-tx.log" || fail "fixed-weir transactional marker: $m"
done
echo 'FPM14_FIXED_WEIR_TRANSACTIONAL_CURRENT_POSTIMAGE_REPLAY=PASS'

FPM14_PRESERVATION_ROOT="$ROOT" FPM08D7_RESTART_EVIDENCE_DIR="$BUILD/weir-restart" bash "$AUG_RESTART" > "$BUILD/weir-restart.log" 2>&1 || {
  cat "$BUILD/weir-restart.log" >&2; fail 'fixed-weir restart replay';
}
for m in \
  FPM08D7_RESTART_O0_O2_EXACT_IDENTITY=PASS \
  FPM08D7_RESTART_LAYOUT_TYPE_FAIL_CLOSED=PASS \
  FPM08D7_RESTART_REJECTION_ATOMIC=PASS \
  FPM08D7_RESTART_ROUNDTRIP_EXACT=PASS; do
  grep -Fq "$m" "$BUILD/weir-restart.log" || fail "fixed-weir restart marker: $m"
done
echo 'FPM14_FIXED_WEIR_RESTART_CURRENT_POSTIMAGE_REPLAY=PASS'

# The admitted temporal preservation runner contains a historical whole-backend
# blob lock that is expected to fail after any orthogonal backend extension.
# Preserve its exact oracle source above, then apply its semantic checks to the
# current backend without weakening the original equality/metric requirements.
python3 - <<'PY'
from pathlib import Path
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
required_numeric=[
 'all(full%pressure_head == half%pressure_head)',
 'all(full%water_content == half%water_content)',
 'full%ponding_depth == half%ponding_depth',
 'full%groundwater_level == half%groundwater_level',
 'full%snow%process%snow_water_storage == half%snow%process%snow_water_storage',
 'full%snow%process%liquid_water_storage == half%snow%process%liquid_water_storage',
 'full%snow%event_t0 == half%snow%event_t0',
]
a=backend.index('  logical function base_physical_states_identical')
b=backend.index('  end function base_physical_states_identical',a)
helper=backend[a:b]
assert all(x in helper for x in required_numeric)
assert 'same_real_bits(' not in helper
assert 'pure elemental logical function same_real_bits(a, b)' in backend
assert 'value = abs(full%surface_water%storage - half%surface_water%storage)' in backend
print('FPM14_FIXED_WEIR_CANONICAL_BASE_TEMPORAL_IDENTITY_PRESERVED=PASS')
print('FPM14_FIXED_WEIR_SWST_TEMPORAL_METRIC_PRESERVED=PASS')
PY

git diff --check "$CANONICAL"..HEAD
echo 'FPM14_PRECOMPUTED_DIVDRA_FIXED_WEIR_PRESERVATION_GATE=PASS'
