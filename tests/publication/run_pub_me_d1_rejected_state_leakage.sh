#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-me-d1-${GITHUB_RUN_ID:-local}-$$"
PATCH="$ROOT/tests/publication/mutants/d1_rejected_candidate_write_through.patch"
TEST="$ROOT/tests/publication/test_pub_me_d1_rejected_state_leakage.f90"
P1E02_TEST="$ROOT/tests/publication/test_pub_p1e02_postsolver_rollback.f90"
TRANS_SOURCE="$ROOT/src/transaction/mod_transaction_reference.f90"
EXPECTED_TRANS_BLOB="d5a71a526efaebd82054580c3186f8e3545db331"

mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_ME_D1_GATE_FAIL $*" >&2; exit 1; }

[[ -f "$PATCH" ]] || fail "missing frozen D1 patch"
[[ -f "$TEST" ]] || fail "missing D1 test"
[[ "$(git hash-object "$TRANS_SOURCE")" == "$EXPECTED_TRANS_BLOB" ]] || fail "transaction source drift from D1 execution base"
git diff --check -- "$TEST" "$PATCH" tests/publication/run_pub_me_d1_rejected_state_leakage.sh || fail "diff check"
[[ -z "$(git diff --name-only -- src reference)" ]] || fail "production/reference source dirty in D1 worktree"

MUTROOT="$BUILD/mutant-source"
mkdir -p "$MUTROOT/src/transaction"
cp "$TRANS_SOURCE" "$MUTROOT/src/transaction/mod_transaction_reference.f90"
patch --batch --forward -p1 -d "$MUTROOT" < "$PATCH" >/dev/null

grep -Fq "call model%advance(committed, t0, attempt_t1, full_outcome)" \
  "$MUTROOT/src/transaction/mod_transaction_reference.f90" || fail "frozen mutant not applied"
grep -Fq "if (policy%temporal_tolerance == 0.0_real64) then" \
  "$MUTROOT/src/transaction/mod_transaction_reference.f90" || fail "mutant trigger not applied"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)

