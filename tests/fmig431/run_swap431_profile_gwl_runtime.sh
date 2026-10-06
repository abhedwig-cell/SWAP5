#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$ROOT"
# Reuse the production dependency closure from the admitted FMR44R gate, but
# compile this branch's runtime oracle instead of mutating production sources.
python3 tests/fmr/_apply_fmr44r_serialized_qbot_runtime_patch.py
mapfile -t SRC < <(python3 - <<'PY'
from pathlib import Path
s=Path('tests/fmr/run_fmr44r_serialized_prescribed_qbot_gate.sh').read_text()
body=s.split('MODULE_SRC=(',1)[1].split(')',1)[0]
for line in body.splitlines():
    line=line.strip()
    if line and not line.startswith('#'): print(line)
PY
)
mapfile -t SRC < <(python3 tests/support/augment_bartholomeus_backend_sources.py "${SRC[@]}")
for opt in 0 2; do
  out="$TMP/o$opt"; mkdir -p "$out"; objs=()
  for source in "${SRC[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran -std=f2008 -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -O"$opt" -J"$out" -I"$out" -c "$source" -o "$obj"
    objs+=("$obj")
  done
  gfortran -std=f2008 -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -O"$opt" -J"$out" -I"$out" -c tests/fmig431/test_swap431_profile_gwl_runtime.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objs[@]}" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
  grep -Fq 'SW431_GW_PROJECTION_RUNTIME_COMMIT=PASS' "$out/output.txt"
  echo "O$opt SW431_GW_PROJECTION_RUNTIME=PASS"
done
