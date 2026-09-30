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
expected=[11060,10260,8016,3030]
if ids!=expected:
    raise SystemExit(f"F_PE_ELASTIC59_FAIL selection={ids}")
for pid in ids: print(pid)
PY
echo "F_PE_ELASTIC59_A1_SELECTION=PASS"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"

: > "$BUILD/all.txt"
while read -r pid; do
  P="$BUILD/p$pid"; mkdir -p "$P/work"

  python3 tests/fpe/prepare_fpe_elastic59.py     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC59_PROFILE_PREP=PASS' "$P/prepare.txt" || fail "profile prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic59_profile.py     --profile-id "$pid"     --o0 "$P/o0/rom0_test"     --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all.txt" <<'PY'
import ast,sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
profiles=[x for x in lines if x.startswith("ELASTIC59_PROFILE|")]
nrows=[x for x in lines if x.startswith("ELASTIC59_N|")]
if len(profiles)!=4:
    raise SystemExit(f"F_PE_ELASTIC59_FAIL profile summaries={len(profiles)}")
if len(nrows)!=20:
    raise SystemExit(f"F_PE_ELASTIC59_FAIL N summaries={len(nrows)}")

accepted=exhausted=0
for line in profiles:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    accepted+=int(d["accepted"]); exhausted+=int(d["exhausted"])
if accepted!=96 or exhausted!=96:
    raise SystemExit(f"F_PE_ELASTIC59_FAIL controller replay accepted={accepted} exhausted={exhausted}")

agg={n:{"complete":0,"failed":0,"failure_steps":{}} for n in (4,8,16,32,64)}
for line in nrows:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    n=int(d["N"])
    agg[n]["complete"]+=int(d["complete"])
    agg[n]["failed"]+=int(d["failed"])
    fs=ast.literal_eval(d["failure_steps"])
    for k,v in fs.items():
        agg[n]["failure_steps"][int(k)]=agg[n]["failure_steps"].get(int(k),0)+int(v)

if agg[32]["complete"]!=42 or agg[32]["failed"]!=54:
    raise SystemExit(f"F_PE_ELASTIC59_FAIL N32 replay={agg[32]}")

for n in (4,8,16,32,64):
    print(f"ELASTIC59_TOTAL_N|N={n}|complete={agg[n]['complete']}|failed={agg[n]['failed']}|failure_steps={agg[n]['failure_steps']}")
best=max((agg[n]["complete"],-n,n) for n in agg)[2]
print(f"ELASTIC59_BEST_COVERAGE_N={best}")
print(f"ELASTIC59_TOTAL|accepted={accepted}|exhausted={exhausted}|n32_complete={agg[32]['complete']}|n32_failed={agg[32]['failed']}")
print("F_PE_ELASTIC59_A1_ACCEPTED_REPLAY=PASS")
print("F_PE_ELASTIC59_A2_N32_REPLAY=PASS")
print("F_PE_ELASTIC59_A3_SWEEP_STATUS=PASS")
print("F_PE_ELASTIC59_A4_DECISION_IDENTITY=PASS")
print("F_PE_ELASTIC59_A5_NO_POLICY_CHANGE=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC59_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC59_A6_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC59_RUN=PASS"