build_and_run() {
  local mode="$1"
  local opt="$2"
  local out="$BUILD/$mode/o$opt"
  local transaction_source="$TRANS_SOURCE"
  mkdir -p "$out"
  if [[ "$mode" == "mutant" ]]; then
    transaction_source="$MUTROOT/src/transaction/mod_transaction_reference.f90"
  fi

  local module_src=(
    tests/fsi/fsi04_real_headcalc_stubs.f90
    "$transaction_source"
    src/solver/mod_soil_water_accepted_step_direction_contract.f90
    src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
    src/runtime/mod_a23bu_worker_execution_context.f90
    src/transaction/mod_accepted_trajectory_directional_publication.f90
    src/transaction/mod_fkt_temporal_indicator_history.f90
    src/runtime/mod_canonical_contracts.f90
    src/runtime/mod_canonical_interval_runtime.f90
    src/kernel/mod_kernel_transactions.f90
    src/runtime/mod_fmr_runtime_core.f90
    src/runtime/mod_fmr_checkpoint_orchestrator.f90
    src/solver/mod_soil_water_solver_contract.f90
    src/solver/mod_process_hydraulic_view.f90
    src/process/mod_drainage_process.f90
    src/process/mod_drainage_tabulated_response.f90
    src/process/mod_drainage_hooghoudt_equivalent_depth.f90
    src/process/mod_drainage_hooghoudt_ipos1_response.f90
    src/process/mod_drainage_hooghoudt_ipos23_response.f90
    src/process/mod_drainage_ernst_ipos45_preparation.f90
    src/process/mod_drainage_ernst_ipos45_response.f90
    src/process/mod_drainage_empirical_interflow_response.f90
    src/process/mod_drainage_multilevel_aggregation.f90
    src/runtime/mod_fmr_drainage_response_binding.f90
    src/process/mod_soil_temperature_contract.f90
    src/process/mod_restricted_soil_temperature.f90
    src/solver/mod_reference_richards_workspace.f90
    src/solver/mod_reference_richards_state_binding.f90
    src/solver/mod_reference_linear_solver.f90
    src/solver/mod_b110_default_mvg_provider.f90
    src/solver/mod_b110_default_mvg_directional_provider.f90
    src/solver/mod_b110_source_sink_provider.f90
    src/solver/mod_fixed_flux_top_boundary_provider.f90
    src/process/mod_restricted_surface_evaporation.f90
    src/solver/mod_b110_dynamic_top_boundary_provider.f90
    src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
    src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
    src/solver/mod_reference_richards_temporal_indicator.f90
    src/legacy/b1_10_port/headcalc.f90
    src/adapter/mod_reference_richards_legacy_binding.f90
    src/adapter/mod_reference_richards_accepted_step_directional_service.f90
    src/adapter/mod_b110_serialized_context_binding.f90
    src/process/mod_snow_process.f90
    src/solver/mod_b110_root_sink_provider.f90
    src/solver/mod_b110_smooth_freatic_projection.f90
    src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
    src/process/mod_restricted_fixed_weir_surface_water.f90
    src/runtime/mod_fmr_soil_water_application_host.f90
    src/runtime/mod_rossfast_d3r_execution_policy.f90
    src/runtime/mod_rossfast_d3r_model_binding.f90
    src/solver/mod_rossfast_d3r_table_kernel.f90
    src/solver/mod_rossfast_d3r_table_provider.f90
    src/solver/mod_rossfast_d3r_soil_water_solver.f90
    src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
    src/runtime/mod_fmr_bottom_thermal_carrier.f90
    src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
    src/runtime/mod_fmr_serialized_reference_backend.f90
    src/runtime/mod_fmr_accepted_commit_receipt.f90
    src/runtime/mod_fmr_owned_commit_receipt.f90
    src/runtime/mod_fmr_bottom_external_thermal_binding.f90
    src/runtime/mod_fmr_bottom_external_thermal_provider.f90
    src/process/mod_liquid_water_sensible_enthalpy.f90
    src/runtime/mod_fmr_bottom_sensible_energy.f90
    src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  )

  local objects=()
  local source obj
  for source in "${module_src[@]}"; do
    [[ -f "$source" ]] || fail "missing compile source $source"
    obj="$out/$(basename "${source%.*}")-$(echo "$source" | tr '/.' '__').o"
    local extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$TEST" -o "$out/d1-test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/d1-test.o" -o "$out/d1-test"
  "$out/d1-test" > "$out/d1-output.txt" 2>&1 || {
    cat "$out/d1-output.txt" >&2
    fail "$mode D1 direct probe O$opt"
  }
  grep -Fq 'PUB_ME_D1_DIRECT_TRANSACTION_PROBE=PASS' "$out/d1-output.txt" || {
    cat "$out/d1-output.txt" >&2
    fail "missing $mode D1 direct marker O$opt"
  }

  if [[ "$mode" == "mutant" ]]; then
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$P1E02_TEST" -o "$out/p1e02-test.o"
    gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/p1e02-test.o" -o "$out/p1e02-test"
    "$out/p1e02-test" > "$out/p1e02-output.txt" 2>&1 || {
      cat "$out/p1e02-output.txt" >&2
      fail "mutant full-stack containment O$opt"
    }
    grep -Fq 'PUB_P1E02_POSTSOLVER_COMMITTED_STATE_IDENTITY=PASS' "$out/p1e02-output.txt" || {
      cat "$out/p1e02-output.txt" >&2
      fail "mutant escaped full-stack committed-state containment O$opt"
    }
  fi
}

for mode in clean mutant; do
  for opt in 0 2; do
    build_and_run "$mode" "$opt"
  done
  cmp -s "$BUILD/$mode/o0/d1-output.txt" "$BUILD/$mode/o2/d1-output.txt" || {
    diff -u "$BUILD/$mode/o0/d1-output.txt" "$BUILD/$mode/o2/d1-output.txt" >&2 || true
    fail "$mode O0/O2 D1 semantic drift"
  }
done

cmp -s "$BUILD/mutant/o0/p1e02-output.txt" "$BUILD/mutant/o2/p1e02-output.txt" || {
  diff -u "$BUILD/mutant/o0/p1e02-output.txt" "$BUILD/mutant/o2/p1e02-output.txt" >&2 || true
  fail "mutant full-stack O0/O2 containment drift"
}

