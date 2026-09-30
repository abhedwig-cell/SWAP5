#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic68-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC68_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic55.py select --artifact-dir "$ARTIFACT_DIR" --output "$BUILD/selected.json" > "$BUILD/select.txt"
grep -Fq 'F_PE_ELASTIC55_SELECT=PASS' "$BUILD/select.txt" || fail "selection"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"
grep -Fq 'F_PE_ELASTIC53_MATERIALIZE=PASS' "$BUILD/indicator.txt" || fail "indicator"

python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
for x in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(x["profile_id"]))
PY

: > "$BUILD/all_results.txt"
while read -r pid; do
  P="$BUILD/p$pid"
  mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic55.py profile     --repo-root "$ROOT" --artifact-dir "$ARTIFACT_DIR" --work-dir "$P/work"     --profile-id "$pid" --fixture "$P/test.f90" --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC55_PROFILE_PREP=PASS' "$P/prepare.txt" || fail "profile prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json" --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT" --stub "$P/stub.f90" --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90 --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic68_profile.py     --profile-id "$pid" --o0 "$P/o0/rom0_test" --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all_results.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all_results.txt" <<'PY'
import sys,math
text=open(sys.argv[1],encoding="utf-8").read().splitlines()
rows=[]
for line in text:
    if not line.startswith("ELASTIC68_ARM_PROFILE|"): continue
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=20:
    raise SystemExit(f"F_PE_ELASTIC68_FAIL arm-profile rows={len(rows)}")

budgets=sorted({float(r["budget"]) for r in rows})
agg={}
for b in budgets:
    rr=[r for r in rows if math.isclose(float(r["budget"]),b,rel_tol=0,abs_tol=1e-15)]
    if len(rr)!=4: raise SystemExit("F_PE_ELASTIC68_FAIL profile count")
    agg[b]={
      "accepted":sum(int(r["accepted"]) for r in rr),
      "exhausted":sum(int(r["exhausted"]) for r in rr),
      "rejections":sum(int(r["rejections"]) for r in rr),
      "work":sum(int(r["work"]) for r in rr),
      "paired":sum(int(r["paired"]) for r in rr),
      "head_max":max(float(r["head_max"]) for r in rr),
      "theta_max":max(float(r["theta_max"]) for r in rr),
      "head_fail":sum(int(r["head_fail"]) for r in rr),
      "theta_fail":sum(int(r["theta_fail"]) for r in rr),
      "off":sum(int(r["off"]) for r in rr),
      "fixed":sum(int(r["fixed"]) for r in rr),
      "generated":sum(int(r["generated"]) for r in rr),
    }

base=agg[0.01]
feasible=[]
for b in budgets:
    a=agg[b]
    regime_equal=(a["off"]==a["fixed"]==a["generated"])
    ok=(a["accepted"]>=base["accepted"] and a["head_fail"]==0 and a["theta_fail"]==0 and regime_equal)
    if ok: feasible.append(b)
    print("ELASTIC68_ARM|budget=%.17g|accepted=%d|exhausted=%d|rejections=%d|work=%d|paired=%d|head_max=%.17e|theta_max=%.17e|head_fail=%d|theta_fail=%d|regime_equal=%s|feasible=%s" %
          (b,a["accepted"],a["exhausted"],a["rejections"],a["work"],a["paired"],a["head_max"],a["theta_max"],
           a["head_fail"],a["theta_fail"],"T" if regime_equal else "F","T" if ok else "F"))
if not feasible:
    print("ELASTIC68_SELECTION=NONE")
    print("F_PE_ELASTIC68_RUN=PASS")
    raise SystemExit(0)

maxacc=max(agg[b]["accepted"] for b in feasible)
stage=[b for b in feasible if agg[b]["accepted"]==maxacc]
minrej=min(agg[b]["rejections"] for b in stage)
near=[b for b in stage if agg[b]["rejections"] <= max(minrej, int(math.ceil(1.05*minrej)))]
selected=min(near)
print("ELASTIC68_SELECTION|budget=%.17g|max_accepted=%d|min_rejections=%d|selected_rejections=%d|selected_work=%d" %
      (selected,maxacc,minrej,agg[selected]["rejections"],agg[selected]["work"]))
print("F_PE_ELASTIC68_A1_BANK=PASS")
print("F_PE_ELASTIC68_A2_O0_O2=PASS")
print("F_PE_ELASTIC68_A3_SCREEN=PASS")
print("F_PE_ELASTIC68_RUN=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
prod=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD","--","src"],text=True).splitlines() if p]
if prod:
    raise SystemExit("F_PE_ELASTIC68_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC68_A4_SOURCE_SCOPE=PASS")
PY
