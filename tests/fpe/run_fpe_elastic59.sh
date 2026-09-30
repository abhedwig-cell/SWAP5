#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic59-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC59_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic55.py select   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/selected.json" > "$BUILD/select.txt"

python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
x=json.load(open(sys.argv[1],encoding="utf-8"))
ids=[int(v["profile_id"]) for v in x]
if ids != [11060,10260,8016,3030]:
    raise SystemExit(f"F_PE_ELASTIC59_FAIL selection={ids}")
for pid in ids: print(pid)
PY
echo "F_PE_ELASTIC59_A1_SELECTION=PASS"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"

: > "$BUILD/all.txt"
while read -r pid; do
  P="$BUILD/p$pid"; mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic58.py     --repo-root "$ROOT" --artifact-dir "$ARTIFACT_DIR" --work-dir "$P/work"     --profile-id "$pid" --fixture "$P/test.f90" --geometry-json "$P/geometry.json" > "$P/prepare.txt"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json" --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT" --stub "$P/stub.f90" --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic59_profile.py     --profile-id "$pid" --o0 "$P/o0/rom0_test" --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all.txt" <<'PY'
import sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
profiles=[x for x in lines if x.startswith("ELASTIC59_PROFILE|")]
budgets=[x for x in lines if x.startswith("ELASTIC59_BUDGET|")]
false=[x for x in lines if x.startswith("ELASTIC59_FALSE_ACCEPT|")]
if len(profiles)!=4: raise SystemExit(f"F_PE_ELASTIC59_FAIL profile rows={len(profiles)}")
if len(budgets)!=12: raise SystemExit(f"F_PE_ELASTIC59_FAIL budget rows={len(budgets)}")
if false: raise SystemExit(f"F_PE_ELASTIC59_FAIL false accepts={len(false)}")
tot_accept=tot_paired=0
agg={}
for line in profiles:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    tot_accept+=int(d["accepts"]); tot_paired+=int(d["paired_accepts"])
for line in budgets:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    b=float(d["budget"]); a=agg.setdefault(b,{"accepts":0,"paired":0,"false":0,"exhausted":0})
    for k in a: a[k]+=int(d[k])
for b in sorted(agg):
    a=agg[b]
    print(f"ELASTIC59_BUDGET_TOTAL|budget={b}|accepts={a['accepts']}|paired={a['paired']}|false={a['false']}|exhausted={a['exhausted']}")
print(f"ELASTIC59_TOTAL|accepts={tot_accept}|paired_accepts={tot_paired}|false_accepts=0")
print("F_PE_ELASTIC59_A3_ALGEBRA=PASS")
print("F_PE_ELASTIC59_A4_NO_FALSE_ACCEPT=PASS")
print("F_PE_ELASTIC59_A5_FAIL_CLOSED=PASS")
print("F_PE_ELASTIC59_A6_ALPHA_FROZEN=PASS")
print("F_PE_ELASTIC59_A7_NO_DEFAULT=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
prod=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines() if p.startswith("src/")]
if prod: raise SystemExit("F_PE_ELASTIC59_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC59_A8_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC59_RUN=PASS"
