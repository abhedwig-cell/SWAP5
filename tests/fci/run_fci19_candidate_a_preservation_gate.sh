#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANDIDATE="4a792636ef73d25c671c5e0953cefd11978cd0ec"
FMR15_POSTIMAGE="af04ee6a2079569db9f1fde6ff3ac63076b22586"
FMQ24_SOURCE="ffab7d705928170db3e76a5d346caafeb560e605"
FVQ17_QUAL="1d9ff946f45488557d10700f047089d3298a4794"
FSI19_QUAL="d3a1bc8eef243b6109af8871398c06e1840fb367"
ARTIFACTS="$ROOT/.fci19-artifacts"
BUILD="${TMPDIR:-/tmp}/swap5-fci19-$$"
FMR15_TMP="$ROOT/tests/fmr/.fci19_fmr15_semantic_$$.sh"

rm -rf "$ARTIFACTS" "$BUILD"
mkdir -p "$ARTIFACTS" "$BUILD"
cleanup() {
  rm -f "$FMR15_TMP"
  rm -rf "$BUILD"
}
trap cleanup EXIT

fail() {
  echo "FCI19_GATE_FAIL $*" >&2
  exit 1
}

# F-CI19 is qualification-only. No production/reference source may differ from
# the exact Candidate A postimage on this branch.
git diff --exit-code "$CANDIDATE"..HEAD -- src reference || fail "Candidate A production/reference source changed"
echo 'FCI19_CANDIDATE_A_SOURCE_IDENTITY=PASS'

# The only production-source overlap introduced after the independently
# admitted F-MR15 postimage must be the four F-KT09 transaction/runtime owner
# files. This is a provenance assertion, not a claim that behavior is preserved.
cat > "$BUILD/expected-overlap.txt" <<'EOF'
src/kernel/mod_kernel_transactions.f90
src/runtime/mod_canonical_contracts.f90
src/runtime/mod_canonical_interval_runtime.f90
src/transaction/mod_transaction_reference.f90
EOF
git diff --name-only "$FMR15_POSTIMAGE".."$CANDIDATE" -- src | sort > "$BUILD/actual-overlap.txt"
diff -u "$BUILD/expected-overlap.txt" "$BUILD/actual-overlap.txt" || fail "unexpected F-MR15 to Candidate A source overlap"
cp "$BUILD/actual-overlap.txt" "$ARTIFACTS/fmr15-to-candidate-a-source-overlap.txt"
echo 'FCI19_FMR15_TO_CANDIDATE_A_OVERLAP=PASS'

# Snow process physics itself must remain bit-identical to the F-MQ24 source
# under test. Runtime/backend changes are deliberately NOT inferred safe here;
# they are executed below against the historical independent snow oracle.
SNOW_OLD="$(git rev-parse "$FMQ24_SOURCE:src/process/mod_snow_process.f90")"
SNOW_NOW="$(git rev-parse "$CANDIDATE:src/process/mod_snow_process.f90")"
[[ "$SNOW_OLD" == "$SNOW_NOW" ]] || fail "snow process blob changed old=$SNOW_OLD candidate=$SNOW_NOW"
printf '%s\n' "$SNOW_NOW" > "$ARTIFACTS/snow-process-blob.txt"
echo 'FCI19_SNOW_PROCESS_SOURCE_IDENTITY=PASS'

# F-KT09 is already source-qualified at Candidate A. Re-run its full executable
# transaction/canonical-runtime/kernel gate on the exact composition tree.
bash tests/transaction/run_fkt09_model_certificate_gate.sh > "$ARTIFACTS/fkt09.out" 2>&1 || {
  cat "$ARTIFACTS/fkt09.out" >&2
  fail "F-KT09 preservation"
}
for marker in \
  'FKT09_TRANSACTION_REFERENCE=PASS' \
  'FKT09_ATTEMPT_CONTEXT=PASS' \
  'FKT09_CANONICAL_COMPOSITION=PASS' \
  'FKT09_KERNEL_DIAGNOSTICS=PASS' \
  'FKT09_EXISTING_EXTERNAL_ESTIMATOR_DEFAULT=PASS' \
  'FKT09_MODEL_CERTIFICATE_OPT_IN=PASS' \
  'FKT09_INVALID_UNAVAILABLE_FAIL_CLOSED=PASS' \
  'FKT09_HARD_MASS_GATE_INDEPENDENT=PASS' \
  'FKT09_RETRY_RESTORES_ATTEMPT_CHECKPOINT=PASS' \
  'FKT09_PRIVATE_SUBSTEPS=PASS' \
  'FKT09_COMMIT_BOUNDARY=PASS' \
  'FKT09_KERNEL_CERTIFICATE_DIAGNOSTICS=PASS' \
  'FKT09_NO_RICHARDS_SPECIFIC_LOGIC=PASS' \
  'FKT09_NO_CALENDAR_SPECIFIC_LOGIC=PASS' \
  'FKT09_GATE PASS_GENERIC_MODEL_OWNED_TEMPORAL_CERTIFICATE_SEAM'; do
  grep -Fq "$marker" "$ARTIFACTS/fkt09.out" || fail "missing F-KT09 marker: $marker"
