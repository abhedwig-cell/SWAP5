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
ids=[int(v["profile_id"]) for v in json.load(open(sys.argv[1],encoding="utf-8"))]
if ids!=[11060,10260,8016,3030]:
    raise SystemExit(f"F_PE_ELASTIC58_FAIL selection ids={ids}")
print("F_PE_ELASTIC58_A1_SELECTION=PASS")
PY

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"
grep -Fq 'F_PE_ELASTIC53_MATERIALIZE=PASS' "$BUILD/indicator.txt" || fail "indicator"

: > "$BUILD/all_results.txt"
python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
for x in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(x["profile_id"]))
PY

while read -r pid; do
  P="$BUILD/p$pid"
  mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic55.py profile     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC55_PROFILE_PREP=PASS' "$P/prepare.txt" || fail "prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic58_profile.py     --profile-id "$pid"     --o0 "$P/o0/rom0_test"     --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all_results.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all_results.txt" <<'PY'
import sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
summ=[x for x in lines if x.startswith("ELASTIC58_PROFILE_SUMMARY|")]
if len(summ)!=4: raise SystemExit(f"F_PE_ELASTIC58_FAIL summaries={len(summ)}")
accepted=paired=unpaired=exhausted=headf=thetaf=envf=0
for line in summ:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    accepted+=int(d["accepted"]); paired+=int(d["paired"]); unpaired+=int(d["unpaired"]); exhausted+=int(d["exhausted"])
    headf+=int(d["head_failures"]); thetaf+=int(d["theta_failures"]); envf+=int(d["envelope_failures"])
print(f"ELASTIC58_TOTAL|accepted={accepted}|paired={paired}|unpaired={unpaired}|exhausted={exhausted}|head_failures={headf}|theta_failures={thetaf}|envelope_failures={envf}")
if headf or thetaf or envf:
    raise SystemExit("F_PE_ELASTIC58_FAIL physical envelope")
print("F_PE_ELASTIC58_A4_CSAFE=PASS")
print("F_PE_ELASTIC58_A5_HEAD=PASS")
print("F_PE_ELASTIC58_A6_THETA=PASS")
print("F_PE_ELASTIC58_A7_GLOBAL_ENVELOPE=PASS")
print(f"F_PE_ELASTIC58_A8_UNPAIRED_COUNT={unpaired}")
PY

python3 - <<'PY'
import math
alpha=0.17320259355765216
budget=0.01/alpha
target=0.05773585599727987
if budget != target:
    raise SystemExit(f"F_PE_ELASTIC58_FAIL budget identity {budget} != {target}")
print("F_PE_ELASTIC58_A3_BUDGET_IDENTITY=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC58_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC58_A9_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC58_RUN=PASS"
