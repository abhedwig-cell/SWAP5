#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_START=9bb73821bb78a04c759b763746b50a3f777cd416
TEST=tests/rom/test_lare_dyn0a_reference.f90
ANALYZER=tests/rom/analyze_lare_dyn0a_crq.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
VARIABLE=tests/rom/materialize_lare_variable_grid_stubs.py
GEOMETRY="${LARE_DYN0A_CRQ_GEOMETRY:-}"

[[ "$GEOMETRY" == "d3" || "$GEOMETRY" == "d2" ]] || { echo "bad geometry" >&2; exit 2; }

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-lare-dyn0a-crq-${GEOMETRY}-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${LARE_DYN0A_CRQ_EVIDENCE_DIR:-$ROOT/LARE_DYN0A_CRQ_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "LARE_DYN0A_CRQ_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CANONICAL_START" HEAD || fail "canonical start not ancestor"
git diff --quiet "$CANONICAL_START"...HEAD -- src reference || fail "CRQ changed src/reference"

case "$GEOMETRY" in
 d3) layers=140,10,10; nodes=3 ;;
 d2) layers=150,10; nodes=2 ;;
esac

python3 "$VARIABLE"   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/grid.f90" --layer-thickness-cm "$layers"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER"     --root "$ROOT"     --stub "$BUILD/grid.f90"     --target "$TEST"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT"     --opt "$opt"
done

: > "$EVIDENCE/status.tsv"
cases=()
for s in 1 2 3; do
  for f in 1 2 3 4; do
    cases+=("S${s}_B1_F${f}")
  done
done

for sub in 1 2 4 8; do
  for case_id in "${cases[@]}"; do
    for opt in 0 2; do
      logfile="$EVIDENCE/${GEOMETRY}-${case_id}-s${sub}-o${opt}.txt"
      set +e
      LARE_DYN0A_BOTTOM_FILTER=1       LARE_DYN0A_CASE_FILTER="$case_id"       LARE_DYN0A_SUBSTEPS="$sub"         "$BUILD/o${opt}/rom0_test" > "$logfile" 2>&1
      rc=$?
      set -e

      status="$(python3 - "$logfile" "$rc" "$nodes" "$sub" <<'PY'
import re,sys
path,rc_raw,nodes_raw,sub_raw=sys.argv[1:]
rc=int(rc_raw); nodes=int(nodes_raw); sub=int(sub_raw)
raw=open(path,errors='replace').read()
hs=[float(x) for x in re.findall(r'\|H=([^|\n]+)',raw)]
max_h=max(hs) if hs else float('-inf')
states=raw.count('LAREDYN0R_STATE|')
node_rows=raw.count('LAREDYN0R_NODE|')
if rc==0:
    if 'LAREDYN0R_EXECUTION_COMPLETE=PASS' not in raw:
        raise SystemExit('successful process omitted completion marker')
    if f'LAREDYN0R_SUBSTEPS={sub}' not in raw:
        raise SystemExit('substep marker drift')
    if states!=1024 or node_rows!=1024*nodes:
        raise SystemExit(f'qualified structure mismatch states={states} nodes={node_rows}')
    if max_h >= -0.01:
        print('OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION')
    else:
        print('QUALIFIED')
else:
    if 'LAREDYN0R_FAIL LAREDYN0R prospective representation bound' in raw or max_h >= -0.01:
        print('OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION')
    elif 'LAREDYN0R_FAIL ' in raw:
        print('BLOCKED_REFERENCE_NUMERICAL_QUALIFICATION')
    else:
        tail='\n'.join(raw.splitlines()[-40:])
        raise SystemExit('unexpected technical Reference failure\n'+tail)
PY
)" || fail "$GEOMETRY $case_id sub=$sub O$opt classification"
      printf '%s\t%s\t%s\t%s\t%s\n' "$GEOMETRY" "$case_id" "$sub" "$opt" "$status" >> "$EVIDENCE/status.tsv"
    done

    s0="$(awk -F '\t' -v g="$GEOMETRY" -v c="$case_id" -v s="$sub" '$1==g && $2==c && $3==s && $4=="0"{print $5}' "$EVIDENCE/status.tsv")"
    s2="$(awk -F '\t' -v g="$GEOMETRY" -v c="$case_id" -v s="$sub" '$1==g && $2==c && $3==s && $4=="2"{print $5}' "$EVIDENCE/status.tsv")"
    [[ -n "$s0" && "$s0" == "$s2" ]] || fail "$GEOMETRY $case_id sub=$sub O0/O2 status drift"

    grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS|FAIL)'       "$EVIDENCE/${GEOMETRY}-${case_id}-s${sub}-o0.txt" > "$BUILD/o0.norm" || true
    grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS|FAIL)'       "$EVIDENCE/${GEOMETRY}-${case_id}-s${sub}-o2.txt" > "$BUILD/o2.norm" || true
    cmp "$BUILD/o0.norm" "$BUILD/o2.norm" || fail "$GEOMETRY $case_id sub=$sub scientific trace drift"
  done
done

python3 "$ANALYZER"   --evidence-dir "$EVIDENCE"   --geometry "$GEOMETRY"   --output "$EVIDENCE/LARE_DYN0A_CRQ_${GEOMETRY^^}.json"

sha256sum "$EVIDENCE"/*.txt "$EVIDENCE"/*.json > "$EVIDENCE/sha256.txt"
git diff --check "$CANONICAL_START"...HEAD
echo "LARE_DYN0A_CRQ_${GEOMETRY^^}=PASS"
