#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof40-owner-persistence-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

# Preserve the complete F-WOF39 crop-event lifecycle before adding restart
# qualification. This also recompiles it against the F-KT13 kernel overlay.
bash tests/fwof/run_fwof39_crop_event_lifecycle_gate.sh

check_blob() {
  local path="$1" expected="$2" label="$3"
  local actual
  actual="$(git hash-object "$path")"
  if [[ "$actual" != "$expected" ]]; then
    echo "F-WOF40 donor drift $label: expected $expected got $actual" >&2
    exit 1
  fi
}

check_blob src/runtime/mod_fmr_wofost_accepted_window_lineage.f90 a5c73ecd3cb7a62396f5ec804a02b14bc96e9b65 lineage
check_blob src/runtime/mod_fmr_wofost_crop_transaction.f90 e4a7076716e6a5b45b21fa5cd576c881c1574773 crop_transaction
check_blob src/kernel/mod_kernel_transactions.f90 f1acff10dd99c308a00f434440d6a9ef14632f0d fkt13_transactions
check_blob src/kernel/mod_kernel_committed_persistence.f90 ffd886c3401fc12739a456fe60a8741c12b9848b fkt13_persistence

python3 tools/fwof40_materialize_persistence_candidate.py \
  src/runtime/mod_fmr_wofost_accepted_window_lineage.f90 \
  src/runtime/mod_fmr_wofost_crop_transaction.f90 \
  "$BUILD/mod_fmr_wofost_accepted_window_lineage.f90" \
  "$BUILD/mod_fmr_wofost_crop_transaction.f90" | tee "$BUILD/materialize.txt"
grep -Fq 'FWOF40_OWNER_PERSISTENCE_CANDIDATE_MATERIALIZED=PASS' "$BUILD/materialize.txt"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace)
SOURCES=(
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
  for src in "${SOURCES[@]}"; do
    gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$ROOT/$src"
  done
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$BUILD/mod_fmr_wofost_accepted_window_lineage.f90"
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$BUILD/mod_fmr_wofost_crop_transaction.f90"
  popd >/dev/null
  echo "FWOF40_OWNER_PERSISTENCE_CANDIDATE_O${OPT}_COMPILE=PASS"
done

echo 'FWOF40_FWO39_PRESERVATION_UNDER_FKT13_OVERLAY=PASS'
echo 'FWOF40_OWNER_PERSISTENCE_CANDIDATE_COMPILE_GATE PASS'
