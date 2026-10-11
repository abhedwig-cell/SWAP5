#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof-pp02-replay-binaries-$$"
ARTIFACT_DIR="$ROOT/.pp02-artifacts"
mkdir -p "$BUILD/o0" "$BUILD/o2"
rm -rf "$ARTIFACT_DIR"
mkdir -p "$ARTIFACT_DIR"
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
TEST=tests/fwof/pp02/test_wofost81_fullseason_replay.f90

for opt in 0 2; do
  out="$BUILD/o$opt"
  exe="$ARTIFACT_DIR/replay_o$opt"
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
done

# Prove the exported binaries reproduce the already admitted case001/case002 CI trajectories.
mkdir -p "$BUILD/case001" "$BUILD/case002"
PARTS=(
  tests/fwof/pp02/case001_fixture.b64.part00
  tests/fwof/pp02/case001_fixture.b64.part01
  tests/fwof/pp02/case001_fixture.b64.part02
  tests/fwof/pp02/case001_fixture.b64.part03
  tests/fwof/pp02/case001_fixture.b64.part04a
  tests/fwof/pp02/case001_fixture.b64.part04b
  tests/fwof/pp02/case001_fixture.b64.part05
)
cat "${PARTS[@]}" > "$BUILD/case001/fixture.b64"
base64 -d "$BUILD/case001/fixture.b64" > "$BUILD/case001/fixture.tar.gz"
tar -xzf "$BUILD/case001/fixture.tar.gz" -C "$BUILD/case001"
head -n 100 "$BUILD/case001/forcing.dat" > "$BUILD/case001/forcing_transitions.dat"

python3 - tests/fwof/pp02/fullseason/case002.tar.xz.b85 "$BUILD/case002/fixture.tar.xz" <<'PY'
import base64, pathlib, sys
src,dst=map(pathlib.Path,sys.argv[1:])
dst.write_bytes(base64.b85decode(src.read_text().strip().encode()))
PY
tar -xJf "$BUILD/case002/fixture.tar.xz" -C "$BUILD/case002"

for opt in 0 2; do
  "$ARTIFACT_DIR/replay_o$opt" "$BUILD/case001/forcing_transitions.dat" "$BUILD/case001/replay_o$opt.csv"
  "$ARTIFACT_DIR/replay_o$opt" "$BUILD/case002/forcing.dat" "$BUILD/case002/replay_o$opt.csv"
done
cmp "$BUILD/case001/replay_o0.csv" "$BUILD/case001/replay_o2.csv"
cmp "$BUILD/case002/replay_o0.csv" "$BUILD/case002/replay_o2.csv"
[[ "$(sha256sum "$BUILD/case001/replay_o0.csv" | awk '{print $1}')" == "64b27e848507a027b9fe7a9b590600de5f90e2ad095fa9696650f565206fb708" ]]
[[ "$(sha256sum "$BUILD/case002/replay_o0.csv" | awk '{print $1}')" == "346fb635aecf1da9c2a39d6af2974a767dd1de6bde31333779a9ee2beaa41753" ]]
sha256sum "$ARTIFACT_DIR/replay_o0" "$ARTIFACT_DIR/replay_o2" > "$ARTIFACT_DIR/SHA256SUMS"
printf '%s\n' "source_commit=${GITHUB_SHA:-unknown}" > "$ARTIFACT_DIR/PROVENANCE.txt"
printf '%s\n' 'case001_replay_sha256=64b27e848507a027b9fe7a9b590600de5f90e2ad095fa9696650f565206fb708' >> "$ARTIFACT_DIR/PROVENANCE.txt"
printf '%s\n' 'case002_replay_sha256=346fb635aecf1da9c2a39d6af2974a767dd1de6bde31333779a9ee2beaa41753' >> "$ARTIFACT_DIR/PROVENANCE.txt"
echo 'F_WOF_PP02_REPLAY_BINARY_EXPORT_GATE PASS'
