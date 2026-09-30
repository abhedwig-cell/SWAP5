#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic55-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC55_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic55.py select   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/selected.json" | tee "$BUILD/select.txt"
grep -Fq 'F_PE_ELASTIC55_SELECT=PASS' "$BUILD/select.txt" || fail "selection"
python3 - "$BUILD/selected.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding="utf-8"))
if len(x)!=4: raise SystemExit("F_PE_ELASTIC55_FAIL selected count")
print("F_PE_ELASTIC55_A1_SELECTION=PASS")
PY

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"
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
  python3 tests/fpe/prepare_fpe_elastic55.py profile     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" | tee "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC55_PROFILE_PREP=PASS' "$P/prepare.txt" || fail "profile prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic55_profile.py     --profile-id "$pid"     --o0 "$P/o0/rom0_test"     --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all_results.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/selected.json" "$BUILD/all_results.txt" <<'PY'
import json,re,sys
selected=json.load(open(sys.argv[1],encoding="utf-8"))
text=open(sys.argv[2],encoding="utf-8").read()
summaries=[x for x in text.splitlines() if x.startswith("ELASTIC55_PROFILE_SUMMARY|")]
if len(summaries)!=4:
    raise SystemExit(f"F_PE_ELASTIC55_FAIL profile summaries={len(summaries)}")
failures=[x for x in text.splitlines() if x.startswith("ELASTIC55_ENVELOPE_FAIL|")]
pairs=0; full=0; mseq=0; mbad=0; maxratio=0.0
for line in summaries:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    pairs+=int(d["paired"]); full+=int(d["full_converged"])
    mseq+=int(d["monotonic_sequences"]); mbad+=int(d["monotonic_violations"])
    maxratio=max(maxratio,float(d["max_ratio"]))
print(f"ELASTIC55_TOTAL|profiles=4|full_converged={full}|paired={pairs}|envelope_failures={len(failures)}|max_ratio={maxratio:.17e}|monotonic_sequences={mseq}|monotonic_violations={mbad}")
for f in failures: print(f)
print("F_PE_ELASTIC55_A3_CASES=PASS")
print("F_PE_ELASTIC55_A4_O0_O2=PASS")
print("F_PE_ELASTIC55_A5_INDICATOR=PASS")
print("F_PE_ELASTIC55_A6_PAIRED_ONLY=PASS")
print("F_PE_ELASTIC55_A7_ALPHA_FROZEN=PASS")
if failures:
    print("F_PE_ELASTIC55_ENVELOPE=FALSIFIED")
else:
    print("F_PE_ELASTIC55_ENVELOPE=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC55_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC55_A8_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC55_RUN=PASS"
