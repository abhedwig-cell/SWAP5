#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PRODUCTION_POSTIMAGE="f143062051107c35162f5a28d7e87a88baab30bf"
SOURCE="$ROOT/reference/swap-4.3.1/b1_10_source"
BUILD="${TMPDIR:-/tmp}/swap5-fsi16-b110-independent-oracle-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

[[ "$(git merge-base "$PRODUCTION_POSTIMAGE" HEAD)" == "$PRODUCTION_POSTIMAGE" ]] || {
  echo 'F-SI16_B110_INDEPENDENT_ORACLE FAIL production-postimage-lineage' >&2; exit 1; }
[[ -z "$(git diff --name-only "$PRODUCTION_POSTIMAGE"...HEAD -- src)" ]] || {
  echo 'F-SI16_B110_INDEPENDENT_ORACLE FAIL production changed after frozen postimage' >&2
  git diff --name-only "$PRODUCTION_POSTIMAGE"...HEAD -- src >&2
  exit 1
}

decode_b64_gzip() {
  local encoded="$1" output="$2"
  base64 --decode "$encoded" | gzip -dc > "$output"
}

# The exact B1.10 HeadCalc payload is intentionally split because the original
# source is large. Base64 ignores the newline boundaries between persisted parts.
cat "$SOURCE"/headcalc.f90.gz.b64.part00 \
    "$SOURCE"/headcalc.f90.gz.b64.part01 \
    "$SOURCE"/headcalc.f90.gz.b64.part02 \
    "$SOURCE"/headcalc.f90.gz.b64.part03 > "$BUILD/headcalc.f90.gz.b64"
decode_b64_gzip "$BUILD/headcalc.f90.gz.b64" "$BUILD/headcalc_exact.f90"
decode_b64_gzip "$SOURCE/watstor.f90.gz.b64" "$BUILD/watstor_exact.f90"
decode_b64_gzip "$SOURCE/fluxes.f90.gz.b64" "$BUILD/fluxes_exact.f90"
decode_b64_gzip "$SOURCE/tridag_b15.f90.gz.b64" "$BUILD/tridag_exact.f90"

echo 'db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5  '"$BUILD/headcalc_exact.f90" | sha256sum -c -
echo 'f82ad4d35f98b7e9d7591762a0a986e0a070cfec13ec1ee1edb02f01fadd9b97  '"$BUILD/watstor_exact.f90" | sha256sum -c -
echo 'b28b163520bc2ed873d98d4e0308d7b02a33577ee81b12a7f4bc1bc4cf746550  '"$BUILD/fluxes_exact.f90" | sha256sum -c -
echo '87b9b1cd6de65e6ee1d7c1775cddff6093c12d4d0744ffcde70844f5f28c6e7a  '"$BUILD/tridag_exact.f90" | sha256sum -c -
echo 'F-SI16_EXACT_B110_SOURCE_HASHES PASS'

# The exact and common executables deliberately use the same deterministic
# external-module fixture and the same qualified SWAP-008/B1.5 tridiagonal
# solver. What differs is the soil-water implementation under test:
#   exact  : canonical B1.10 HeadCalc + watstor + fluxes
#   common : SWAP5 common request -> ported B1.10 HeadCalc -> result materializer
# This removes the former self-oracle and compares the authoritative qbot path
# directly, with no scientific tolerance.
FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)

compile_exact() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fsi/fsi16_exact_b110_oracle_stubs.f90 -o "$out/stubs.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/tridag_exact.f90" -o "$out/tridag.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/headcalc_exact.f90" -o "$out/headcalc.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/watstor_exact.f90" -o "$out/watstor.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/fluxes_exact.f90" -o "$out/fluxes.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi16_exact_b110_oracle.F90 -o "$out/driver.o"
  gfortran "${FLAGS[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/watstor.o" "$out/fluxes.o" \
    "$out/tridag.o" "$out/stubs.o" -o "$out/test"
}

compile_common() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fsi/fsi16_exact_b110_oracle_stubs.f90 -o "$out/stubs.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/tridag_exact.f90" -o "$out/tridag.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/runtime/mod_a23bu_worker_execution_context.f90 -o "$out/worker.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_solver_contract.f90 -o "$out/contract.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_reference_richards_workspace.f90 -o "$out/workspace.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_reference_richards_state_binding.f90 -o "$out/state.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c tests/fsi/mod_fsi16_b110_direct_oracle_fixture.f90 -o "$out/fixture.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/legacy/b1_10_port/headcalc.f90 -o "$out/headcalc.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/adapter/mod_reference_richards_legacy_binding.f90 -o "$out/adapter.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi16_b110_direct_oracle_common.F90 -o "$out/driver.o"
  gfortran "${FLAGS[@]}" -O"$opt" "$out/driver.o" "$out/adapter.o" "$out/headcalc.o" "$out/fixture.o" \
    "$out/state.o" "$out/workspace.o" "$out/contract.o" "$out/worker.o" "$out/tridag.o" "$out/stubs.o" -o "$out/test"
}

for opt in 0 2; do
  exact="$BUILD/exact-o$opt"
  common="$BUILD/common-o$opt"
  compile_exact "$opt" "$exact"
  compile_common "$opt" "$common"
  timeout 30s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$exact/test" > "$exact/output.txt"
  timeout 30s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$common/test" > "$common/output.txt"

  if ! cmp "$exact/output.txt" "$common/output.txt"; then
    echo "F-SI16_B110_INDEPENDENT_ORACLE_O${opt} FAIL exact/common bitwise mismatch" >&2
    diff -u "$exact/output.txt" "$common/output.txt" >&2 || true
    exit 1
  fi
  echo "F-SI16_B110_EXACT_COMMON_IDENTITY_O${opt} PASS"
done

cmp "$BUILD/exact-o0/output.txt" "$BUILD/exact-o2/output.txt"
cmp "$BUILD/common-o0/output.txt" "$BUILD/common-o2/output.txt"
echo 'F-SI16_B110_EXACT_O0_O2_IDENTITY PASS'
echo 'F-SI16_B110_COMMON_O0_O2_IDENTITY PASS'
echo 'F-SI16_B110_INDEPENDENT_QBOT_AUTHORITY PASS'
echo 'F-SI16_B110_INDEPENDENT_ORACLE_GATE PASS'
