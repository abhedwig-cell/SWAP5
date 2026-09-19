#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_START=9bb73821bb78a04c759b763746b50a3f777cd416
TEST=tests/rom/test_lare_dyn0a_reference.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
UNIFORM=tests/rom/materialize_f_rom0_headcalc_stubs.py
VARIABLE=tests/rom/materialize_lare_variable_grid_stubs.py

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-lare-dyn0a-ref-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${LARE_DYN0A_REFERENCE_EVIDENCE_DIR:-$ROOT/LARE_DYN0A_REFERENCE_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "LARE_DYN0A_REFERENCE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CANONICAL_START" HEAD || fail "canonical start not ancestor"
git diff --quiet "$CANONICAL_START"...HEAD -- src reference || fail "DYN0A changed src/reference"
echo 'LARE_DYN0A_REFERENCE_SOURCE_FREEZE=PASS'

python3 "$UNIFORM"   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/fine.f90"   --nodes 16 --dz-cm 10

python3 "$VARIABLE"   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/d3.f90"   --layer-thickness-cm 140,10,10

python3 "$VARIABLE"   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/d2.f90"   --layer-thickness-cm 150,10

for geometry in fine d3 d2; do
  case "$geometry" in
    fine) nodes=16 ;;
    d3) nodes=3 ;;
    d2) nodes=2 ;;
  esac

  for opt in 0 2; do
    OUT="$BUILD/${geometry}-o${opt}"
    python3 "$COMPILER"       --root "$ROOT"       --stub "$BUILD/${geometry}.f90"       --target "$TEST"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT"       --opt "$opt"

    "$OUT/rom0_test" > "$EVIDENCE/${geometry}-o${opt}.txt" 2>&1 || {
      tail -n 500 "$EVIDENCE/${geometry}-o${opt}.txt" >&2
      fail "${geometry} O${opt} execution"
    }

    grep -Fq 'LAREDYN0R_EXECUTION_COMPLETE=PASS' "$EVIDENCE/${geometry}-o${opt}.txt" ||
      fail "missing completion marker ${geometry} O${opt}"
    [[ "$(grep -c 'LAREDYN0R_STATE|' "$EVIDENCE/${geometry}-o${opt}.txt")" -eq 24576 ]] ||
      fail "state count ${geometry} O${opt}"
    expected_nodes=$((24576 * nodes))
    [[ "$(grep -c 'LAREDYN0R_NODE|' "$EVIDENCE/${geometry}-o${opt}.txt")" -eq "$expected_nodes" ]] ||
      fail "node count ${geometry} O${opt}"
  done

  cmp "$EVIDENCE/${geometry}-o0.txt" "$EVIDENCE/${geometry}-o2.txt" ||
    fail "${geometry} O0/O2 stdout drift"
  echo "LARE_DYN0A_${geometry^^}_O0_O2_IDENTITY=PASS"
done

python3 - "$EVIDENCE" <<'PY'
import pathlib,sys,re
root=pathlib.Path(sys.argv[1])
for geom,nodes in [('fine',16),('d3',3),('d2',2)]:
    raw=(root/f'{geom}-o2.txt').read_text()
    m=re.search(r'LAREDYN0R_MAX_ABS_MASS=([^\n]+)',raw)
    assert m, geom
    max_mass=float(m.group(1))
    assert max_mass <= 1e-12, (geom,max_mass)
    active=re.search(r'LAREDYN0R_ACTIVE_NODES=(\d+)',raw)
    assert active and int(active.group(1))==nodes
print('LARE_DYN0A_REFERENCE_STRUCTURAL_GATE=PASS')
PY

sha256sum "$EVIDENCE"/*.txt > "$EVIDENCE/sha256.txt"
git diff --check "$CANONICAL_START"...HEAD
echo 'LARE_DYN0A_REFERENCE_GATE=PASS'
