#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap431_soil_crop_n_tx"
rm -rf "$BUILD"
mkdir -p "$BUILD"

for OPT in O0 O2; do
  FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow "-$OPT")
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/transaction/mod_transaction_reference.f90" -o "$BUILD/tx_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_soil_n_pool_state.f90" -o "$BUILD/pool_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_soil_organic_turnover.f90" -o "$BUILD/org_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_soil_n_organic_mineralization_transfer.f90" -o "$BUILD/orgn_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_soil_n_organic_turnover_transfer.f90" -o "$BUILD/orgtx_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_soil_organic_dissimilation.f90" -o "$BUILD/diss_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_soil_n_rate_factors.f90" -o "$BUILD/rates_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_soil_n_storage_conversion.f90" -o "$BUILD/storage_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_soil_n_transport.f90" -o "$BUILD/transport_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_soil_n_daily_exchange.f90" -o "$BUILD/exchange_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_soil_n_daily_candidate.f90" -o "$BUILD/candidate_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/crop/mod_b111_crop_n_fixation_policy.f90" -o "$BUILD/fix_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/crop/mod_b111_crop_n_owner.f90" -o "$BUILD/crop_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" "$ROOT/tests/fwof/pp02/test_b111_crop_n_owner.f90" "$BUILD/fix_$OPT.o" "$BUILD/crop_$OPT.o" -o "$BUILD/crop_test_$OPT"
  "$BUILD/crop_test_$OPT"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/runtime/mod_fmr_b111_soil_n_transaction.f90" -o "$BUILD/soilstate_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/runtime/mod_fmr_b111_soil_crop_n_transaction.f90" -o "$BUILD/coupled_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" "$ROOT/tests/physics/test_fmr_b111_soil_crop_n_transaction.f90" \
    "$BUILD/tx_$OPT.o" "$BUILD/pool_$OPT.o" "$BUILD/org_$OPT.o" "$BUILD/orgn_$OPT.o" "$BUILD/orgtx_$OPT.o" \
    "$BUILD/diss_$OPT.o" "$BUILD/rates_$OPT.o" "$BUILD/storage_$OPT.o" "$BUILD/transport_$OPT.o" \
    "$BUILD/exchange_$OPT.o" "$BUILD/candidate_$OPT.o" "$BUILD/fix_$OPT.o" "$BUILD/crop_$OPT.o" \
    "$BUILD/soilstate_$OPT.o" "$BUILD/coupled_$OPT.o" -o "$BUILD/test_$OPT"
  "$BUILD/test_$OPT"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" "$ROOT/tests/fwof/pp02/test_fmr_b111_soil_crop_n_transaction.f90" \
    "$BUILD/tx_$OPT.o" "$BUILD/pool_$OPT.o" "$BUILD/org_$OPT.o" "$BUILD/orgn_$OPT.o" "$BUILD/orgtx_$OPT.o" \
    "$BUILD/diss_$OPT.o" "$BUILD/rates_$OPT.o" "$BUILD/storage_$OPT.o" "$BUILD/transport_$OPT.o" \
    "$BUILD/exchange_$OPT.o" "$BUILD/candidate_$OPT.o" "$BUILD/fix_$OPT.o" "$BUILD/crop_$OPT.o" \
    "$BUILD/soilstate_$OPT.o" "$BUILD/coupled_$OPT.o" -o "$BUILD/fwof_test_$OPT"
  "$BUILD/fwof_test_$OPT"
done