done
echo 'FCI19_FKT09_PRESERVATION=PASS'

# Preserve the historical F-MR15 gate unchanged. Generate a temporary runner
# that suppresses ONLY its exact historical src/* blob-lock invocations and
# misleading historical scope-declaration echoes. All executable scientific,
# mass, rollback, observer and O0/O2 workloads then compile against Candidate A.
python3 - "$ROOT/tests/fmr/run_fmr15_owner_composition_gate.sh" "$FMR15_TMP" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
out = []
for line in src:
    stripped = line.strip()
    if stripped.startswith('check_blob src/'):
        out.append('# F-CI19 composition replay: historical exact-postimage lock intentionally not re-applied here')
        continue
    if stripped == "echo 'FMR15_EXACT_COMPOSED_SOURCE_LOCKS=PASS'":
        out.append("echo 'FCI19_FMR15_HISTORICAL_SOURCE_LOCK_CALLS_SUPPRESSED_FOR_COMPOSITION_REPLAY=PASS'")
        continue
    if stripped in {
        "echo 'FMR15_PHYSICS_CHANGED=NO'",
        "echo 'FMR15_NUMERICAL_CONTROLS_CHANGED=NO'",
        "echo 'FMR15_ACCEPTANCE_CHANGED=NO'",
        "echo 'FMR15_TRANSACTION_SEMANTICS_CHANGED=NO'",
    }:
        out.append('# F-CI19 composition replay: historical change declaration omitted; behavior is tested above')
        continue
    out.append(line)
Path(sys.argv[2]).write_text('\n'.join(out) + '\n', encoding='utf-8')
PY
chmod +x "$FMR15_TMP"
"$FMR15_TMP" > "$ARTIFACTS/fmr15-semantic-replay.out" 2>&1 || {
  cat "$ARTIFACTS/fmr15-semantic-replay.out" >&2
  fail "F-MR15 semantic replay"
}
for marker in \
  'FCI19_FMR15_HISTORICAL_SOURCE_LOCK_CALLS_SUPPRESSED_FOR_COMPOSITION_REPLAY=PASS' \
  'FVQ26V2_ACCEPTED_NEGATIVE_QBOT=PASS' \
  'FVQ26V2_ACCEPTED_POSITIVE_QBOT=PASS' \
  'FVQ26V2_BOTTOM_HEAD_AUTHORITY=PASS' \
  'FVQ26V2_BOTTOM_FLUX_SEED_IRRELEVANCE=PASS' \
  'FVQ26V2_QBOT_MASS_EXACTLY_ONCE=PASS' \
  'FVQ26V2_TRANSACTION_DISCARD_ISOLATION=PASS' \
  'FVQ26V2_A_B_A_REPLAY=PASS' \
  'FVQ26V2_ZERO_TOLERANCE_TEMPORAL_ACCEPTANCE=PASS' \
  'FVQ26V2_FAIL_CLOSED_PROFILE=PASS' \
  'FVQ26V2_SERIALIZED_ONLY=PASS' \
  'FMR15_ACCEPTED_TWO_SIGN_MODE5_DIAGNOSTICS=PASS' \
  'FVQ26V2_PRESCRIBED_BOTTOM_HEAD_RUNTIME_ORACLE PASS' \
  'FMR15_O0_O2_OUTPUT_AND_DIAGNOSTIC_IDENTITY=PASS' \
  'FMR15_FSI16_PARENT_REPLAY=PASS' \
  'FMR15_OWNER_COMPOSITION_GATE PASS'; do
  grep -Fq "$marker" "$ARTIFACTS/fmr15-semantic-replay.out" || fail "missing F-MR15 semantic marker: $marker"
