#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof-pp02-case001-$$"
mkdir -p "$BUILD/data" "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PARTS=(
  tests/fwof/pp02/case001_fixture.b64.part00
  tests/fwof/pp02/case001_fixture.b64.part01
  tests/fwof/pp02/case001_fixture.b64.part02
  tests/fwof/pp02/case001_fixture.b64.part03
  tests/fwof/pp02/case001_fixture.b64.part04
  tests/fwof/pp02/case001_fixture.b64.part05
)
EXPECTED_PART_SHA=(
  5d62aebf9db34e6b2a0eceb6c66878a5e571113c13288fccdc8e24cdd28e4c7e
  a7955880c199085eca61792466efa84a7f4d9df6ed20e7be69dfbf3fd235e425
  645a4a9550c6dd99d98d02428eba40beb4e8d65cf456ab1b1460f36413ac98ee
  1595eb562d4dcb3506d1b96f86990a667ebddaf56419270515bb610d17f97e0f
  40060700d6f444f930251cab331865747dce821a54d83c5f8966fbaea0ff1c6c
  6c5412e05c0ae39b975778a05eaca0e4b2fff96b0c3239e4745fcb7ba4e8ed5e
)
for i in "${!PARTS[@]}"; do
  got=$(sha256sum "${PARTS[$i]}" | awk '{print $1}')
  [[ "$got" == "${EXPECTED_PART_SHA[$i]}" ]]
done
cat "${PARTS[@]}" > "$BUILD/case001_fixture.tar.gz.b64"
[[ "$(sha256sum "$BUILD/case001_fixture.tar.gz.b64" | awk '{print $1}')" == "f20f07cfc70ab4eab27a285ad6609b322c83b475c0dc297645742669aabb9c82" ]]
base64 -d "$BUILD/case001_fixture.tar.gz.b64" > "$BUILD/case001_fixture.tar.gz"
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