python3 - "$BUILD/clean/o0/d1-output.txt" "$BUILD/mutant/o0/d1-output.txt" <<'PY'
import re
import sys
from pathlib import Path

clean_text = Path(sys.argv[1]).read_text()
mutant_text = Path(sys.argv[2]).read_text()

def marker(text, key):
    m = re.search(rf"^{re.escape(key)}=(.+)$", text, re.M)
    if not m:
        raise SystemExit(f"missing marker {key}")
    return m.group(1).strip()

def as_bool(v):
    if v == "T":
        return True
    if v == "F":
        return False
    raise SystemExit(f"invalid logical {v}")

def as_float(v):
    return float(v.replace("D","E"))

clean_changed = as_bool(marker(clean_text, "PUB_ME_D1_REJECT_CHANGED"))
mutant_changed = as_bool(marker(mutant_text, "PUB_ME_D1_REJECT_CHANGED"))
if clean_changed:
    raise SystemExit("clean control changed committed transaction state after reject")
if not mutant_changed:
    raise SystemExit("D1 mutant non-operative: no rejected-state contamination")

for text, name in [(clean_text, "clean"), (mutant_text, "mutant")]:
    if abs(as_float(marker(text, "PUB_ME_D1_REJECT_ACCEPTED_TOTAL_IN"))) != 0.0:
        raise SystemExit(f"{name} rejected accepted-total-in not zero")
    if abs(as_float(marker(text, "PUB_ME_D1_REJECT_ACCEPTED_TOTAL_OUT"))) != 0.0:
        raise SystemExit(f"{name} rejected accepted-total-out not zero")
    if not as_bool(marker(text, "PUB_ME_D1_CONTINUATION_MASS_COMPLETE")):
        raise SystemExit(f"{name} continuation mass incomplete")
    if abs(as_float(marker(text, "PUB_ME_D1_CONTINUATION_MASS_RESIDUAL_CM"))) > 1.0e-12:
        raise SystemExit(f"{name} continuation mass gate failed")

def state_lines(text):
    return tuple(line for line in text.splitlines() if line.startswith("PUB_ME_D1_FINAL_"))

downstream_diff = state_lines(clean_text) != state_lines(mutant_text)
classification = "EARLIER_DETECTION" if downstream_diff else "UNIQUE_DETECTION_WITHIN_BOUNDED_CONTINUATION"

print("PUB_ME_D1_CLEAN_REJECT_STATE_CHANGED=F")
print("PUB_ME_D1_MUTANT_REJECT_STATE_CHANGED=T")
print("PUB_ME_D1_B1_REJECTED_LEDGER_DIFFERENCE=NONE")
print(f"PUB_ME_D1_DOWNSTREAM_ACCEPTED_ENDPOINT_DIFF={'T' if downstream_diff else 'F'}")
print(f"PUB_ME_D1_TRANSACTION_LAYER_CLASSIFICATION={classification}")
print("PUB_ME_D1_B2_IMMEDIATE_REJECTION_BOUNDARY_DETECTION=PASS")
PY

grep -Fq 'PUB_P1E02_POSTSOLVER_COMMITTED_STATE_IDENTITY=PASS' "$BUILD/mutant/o0/p1e02-output.txt" || \
  fail "full-stack structural containment not demonstrated"

echo "PUB_ME_D1_FULL_STACK_STRUCTURAL_PREVENTION=PASS"
echo "PUB_ME_D1_CLEAN_O0_O2_SHA256=$(sha256sum "$BUILD/clean/o0/d1-output.txt" | awk '{print $1}')"
echo "PUB_ME_D1_MUTANT_O0_O2_SHA256=$(sha256sum "$BUILD/mutant/o0/d1-output.txt" | awk '{print $1}')"
echo "PUB_ME_D1_MUTANT_FULL_STACK_O0_O2_SHA256=$(sha256sum "$BUILD/mutant/o0/p1e02-output.txt" | awk '{print $1}')"
echo "PUB_ME_D1_GATE=PASS"
