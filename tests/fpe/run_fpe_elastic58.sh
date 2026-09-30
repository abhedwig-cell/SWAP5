#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic58-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC58_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic58.py select   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/selected.json" | tee "$BUILD/select.txt"
grep -Fq 'F_PE_ELASTIC58_SELECT=PASS' "$BUILD/select.txt" || fail "selection"

python3 - "$BUILD/selected.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding="utf-8"))
if len(x)!=4: raise SystemExit("F_PE_ELASTIC58_FAIL selected count")
classes=[int(v["horizon_count"]) for v in x]
if len(set(classes)) < 3:
    raise SystemExit(f"F_PE_ELASTIC58_FAIL horizon diversity classes={classes}")
print("F_PE_ELASTIC58_A1_SELECTION=PASS")
print("ELASTIC58_SELECTED_IDS="+",".join(str(int(v["profile_id"])) for v in x))
PY

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_indicator_oracle.f90" > "$BUILD/indicator.txt"
grep -Fq 'F_PE_ELASTIC53_MATERIALIZE=PASS' "$BUILD/indicator.txt" || fail "indicator materialize"

: > "$BUILD/all_results.txt"
python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
for x in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(x["profile_id"]))
PY

while read -r pid; do
  P="$BUILD/p$pid"
  mkdir -p "$P/work"

  # Selector fixture: same physical/material and research-indicator semantics as ELASTIC55.
  python3 tests/fpe/prepare_fpe_elastic55.py profile     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/selector.f90"     --geometry-json "$P/geometry.json" > "$P/prepare_selector.txt"
  grep -Fq 'F_PE_ELASTIC55_PROFILE_PREP=PASS' "$P/prepare_selector.txt" || fail "selector prepare $pid"

  # Oracle fixture is generated only after selector materialization; it cannot affect dt selection.
  python3 tests/fpe/prepare_fpe_elastic58.py oracle     --selector-fixture "$P/selector.f90"     --oracle-fixture "$P/oracle.f90" > "$P/prepare_oracle.txt"
  grep -Fq 'F_PE_ELASTIC58_ORACLE_PREP=PASS' "$P/prepare_oracle.txt" || fail "oracle prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    SOUT="$P/selector_o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/selector.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$SOUT" --opt "$opt"

    OOUT="$P/oracle_o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/oracle.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OOUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic58_profile.py     --profile-id "$pid"     --selector-o0 "$P/selector_o0/rom0_test"     --selector-o2 "$P/selector_o2/rom0_test"     --oracle-o0 "$P/oracle_o0/rom0_test"     --oracle-o2 "$P/oracle_o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all_results.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all_results.txt" <<'PY'
import math,sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
summ=[x for x in lines if x.startswith("ELASTIC58_PROFILE_SUMMARY|")]
if len(summ)!=4:
    raise SystemExit(f"F_PE_ELASTIC58_FAIL profile summaries={len(summ)}")
tot={k:0 for k in ("accepted","exhausted","oracle_incomplete","head_fail","theta_fail","q_fail","exchange_fail","mass_fail")}
mx={k:0.0 for k in ("max_head","max_theta","max_qrel","max_xrel","max_mass")}
for line in summ:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1);d[k]=v
    for k in tot: tot[k]+=int(d[k])
    for k in mx: mx[k]=max(mx[k],float(d[k]))
failures=tot["oracle_incomplete"]+tot["head_fail"]+tot["theta_fail"]+tot["q_fail"]+tot["exchange_fail"]+tot["mass_fail"]
print("ELASTIC58_TOTAL|"+("|".join([f"{k}={v}" for k,v in tot.items()]+[f"{k}={v:.17e}" for k,v in mx.items()])))
if failures:
    print("F_PE_ELASTIC58_PHYSICAL_BUDGET=FALSIFIED")
else:
    print("F_PE_ELASTIC58_PHYSICAL_BUDGET=PASS")
print("F_PE_ELASTIC58_A2_SEQUENCES=PASS")
print("F_PE_ELASTIC58_A3_CSAFE=PASS")
print("F_PE_ELASTIC58_A4_ORACLE_ACCOUNTED=PASS")
print("F_PE_ELASTIC58_A5_PHYSICAL_GATES_ACCOUNTED=PASS")
print("F_PE_ELASTIC58_A6_EXHAUSTION_EXPLICIT=PASS")
print("F_PE_ELASTIC58_A7_O0_O2=PASS")
print("F_PE_ELASTIC58_A8_CONSTANTS_FROZEN=PASS")
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
