#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof-pp02-case002-$$"
mkdir -p "$BUILD/data" "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FIXTURE=tests/fwof/pp02/fullseason/case002.tar.xz.b85
[[ "$(sha256sum "$FIXTURE" | awk '{print $1}')" == "4225c78cde38710fb90e6a9f4cf7e9ebeda4bc864e3bfec63a2e12b6e6448383" ]]
python3 - "$FIXTURE" "$BUILD/case002.tar.xz" <<'PY'
import base64, pathlib, sys
src,dst=map(pathlib.Path,sys.argv[1:])
dst.write_bytes(base64.b85decode(src.read_text().strip().encode()))
PY
[[ "$(sha256sum "$BUILD/case002.tar.xz" | awk '{print $1}')" == "542b788050f7f81ddb78d1980e94a6c740284dde7f21c2371d2482979b529f69" ]]
tar -xJf "$BUILD/case002.tar.xz" -C "$BUILD/data"
[[ "$(sha256sum "$BUILD/data/forcing.dat" | awk '{print $1}')" == "cca81e5c0310667577c738ae8e311ce484c7c7e37c331cbeb9ed3f3b2f300b92" ]]
[[ "$(sha256sum "$BUILD/data/reference.csv" | awk '{print $1}')" == "683ddc7ef5279250f9c0fde43e20a918b655710382a6c5e72188477ff6722fb0" ]]
[[ "$(sha256sum "$BUILD/data/precision.csv" | awk '{print $1}')" == "1bf8d520324af2c003fa0daecb44a7c32c112fac8dcbcbf9c12775aa3511185a" ]]
[[ "$(($(wc -l < "$BUILD/data/reference.csv") - 1))" -eq 109 ]]
[[ "$(wc -l < "$BUILD/data/forcing.dat")" -eq 108 ]]
echo 'F_WOF_PP02_CASE002_FIXTURE_IDENTITY=PASS STATES=109 TRANSITIONS=108'

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
  echo "F_WOF_PP02_CASE002_O${opt}=PASS"
done

cmp "$BUILD/replay_o0.csv" "$BUILD/replay_o2.csv"
cmp "$BUILD/summary_o0.json" "$BUILD/summary_o2.json"
replay_sha=$(sha256sum "$BUILD/replay_o0.csv" | awk '{print $1}')
summary_sha=$(sha256sum "$BUILD/summary_o0.json" | awk '{print $1}')
echo "F_WOF_PP02_CASE002_O0_O2_IDENTITY=PASS REPLAY_SHA256=$replay_sha SUMMARY_SHA256=$summary_sha"
echo 'F_WOF_PP02_CASE002_FULLSEASON_GATE PASS'
