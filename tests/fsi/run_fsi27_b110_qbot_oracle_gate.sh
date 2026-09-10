#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="6318f04bd4d7dd8f9a587f03decaaea63d4f5f36"
HIST="e1f8e810a4b3018ef2901b9f35137e4381a0970e"
SOURCE_PATH="reference/swap-4.3.1/b1_10_source"
BUILD="${TMPDIR:-/tmp}/swap5-fsi27-b110-qbot-oracle-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FSI27_B110_ORACLE_FAIL $*" >&2; exit 1; }

git cat-file -e "$BASE^{commit}" || fail 'frozen canonical base missing'
git merge-base --is-ancestor "$BASE" HEAD || fail 'candidate does not descend from frozen canonical base'
git cat-file -e "$HIST^{commit}" || fail 'pinned F-SI16 tested oracle head missing'
changed_src="$(git diff --name-only "$BASE"...HEAD -- src | sort)"
[[ "$changed_src" == 'src/adapter/mod_reference_richards_legacy_binding.f90' ]] || fail "unexpected production delta: $changed_src"
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == '2cb1126397147b9e447634b131c93932c097177d' ]] || fail 'adapter blob drift'
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == '55893f1f5ccba2052ad681743aa155b69f351246' ]] || fail 'HeadCalc blob drift'

# The independent oracle is reconstructed from the exact historical F-SI16
# tested head. That line is intentionally independent from the current canonical
# ancestry; authority is by pinned commit + decoded-source hashes, not merge ancestry.
git show "$HIST:tests/fsi/fsi16_exact_b110_oracle_stubs.f90" > "$BUILD/exact_stubs.f90"
for f in headcalc_exact.f90.gz.b64 watstor.f90.gz.b64 fluxes.f90.gz.b64 tridag_b15.f90.gz.b64; do
  git show "$HIST:$SOURCE_PATH/$f" > "$BUILD/$f" || fail "missing pinned oracle payload $f"
done

decode() { base64 --decode "$1" | gzip -dc > "$2"; }
decode "$BUILD/headcalc_exact.f90.gz.b64" "$BUILD/headcalc_exact.f90"
decode "$BUILD/watstor.f90.gz.b64" "$BUILD/watstor_exact.f90"
decode "$BUILD/fluxes.f90.gz.b64" "$BUILD/fluxes_exact.f90"
decode "$BUILD/tridag_b15.f90.gz.b64" "$BUILD/tridag_exact.f90"

echo 'db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5  '"$BUILD/headcalc_exact.f90" | sha256sum -c -
echo 'f82ad4d35f98b7e9d7591762a0a986e0a070cfec13ec1ee1edb02f01fadd9b97  '"$BUILD/watstor_exact.f90" | sha256sum -c -
echo 'b28b163520bc2ed873d98d4e0308d7b02a33577ee81b12a7f4bc1bc4cf746550  '"$BUILD/fluxes_exact.f90" | sha256sum -c -
echo '87b9b1cd6de65e6ee1d7c1775cddff6093c12d4d0744ffcde70844f5f28c6e7a  '"$BUILD/tridag_exact.f90" | sha256sum -c -
echo 'FSI27_B110_ORACLE_PINNED_SOURCE_HASHES=PASS'

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)

compile_exact() {
  local opt="$1" out="$BUILD/exact-o$1"
  mkdir -p "$out"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/exact_stubs.f90" -o "$out/stubs.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/tridag_exact.f90" -o "$out/tridag.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/headcalc_exact.f90" -o "$out/headcalc.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/watstor_exact.f90" -o "$out/watstor.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/fluxes_exact.f90" -o "$out/fluxes.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi27_exact_b110_qbot_oracle.F90 -o "$out/driver.o"
  gfortran "${FLAGS[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/watstor.o" "$out/fluxes.o" "$out/tridag.o" "$out/stubs.o" -o "$out/test"
}

compile_common() {
  local opt="$1" out="$BUILD/common-o$1"
  mkdir -p "$out"
  local src obj
  local objects=()
  local sources=(
    tests/fsi/fsi04_real_headcalc_stubs.f90
    src/runtime/mod_a23bu_worker_execution_context.f90
    src/solver/mod_soil_water_solver_contract.f90
    src/solver/mod_reference_linear_solver.f90
    src/solver/mod_reference_richards_workspace.f90
    src/solver/mod_reference_richards_state_binding.f90
    src/solver/mod_b110_default_mvg_provider.f90
    src/solver/mod_b110_source_sink_provider.f90
    src/solver/mod_fixed_flux_top_boundary_provider.f90
    src/solver/mod_reference_richards_temporal_indicator.f90
    tests/fsi/mod_fsi27_b110_oracle_fixture.f90
    src/legacy/b1_10_port/headcalc.f90
    src/adapter/mod_reference_richards_legacy_binding.f90
    tests/fsi/test_fsi27_b110_qbot_oracle_common.F90
  )
  for src in "${sources[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${FLAGS[@]}" -O"$opt" "${objects[@]}" -o "$out/test"
}

# Comparison policy is frozen before execution: exact byte-for-byte observable
# identity for pressure head, water content, authoritative qbot and nonlinear
# iteration count. No scientific tolerance is introduced after observing data.
for opt in 0 2; do
  compile_exact "$opt"
  compile_common "$opt"
  for spec in 'pos:0.2' 'zero:0.0' 'neg:-0.4'; do
    label="${spec%%:*}"; q="${spec#*:}"
    timeout 60s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$BUILD/exact-o$opt/test" "$q" > "$BUILD/exact-o$opt/$label.txt"
    timeout 60s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$BUILD/common-o$opt/test" "$q" > "$BUILD/common-o$opt/$label.txt"
    if ! cmp "$BUILD/exact-o$opt/$label.txt" "$BUILD/common-o$opt/$label.txt"; then
      echo "FSI27_B110_ORACLE_O${opt}_${label}=FAIL" >&2
      diff -u "$BUILD/exact-o$opt/$label.txt" "$BUILD/common-o$opt/$label.txt" >&2 || true
      exit 1
    fi
    echo "FSI27_B110_ORACLE_O${opt}_${label}=PASS"
  done
done

for label in pos zero neg; do
  cmp "$BUILD/exact-o0/$label.txt" "$BUILD/exact-o2/$label.txt" || fail "exact O0/O2 drift $label"
  cmp "$BUILD/common-o0/$label.txt" "$BUILD/common-o2/$label.txt" || fail "common O0/O2 drift $label"
done

echo 'FSI27_B110_ORACLE_SIGN_COVERAGE=PASS'
echo 'FSI27_B110_ORACLE_O0_O2_IDENTITY=PASS'
echo 'FSI27_B110_INDEPENDENT_EXACT_MODE2_ORACLE=PASS'
