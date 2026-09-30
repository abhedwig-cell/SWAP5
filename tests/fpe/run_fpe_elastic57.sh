#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic57-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC57_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic55.py select   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/selected.json" > "$BUILD/select.txt"

python3 - "$BUILD/selected.json" <<'PY'
import json,sys
ids=[int(x["profile_id"]) for x in json.load(open(sys.argv[1],encoding="utf-8"))]
if ids != [11060,10260,8016,3030]:
    raise SystemExit(f"F_PE_ELASTIC57_FAIL ids={ids}")
print("F_PE_ELASTIC57_A1_PROFILES=PASS")
PY

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"

: > "$BUILD/all.txt"
python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
for x in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(x["profile_id"]))
PY

while read -r pid; do
  P="$BUILD/p$pid"; mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic55.py profile     --repo-root "$ROOT" --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work" --profile-id "$pid"     --fixture "$P/test.f90" --geometry-json "$P/geometry.json" > "$P/prepare.txt"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json" --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT" --stub "$P/stub.f90" --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic57_profile.py     --profile-id "$pid" --o0 "$P/o0/rom0_test" --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all.txt" <<'PY'
import math,sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
summ=[x for x in lines if x.startswith("ELASTIC57_PROFILE_SUMMARY|")]
if len(summ)!=4: raise SystemExit(f"F_PE_ELASTIC57_FAIL summaries={len(summ)}")
accepts=exhausted=false_accepts=nonmono=0
for line in summ:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    accepts+=int(d["accepts"]); exhausted+=int(d["exhausted"])
    false_accepts+=int(d["false_accepts"]); nonmono+=int(d["nonmonotone_sequences"])
if false_accepts: raise SystemExit("F_PE_ELASTIC57_FAIL aggregate false acceptance")
print(f"ELASTIC57_TOTAL|profiles=4|accepts={accepts}|exhausted={exhausted}|false_accepts={false_accepts}|nonmonotone_sequences={nonmono}")
print("F_PE_ELASTIC57_A3_ALPHA_FROZEN=PASS")
print("F_PE_ELASTIC57_A4_THRESHOLD_ONLY=PASS")
print("F_PE_ELASTIC57_A6_STRICT_HALVING=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod: raise SystemExit("F_PE_ELASTIC57_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC57_A7_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC57_RUN=PASS"
