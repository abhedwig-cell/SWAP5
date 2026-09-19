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

python3 "$UNIFORM"   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/fine.f90" --nodes 16 --dz-cm 10
python3 "$VARIABLE"   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/d3.f90" --layer-thickness-cm 140,10,10
python3 "$VARIABLE"   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/d2.f90" --layer-thickness-cm 150,10

: > "$EVIDENCE/status.tsv"

cases=()
for s in 1 2 3; do
  for f in 1 2 3 4; do
    cases+=("S${s}_B1_F${f}")
  done
done

for geometry in fine d3 d2; do
  case "$geometry" in
    fine) nodes=16 ;;
    d3) nodes=3 ;;
    d2) nodes=2 ;;
  esac

  for opt in 0 2; do
    OUT="$BUILD/${geometry}-o${opt}"
    python3 "$COMPILER"       --root "$ROOT"       --stub "$BUILD/${geometry}.f90"       --target "$TEST"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT"       --opt "$opt"

    for case_id in "${cases[@]}"; do
      logfile="$EVIDENCE/${geometry}-${case_id}-o${opt}.txt"
      set +e
      LARE_DYN0A_BOTTOM_FILTER=1 LARE_DYN0A_CASE_FILTER="$case_id"         "$OUT/rom0_test" > "$logfile" 2>&1
      rc=$?
      set -e

      status="$(python3 - "$logfile" "$rc" "$nodes" <<'PY'
import re,sys
path,rc_raw,nodes_raw=sys.argv[1:]
rc=int(rc_raw); nodes=int(nodes_raw)
raw=open(path,errors='replace').read()
hs=[float(x) for x in re.findall(r'\|H=([^|\n]+)',raw)]
max_h=max(hs) if hs else float('-inf')
states=raw.count('LAREDYN0R_STATE|')
node_rows=raw.count('LAREDYN0R_NODE|')
if rc==0:
    if 'LAREDYN0R_EXECUTION_COMPLETE=PASS' not in raw:
        raise SystemExit('successful process omitted completion marker')
    if states!=1024 or node_rows!=1024*nodes:
        raise SystemExit(f'qualified structure mismatch states={states} nodes={node_rows}')
    if max_h >= -0.01:
        print('OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION')
    else:
        print('QUALIFIED')
else:
    known_domain = (
        'LAREDYN0R_FAIL LAREDYN0R prospective representation bound' in raw
        or max_h >= -0.01
    )
    if not known_domain:
        tail='\n'.join(raw.splitlines()[-40:])
        raise SystemExit('unexpected Reference failure\n'+tail)
    print('OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION')
PY
)" || fail "${geometry} ${case_id} O${opt} classification"

      printf '%s\t%s\t%s\t%s\n' "$geometry" "$case_id" "$opt" "$status" >> "$EVIDENCE/status.tsv"
    done
  done

  for case_id in "${cases[@]}"; do
    s0="$(awk -F '\t' -v g="$geometry" -v c="$case_id" '$1==g && $2==c && $3=="0"{print $4}' "$EVIDENCE/status.tsv")"
    s2="$(awk -F '\t' -v g="$geometry" -v c="$case_id" '$1==g && $2==c && $3=="2"{print $4}' "$EVIDENCE/status.tsv")"
    [[ -n "$s0" && "$s0" == "$s2" ]] || fail "${geometry} ${case_id} O0/O2 status drift"

    grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS|FAIL)'       "$EVIDENCE/${geometry}-${case_id}-o0.txt" > "$BUILD/o0.norm" || true
    grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS|FAIL)'       "$EVIDENCE/${geometry}-${case_id}-o2.txt" > "$BUILD/o2.norm" || true
    cmp "$BUILD/o0.norm" "$BUILD/o2.norm" ||
      fail "${geometry} ${case_id} O0/O2 scientific trace drift"
  done
  echo "LARE_DYN0A_${geometry^^}_CASEWISE_O0_O2_IDENTITY=PASS"
done

python3 - "$EVIDENCE" <<'PY'
import json,pathlib,re,sys
root=pathlib.Path(sys.argv[1])
rows=[]
for line in (root/'status.tsv').read_text().splitlines():
    geom,case,opt,status=line.split('\t')
    rows.append((geom,case,int(opt),status))
out={}
for geom in ('fine','d3','d2'):
    by={}
    for case in sorted({r[1] for r in rows if r[0]==geom}):
        vals=[r for r in rows if r[0]==geom and r[1]==case]
        assert len(vals)==2 and vals[0][3]==vals[1][3]
        status=vals[0][3]
        raw=(root/f'{geom}-{case}-o2.txt').read_text(errors='replace')
        hs=[float(x) for x in re.findall(r'\|H=([^|\n]+)',raw)]
        masses=[abs(float(x)) for x in re.findall(r'\|MASS=([^|\n]+)',raw)]
        out.setdefault(geom,{})[case]={
            'status':status,
            'state_count':raw.count('LAREDYN0R_STATE|'),
            'max_pressure_head_cm':max(hs) if hs else None,
            'max_abs_mass_residual_cm':max(masses) if masses else None,
        }
        if status=='QUALIFIED':
            assert raw.count('LAREDYN0R_STATE|')==1024
            assert max(masses,default=0.0)<=1e-12
            assert max(hs,default=-1e99)<-0.01
summary={
  'schema':'swap5.lare.dyn0a.fx.richards-reference-status.v1',
  'decision':'LARE_DYN0A_FX_REFERENCE_CASES_CHARACTERIZED',
  'bottom_boundary':'FIXED_FLUX',
  'geometries':out,
  'qualified_counts':{
      geom:sum(v['status']=='QUALIFIED' for v in cases.values())
      for geom,cases in out.items()
  },
  'outside_domain_counts':{
      geom:sum(v['status']!='QUALIFIED' for v in cases.values())
      for geom,cases in out.items()
  },
  'production_rom_authorized':False,
}
(root/'LARE_DYN0A_FX_REFERENCE_STATUS.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')
print(json.dumps({
  'decision':summary['decision'],
  'qualified_counts':summary['qualified_counts'],
  'outside_domain_counts':summary['outside_domain_counts'],
},sort_keys=True))
PY

sha256sum "$EVIDENCE"/*.txt "$EVIDENCE"/*.json > "$EVIDENCE/sha256.txt"
git diff --check "$CANONICAL_START"...HEAD
echo 'LARE_DYN0A_FX_REFERENCE_GATE=PASS'
