#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof40-process-restart-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

# Preserve F-WOF39 and compile the owner-controlled persistence candidate first.
bash tests/fwof/run_fwof40_owner_persistence_candidate_gate.sh

python3 tools/fwof40_materialize_persistence_candidate.py \
  src/runtime/mod_fmr_wofost_accepted_window_lineage.f90 \
  src/runtime/mod_fmr_wofost_crop_transaction.f90 \
  "$BUILD/mod_fmr_wofost_accepted_window_lineage.f90" \
  "$BUILD/mod_fmr_wofost_crop_transaction.f90" >/dev/null

FWO34=85c0f7838d56c63d49f16af8242bdf4cbe4219d9
git show "$FWO34:tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90" > "$BUILD/fwof34_full.f90"
python3 - "$BUILD/fwof34_full.f90" "$BUILD/mod_fwof34_test_model.f90" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')
marker = '\nprogram test_fwof34_accepted_window_runtime_lineage\n'
if src.count(marker) != 1:
    raise SystemExit(f'F-WOF40 F-WOF34 module boundary count={src.count(marker)}')
Path(sys.argv[2]).write_text(src.split(marker, 1)[0].rstrip() + '\n', encoding='utf-8')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
BASE_SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
  src/crop/mod_wofost_actual_biomass_state.f90
  src/crop/mod_wofost_crop_owner_state.f90
  src/crop/mod_wofost_one_day_structural_evolution.f90
  src/crop/mod_wofost_one_day_rate_state_view.f90
  src/crop/mod_wofost_rate_table.f90
  src/crop/mod_wofost_rate_parameters.f90
  src/crop/mod_wofost_prepare_assimilation.f90
  src/crop/mod_wofost_finalize_rates.f90
  src/crop/mod_wofost_two_phase_crop_window.f90
)

