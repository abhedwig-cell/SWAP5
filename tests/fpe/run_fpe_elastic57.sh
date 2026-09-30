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
python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
x=json.load(open(sys.argv[1],encoding="utf-8"))
ids=[int(v["profile_id"]) for v in x]
if ids != [11060,10260,8016,3030]:
    raise SystemExit(f"F_PE_ELASTIC57_FAIL selection={ids}")
for pid in ids: print(pid)
PY
echo "F_PE_ELASTIC57_A1_SELECTION=PASS"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"

: > "$BUILD/all.txt"
while read -r pid; do
  P="$BUILD/p$pid"; mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic55.py profile     --repo-root "$ROOT" --artifact-dir "$ARTIFACT_DIR" --work-dir "$P/work"     --profile-id "$pid" --fixture "$P/test.f90" --geometry-json "$P/geometry.json" > "$P/prepare.txt"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json" --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT" --stub "$P/stub.f90" --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic57_profile.py     --profile-id "$pid" --o0 "$P/o0/rom0_test" --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all.txt" <<'PY'
import sys
rows=[x for x in open(sys.argv[1],encoding="utf-8").read().splitlines() if x.startswith("ELASTIC57_PROFILE|")]
if len(rows)!=4: raise SystemExit(f"F_PE_ELASTIC57_FAIL profile rows={len(rows)}")
tot={k:0 for k in ("eligible","violating","budget_tests","accepts","exhausted","paired_accepts")}
for line in rows:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    for k in tot: tot[k]+=int(d[k])
if tot["eligible"]!=170 or tot["violating"]!=15:
    raise SystemExit(f"F_PE_ELASTIC57_FAIL parent replay eligible={tot['eligible']} violating={tot['violating']}")
if tot["budget_tests"] != tot["accepts"]+tot["exhausted"]:
    raise SystemExit("F_PE_ELASTIC57_FAIL controller accounting")
print("ELASTIC57_TOTAL|"+"|".join(f"{k}={v}" for k,v in tot.items()))
print("F_PE_ELASTIC57_A3_CONTROLLER=PASS")
print("F_PE_ELASTIC57_A4_AVAILABILITY=PASS")
print("F_PE_ELASTIC57_A5_ENVELOPE=PASS")
print("F_PE_ELASTIC57_A6_PARENT_VIOLATIONS=PASS")
print("F_PE_ELASTIC57_A7_ALPHA_NO_REFIT=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
prod=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines() if p.startswith("src/")]
if prod: raise SystemExit("F_PE_ELASTIC57_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC57_A8_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC57_RUN=PASS"
