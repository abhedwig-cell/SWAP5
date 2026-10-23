#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; B="${RUNNER_TEMP:-/tmp}/difficulty-p0d-$$"; mkdir -p "$B"; trap 'rm -rf "$B"' EXIT; cd "$ROOT"
F=(-std=f2008 -ffree-line-length-none -fcheck=all -J "$B" -I "$B")
gfortran "${F[@]}" -c src/solver/mod_soil_water_solver_contract.f90 -o "$B/c.o"
gfortran "${F[@]}" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$B/m.o"
gfortran "${F[@]}" -c src/research/mod_difficulty_pretrial_descriptors.f90 -o "$B/d.o"
gfortran "${F[@]}" -c tests/publication/test_difficulty_p0d_descriptors.f90 -o "$B/t.o"
gfortran "$B/c.o" "$B/m.o" "$B/d.o" "$B/t.o" -o "$B/t"
"$B/t" | tee "$B/out"
grep -Fq 'DIFFICULTY_P0D_PRETRIAL_ONLY=PASS' "$B/out"
grep -Fq 'DIFFICULTY_P0D_CONSTITUTIVE_AUTHORITY=PASS' "$B/out"
echo DIFFICULTY_P0D_DESCRIPTORS=PASS
