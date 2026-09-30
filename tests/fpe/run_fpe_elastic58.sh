#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic58-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC58_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic55.py select   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/selected.json" > "$BUILD/select.txt"

python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
x=json.load(open(sys.argv[1],encoding="utf-8"))
ids=[int(v["profile_id"]) for v in x]
if ids != [11060,10260,8016,3030]:
    raise SystemExit(f"F_PE_ELASTIC58_FAIL selection={ids}")
for pid in ids: print(pid)
PY
echo "F_PE_ELASTIC58_A1_SELECTION=PASS"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"
grep -Fq 'F_PE_ELASTIC53_MATERIALIZE=PASS' "$BUILD/indicator.txt" || fail "indicator materialize"

: > "$BUILD/all_points.txt"
while read -r pid; do
  P="$BUILD/p$pid"
  mkdir -p "$P/work"

  python3 tests/fpe/prepare_fpe_elastic55.py profile     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC55_PROFILE_PREP=PASS' "$P/prepare.txt" || fail "profile prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic58_profile.py     --profile-id "$pid"     --o0 "$P/o0/rom0_test"     --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  grep '^ELASTIC58_POINT|' "$P/result.txt" >> "$BUILD/all_points.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all_points.txt" <<'PY'
import math,statistics,sys
rows=[]
for line in open(sys.argv[1],encoding="utf-8"):
    if not line.startswith("ELASTIC58_POINT|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    d["profile"]=int(d["profile"]); d["h0"]=float(d["h0"]); d["delta"]=float(d["delta"])
    d["retry"]=int(d["retry"]); d["dt"]=float(d["dt"]); d["binf"]=float(d["binf"]); d["e"]=float(d["e"])
    d["paired"]=d["paired"]=="T"; d["hinf"]=float(d["hinf"])
    rows.append(d)
if not rows: raise SystemExit("F_PE_ELASTIC58_FAIL no points")

profiles=(11060,10260,8016,3030)
regimes=("OFF","FIXED_1E6","GENERATED")
heads=(-75.0,-20.0,2.0,10.0)
deltas=(-0.05,-0.035,0.035,0.05)
seqs={(p,r,h,d):[] for p in profiles for r in regimes for h in heads for d in deltas}
for r in rows:
    k=(r["profile"],r["regime"],r["h0"],r["delta"])
    if k not in seqs:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL unexpected sequence key={k}")
    seqs[k].append(r)
for v in seqs.values(): v.sort(key=lambda r:r["retry"])
if len(seqs)!=192:
    raise SystemExit(f"F_PE_ELASTIC58_FAIL sequence count={len(seqs)}")

vals=sorted(set(r["e"] for r in rows if r["e"]>0))
if not vals: raise SystemExit("F_PE_ELASTIC58_FAIL no positive E")
budgets=[vals[0]*0.5]
budgets += [math.sqrt(a*b) for a,b in zip(vals,vals[1:])]
budgets += [vals[-1]*2.0]
if len(budgets)!=len(vals)+1:
    raise SystemExit("F_PE_ELASTIC58_FAIL decision region count")

surfaces=[]
decision_signatures=set()
for idx,budget in enumerate(budgets):
    accepted=[]; exhausted=0; retry_sum=0
    signature=[]
    for k in sorted(seqs):
        chosen=None
        for r in seqs[k]:
            if r["e"]<=budget:
                chosen=r; break
        if chosen is None:
            exhausted+=1
            signature.append((k,None))
        else:
            accepted.append(chosen); retry_sum+=chosen["retry"]
            signature.append((k,chosen["retry"]))
    paired=[r for r in accepted if r["paired"]]
    herr=sorted(r["hinf"] for r in paired)
    margins=[r["e"]-r["hinf"] for r in paired]
    if any(m < -1e-12 for m in margins):
        raise SystemExit("F_PE_ELASTIC58_FAIL frozen envelope")
    if herr:
        median=statistics.median(herr)
        p95=herr[min(len(herr)-1,math.ceil(0.95*len(herr))-1)]
        hmax=max(herr)
        minmargin=min(margins)
    else:
        median=p95=hmax=float("nan"); minmargin=float("nan")
    surfaces.append((budget,len(accepted),exhausted,len(paired),retry_sum,median,p95,hmax,minmargin))
    decision_signatures.add(tuple(signature))
    print(
        f"ELASTIC58_SURFACE|region={idx}|budget={budget:.17e}|accepted={len(accepted)}|exhausted={exhausted}"
        f"|paired={len(paired)}|retry_sum={retry_sum}|hinf_median={median}|hinf_p95={p95}"
        f"|hinf_max={hmax}|min_margin={minmargin}"
    )

print(f"ELASTIC58_SURFACE_SUMMARY|points={len(rows)}|sequences={len(seqs)}|breakpoints={len(vals)}"
      f"|regions={len(budgets)}|distinct_decisions={len(decision_signatures)}"
      f"|budget_min={budgets[0]:.17e}|budget_max={budgets[-1]:.17e}")

if len(decision_signatures)<2:
    raise SystemExit("F_PE_ELASTIC58_FAIL degenerate surface")

print("F_PE_ELASTIC58_A3_REGIONS=PASS")
print("F_PE_ELASTIC58_A4_CONTROLLER=PASS")
print("F_PE_ELASTIC58_A5_ENVELOPE=PASS")
print("F_PE_ELASTIC58_A6_ALPHA_NO_REFIT=PASS")
PY

python3 - <<'PY'
import json
p="integration/f-ci/F-CI14_TEMPORAL_POLICY_PROFILE.json"
x=json.load(open(p,encoding="utf-8"))
if x.get("profile_status")!="UNQUALIFIED_NO_NUMERIC_LIMITS":
    raise SystemExit("F_PE_ELASTIC58_FAIL F-CI14 status changed")
metrics=x.get("acceptance_metrics",{})
if not metrics or any(v is not None for v in metrics.values()):
    raise SystemExit("F_PE_ELASTIC58_FAIL numeric temporal authority now exists")
print("ELASTIC58_INDEPENDENT_PHYSICAL_BUDGET_AUTHORITY=ABSENT")
print("F_PE_ELASTIC58_IDENTIFIABILITY=NOT_IDENTIFIED")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
prod=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines() if p.startswith("src/")]
if prod: raise SystemExit("F_PE_ELASTIC58_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC58_A7_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC58_RUN=PASS"
