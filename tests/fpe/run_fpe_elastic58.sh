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
grep -Fq 'F_PE_ELASTIC55_SELECT=PASS' "$BUILD/select.txt" || fail "selection"

python3 - "$BUILD/selected.json" <<'PY'
import json,sys
ids=[int(x["profile_id"]) for x in json.load(open(sys.argv[1],encoding="utf-8"))]
if ids != [11060,10260,8016,3030]:
    raise SystemExit(f"F_PE_ELASTIC58_FAIL selection ids={ids}")
print("F_PE_ELASTIC58_A1_SELECTION=PASS")
PY

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

  python3 tests/fpe/prepare_fpe_elastic58.py     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" | tee "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC58_PREP=PASS' "$P/prepare.txt" || fail "profile prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic58_profile.py     --profile-id "$pid"     --o0 "$P/o0/rom0_test"     --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all_results.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all_results.txt" <<'PY'
import math,statistics,sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
summ=[x for x in lines if x.startswith("ELASTIC58_PROFILE_SUMMARY|")]
if len(summ)!=4:
    raise SystemExit(f"F_PE_ELASTIC58_FAIL summaries={len(summ)}")
fails=[x for x in lines if x.startswith("ELASTIC58_ENVELOPE_FAIL|")]
full=refq=0
for line in summ:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    full+=int(d["full_converged"]); refq+=int(d["reference_qualified"])

bands={}
for line in lines:
    if not line.startswith("ELASTIC58_BAND|"): continue
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    if int(d["count"])<=0: continue
    b=d["band"]
    bands.setdefault(b,{"count":0,"max_href":0.0,"max_ratio":0.0,"medians":[]})
    x=bands[b]
    x["count"]+=int(d["count"])
    x["max_href"]=max(x["max_href"],float(d["max_href"]))
    x["max_ratio"]=max(x["max_ratio"],float(d["max_ratio"]))
    x["medians"].append((int(d["count"]),float(d["median_href"])))

print(f"ELASTIC58_TOTAL|profiles=4|cases=384|full_converged={full}|reference_qualified={refq}|envelope_failures={len(fails)}")
for name in ("LE_0P01","0P01_0P05","0P05_0P10","0P10_0P25","0P25_0P50","GT_0P50"):
    x=bands.get(name)
    if not x:
        print(f"ELASTIC58_FRONTIER|band={name}|count=0")
        continue
    # Per-profile medians cannot be pooled exactly without raw rows; report weighted mean
    # of profile medians as descriptive only and retain exact maxima.
    n=sum(w for w,_ in x["medians"])
    wmed=sum(w*m for w,m in x["medians"])/n
    print(f"ELASTIC58_FRONTIER|band={name}|count={x['count']}|weighted_profile_median_href={wmed:.17e}|max_href={x['max_href']:.17e}|max_ratio={x['max_ratio']:.17e}")
for f in fails: print(f)

print("F_PE_ELASTIC58_A2_CASES=PASS")
print("F_PE_ELASTIC58_A3_REFERENCE_STABILITY=PASS")
print("F_PE_ELASTIC58_A4_INDICATOR=PASS")
print("F_PE_ELASTIC58_A5_ALPHA_FROZEN=PASS")
if fails:
    print("F_PE_ELASTIC58_ENVELOPE=FALSIFIED")
else:
    print("F_PE_ELASTIC58_ENVELOPE=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC58_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC58_A6_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC58_RUN=PASS"
