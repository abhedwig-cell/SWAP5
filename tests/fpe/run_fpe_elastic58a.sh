#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic58a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC58A_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic58.py select   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/selected.json" > "$BUILD/select.txt"
grep -Fq 'F_PE_ELASTIC58_SELECT=PASS' "$BUILD/select.txt" || fail "selection"

python3 - "$BUILD/selected.json" <<'PY'
import json,sys
ids=[int(x["profile_id"]) for x in json.load(open(sys.argv[1],encoding="utf-8"))]
expected=[11020,8120,4015,3011]
if ids!=expected:
    raise SystemExit(f"F_PE_ELASTIC58A_FAIL profile replay ids={ids}")
print("F_PE_ELASTIC58A_A1_PROFILE_REPLAY=PASS")
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
  python3 tests/fpe/prepare_fpe_elastic55.py profile     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/selector.f90"     --geometry-json "$P/geometry.json" > "$P/prepare_selector.txt"
  grep -Fq 'F_PE_ELASTIC55_PROFILE_PREP=PASS' "$P/prepare_selector.txt" || fail "selector prepare $pid"

  python3 tests/fpe/prepare_fpe_elastic58.py oracle     --selector-fixture "$P/selector.f90"     --oracle-fixture "$P/oracle.f90" > "$P/prepare_oracle.txt"
  grep -Fq 'F_PE_ELASTIC58_ORACLE_PREP=PASS' "$P/prepare_oracle.txt" || fail "oracle prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    SOUT="$P/selector_o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/selector.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$SOUT" --opt "$opt"

    OOUT="$P/oracle_o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/oracle.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OOUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic58a_profile.py     --profile-id "$pid"     --selector-o0 "$P/selector_o0/rom0_test"     --selector-o2 "$P/selector_o2/rom0_test"     --oracle-o0 "$P/oracle_o0/rom0_test"     --oracle-o2 "$P/oracle_o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all_results.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all_results.txt" <<'PY'
import sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
summ=[x for x in lines if x.startswith("ELASTIC58A_PROFILE_SUMMARY|")]
if len(summ)!=4: raise SystemExit(f"F_PE_ELASTIC58A_FAIL summaries={len(summ)}")
tot={"accepted":0,"complete":0,"first_substep":0,"late_chain":0}
for line in summ:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1);d[k]=v
    for k in tot: tot[k]+=int(d[k])
if tot["accepted"]!=97:
    raise SystemExit(f"F_PE_ELASTIC58A_FAIL accepted replay={tot['accepted']} expected=97")
if tot["complete"]+tot["first_substep"]+tot["late_chain"]!=97:
    raise SystemExit("F_PE_ELASTIC58A_FAIL classification coverage")
print("ELASTIC58A_TOTAL|"+("|".join(f"{k}={v}" for k,v in tot.items())))
print("F_PE_ELASTIC58A_A1_ACCEPTED_REPLAY=PASS")
print("F_PE_ELASTIC58A_A2_CLASSIFICATION=PASS")
print("F_PE_ELASTIC58A_A3_O0_O2=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC58A_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC58A_A5_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC58A_RUN=PASS"
