#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi09-b110-provider-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 tools/fsi/fsi09_verify_b110_reference_payload.py
python3 - "$ROOT/reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.f90.gz.b64" "$BUILD/MOD_MvG_functions.B1.10.f90" <<'PY'
import base64,gzip,pathlib,sys,hashlib
payload=pathlib.Path(sys.argv[1]).read_text()
raw=gzip.decompress(base64.b64decode(''.join(payload.split()),validate=True))
sha=hashlib.sha256(raw).hexdigest()
assert sha=='4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1',sha
pathlib.Path(sys.argv[2]).write_bytes(raw)
PY

PROVIDER="$ROOT/src/solver/mod_b110_constitutive_provider.f90"
CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
STUBS="$ROOT/tests/fsi/fsi09_b110_oracle_stubs.f90"
DRIVER="$ROOT/tests/fsi/test_fsi09_b110_provider_oracle.f90"
ORACLE="$BUILD/MOD_MvG_functions.B1.10.f90"

# The production provider must not import legacy mutable modules or declare SAVE state.
python3 - "$PROVIDER" "$ORACLE" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]).read_text().lower()
o=Path(sys.argv[2]).read_text().lower()
for token in ['use mod_mvg','use variables','use mod_grid','use mod_swap_base','save ::']:
    if token in p:
        raise SystemExit(f'F-SI09 provider forbidden legacy/shared state token: {token}')
required_oracle=[
 'watcon = dmax1(1.0000001*wcr(node), wcr(node) + wcsminwcr(node)*dexp(alfamg(node)*head))',
 'moiscap = alfamg(node)*wcsminwcr(node)*dexp(alfamg(node)*head)',
 'hconduc = ksatfit(node)*relsat',
 'else if (imod == 3) then',
 'if (head > -1.0d0 .and. moiscap < (dt * 1.0d-7)) moiscap = dt * 1.0d-7',
]
for token in required_oracle:
    if token.lower() not in o:
        raise SystemExit(f'F-SI09 exact B1.10 oracle token missing: {token}')
print('F-SI09_PROVIDER_STATIC_OWNERSHIP PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  d="$BUILD/o$opt"; mkdir -p "$d"
  gfortran "${COMMON[@]}" -O"$opt" -J "$d" -I "$d" -c "$STUBS" -o "$d/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$d" -I "$d" -c "$CONTRACT" -o "$d/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$d" -I "$d" -c "$PROVIDER" -o "$d/provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$d" -I "$d" -c "$ORACLE" -o "$d/oracle.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$d" -I "$d" -c "$DRIVER" -o "$d/driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$d/driver.o" "$d/provider.o" "$d/oracle.o" "$d/contract.o" "$d/stubs.o" -o "$d/test"
  "$d/test" | tee "$d/output.txt"
  grep -Fq 'F-SI09_B110_PROVIDER_ORACLE PASS' "$d/output.txt"
  echo "F-SI09_B110_PROVIDER_ORACLE_O${opt} PASS"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'F-SI09_B110_PROVIDER_O0_O2_IDENTITY PASS'

# Re-run the fully qualified F-SI08 boundary. New provider code may not perturb it.
bash tests/fsi/run_fsi08_provider_context_gate.sh
echo 'F-SI09_FSI08_REGRESSION PASS'

echo 'F-SI09_B110_PROVIDER_GATE PASS'
