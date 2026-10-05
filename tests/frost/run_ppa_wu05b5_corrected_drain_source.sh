#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/ppa-frost-corrected-drain"
mkdir -p "$BUILD"
CORRECTION="$ROOT/reference/swap-4.3.1/frost-corrections/FROST-DRAIN-01"
python3 "$CORRECTION/apply.py" "$ROOT/reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90" "$BUILD/patched.f90"
cmp "$BUILD/patched.f90" "$CORRECTION/frozencond.f90"
python3 - "$BUILD" <<'PY'
import pathlib,sys
folder=pathlib.Path(sys.argv[1]);data=(folder/'patched.f90').read_bytes()
data=data.replace(b'module MOD_frost\r\n',b'module MOD_frost_corrected\r\n')
(folder/'namespaced.f90').write_bytes(data)
PY
for opt in 0 2; do
 mkdir -p "$BUILD/o$opt"
 gfortran -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow \
   -O"$opt" -J "$BUILD/o$opt" -I "$BUILD/o$opt" \
   "$ROOT/tests/frost/test_ppa_wu05b5_corrected_drain_globals.f90" \
   "$ROOT/reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90" \
   "$BUILD/namespaced.f90" "$ROOT/tests/frost/test_ppa_wu05b5_corrected_drain.f90" -o "$BUILD/o$opt/test"
 "$BUILD/o$opt/test" > "$BUILD/o$opt/output.txt"
 cat "$BUILD/o$opt/output.txt"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
