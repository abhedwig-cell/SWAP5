#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-}"
case "$MODE" in restart|parallel|parallel-restart) ;; *) echo "usage: $0 {restart|parallel|parallel-restart}" >&2; exit 2;; esac
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-ftb04-replay-$$-$MODE"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "FTB04_CURRENT_REPLAY_FAIL:$MODE:$*" >&2; exit 44; }

CANONICAL=0aeb0a2ed4096e1f9493d3dabc70962ea5270182
SRC_TREE=8ceeb70a64012631ebba295f5c045ea908b0681f
REF_TREE=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
[[ "$(git rev-parse HEAD:src)" == "$SRC_TREE" ]] || fail 'current canonical src tree drift'
[[ "$(git rev-parse HEAD:reference)" == "$REF_TREE" ]] || fail 'current canonical reference tree drift'
echo "FTB04_CURRENT_CANONICAL_SOURCE_AUTHORITY=PASS:MODE=$MODE"

run_restart() {
  local HIST=tests/fci/run_fci28_restart_current_canonical_admission.sh
  local BLOB=5cf6523628b6df2dcf9c98baf05de103c24222f5
  local TMP="$BUILD/fci28-rebound.sh"
  [[ "$(git rev-parse HEAD:$HIST)" == "$BLOB" ]] || fail 'FCI28 historical replay blob drift'
  cp "$HIST" "$TMP"
  python3 - "$TMP" "$SRC_TREE" "$REF_TREE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=sys.argv[2]; ref=sys.argv[3]; s=p.read_text()
old='''if ! git diff --quiet "$CANDIDATE"..HEAD -- src; then
  git diff --name-only "$CANDIDATE"..HEAD -- src >&2
  fail 'qualification branch mutated production source after candidate'
fi
echo 'FCI28_EXACT_CANDIDATE_SOURCE_DELTA=PASS'
echo 'FCI28_QUALIFICATION_PRODUCTION_IMMUTABLE=PASS' '''
# Exact historical script has no trailing space; use a second strict spelling.
if old not in s:
    old='''if ! git diff --quiet "$CANDIDATE"..HEAD -- src; then
  git diff --name-only "$CANDIDATE"..HEAD -- src >&2
  fail 'qualification branch mutated production source after candidate'
fi
echo 'FCI28_EXACT_CANDIDATE_SOURCE_DELTA=PASS'
echo 'FCI28_QUALIFICATION_PRODUCTION_IMMUTABLE=PASS' '''.rstrip()
if old not in s:
    raise SystemExit('FTB04_FCI28_REBIND_FAIL:historical source-drift guard not found')
new=f'''[[ "$(git rev-parse HEAD:src)" == "{src}" ]] || fail 'F-TB04 current-canonical src tree drift'
[[ "$(git rev-parse HEAD:reference)" == "{ref}" ]] || fail 'F-TB04 current-canonical reference tree drift'
echo 'FCI28_EXACT_CANDIDATE_SOURCE_DELTA=PASS'
echo 'FCI28_QUALIFICATION_PRODUCTION_IMMUTABLE=PASS'
echo 'FTB04_FCI28_CURRENT_CANONICAL_GOVERNANCE_REBOUND=PASS' '''.rstrip()
s=s.replace(old,new,1)
p.write_text(s)
PY
  chmod +x "$TMP"
  bash "$TMP" | tee "$BUILD/fci28.txt"
  for marker in \
    'FTB04_FCI28_CURRENT_CANONICAL_GOVERNANCE_REBOUND=PASS' \
    'FCI28_O0_O2_OUTPUT_IDENTITY=PASS' \
    'FCI28_RESTART_MASS_AND_CONTINUATION=PASS' \
    'FCI28_FAIL_CLOSED_STATE_FAMILY_AND_ATOMICITY=PASS' \
    'FCI28_RESTART_CURRENT_CANONICAL_ADMISSION_GATE=PASS'; do
    grep -Fq "$marker" "$BUILD/fci28.txt" || fail "FCI28 marker $marker"
  done
  echo 'FTB04_CURRENT_CANONICAL_RESTART_REPLAY=PASS'
}