for OPT in 0 2; do
  OUT="$BUILD/o$OPT"
  pushd "$OUT" >/dev/null
  for src in "${BASE_SOURCES[@]}"; do
    gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$ROOT/$src"
  done
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$BUILD/mod_fmr_wofost_accepted_window_lineage.f90"
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$BUILD/mod_fmr_wofost_crop_transaction.f90"
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$ROOT/src/runtime/mod_fmr_wofost_crop_event_lifecycle.f90"
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$BUILD/mod_fwof34_test_model.f90"
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$ROOT/tests/fwof/mod_fwof40_restart_fixture.f90"
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$ROOT/tests/fwof/mod_fwof40_external_crop_restart_adapter.f90"

  OBJECTS=(./*.o)
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . "$ROOT/tests/fwof/test_fwof40_reference.f90" "${OBJECTS[@]}" -o reference
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . "$ROOT/tests/fwof/test_fwof40_producer.f90" "${OBJECTS[@]}" -o producer
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . "$ROOT/tests/fwof/test_fwof40_consumer.f90" "${OBJECTS[@]}" -o consumer
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . "$ROOT/tests/fwof/test_fwof40_negative_probe.f90" "${OBJECTS[@]}" -o negative_probe

  ./reference reference.artifact > reference.log 2>&1
  ./producer restart.artifact > producer.log 2>&1
  ./consumer restart.artifact restarted_end.artifact > consumer.log 2>&1
  cmp reference.artifact restarted_end.artifact

  if grep -Eqi 'accepted_window|event_delivered|delivery_committed|solver|scratch|forcing|parameter' restart.artifact; then
    echo 'F-WOF40 retired/non-state data leaked into restart artifact' >&2
    cat restart.artifact >&2
    exit 1
  fi

  python3 - restart.artifact . <<'PY'
from pathlib import Path
import sys
base = Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
out = Path(sys.argv[2])

def replace(prefix, replacement, name):
    lines = list(base)
    hits = [i for i, line in enumerate(lines) if line.startswith(prefix)]
    if len(hits) != 1:
        raise SystemExit(f'{name}: prefix {prefix!r} hits={len(hits)}')
    lines[hits[0]] = replacement
    (out / name).write_text('\n'.join(lines) + '\n', encoding='utf-8')

replace('schema ', 'schema 2', 'bad_schema.artifact')
replace('layout ', 'layout 0', 'bad_layout.artifact')
replace('codec ', 'codec 2', 'bad_codec.artifact')
replace('receipt_final_revision ', 'receipt_final_revision -1', 'bad_receipt_revision.artifact')
replace('owner_development_stage_bits ', 'owner_development_stage_bits 9221120237041090560', 'nan_owner.artifact')
replace('leaf_count ', 'leaf_count -1', 'bad_leaf_count.artifact')
replace('receipt_present ', 'receipt_present 0', 'missing_receipt.artifact')
(out / 'truncated.artifact').write_text('\n'.join(base[:-1]) + '\n', encoding='utf-8')
(out / 'extra_field.artifact').write_text('\n'.join(base) + '\nunexpected 1\n', encoding='utf-8')
lines = list(base)
lines.insert(2, 'schema 1')
(out / 'duplicate_field.artifact').write_text('\n'.join(lines) + '\n', encoding='utf-8')
PY

  : > negative.log
  for bad in bad_schema.artifact bad_layout.artifact bad_codec.artifact bad_receipt_revision.artifact \
      nan_owner.artifact bad_leaf_count.artifact missing_receipt.artifact truncated.artifact \
      extra_field.artifact duplicate_field.artifact; do
    ./negative_probe "$bad" >> negative.log 2>&1
  done
  [[ "$(grep -Fc 'FWOF40_NEGATIVE_EXPECTED_REJECTION' negative.log)" == 10 ]]

  grep -Fq 'FWOF40_CONTINUOUS_TWO_EVENT_REFERENCE=PASS' reference.log
  grep -Fq 'FWOF40_PRODUCER_COMMIT_RETIRE_WRITE_AND_EXIT=PASS' producer.log
  grep -Fq 'FWOF40_FRESH_PROCESS_RECONSTRUCTION=PASS' consumer.log
  grep -Fq 'FWOF40_RESTORED_RECEIPT_REJECTS_STALE_EVENT=PASS' consumer.log
  grep -Fq 'FWOF40_NEW_EVENT_CONTINUES_AFTER_RESTART=PASS' consumer.log
  echo "FWOF40_TRUE_PROCESS_RESTART_O${OPT}=PASS"
  popd >/dev/null
done

cmp "$BUILD/o0/reference.artifact" "$BUILD/o2/reference.artifact"
cmp "$BUILD/o0/restart.artifact" "$BUILD/o2/restart.artifact"
cmp "$BUILD/o0/restarted_end.artifact" "$BUILD/o2/restarted_end.artifact"
cmp "$BUILD/o0/reference.log" "$BUILD/o2/reference.log"
cmp "$BUILD/o0/producer.log" "$BUILD/o2/producer.log"
cmp "$BUILD/o0/consumer.log" "$BUILD/o2/consumer.log"
cmp "$BUILD/o0/negative.log" "$BUILD/o2/negative.log"

cat "$BUILD/o0/reference.log"
cat "$BUILD/o0/producer.log"
cat "$BUILD/o0/consumer.log"
cat "$BUILD/o0/negative.log"
echo 'FWOF40_TWO_SEPARATE_OS_PROCESSES_PRODUCER_THEN_CONSUMER=PASS'
echo 'FWOF40_CONTINUOUS_VERSUS_PROCESS_RESTART_ENDPOINT_EXACT=PASS'
echo 'FWOF40_RETIRED_ACCEPTED_WINDOW_NOT_PERSISTED=PASS'
echo 'FWOF40_EXTERNAL_NEGATIVE_CASES_FAIL_CLOSED=PASS'
echo 'FWOF40_EXTERNAL_REPRESENTATION_O0_O2_IDENTITY=PASS'
echo 'FWOF40_TRUE_PROCESS_RESTART_QUALIFICATION_GATE PASS'
