#!/usr/bin/env bash
set -euo pipefail
R="$(cd "$(dirname "$0")/../.."&&pwd)"; B="${RUNNER_TEMP:-/tmp}/dif-p0e-$$"; mkdir -p "$B"; trap 'rm -rf "$B"' EXIT; cd "$R"
F=(-std=f2008 -ffree-line-length-none -fcheck=all -J "$B" -I "$B")
gfortran "${F[@]}" -c src/solver/mod_soil_water_solver_contract.f90 -o "$B/c.o"
gfortran "${F[@]}" -c src/research/mod_difficulty_pretrial_descriptors.f90 -o "$B/d.o"
gfortran "${F[@]}" -c src/research/mod_difficulty_regime_selector.f90 -o "$B/r.o"
gfortran "${F[@]}" -c tests/publication/test_difficulty_p0e_regimes.f90 -o "$B/t.o"
gfortran "$B/c.o" "$B/d.o" "$B/r.o" "$B/t.o" -o "$B/t"; "$B/t"|tee "$B/out"
grep -Fq DIFFICULTY_P0E_OUTCOME_BLIND_REGIMES=PASS "$B/out"; echo DIFFICULTY_P0E_REGIMES=PASS
