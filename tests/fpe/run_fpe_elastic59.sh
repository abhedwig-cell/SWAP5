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
grep -Fq 'F_PE_ELASTIC55_SELECT=PASS' "$BUILD/select.txt" || fail "selection"

python3 - "$BUILD/selected.json" <<'PY'
import json,sys
ids=[int(x["profile_id"]) for x in json.load(open(sys.argv[1],encoding="utf-8"))]
if ids != [11060,10260,8016,3030]:
    raise SystemExit(f"F_PE_ELASTIC59_FAIL selection {ids}")
print("F_PE_ELASTIC59_A1_SELECTION=PASS")
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

  python3 tests/fpe/run_fpe_elastic59_profile.py     --profile-id "$pid"     --o0 "$P/o0/rom0_test"     --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all_results.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all_results.txt" <<'PY'
import sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
domains=[]
profiles=[]
for line in lines:
    if line.startswith("ELASTIC59_DOMAIN|"): domains.append(line)
    if line.startswith("ELASTIC59_PROFILE_SUMMARY|"): profiles.append(line)
if len(profiles)!=4:
    raise SystemExit(f"F_PE_ELASTIC59_FAIL profile summaries={len(profiles)}")
sat=[x for x in domains if "|domain=SAT|" in x]
unsat=[x for x in domains if "|domain=UNSAT|" in x]
if len(sat)!=4 or len(unsat)!=4:
    raise SystemExit(f"F_PE_ELASTIC59_FAIL domain summaries sat={len(sat)} unsat={len(unsat)}")
def parse(line):
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    return d
S=[parse(x) for x in sat]; U=[parse(x) for x in unsat]
paired_sat=sum(int(d["paired"]) for d in S)
paired_unsat=sum(int(d["paired"]) for d in U)
two_fail_sat=sum(int(d["two_defect_failures"]) for d in S)
two_fail_unsat=sum(int(d["two_defect_failures"]) for d in U)
amp_sat=max(float(d["binf_over_two_defect_max"]) for d in S)
amp_unsat=max(float(d["binf_over_two_defect_max"]) for d in U)
print(f"ELASTIC59_TOTAL|paired_sat={paired_sat}|paired_unsat={paired_unsat}|two_defect_fail_sat={two_fail_sat}|two_defect_fail_unsat={two_fail_unsat}|max_binf_over_two_defect_sat={amp_sat:.17e}|max_binf_over_two_defect_unsat={amp_unsat:.17e}")
print("F_PE_ELASTIC59_A2_BANK=PASS")
print("F_PE_ELASTIC59_A4_DIRECT_HEAD=PASS")
print("F_PE_ELASTIC59_A5_NO_EXTRA_SOLVE=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC59_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC59_A7_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC59_RUN=PASS"
