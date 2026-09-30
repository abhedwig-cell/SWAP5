#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic61-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC61_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic55.py select   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/selected.json" > "$BUILD/select.txt"

python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
x=json.load(open(sys.argv[1],encoding="utf-8"))
ids=[int(v["profile_id"]) for v in x]
expected=[11060,10260,8016,3030]
if ids!=expected:
    raise SystemExit(f"F_PE_ELASTIC61_FAIL selection={ids}")
for pid in ids: print(pid)
PY
echo "F_PE_ELASTIC61_A1_SELECTION=PASS"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"

: > "$BUILD/all.txt"
while read -r pid; do
  P="$BUILD/p$pid"; mkdir -p "$P/work"

  python3 tests/fpe/prepare_fpe_elastic60.py     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC60_PROFILE_PREP=PASS' "$P/prepare.txt" || fail "profile prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic61_profile.py     --profile-id "$pid"     --o0 "$P/o0/rom0_test"     --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all.txt" <<'PY'
import sys
rows=[x for x in open(sys.argv[1],encoding="utf-8").read().splitlines() if x.startswith("ELASTIC61_PROFILE|")]
if len(rows)!=4: raise SystemExit(f"F_PE_ELASTIC61_FAIL profile rows={len(rows)}")
keys=("accepted","exhausted","parent_triple","parent_unavailable","validation","validation_tail_fail",
      "validation_physical_fail","residual","residual_pair","residual_no_pair",
      "residual_physical_pass","residual_physical_fail")
tot={k:0 for k in keys}
for line in rows:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    for k in keys: tot[k]+=int(d[k])

if tot["accepted"]!=96 or tot["exhausted"]!=96:
    raise SystemExit(f"F_PE_ELASTIC61_FAIL controller replay={tot}")
if tot["parent_triple"]!=60 or tot["parent_unavailable"]!=36:
    raise SystemExit(f"F_PE_ELASTIC61_FAIL parent adaptive replay={tot}")
if tot["validation"]!=60:
    raise SystemExit(f"F_PE_ELASTIC61_FAIL validation count={tot['validation']}")

print("ELASTIC61_TOTAL|"+("|".join(f"{k}={v}" for k,v in tot.items())))
print("F_PE_ELASTIC61_A1_PARENT_REPLAY=PASS")
print("F_PE_ELASTIC61_A2_FACTOR_FROZEN=PASS")

if tot["validation_tail_fail"]==0 and tot["validation_physical_fail"]==0:
    print("F_PE_ELASTIC61_A3_VALIDATION=PASS")
    print("F_PE_ELASTIC61_RESIDUAL_APPLICATION=AUTHORIZED_BY_VALIDATION")
    if tot["residual_physical_fail"]==0:
        print("F_PE_ELASTIC61_PHYSICAL=PASS")
    else:
        print(f"F_PE_ELASTIC61_PHYSICAL=FALSIFIED|residual_failures={tot['residual_physical_fail']}")
else:
    print(f"F_PE_ELASTIC61_A3_VALIDATION=FALSIFIED|tail_fail={tot['validation_tail_fail']}|physical_fail={tot['validation_physical_fail']}")
    print("F_PE_ELASTIC61_RESIDUAL_APPLICATION=NOT_AUTHORIZED")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC61_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC61_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC61_RUN=PASS"