parallel_modules() {
  cat <<'EOF'
tests/fsi/fsi04_real_headcalc_stubs.f90
src/runtime/mod_a23bu_worker_execution_context.f90
src/transaction/mod_transaction_reference.f90
src/transaction/mod_fkt_temporal_indicator_history.f90
src/runtime/mod_canonical_contracts.f90
src/runtime/mod_canonical_interval_runtime.f90
src/kernel/mod_kernel_transactions.f90
src/runtime/mod_fmr_runtime_core.f90
src/runtime/mod_fmr_checkpoint_orchestrator.f90
src/runtime/mod_fmr_accepted_commit_receipt.f90
src/solver/mod_soil_water_solver_contract.f90
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
src/runtime/mod_fmr_serialized_reference_backend.f90
src/runtime/mod_fmr_serialized_multiswap_runtime.f90
src/runtime/mod_fmr_parallel_physical_scheduler.f90
src/runtime/mod_fmr_parallel_worker_pool.f90
EOF
}

run_parallel() {
  local MATRIX=26cc6e0ace986dc40db7635de7192958a1c0b868
  local ORDER=f2584b0236e85d4f6e8b687cee97981eaaa909c9
  git cat-file blob "$MATRIX" > "$BUILD/parallel_matrix.f90"
  git cat-file blob "$ORDER" > "$BUILD/publication_order.f90"
  [[ "$(git hash-object "$BUILD/parallel_matrix.f90")" == "$MATRIX" ]] || fail 'FMQ26 matrix blob drift'
  [[ "$(git hash-object "$BUILD/publication_order.f90")" == "$ORDER" ]] || fail 'FMQ26 publication-order blob drift'
  mapfile -t MODULES < <(parallel_modules)
  local COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
  export OMP_DYNAMIC=FALSE OMP_THREAD_LIMIT=4 OMP_PROC_BIND=spread OMP_PLACES=cores
  for opt in 0 2; do
    local OUT="$BUILD/parallel-o$opt"; mkdir -p "$OUT"; local objs=()
    for src in "${MODULES[@]}"; do
      local obj="$OUT/$(basename "${src%.*}").o"
      gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
      objs+=("$obj")
    done
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/parallel_matrix.f90" -o "$OUT/matrix.o"
    gfortran -fopenmp -O"$opt" "${objs[@]}" "$OUT/matrix.o" -o "$OUT/matrix"
    "$OUT/matrix" > "$OUT/matrix.txt" 2>&1 || { cat "$OUT/matrix.txt" >&2; fail "FMQ26 matrix O$opt"; }
    for marker in \
      'FMQ26_INPUT_ORDER_INDEPENDENCE=PASS' \
      'FMQ26_REJECTION_AT_BATCH_BOUNDARY=PASS' \
      'FMQ26_REJECTION_INTERIOR=PASS' \
      'FMQ26_TWO_WORKER_SEPARATED_REJECTIONS=PASS' \
      'FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS' \
      'FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS' \
      'FMQ26_HARD_MASS_ALL_CASES=PASS' \
      'FMQ26_WORKER_COUNT_INDEPENDENCE=PASS' \
      'FMQ26_DETERMINISTIC_REPLAY=PASS' \
      'FMQ26_PARALLEL_V1_ADMISSION_TEST PASS'; do
      grep -Fq "$marker" "$OUT/matrix.txt" || fail "FMQ26 matrix marker O$opt: $marker"
    done
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/publication_order.f90" -o "$OUT/order.o"
    gfortran -fopenmp -O"$opt" "${objs[@]}" "$OUT/order.o" -o "$OUT/order"
    "$OUT/order" > "$OUT/order.txt" 2>&1 || { cat "$OUT/order.txt" >&2; fail "FMQ26 order O$opt"; }
    grep -Fq 'FMQ26_CANONICAL_PUBLICATION_ORDER=PASS' "$OUT/order.txt" || fail "FMQ26 publication-order marker O$opt"
  done
  cmp -s "$BUILD/parallel-o0/matrix.txt" "$BUILD/parallel-o2/matrix.txt" || fail 'FMQ26 matrix O0/O2 transcript identity'
  cmp -s "$BUILD/parallel-o0/order.txt" "$BUILD/parallel-o2/order.txt" || fail 'FMQ26 order O0/O2 transcript identity'
  echo 'FTB04_CURRENT_PARALLEL_MATRIX_O0_O2_BIT_IDENTITY=PASS'
  echo 'FTB04_CURRENT_PARALLEL_PUBLICATION_O0_O2_BIT_IDENTITY=PASS'
  echo 'FTB04_CURRENT_PARALLEL_SERIAL_2W_4W_EQUIVALENCE=PASS'
}