done
echo 'FCI19_FMR15_OWNER_SEMANTIC_PRESERVATION=PASS'

# Independently replay the historical F-SI19 originalB-layer linear-solver
# oracle against Candidate A's current reference linear solver.
git show "$FSI19_QUAL:tests/fsi/test_fsi19_reference_linear_solver.f90" > "$BUILD/fsi19.f90"
[[ "$(sha256sum "$BUILD/fsi19.f90" | cut -d' ' -f1)" == "275790181531838bed38f4013e5f9f51c3b19f7221e91e5b84cb72e8f11d7fa0" ]] || \
  fail "F-SI19 historical oracle hash mismatch"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/fsi19-o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_reference_linear_solver.f90 -o "$OUT/solver.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fsi19.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/solver.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "F-SI19 O$opt"; }
  for marker in \
    'FSI19_DIRECT_ORIGINALB_LAYER_ORACLE=PASS' \
    'FSI19_SOLUTION_IDENTITY=PASS' \
    'FSI19_ITERATION_DETAIL_IDENTITY=PASS' \
    'FSI19_ADMISSIBILITY_IDENTITY=PASS' \
    'FSI19_SINGULAR_PIVOT_REJECTION=PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || fail "missing F-SI19 marker at O$opt: $marker"
  done
done
cmp "$BUILD/fsi19-o0/out.txt" "$BUILD/fsi19-o2/out.txt" || fail "F-SI19 O0/O2 output mismatch"
cp "$BUILD/fsi19-o0/out.txt" "$ARTIFACTS/fsi19.out"
echo 'FCI19_FSI19_REFERENCE_LINEAR_SOLVER_PRESERVATION=PASS'

# Replay the independent F-VQ17 snow/MultiSWAP scientific workload against
# Candidate A. The historical test source is immutable; current production
# modules are compiled and executed at both O0 and O2.
git show "$FVQ17_QUAL:tests/vq/fvq17/test_fvq17_snow_multiswap_reference.f90" > "$BUILD/fvq17_snow.f90"
SNOW_MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)
for opt in 0 2; do
  OUT="$BUILD/snow-o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${SNOW_MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fvq17_snow.f90" -o "$OUT/fvq17.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fvq17.o" -o "$OUT/fvq17"
  "$OUT/fvq17" > "$OUT/fvq17.out" 2>&1 || { cat "$OUT/fvq17.out" >&2; fail "F-VQ17 semantic O$opt"; }
  for marker in \
    'FVQ17_PROFILE_ALL_INACTIVE_1_2_17_31=PASS' \
    'FVQ17_PROFILE_ALL_ACTIVE_1_2_17_31=PASS' \
    'FVQ17_PROFILE_MIXED_1_2_17_31=PASS' \
    'FVQ17_DIRECT_FVQ16_SNOW_STATE_IDENTITY=PASS' \
    'FVQ17_NONZERO_MELT_INTERNAL_TRANSFER=PASS' \
    'FVQ17_SNOW_INACTIVE_ZERO_STATE=PASS' \
    'FVQ17_REVERSE_ORDER_COLUMN_IDENTITY=PASS' \
    'FVQ17_REVERSE_ORDER_AGGREGATE_MASS_IDENTITY=PASS' \
    'FVQ17_A_B_A_EXACT=PASS' \
    'FVQ17_AUTHORITATIVE_MASS_COMPLETE=PASS' \
    'FVQ17_SUBDAILY_RUNTIME_FAIL_CLOSED=PASS' \
    'FVQ17_MULTIDAY_RUNTIME_FAIL_CLOSED=PASS' \
    'FVQ17_MAX_SIMULTANEOUS_REAL_PHYSICAL_SOLVES=1' \
    'FVQ17_INDEPENDENT_SNOW_MULTISWAP_REFERENCE PASS'; do
    grep -Fq "$marker" "$OUT/fvq17.out" || fail "missing F-VQ17 marker at O$opt: $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr06_snow_smoke.f90 -o "$OUT/smoke.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/smoke.o" -o "$OUT/smoke"
  "$OUT/smoke" > "$OUT/smoke.out" 2>&1 || { cat "$OUT/smoke.out" >&2; fail "F-MR06 snow smoke O$opt"; }
  for marker in \
    'FMR06_SNOW_ONE_CALL_DAILY_TRIAL=PASS' \
    'FMR06_SNOW_ROLLBACK=PASS' \
    'FMR06_SNOW_REPLAY_BITWISE=PASS' \
    'FMR06_SNOW_COMMIT=PASS' \
    'FMR06_SNOW_AUTHORITATIVE_MASS_COMPLETE=PASS' \
    'FMR06_SNOW_SUBDAILY_FAIL_CLOSED=PASS' \
    'FMR06_SNOW_MULTIDAY_FAIL_CLOSED=PASS'; do
    grep -Fq "$marker" "$OUT/smoke.out" || fail "missing F-MR06 marker at O$opt: $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr05_single_fmr04_identity.f90 -o "$OUT/inactive.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/inactive.o" -o "$OUT/inactive"
  "$OUT/inactive" > "$OUT/inactive.out" 2>&1 || { cat "$OUT/inactive.out" >&2; fail "F-MR05 inactive O$opt"; }
  grep -Fq 'FMR05_SINGLE_COLUMN_FMR04_ROUTE_IDENTITY=PASS' "$OUT/inactive.out"
  grep -Fq 'FMR05_SINGLE_COLUMN_FMR04_MASS_BITWISE_IDENTITY=PASS' "$OUT/inactive.out"
  grep -Fq 'FMR05_SINGLE_COLUMN_FMR04_COMMITTED_STATE_IDENTITY=PASS' "$OUT/inactive.out"

