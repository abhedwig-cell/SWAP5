#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL=df51575e18777856a47a5d0d1e2e1c7456be4601
BUILD="${RUNNER_TEMP:-/tmp}/eb-i10r2-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"; mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "EB_I10R_GATE_FAIL $*" >&2; exit 110; }

# Current-canonical race guard. This replay is a current-canonical owner candidate,
# not a floating patch against whatever canonical happens to become later.
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch current canonical'
CURRENT="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CURRENT" == "$CANONICAL" ]] || fail "canonical race: expected $CANONICAL got $CURRENT"
echo 'EB_I10R_CURRENT_CANONICAL_RACE_GUARD=PASS'

# Exact workunit delta. Existing F-KT, F-MR18, F-MR39, MultiSWAP runtime and
# process physics must remain byte-identical to canonical.
mapfile -t changed < <(git diff --name-only "$CANONICAL"..HEAD | sort)
printf '%s\n' "${changed[@]}" > "$BUILD/changed.txt"
cat > "$BUILD/allowed.txt" <<'EOF'
.github/workflows/eb-i10r-owner-gate.yml
src/runtime/mod_fmr_accepted_water_thermal_binding.f90
tests/eb/EB-I10R_ARCHITECTURE_AUDIT.json
tests/eb/EB-I10R_CONTRACT.md
tests/eb/run_eb_i10r_atomic_binding_gate.sh
tests/eb/test_eb_i10r_atomic_water_thermal_binding.f90
EOF
sort -o "$BUILD/allowed.txt" "$BUILD/allowed.txt"
diff -u "$BUILD/allowed.txt" "$BUILD/changed.txt" || fail 'unexpected branch delta'
git diff --quiet "$CANONICAL"..HEAD -- \
  src/kernel/mod_kernel_transactions.f90 \
  src/runtime/mod_fmr_accepted_commit_receipt.f90 \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  src/process/mod_soil_temperature_contract.f90 \
  src/process/mod_restricted_soil_temperature.f90 || fail 'canonical transaction/thermal authority changed'
echo 'EB_I10R_CANONICAL_TRANSACTION_AND_THERMAL_AUTHORITIES_IMMUTABLE=PASS'
echo 'EB_I10R_EXACT_WORKUNIT_SCOPE=PASS'

# Semantic collision guard: the superseded design accepted detached candidates
# and receipts. The remediated module may expose only the atomic run seam and
# read-only accepted-record metadata.
SRC=src/runtime/mod_fmr_accepted_water_thermal_binding.f90
! grep -Fq 'kernel_candidate_state_t' "$SRC" || fail 'candidate type leaked into EB-I10R public composition'
! grep -Fq 'fmr_commit_candidate_with_receipt' "$SRC" || fail 'EB-I10R introduced direct commit path'
! grep -Eiq 'public[[:space:]]*::[[:space:]].*(capture_|authorize_|bind_.*provenance|receipt)' "$SRC" || \
  fail 'post-hoc authorization surface reintroduced'
! grep -Eiq '^[[:space:]]*(open|read|write)[[:space:]]*\(' "$SRC" || fail 'I/O leaked into runtime seam'
! grep -Eiq '(headcalc|modflow|\.swp)' "$SRC" || fail 'legacy/coupler implementation detail leaked into runtime seam'
grep -Fq 'public :: fmr_run_serialized_multiswap_with_water_thermal_binding' "$SRC" || fail 'atomic entry point missing'
grep -Fq 'call fmr_run_serialized_physical_multiswap' "$SRC" || fail 'canonical MultiSWAP runtime not reused'
echo 'EB_I10R_NO_POSTHOC_CANDIDATE_RECEIPT_AUTHORIZATION_API=PASS'
echo 'EB_I10R_NO_SECOND_COMMIT_OR_IO_PATH=PASS'

