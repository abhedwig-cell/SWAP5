#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi21-gatea-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=631d80abf04915cc964b24144f3fde8ef937093f
PROVIDER_BLOB=97d67eb373073b183be6d1bf5b756ecb5125dde2
CONTRACT_BLOB=4271372085d800fd5da969a2ed073b00422d79c6
STUB_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
DRIVER_BLOB=c3eaf112295c431d7ba530ee606e063c8eb77242
FVQ28_BRANCH=origin/qualification/f-vq28-richards-temporal-numeric-profile
FVQ28_GATEB=integration/f-vq/F-VQ28_GATE_B_EVIDENCE.json
FVQ28_GATEB_BLOB=279d50777a6fb362514818d004a5ddd23423b60d

fail() { echo "FSI21_GATEA_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$BASE" HEAD || fail 'F-SI20 negative handback base not ancestor'
git diff --quiet "$BASE" -- src || fail 'production source drift from F-SI20 handback'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" == "$PROVIDER_BLOB" ]] || fail 'production MvG provider drift'
[[ "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" == "$CONTRACT_BLOB" ]] || fail 'soil-water contract drift'
[[ "$(git rev-parse HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90)" == "$STUB_BLOB" ]] || fail 'test grid stub drift'
[[ "$(git rev-parse HEAD:tests/fsi/test_fsi21_initial_hydraulic_timescale.f90)" == "$DRIVER_BLOB" ]] || fail 'Gate A driver drift'
[[ "$(git rev-parse "$FVQ28_BRANCH:$FVQ28_GATEB")" == "$FVQ28_GATEB_BLOB" ]] || fail 'F-VQ28 Gate B evidence drift'
git show "$FVQ28_BRANCH:$FVQ28_GATEB" > "$BUILD/fvq28_gateb.json"
echo 'FSI21_GATEA_SOURCE_LOCK=PASS'
echo 'FSI21_GATEA_FVQ28_PATTERN_LOCK=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fsi/fsi04_real_headcalc_stubs.f90 -o "$OUT/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$OUT/provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fsi/test_fsi21_initial_hydraulic_timescale.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/stubs.o" "$OUT/contract.o" "$OUT/provider.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/run1.txt" 2>&1
  "$OUT/test" > "$OUT/run2.txt" 2>&1
  cmp "$OUT/run1.txt" "$OUT/run2.txt"
  grep -Fq 'FSI21_GATEA_INITIAL_HYDRAULIC_TIMESCALE_DRIVER PASS' "$OUT/run1.txt"
  echo "FSI21_GATEA_REPEAT_O${opt}=PASS"
done
cmp "$BUILD/o0/run1.txt" "$BUILD/o2/run1.txt"
echo 'FSI21_GATEA_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/run1.txt"

python3 - "$BUILD/o0/run1.txt" "$BUILD/fvq28_gateb.json" <<'PY'
from pathlib import Path
import json, math, re, sys

rows = {}
rx = re.compile(
    r'FSI21_GATEA_ROW:STATE=(\d+):ATTEMPT=(\d+):H0_CM=\s*([^:]+):DT_DAY=\s*([^:]+)'
    r':K0_CM_DAY=\s*([^:]+):C0_PER_CM=\s*([^:]+):D0_CM2_DAY=\s*([^:]+)'
    r':L_BOTTOM_CM=\s*([^:]+):TAU_DAY=\s*([^:]+):LAMBDA=\s*(\S+)')
for line in Path(sys.argv[1]).read_text().splitlines():
    m = rx.match(line)
    if not m:
        continue
    sid, aid = int(m.group(1)), int(m.group(2))
    rows[(sid, aid)] = {
        'h0': float(m.group(3)), 'dt': float(m.group(4)), 'k': float(m.group(5)),
        'c': float(m.group(6)), 'd': float(m.group(7)), 'l': float(m.group(8)),
        'tau': float(m.group(9)), 'lam': float(m.group(10))}
if len(rows) != 18:
    raise SystemExit(f'expected 18 descriptor rows, got {len(rows)}')

for sid in range(1, 7):
    a = [rows[(sid, i)] for i in (1,2,3)]
    if not (a[0]['k'] == a[1]['k'] == a[2]['k'] and a[0]['c'] == a[1]['c'] == a[2]['c']):
        raise SystemExit(f'state {sid}: K/C changed with retry horizon at unchanged T0')
    for i in (1,2):
        if not math.isclose(a[i]['lam']/a[i-1]['lam'], 0.5, rel_tol=2e-15, abs_tol=0.0):
            raise SystemExit(f'state {sid}: lambda did not halve with retry horizon')
print('FSI21_GATEA_LAMBDA_HALVES_EXACTLY_WITH_RETRY=PASS')

evidence = json.loads(Path(sys.argv[2]).read_text())
by_state = evidence['resolved_relationship']['by_initial_state']
if len(by_state) != 6:
    raise SystemExit('F-VQ28 state count drift')

state_coherent = True
counterexamples = []
for sid, item in enumerate(by_state, 1):
    h0 = float(item['initial_head_cm'])
    if not math.isclose(rows[(sid,1)]['h0'], h0, rel_tol=0.0, abs_tol=1e-15):
        raise SystemExit(f'state {sid}: H0 mismatch to F-VQ28')
    pats = item['case_patterns']
    if len(pats) != 4 or any(len(p) != 3 for p in pats):
        raise SystemExit(f'state {sid}: pattern shape drift')
    # At each retry horizon all resolved jump cases must agree for state-coherence.
    for pos in range(3):
        resolved = {p[pos] for p in pats if p[pos] in ('C','U')}
        if len(resolved) > 1:
            state_coherent = False
    # Any fully resolved C/U sequence with two transitions cannot result from a
    # one-threshold rule applied to monotonically halving initial-state lambda.
    for p in pats:
        if 'X' not in p:
            transitions = sum(p[i] != p[i-1] for i in (1,2))
            if transitions > 1:
                counterexamples.append((sid, h0, p))

if not state_coherent:
    raise SystemExit('resolved classifications are not coherent within hydraulic state across jumps')
if not counterexamples:
    raise SystemExit('predeclared one-threshold falsifier was not triggered')
if not any(h0 == -320.0 and p == 'UCU' for _,h0,p in counterexamples):
    raise SystemExit('expected -320 cm UCU falsifier absent')

taus = [rows[(sid,1)]['tau'] for sid in range(1,7)]
if len(set(taus)) != 6:
    raise SystemExit('hydraulic states did not produce distinct initial timescales')
spread = max(taus)/min(taus)
print('FSI21_GATEA_STATE_PATTERN_COHERENCE_ACROSS_JUMPS=PASS')
print(f'FSI21_GATEA_DISTINCT_INITIAL_TIMESCALES=PASS:TAU_SPREAD={spread:.17e}')
print('FSI21_GATEA_INITIAL_SCALAR_THRESHOLD_FALSIFIED=PASS:COUNTEREXAMPLES='+str(len(counterexamples)))
for sid,h0,p in counterexamples:
    print(f'FSI21_GATEA_THRESHOLD_COUNTEREXAMPLE:STATE={sid}:H0_CM={h0:.17e}:PATTERN={p}')
print('FSI21_GATEA_INTERPRETATION=HYDRAULIC_STATE_IS_INFORMATIVE_BUT_INITIAL_K_C_TIMESCALE_ALONE_CANNOT_EXPLAIN_RETRY_TRANSLATION')
print('FSI21_GATEA_DECISION=B_INITIAL_STATE_TIMESCALE_INFORMATIVE_BUT_INSUFFICIENT_DYNAMIC_LOCAL_CHARACTERIZATION_REQUIRED')
print('FSI21_GATEA_PRODUCTION_METRIC_SELECTED=NO')
print('FSI21_GATEA_NORMALIZATION_SELECTED=NO')
print('FSI21_GATEA_TOLERANCE_SELECTED=NO')
PY

git diff --quiet "$BASE" -- src || fail 'production source changed during Gate A'
echo 'FSI21_GATEA_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FSI21_INITIAL_HYDRAULIC_TIMESCALE_GATE PASS'