done
cmp "$BUILD/snow-o0/fvq17.out" "$BUILD/snow-o2/fvq17.out" || fail "F-VQ17 O0/O2 mismatch"
cmp "$BUILD/snow-o0/smoke.out" "$BUILD/snow-o2/smoke.out" || fail "F-MR06 O0/O2 mismatch"
cmp "$BUILD/snow-o0/inactive.out" "$BUILD/snow-o2/inactive.out" || fail "F-MR05 O0/O2 mismatch"
cp "$BUILD/snow-o0/fvq17.out" "$ARTIFACTS/fvq17-snow.out"
cp "$BUILD/snow-o0/smoke.out" "$ARTIFACTS/fmr06-snow-smoke.out"
cp "$BUILD/snow-o0/inactive.out" "$ARTIFACTS/fmr05-inactive.out"
echo 'FCI19_FMQ24_SNOW_PRESERVATION=PASS'

# Re-run the inherited F-CI18 governance ownership gate. This is not a new
# production qualification claim; it checks that CI19 has not silently relaxed
# the non-delegable mass/transaction/provenance governance contract.
bash tests/fci/run_fci18_gate.sh > "$ARTIFACTS/fci18-governance.out" 2>&1 || {
  cat "$ARTIFACTS/fci18-governance.out" >&2
  fail "F-CI18 inherited governance gate"
}
grep -Fq 'FCI18_EXIT_SCOPE_OWNERSHIP PASS' "$ARTIFACTS/fci18-governance.out" || fail "missing F-CI18 governance marker"
echo 'FCI19_FCI18_GOVERNANCE_PRESERVATION=PASS'

# Final fail-closed source identity check after every executable replay.
git diff --exit-code "$CANDIDATE"..HEAD -- src reference || fail "production/reference source drift during qualification"
sha256sum "$ARTIFACTS"/*.out "$ARTIFACTS"/*.txt > "$ARTIFACTS/artifact-sha256.txt"
printf '%s\n' "$CANDIDATE" > "$ARTIFACTS/candidate-a.txt"
git rev-parse HEAD > "$ARTIFACTS/qualification-head.txt"

echo 'FCI19_FVQ27_SEMANTIC_PRESERVATION=PASS'
echo 'FCI19_HARD_MASS_PRESERVATION=PASS'
echo 'FCI19_ROLLBACK_REPLAY_PRESERVATION=PASS'
echo 'FCI19_O0_O2_PRESERVATION=PASS'
echo 'FCI19_GATE PASS_CANDIDATE_A_COMPOSITION_PRESERVATION'