run_parallel_restart() {
  local HIST=tests/fci/run_fci35_parallel_restart_current_canonical_admission.sh
  local BLOB=3c4e92369058b72c4b71e0f94dc51e76ac989db7
  local TMP="$BUILD/fci35-rebound.sh"
  [[ "$(git rev-parse HEAD:$HIST)" == "$BLOB" ]] || fail 'FCI35 historical replay blob drift'
  cp "$HIST" "$TMP"
  python3 - "$TMP" "$SRC_TREE" "$REF_TREE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=sys.argv[2]; ref=sys.argv[3]; s=p.read_text()
old='''git merge-base --is-ancestor "$BASE" HEAD || fail 'admission head not descended from exact canonical base'
git diff --quiet "$BASE"..HEAD -- src reference || {
  git diff --name-only "$BASE"..HEAD -- src reference >&2
  fail 'F-CI35 changed production/reference source'
}'''
if old not in s:
    raise SystemExit('FTB04_FCI35_REBIND_FAIL:outer source-drift guard not found')
new=f'''git merge-base --is-ancestor "$BASE" HEAD || fail 'admission head not descended from exact canonical base'
[[ "$(git rev-parse HEAD:src)" == "{src}" ]] || fail 'F-TB04 current-canonical src tree drift'
[[ "$(git rev-parse HEAD:reference)" == "{ref}" ]] || fail 'F-TB04 current-canonical reference tree drift'
echo 'FTB04_FCI35_CURRENT_CANONICAL_GOVERNANCE_REBOUND=PASS' '''.rstrip()
s=s.replace(old,new,1)
needle='''s=s.replace("integration/f-mq/F-MQ29_QUALIFICATION_MATRIX.json",matrix)
p.write_text(s)'''
if needle not in s:
    raise SystemExit('FTB04_FCI35_REBIND_FAIL:inner replay adaptation seam not found')
insert=f'''s=s.replace("integration/f-mq/F-MQ29_QUALIFICATION_MATRIX.json",matrix)
old_guard="git diff --quiet \\\"$BASE\\\"..HEAD -- src reference || fail 'F-MQ29 qualification mutated production/reference source'"
new_guard="[[ \\\"$(git rev-parse HEAD:src)\\\" == \\\"{src}\\\" ]] || fail 'F-TB04 current-canonical src tree drift'\\n[[ \\\"$(git rev-parse HEAD:reference)\\\" == \\\"{ref}\\\" ]] || fail 'F-TB04 current-canonical reference tree drift'"
if old_guard not in s:
    raise SystemExit('FTB04_FMQ29_REBIND_FAIL:historical source-drift guard not found')
s=s.replace(old_guard,new_guard,1)
p.write_text(s)'''
s=s.replace(needle,insert,1)
p.write_text(s)
PY
  chmod +x "$TMP"
  bash "$TMP" | tee "$BUILD/fci35.txt"
  for marker in \
    'FTB04_FCI35_CURRENT_CANONICAL_GOVERNANCE_REBOUND=PASS' \
    'FCI35_EXACT_FMQ29_REPLAY_ON_CURRENT_CANONICAL=PASS' \
    'FCI35_HELDOUT_CROSS_WORKER_RESTART_REPLAY=PASS' \
    'FCI35_HARD_MASS_AND_CANONICAL_PUBLICATION_REPLAY=PASS' \
    'FCI35_DECISION=READY_FOR_CANONICAL_CAPABILITY_ADMISSION'; do
    grep -Fq "$marker" "$BUILD/fci35.txt" || fail "FCI35 marker $marker"
  done
  echo 'FTB04_CURRENT_CANONICAL_PARALLEL_RESTART_REPLAY=PASS'
}

case "$MODE" in
  restart) run_restart ;;
  parallel) run_parallel ;;
  parallel-restart) run_parallel_restart ;;
esac
