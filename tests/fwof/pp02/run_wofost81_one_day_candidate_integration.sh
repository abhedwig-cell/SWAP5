#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof-pp02-integration-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

CANONICAL_SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/crop/mod_wofost_rate_table.f90
  src/crop/mod_wofost_actual_biomass_state.f90
  src/crop/mod_wofost_crop_owner_state.f90
  src/crop/mod_wofost_one_day_structural_evolution.f90
  src/crop/mod_wofost_one_day_rate_state_view.f90
  src/crop/mod_wofost_rate_parameters.f90
  src/crop/mod_wofost_prepare_assimilation.f90
  src/crop/mod_wofost_finalize_rates.f90
)
PP02_SOURCES=(
  src/crop/mod_wofost81_assimilation.f90
  src/crop/mod_wofost81_nitrogen.f90
  src/crop/mod_wofost81_n_stress.f90
  src/crop/mod_wofost81_parameter_contract.f90
  src/crop/mod_wofost81_n_owner_state.f90
  src/crop/mod_wofost81_crop_owner_state.f90
  src/crop/mod_wofost81_daily_parameter_contract.f90
  src/crop/mod_wofost81_prepare_assimilation.f90
  src/crop/mod_wofost81_rate_correction.f90
  src/crop/mod_wofost81_leaf_structural_evolution.f90
  src/crop/mod_wofost81_one_day_candidate.f90
)
TEST=tests/fwof/pp02/test_wofost81_one_day_candidate_integration.f90

for opt in 0 2; do
  out="$BUILD/o$opt"
  exe="$BUILD/test_o$opt"
  objects=()
  for source in "${CANONICAL_SOURCES[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  for source in "${PP02_SOURCES[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  test_obj="$out/test_wofost81_one_day_candidate_integration.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$TEST" -o "$test_obj"
  objects+=("$test_obj")
  gfortran "${STRICT[@]}" -O"$opt" "${objects[@]}" -o "$exe"
  "$exe" > "$BUILD/out_o$opt.txt"
  cat "$BUILD/out_o$opt.txt"
  grep -Fq 'F_WOF_PP02_REPOSITORY_INTEGRATION_PASS' "$BUILD/out_o$opt.txt"
  echo "F_WOF_PP02_REPOSITORY_INTEGRATION_O${opt}=PASS"
done

cmp "$BUILD/out_o0.txt" "$BUILD/out_o2.txt"
sha=$(sha256sum "$BUILD/out_o0.txt" | awk '{print $1}')
echo "F_WOF_PP02_REPOSITORY_INTEGRATION_O0_O2_IDENTITY=PASS SHA256=$sha"
echo 'F_WOF_PP02_REPOSITORY_INTEGRATION_GATE PASS'