python3 - <<'PY'
import json
from pathlib import Path
p=Path('tests/eb/EB-I10R_ARCHITECTURE_AUDIT.json')
a=json.loads(p.read_text())
assert a['canonical_base']=='df51575e18777856a47a5d0d1e2e1c7456be4601'
assert a['supersedes']=='blocked post-hoc EB-I10 tuple-token design'
inv=a['invariants']
assert len(inv)==30
assert [x['id'] for x in inv]==list(range(1,31))
assert all(x['status'] in {'pass','preserved','bounded_nonclaim'} for x in inv)
attack=a['semantic_attack_review']
assert attack['no_new_nonce'] and attack['no_kernel_change'] and attack['no_second_commit_path']
assert attack['no_physical_payload_copy'] and attack['no_extra_physical_solve']
print('EB_I10R_ALL_30_ARCHITECTURE_INVARIANTS_RECONCILED=PASS')
print('EB_I10R_SEMANTIC_ATTACK_REMEDIATION_RECORDED=PASS')
PY
grep -Fq 'There is no public candidate-capture API' tests/eb/EB-I10R_CONTRACT.md || fail 'contract missing anti-collision rule'
grep -Fq 'does not yet bind a specific water-transfer amount or route' tests/eb/EB-I10R_CONTRACT.md || fail 'payload nonclaim missing'
grep -Fq 'parallel-backend provenance publication' tests/eb/EB-I10R_CONTRACT.md || fail 'backend nonclaim missing'
git diff --check "$CANONICAL" -- "$SRC" tests/eb .github/workflows || fail 'diff check failed'
echo 'EB_I10R_CONTRACT_AND_DIFF_CHECK=PASS'

RFLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
NEWFLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
 tests/fsi/fsi04_real_headcalc_stubs.f90
 src/runtime/mod_a23bu_worker_execution_context.f90
 src/transaction/mod_transaction_reference.f90
 src/transaction/mod_fkt_temporal_indicator_history.f90
 src/runtime/mod_canonical_contracts.f90
 src/runtime/mod_canonical_interval_runtime.f90
 src/kernel/mod_kernel_transactions.f90
 src/kernel/mod_kernel_committed_persistence.f90
 src/runtime/mod_fmr_runtime_core.f90
 src/runtime/mod_fmr_checkpoint_orchestrator.f90
 src/runtime/mod_fmr_accepted_commit_receipt.f90
 src/solver/mod_soil_water_solver_contract.f90
 src/solver/mod_process_hydraulic_view.f90
 src/solver/mod_reference_richards_workspace.f90
 src/solver/mod_reference_richards_state_binding.f90
 src/solver/mod_b110_default_mvg_provider.f90
 src/solver/mod_b110_source_sink_provider.f90
 src/solver/mod_b110_root_sink_provider.f90
 src/solver/mod_fixed_flux_top_boundary_provider.f90
 src/solver/mod_reference_linear_solver.f90
 src/solver/mod_reference_richards_temporal_indicator.f90
 src/legacy/b1_10_port/headcalc.f90
 src/adapter/mod_reference_richards_legacy_binding.f90
 src/adapter/mod_b110_serialized_context_binding.f90
 src/process/mod_snow_process.f90
 src/process/mod_soil_temperature_contract.f90
 src/process/mod_restricted_soil_temperature.f90
 src/process/mod_restricted_fixed_weir_surface_water.f90
 src/runtime/mod_fmr_serialized_reference_backend.f90
 src/runtime/mod_fmr_serialized_multiswap_runtime.f90
 src/runtime/mod_fmr_accepted_water_thermal_binding.f90
 tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    flags=("${RFLAGS[@]}")
    case "$src" in
      src/runtime/mod_fmr_accepted_water_thermal_binding.f90) flags=("${NEWFLAGS[@]}");;
    esac
    gfortran "${flags[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${NEWFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/eb/test_eb_i10r_atomic_water_thermal_binding.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test-eb-i10r"
  "$OUT/test-eb-i10r" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  "$OUT/test-eb-i10r" > "$OUT/repeat.txt" 2>&1 || { cat "$OUT/repeat.txt" >&2; fail "repeat O$opt"; }
  cmp "$OUT/output.txt" "$OUT/repeat.txt" || fail "repeat nondeterminism O$opt"
  for marker in \
    EB_I10R_ACCEPTED_THERMAL_TRANSACTION_BINDING=PASS \
    EB_I10R_EXISTING_WATER_MASS_AUTHORITY_PRESERVED=PASS \
    EB_I10R_THERMAL_FAILURE_NO_PROVENANCE_AND_EXACT_ROLLBACK=PASS \
    EB_I10R_NONTHERMAL_REQUEST_FAILS_PRECOMMIT=PASS \
    EB_I10R_SPARSE_MULTISWAP_THERMAL_BINDING=PASS \
    EB_I10R_INVALID_BINDING_REQUESTS_PRECOMMIT=PASS \
    'EB_I10R_ATOMIC_WATER_THERMAL_BINDING_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || fail "missing marker $marker O$opt"
  done
  echo "EB_I10R_EXECUTABLE_GATE_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 output drift'
echo 'EB_I10R_REPEAT_AND_O0_O2_DETERMINISM=PASS'
sha256sum "$BUILD/o0/output.txt" | awk '{print "EB_I10R_EVIDENCE_SHA256=" $1}'
echo 'EB_I10R_OWNER_GATE PASS'
