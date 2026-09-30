#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic63-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC63_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic55.py select   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/selected.json" > "$BUILD/select.txt"
grep -Fq 'F_PE_ELASTIC55_SELECT=PASS' "$BUILD/select.txt" || fail "selection"

python3 - "$BUILD/selected.json" <<'PY'
import json,sys
ids=[int(v["profile_id"]) for v in json.load(open(sys.argv[1],encoding="utf-8"))]
if ids!=[11060,10260,8016,3030]:
    raise SystemExit(f"F_PE_ELASTIC63_FAIL selection ids={ids}")
print("F_PE_ELASTIC63_A1_SELECTION=PASS")
PY

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"
grep -Fq 'F_PE_ELASTIC53_MATERIALIZE=PASS' "$BUILD/indicator.txt" || fail "indicator materialize"

: > "$BUILD/all_diag.txt"
python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
for x in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(x["profile_id"]))
PY

while read -r pid; do
  P="$BUILD/p$pid"
  mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic63.py     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC63_PREP=PASS' "$P/prepare.txt" || fail "profile prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
    : > "$OUT/result.txt"
    for h0 in -75 -20 2 10; do
      for delta in -0.05 -0.035 0.035 0.05; do
        for regime in OFF FIXED_1E6 GENERATED; do
          dt=0.015625
          for retry in 0 1 2 3 4 5 6 7 8; do
            "$OUT/rom0_test" "$regime" "$h0" "$delta" "$dt" >> "$OUT/result.txt"
            dt="$(python3 -c "print(float('$dt')*0.5)")"
          done
        done
      done
    done
    test "$(grep -c '^ELASTIC63_SOLVE|' "$OUT/result.txt")" -eq 864 || fail "O$opt solve count profile $pid"
    test "$(grep -c '^F_PE_ELASTIC63_EXEC=PASS' "$OUT/result.txt")" -eq 432 || fail "O$opt case count profile $pid"
  done

  cmp -s "$P/o0/result.txt" "$P/o2/result.txt" || {
    diff -u "$P/o0/result.txt" "$P/o2/result.txt" >&2 || true
    fail "O0/O2 drift profile $pid"
  }
  grep '^ELASTIC63_SOLVE|' "$P/o2/result.txt" >> "$BUILD/all_diag.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all_diag.txt" <<'PY'
import math,sys,collections
rows=[]
for line in open(sys.argv[1],encoding="utf-8"):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    rows.append(d)
if len(rows)!=3456:
    raise SystemExit(f"F_PE_ELASTIC63_FAIL diagnostic rows={len(rows)}")

classes=collections.Counter()
stats={agg:collections.defaultdict(lambda:{"n":0,"covered":0,"max":0.0}) for agg in ("MAX","RSS","SUM")}
baltol_retry_resolved=0
baltol_retries=0

def classify(r):
    status=int(r["status"])
    local=float(r["max_local_residual"]); total=float(r["abs_total_residual"])
    if status==1: return "STRICT_SUCCESS"
    if status==2:
        if local>1e-12: return "LOCAL_ABOVE_STRICT"
        if local<=1e-12 and total>1e-12: return "TOTAL_ONLY_STRICT"
        return "OTHER_RETRY"
    return "OTHER_STATUS"

for r in rows:
    vals=[float(r[k]) for k in ("max_local_residual","abs_total_residual","floor_max","floor_rss","floor_sum","baltol_rate")]
    if not all(math.isfinite(x) and x>=0 for x in vals):
        raise SystemExit("F_PE_ELASTIC63_FAIL nonfinite diagnostic")
    cls=classify(r); classes[cls]+=1
    total=float(r["abs_total_residual"])
    floors={"MAX":float(r["floor_max"]),"RSS":float(r["floor_rss"]),"SUM":float(r["floor_sum"])}
    for agg,f in floors.items():
        ratio=total/f if f>0 else (0.0 if total==0 else math.inf)
        q=stats[agg][cls]; q["n"]+=1; q["covered"]+=int(ratio<=1+1e-12); q["max"]=max(q["max"],ratio)
    if int(r["status"])==2:
        baltol_retries+=1
        rate=float(r["baltol_rate"])
        if float(r["max_local_residual"])<=rate and total<=rate:
            baltol_retry_resolved+=1

# Exact ELASTIC62 reproduction.
parent=[]
for r in rows:
    if int(r["profile"])!=8016 or r["stage"]!="HALF1" or float(r["h0"])!=-20.0: continue
    if float(r["dt"])!=0.00048828125: continue
    if float(r["delta"]) not in (0.035,0.05): continue
    if r["regime"] not in ("OFF","FIXED_1E6","GENERATED"): continue
    rl=float(r["max_local_residual"])/float(r["floor_max"])
    rt=float(r["abs_total_residual"])/float(r["floor_sum"])
    parent.append((float(r["delta"]),rl,rt))
if len(parent)!=6:
    raise SystemExit(f"F_PE_ELASTIC63_FAIL ELASTIC62 replay count={len(parent)}")
for d,rl,rt in parent:
    erl=0.92138671875 if d==0.035 else 0.919921875
    ert=0.305615234375 if d==0.035 else 0.07745768229166669
    if abs(rl-erl)>1e-12 or abs(rt-ert)>1e-12:
        raise SystemExit(f"F_PE_ELASTIC63_FAIL parent ratio drift d={d} rl={rl} rt={rt}")

print("ELASTIC63_CLASS_COUNTS|"+("|".join(f"{k}={v}" for k,v in sorted(classes.items()))))
for agg in ("MAX","RSS","SUM"):
    for cls in ("STRICT_SUCCESS","TOTAL_ONLY_STRICT","LOCAL_ABOVE_STRICT","OTHER_RETRY","OTHER_STATUS"):
        q=stats[agg].get(cls)
        if not q or q["n"]==0: continue
        print(f"ELASTIC63_AGG|agg={agg}|class={cls}|n={q['n']}|covered={q['covered']}|fraction={q['covered']/q['n']:.17e}|max_ratio={q['max']:.17e}")
print(f"ELASTIC63_BALTOL02_DIAG|retry_states={baltol_retries}|residual_snapshots_within_effective_rate={baltol_retry_resolved}")
print("F_PE_ELASTIC63_A2_CASES=PASS")
print("F_PE_ELASTIC63_A3_O0_O2=PASS")
print("F_PE_ELASTIC63_A4_FINITE=PASS")
print("F_PE_ELASTIC63_A5_ELASTIC62_REPLAY=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC63_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC63_A6_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC63_RUN=PASS"
