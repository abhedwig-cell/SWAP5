#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

STUB="tests/fsi/fsi04_real_headcalc_stubs.f90"
EXPECTED_STUB_BLOB="23c00e4a188e88bc36ef95cbe4faaacdd6aad639"
FSI18_GENERATOR_BLOB="bf25c4c7fefaa59811255b0bc25c041522ab008e"
FSI18_REFERENCE_EVIDENCE_BLOB="bf433c7adff71ce9d10463d53a55a92fe4599655"
FSI18_BRANCH="origin/work/f-si18-reference-convergence-cliff"
FVQ27="1dc8219beda37fbcd6fd4232c964208fa0f17c8f"
TMP="${TMPDIR:-/tmp}/swap5-fsi20-reference-tridag-$$"
ORIGINAL="$TMP/fsi04_real_headcalc_stubs.original.f90"
mkdir -p "$TMP"
cleanup() {
  if [[ -f "$ORIGINAL" ]]; then cp "$ORIGINAL" "$STUB"; fi
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() { echo "FSI20_REFERENCE_TRIDAG_REQUALIFICATION_FAIL $*" >&2; exit 1; }

git diff --quiet "$FVQ27" -- src || fail 'production source differs from FVQ27'
[[ "$(git rev-parse HEAD:$STUB)" == "$EXPECTED_STUB_BLOB" ]] || fail 'local zero-correction stub drift'
[[ "$(git rev-parse "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 generator drift'
[[ "$(git rev-parse "$FSI18_BRANCH:integration/f-si/F-SI18_REFERENCE_TRIDAG_EVIDENCE.json")" == "$FSI18_REFERENCE_EVIDENCE_BLOB" ]] || fail 'F-SI18 reference evidence drift'
cp "$STUB" "$ORIGINAL"
grep -Fq 'solution(i) = 0.0d0' "$ORIGINAL" || fail 'expected zero-correction TRIDAG not present'
echo 'FSI20_REFERENCE_TRIDAG_ZERO_STUB_PROVENANCE=PASS'
echo 'FSI20_REFERENCE_TRIDAG_FSI18_CONTROL_PROVENANCE=PASS'
echo 'FSI20_REFERENCE_TRIDAG_PRODUCTION_SOURCE_IMMUTABILITY=PASS'

# Reuse the independently diagnosed F-SI18 test-only control generator verbatim.
git show "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py" > "$TMP/make_reference_tridag.py"
python3 "$TMP/make_reference_tridag.py" "$ORIGINAL" "$STUB"
if grep -Fq 'solution(i) = 0.0d0' "$STUB"; then fail 'zero-correction TRIDAG survived replacement'; fi
grep -Fq 'SWAP 4.3.1 tridag.f90' "$STUB" || fail 'reference TRIDAG marker missing'
echo 'FSI20_REFERENCE_TRIDAG_TEST_DEPENDENCY_REPLACED=PASS'

run_gate() {
  local name="$1" script="$2"
  local log="$TMP/${name}.log"
  echo "FSI20_REFERENCE_TRIDAG_GATE_BEGIN=$name"
  bash "$script" > "$log" 2>&1 || { cat "$log" >&2; fail "$name"; }
  cat "$log"
  echo "FSI20_REFERENCE_TRIDAG_GATE_END=$name:PASS"
}

# These are the same committed F-SI20 characterization programs, with only the
# test dependency TRIDAG changed from the known-zero stub to the F-SI18
# SWAP-4.3.1 Thomas control. No production source or solver control is altered.
run_gate fixed_horizon tests/fsi/run_fsi20_fixed_horizon_reference.sh
run_gate fixed_horizon_tolerance_axis tests/fsi/run_fsi20_fixed_horizon_tolerance_axis.sh
run_gate prescribed_head_temporal tests/fsi/run_fsi20_prescribed_head_temporal_characterization.sh
run_gate extended_startup_tail tests/fsi/run_fsi20_extended_startup_retry_ladder.sh

# Extract a compact cross-gate record without imposing acceptance thresholds.
python3 - "$TMP" <<'PY'
from pathlib import Path
import re,sys,math
root=Path(sys.argv[1])
fixed=(root/'fixed_horizon.log').read_text().splitlines()
temp=(root/'prescribed_head_temporal.log').read_text().splitlines()
extd=(root/'extended_startup_tail.log').read_text().splitlines()

comparisons=[]
for line in fixed:
    if line.startswith('FSI20_FIXED_COMPARE:'):
        m=re.search(r'N=(\d+):N2=(\d+):DHEAD_N_N2=\s*([^:]+)', line)
        if m: comparisons.append((int(m.group(1)),int(m.group(2)),float(m.group(3))))
if not comparisons: raise SystemExit('no fixed-horizon comparisons')
print(f'FSI20_REFERENCE_TRIDAG_FIXED_COMPARISONS={len(comparisons)}')
print(f'FSI20_REFERENCE_TRIDAG_FIXED_FIRST_DHEAD_CM={comparisons[0][2]:.17e}')
print(f'FSI20_REFERENCE_TRIDAG_FIXED_LAST_DHEAD_CM={comparisons[-1][2]:.17e}')
print('FSI20_REFERENCE_TRIDAG_FIXED_SUCCESSIVE_DECREASE='+('YES' if all(b[2] < a[2] for a,b in zip(comparisons,comparisons[1:])) else 'NO'))

rows=[]
for line in temp:
    if line.startswith('FSI20_CASE=2:COMPARE='):
        m=re.search(r'COMPARE=(\d+):DT=([^:]+):DHEAD=([^:]+)',line)
        if m: rows.append((int(m.group(1)),float(m.group(2)),float(m.group(3))))
if not rows: raise SystemExit('no temporal rows')
print(f'FSI20_REFERENCE_TRIDAG_LOCAL_ROWS={len(rows)}')
print(f'FSI20_REFERENCE_TRIDAG_LOCAL_FIRST_DHEAD_CM={rows[0][2]:.17e}')
print(f'FSI20_REFERENCE_TRIDAG_LOCAL_LAST_DHEAD_CM={rows[-1][2]:.17e}')

attempt=None
for line in extd:
    if line.startswith('FSI20_EXTENDED_STARTUP_ATTRIBUTION:'):
        attempt=line
if attempt:
    print('FSI20_REFERENCE_TRIDAG_'+attempt)

for label,path in [('fixed_horizon',root/'fixed_horizon.log'),('tolerance_axis',root/'fixed_horizon_tolerance_axis.log'),('temporal',root/'prescribed_head_temporal.log'),('extended',root/'extended_startup_tail.log')]:
    text=path.read_text()
    if 'MASS_REQUIREMENT_CHANGED=YES' in text or 'PRODUCTION_ACCEPTANCE_CHANGED=YES' in text:
        raise SystemExit(f'forbidden policy mutation marker in {label}')
print('FSI20_REFERENCE_TRIDAG_REQUALIFICATION_CHARACTERIZATION_ONLY=PASS')
PY

cp "$ORIGINAL" "$STUB"
cmp "$STUB" <(git show HEAD:$STUB)
echo 'FSI20_REFERENCE_TRIDAG_COMMITTED_STUB_RESTORED=PASS'
git diff --quiet "$FVQ27" -- src || fail 'production source changed after requalification'
echo 'FSI20_REFERENCE_TRIDAG_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FSI20_REFERENCE_TRIDAG_REQUALIFICATION PASS'
