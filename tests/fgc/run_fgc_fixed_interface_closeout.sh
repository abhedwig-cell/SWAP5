#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fgc-closeout-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

run_and_capture() {
  local label="$1"; shift
  "$@" | tee "$BUILD/$label.out"
}

run_and_capture participant bash tests/fgc/run_fgc44_real_fmr_participant.sh
grep -Fq 'FGC44_REAL_FMR_PHYSICAL_OUTWARD_TANGENT=PASS' "$BUILD/participant.out"
grep -Fq 'FGC44_REAL_FMR_TANGENT_REPLAY=PASS' "$BUILD/participant.out"

run_and_capture ownership bash tests/fapp/run_ppa_wu01_production_application_bootstrap.sh
grep -Fq 'F_GC_STORAGE_HEAD_STATE_CAPACITANCE_AUTHORITY=PASS' "$BUILD/ownership.out"
grep -Fq 'F_GC_DRAINAGE_NONE_AUTHORITY=PASS' "$BUILD/ownership.out"
grep -Fq 'F_GC_UNRESOLVED_APPLICATION_AUTHORITY_FAIL_CLOSED=PASS' "$BUILD/ownership.out"
grep -Fq 'F_GC_STALE_SWAP_RESPONSE_ORIGIN_FAIL_CLOSED=PASS' "$BUILD/ownership.out"

run_and_capture prodabi bash tests/fgc/run_fgc49d_live_production_application_context.sh
grep -Fq 'FGC49D_LIVE_PRODUCTION_FMR_ABI=PASS' "$BUILD/prodabi.out"
grep -Fq 'FGC49D_LIVE_PER_CELL_CONJUNCTIVE_CONVERGENCE=PASS' "$BUILD/prodabi.out"
grep -Fq 'FGC49D_LIVE_MODFLOW_SWAP_LEDGER_PUBLICATION=PASS' "$BUILD/prodabi.out"

run_and_capture e2e_a env FGC44_CLOSEOUT_ONECELL=1 FGC44_CLOSEOUT_COMPATIBLE_SOLVER=1 bash tests/fgc/run_fgc44_real_swap_modflow_end_to_end.sh
grep -Fq 'PUB_GC_E1_INTERFACE_IDENTITY=PASS' "$BUILD/e2e_a.out"
grep -Fq 'PUB_GC_E2_REJECTED_TRIAL_ZERO_AUTHORITY=PASS' "$BUILD/e2e_a.out"
grep -Fq 'PUB_GC_E2_PREPUBLICATION_ABORT_ZERO_AUTHORITY=PASS' "$BUILD/e2e_a.out"
grep -Fq 'PUB_GC_E2_EXACTLY_ONCE_PUBLICATION=PASS' "$BUILD/e2e_a.out"
grep -Fq 'FGC44_REAL_SWAP_PHYSICAL_RESPONSE_RELINEARIZATION=PASS' "$BUILD/e2e_a.out"
grep -Fq 'FGC44_CLOSEOUT_ONE_SWAP_ONE_MODFLOW_CELL=PASS' "$BUILD/e2e_a.out"
grep -Fq 'FGC44_INDEPENDENT_PHYSICAL_ENDPOINT=PASS' "$BUILD/e2e_a.out"
grep -Fq 'FGC44_ACCEPTED_MODFLOW_COMPONENT_BALANCE=PASS' "$BUILD/e2e_a.out"
grep -Fq 'FGC44_STOPPING_FLOW_BUDGET=PASS' "$BUILD/e2e_a.out"
grep -Fq 'FGC44_STOPPING_COMPATIBILITY_CONTRACT=PASS' "$BUILD/e2e_a.out"
grep -Fq 'FGC44_REAL_SWAP_MODFLOW_END_TO_END=PASS' "$BUILD/e2e_a.out"

run_and_capture e2e_b env FGC44_CLOSEOUT_ONECELL=1 FGC44_CLOSEOUT_COMPATIBLE_SOLVER=1 bash tests/fgc/run_fgc44_real_swap_modflow_end_to_end.sh
for key in FGC44_FINAL_HEAD_M FGC44_FINAL_Q_SWAP_M_PER_S FGC44_FINAL_Q_GW_M_PER_S FGC44_LEDGER_EXCHANGE_M; do
  grep "^$key=" "$BUILD/e2e_a.out" > "$BUILD/$key.a"
  grep "^$key=" "$BUILD/e2e_b.out" > "$BUILD/$key.b"
  diff -u "$BUILD/$key.a" "$BUILD/$key.b"
done
echo 'F_GC_CLOSEOUT_REAL_E2E_FRESH_PROCESS_REPLAY=PASS'

run_and_capture restart bash tests/fgc/run_fgc24_coupled_restart_split_process_gate.sh
grep -Fq 'FGC24_TRUE_PROCESS_SPLIT_EQUIVALENCE_O0=PASS' "$BUILD/restart.out"
grep -Fq 'FGC24_TRUE_PROCESS_SPLIT_EQUIVALENCE_O2=PASS' "$BUILD/restart.out"
grep -Fq 'FGC24_NO_TRANSIENT_PUBLICATION_TOKEN_PERSISTENCE=PASS' "$BUILD/restart.out"
grep -Fq 'F-GC24 COUPLED RESTART SPLIT-PROCESS GATE PASS' "$BUILD/restart.out"

echo 'F_GC_CLOSEOUT_FIXED_INTERFACE_CONTRACT=PASS'
echo 'F_GC_CLOSEOUT_FIXED_INTERFACE_GATE_PASS'
