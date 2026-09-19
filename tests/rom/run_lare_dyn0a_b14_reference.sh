#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_START=9bb73821bb78a04c759b763746b50a3f777cd416
TEST=tests/rom/test_lare_dyn0a_b14_reference.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
UNIFORM=tests/rom/materialize_f_rom0_headcalc_stubs.py

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-lare-dyn0a-b14-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${LARE_DYN0A_B14_EVIDENCE_DIR:-$ROOT/LARE_DYN0A_B14_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "LARE_DYN0A_B14_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CANONICAL_START" HEAD || fail "canonical start not ancestor"
git diff --quiet "$CANONICAL_START"...HEAD -- src reference || fail "MECH2B changed src/reference"
echo 'LARE_DYN0A_B14_SOURCE_FREEZE=PASS'

python3 "$UNIFORM" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$BUILD/fine.f90" --nodes 16 --dz-cm 10

cases=()
for s in 1 2 3; do
  for f in 1 2 3 4; do
    cases+=("S${s}_B1_F${f}")
  done
done

: > "$EVIDENCE/status.tsv"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" \
    --root "$ROOT" \
    --stub "$BUILD/fine.f90" \
    --target "$TEST" \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" \
    --opt "$opt"

  for case_id in "${cases[@]}"; do
    logfile="$EVIDENCE/fine-${case_id}-o${opt}.txt"
    set +e
    LARE_DYN0A_BOTTOM_FILTER=1 LARE_DYN0A_CASE_FILTER="$case_id" \
      "$OUT/rom0_test" > "$logfile" 2>&1
    rc=$?
    set -e

    status="$(python3 - "$logfile" "$rc" <<'PY'
import re,sys
path,rc_raw=sys.argv[1:]
rc=int(rc_raw)
raw=open(path,errors='replace').read()
hs=[float(x) for x in re.findall(r'\|H=([^|\n]+)',raw)]
max_h=max(hs) if hs else float('-inf')
states=raw.count('LAREDYN0R_STATE|')
nodes=raw.count('LAREDYN0R_NODE|')
if rc==0:
    if 'LAREDYN0R_EXECUTION_COMPLETE=PASS' not in raw:
        raise SystemExit('successful process omitted completion marker')
    if states!=1024 or nodes!=1024*16:
        raise SystemExit(f'qualified structure mismatch states={states} nodes={nodes}')
    print('OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION' if max_h>=-0.01 else 'QUALIFIED')
else:
    known_domain=(
        'LAREDYN0R_FAIL LAREDYN0R prospective representation bound' in raw
        or max_h>=-0.01
    )
    if known_domain:
        print('OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION')
    elif 'LAREDYN0R_FAIL ' in raw:
        print('BLOCKED_REFERENCE_NUMERICAL_QUALIFICATION')
    else:
        tail='\n'.join(raw.splitlines()[-40:])
        raise SystemExit('unexpected technical B14 Reference failure\n'+tail)
PY
)" || fail "$case_id O$opt classification"
    printf '%s\t%s\t%s\n' "$case_id" "$opt" "$status" >> "$EVIDENCE/status.tsv"
  done
done

for case_id in "${cases[@]}"; do
  s0="$(awk -F '\t' -v c="$case_id" '$1==c && $2=="0"{print $3}' "$EVIDENCE/status.tsv")"
  s2="$(awk -F '\t' -v c="$case_id" '$1==c && $2=="2"{print $3}' "$EVIDENCE/status.tsv")"
  [[ -n "$s0" && "$s0" == "$s2" ]] || fail "$case_id O0/O2 status drift"
  grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS|FAIL)' "$EVIDENCE/fine-${case_id}-o0.txt" > "$BUILD/o0.norm" || true
  grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS|FAIL)' "$EVIDENCE/fine-${case_id}-o2.txt" > "$BUILD/o2.norm" || true
  cmp "$BUILD/o0.norm" "$BUILD/o2.norm" || fail "$case_id O0/O2 scientific trace drift"
done
echo 'LARE_DYN0A_B14_CASEWISE_O0_O2_IDENTITY=PASS'

python3 - "$EVIDENCE" <<'PY'
import json,pathlib,re,sys
root=pathlib.Path(sys.argv[1])
rows=[line.split('\t') for line in (root/'status.tsv').read_text().splitlines()]
out={}
for case in sorted({r[0] for r in rows}):
    vals=[r for r in rows if r[0]==case]
    assert len(vals)==2 and vals[0][2]==vals[1][2]
    status=vals[0][2]
    raw=(root/f'fine-{case}-o2.txt').read_text(errors='replace')
    hs=[float(x) for x in re.findall(r'\|H=([^|\n]+)',raw)]
    masses=[abs(float(x)) for x in re.findall(r'\|MASS=([^|\n]+)',raw)]
    out[case]={
      'status':status,
      'state_count':raw.count('LAREDYN0R_STATE|'),
      'max_pressure_head_cm':max(hs) if hs else None,
      'max_abs_mass_residual_cm':max(masses) if masses else None,
    }
    if status=='QUALIFIED':
        assert out[case]['state_count']==1024
        assert max(masses,default=0.0)<=1e-12
        assert max(hs,default=-1e99)<-0.01
summary={
  'schema':'swap5.lare.dyn0a.mech2b.b14-reference-status.v1',
  'decision':'LARE_DYN0A_MECH2B_B14_REFERENCE_CHARACTERIZED',
  'material':'B14',
  'bottom_boundary':'FIXED_FLUX',
  'geometries':{'fine':out},
  'qualified_count':sum(v['status']=='QUALIFIED' for v in out.values()),
  'outside_domain_count':sum(v['status']=='OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION' for v in out.values()),
  'numerical_block_count':sum(v['status']=='BLOCKED_REFERENCE_NUMERICAL_QUALIFICATION' for v in out.values()),
  'production_rom_authorized':False,
}
(root/'LARE_DYN0A_MECH2B_B14_REFERENCE_STATUS.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')
print(json.dumps({k:summary[k] for k in ('decision','qualified_count','outside_domain_count','numerical_block_count')},sort_keys=True))
PY

sha256sum "$EVIDENCE"/*.txt "$EVIDENCE"/*.json > "$EVIDENCE/sha256.txt"
git diff --check "$CANONICAL_START"...HEAD
echo 'LARE_DYN0A_B14_REFERENCE_GATE=PASS'
