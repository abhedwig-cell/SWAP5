#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-int12-c-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=b0d2cc0ac749e1fa60ba4f5f610d01fc0b3b6ad9
expected_src='src/runtime/mod_fmr_interception_source_window_binding.f90'
changed_src="$(git diff --name-only "$BASE" -- src | sort)"
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'INT12C_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'INT12C_SINGLE_RUNTIME_PROVENANCE_ADAPTER=PASS'

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/process/mod_pmdirect_swetr0_process.f90 -o "$OUT/pmdirect.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/runtime/mod_interception_source_window_runtime.f90 -o "$OUT/int12_p0.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -Wno-error=unused-dummy-argument -O"$opt" -J"$OUT" -I"$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/soil_water_solver_contract.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J"$OUT" -I"$OUT" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$OUT/b110_default_mvg.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J"$OUT" -I"$OUT" -c src/solver/mod_b110_dynamic_top_boundary_provider.f90 -o "$OUT/b110_dynamic_top.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/runtime/mod_fmr_pmdirect_dynamic_top_boundary_binding.f90 -o "$OUT/pmdirect_top_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/runtime/mod_fmr_interception_source_window_binding.f90 -o "$OUT/int12_c_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c tests/fpm/test_f_mig431_int12_c.f90 -o "$OUT/int12_c_test.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/int12_p0.o" "$OUT/soil_water_solver_contract.o" \
    "$OUT/b110_default_mvg.o" "$OUT/b110_dynamic_top.o" "$OUT/pmdirect_top_binding.o" \
    "$OUT/int12_c_binding.o" "$OUT/int12_c_test.o" -o "$OUT/int12-c"
  "$OUT/int12-c" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  grep -Fq 'F-MIG431-INT12-C RESTRICTED HUPSEL COMPOSITION PASS' "$OUT/output.txt"
  echo "INT12C_O$opt=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'INT12C_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "INT12C_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'F-MIG431-INT12-C QUALIFICATION PASS'
