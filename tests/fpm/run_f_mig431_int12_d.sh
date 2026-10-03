#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; B="${TMPDIR:-/tmp}/int12d-$$"; mkdir -p "$B"; trap 'rm -rf "$B"' EXIT; cd "$ROOT"
C=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow)
for o in 0 2; do mkdir -p "$B/o$o"; gfortran "${C[@]}" -O$o -J"$B/o$o" src/process/mod_gash_interception_process.f90 tests/fpm/test_f_mig431_int12_d_gash.f90 -o "$B/o$o/t"; "$B/o$o/t" >"$B/o$o/out"; gfortran "${C[@]}" -O$o -J"$B/o$o" src/process/mod_gash_interception_process.f90 tests/fvq/test_fvq_int12d_gash_independent.f90 -o "$B/o$o/vq"; "$B/o$o/vq" >>"$B/o$o/out"; done
cmp "$B/o0/out" "$B/o2/out"; cat "$B/o0/out"; echo F-MIG431-INT12-D-O0-O2=PASS
