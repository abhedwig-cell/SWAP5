#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic60-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC60_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic60.py   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/selected.json" | tee "$BUILD/select.txt"
grep -Fq 'F_PE_ELASTIC60_SELECT=PASS' "$BUILD/select.txt" || fail "selection"

python3 - "$BUILD/selected.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding="utf-8"))
ids=[int(v["profile_id"]) for v in x]
if len(ids)!=4: raise SystemExit("F_PE_ELASTIC60_FAIL selected count")
if any(v in {11060,10260,8016,3030,90116260} for v in ids):
    raise SystemExit(f"F_PE_ELASTIC60_FAIL overlap {ids}")
print("F_PE_ELASTIC60_A1_SELECTION=PASS")
PY

python3 tests/fpe/materialize_fpe_elastic59_indicator.py   --root "$ROOT"   --output "$BUILD/mod_fpe_elastic59_reference_richards_temporal_indicator.f90" > "$BUILD/materialize.txt"
grep -Fq 'F_PE_ELASTIC59_MATERIALIZE=PASS' "$BUILD/materialize.txt" || fail "materialize"

: > "$BUILD/all_results.txt"
python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
for x in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(x["profile_id"]))
PY

while read -r pid; do
  P="$BUILD/p$pid"
  mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic59.py     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC59_PROFILE_PREP=PASS' "$P/prepare.txt" || fail "prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic59_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic60_profile.py     --profile-id "$pid"     --o0 "$P/o0/rom0_test"     --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all_results.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all_results.txt" <<'PY'
import sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
rows=[x for x in lines if x.startswith("ELASTIC60_PROFILE|")]
if len(rows)!=4: raise SystemExit(f"F_PE_ELASTIC60_FAIL profile summaries={len(rows)}")
tot={k:0 for k in ("D1_selected","D1_sat","D1_head_fail","D1_theta_fail","D2_selected","D2_sat","D2_head_fail","D2_theta_fail")}
for line in rows:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    for k in tot: tot[k]+=int(d[k])
print("ELASTIC60_TOTAL|"+("|".join(f"{k}={v}" for k,v in tot.items())))
print("F_PE_ELASTIC60_A2_BANK=PASS")
print("F_PE_ELASTIC60_A4_DIRECT=PASS")
print("F_PE_ELASTIC60_A5_NO_REFIT=PASS")
if tot["D1_head_fail"] or tot["D1_theta_fail"]:
    print("F_PE_ELASTIC60_D1=FALSIFIED")
else:
    print("F_PE_ELASTIC60_D1=PASS")
if tot["D2_head_fail"] or tot["D2_theta_fail"]:
    print("F_PE_ELASTIC60_D2=FALSIFIED")
else:
    print("F_PE_ELASTIC60_D2=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod: raise SystemExit("F_PE_ELASTIC60_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC60_A8_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC60_RUN=PASS"
