#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof-pp02-case001-$$"
mkdir -p "$BUILD/data" "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FIXTURE_B64=tests/fwof/pp02/case001_fixture.tar.gz.b64
[[ "$(sha256sum "$FIXTURE_B64" | awk '{print $1}')" == "f20f07cfc70ab4eab27a285ad6609b322c83b475c0dc297645742669aabb9c82" ]]
base64 -d "$FIXTURE_B64" > "$BUILD/case001_fixture.tar.gz"
[[ "$(sha256sum "$BUILD/case001_fixture.tar.gz" | awk '{print $1}')" == "d9ac276be4ecea1c7fca0d6ba720ae9e1532549c33a592962634867e0fd0dafd" ]]
tar -xzf "$BUILD/case001_fixture.tar.gz" -C "$BUILD/data"
[[ "$(sha256sum "$BUILD/data/forcing.dat" | awk '{print $1}')" == "ae6c330055134df713aef3e9d7bc27b5220c0d39fcaa2e022fd954d38c149e45" ]]
[[ "$(sha256sum "$BUILD/data/reference.csv" | awk '{print $1}')" == "94daa08000097f4a124847c89b6ba3de1d29ca5d08fa07ae13dbcbb5b9efeaed" ]]
[[ "$(sha256sum "$BUILD/data/precision.csv" | awk '{print $1}')" == "1bf8d520324af2c003fa0daecb44a7c32c112fac8dcbcbf9c12775aa3511185a" ]]
echo 'F_WOF_PP02_CASE001_FIXTURE_IDENTITY=PASS'

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
TEST=tests/fwof/pp02/test_wofost81_fullseason_replay.f90
COMPARE=tests/fwof/pp02/compare_wofost81_fullseason.py

for opt in 0 2; do
  out="$BUILD/o$opt"
  exe="$BUILD/replay_o$opt"
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
  test_obj="$out/test_wofost81_fullseason_replay.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$TEST" -o "$test_obj"
  objects+=("$test_obj")
  gfortran "${STRICT[@]}" -O"$opt" "${objects[@]}" -o "$exe"
  "$exe" "$BUILD/data/forcing.dat" "$BUILD/replay_o$opt.csv"
  python3 "$COMPARE" "$BUILD/replay_o$opt.csv" "$BUILD/data/reference.csv" \
    "$BUILD/data/precision.csv" "$BUILD/summary_o$opt.json"
  echo "F_WOF_PP02_CASE001_O${opt}=PASS"
done

cmp "$BUILD/replay_o0.csv" "$BUILD/replay_o2.csv"
cmp "$BUILD/summary_o0.json" "$BUILD/summary_o2.json"
replay_sha=$(sha256sum "$BUILD/replay_o0.csv" | awk '{print $1}')
summary_sha=$(sha256sum "$BUILD/summary_o0.json" | awk '{print $1}')
echo "F_WOF_PP02_CASE001_O0_O2_IDENTITY=PASS REPLAY_SHA256=$replay_sha SUMMARY_SHA256=$summary_sha"
echo 'F_WOF_PP02_CASE001_FULLSEASON_GATE PASS'
