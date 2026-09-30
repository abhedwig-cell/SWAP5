#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic61-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC61_FAIL $*" >&2; exit 1; }

# Source-only blind selection may happen before calibration; no holdout solve is
# executed until alpha_D1 has been frozen below.
python3 tests/fpe/prepare_fpe_elastic61.py   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/holdout_selected.json" | tee "$BUILD/holdout_select.txt"
grep -Fq 'F_PE_ELASTIC61_SELECT=PASS' "$BUILD/holdout_select.txt" || fail "holdout selection"

python3 - "$BUILD/holdout_selected.json" <<'PY'
import json,sys
ids=[int(x["profile_id"]) for x in json.load(open(sys.argv[1],encoding="utf-8"))]
excluded={90116260,11060,10260,8016,3030,11020,8120,4015,3011}
if len(ids)!=4 or any(x in excluded for x in ids):
    raise SystemExit(f"F_PE_ELASTIC61_FAIL holdout ids={ids}")
print("F_PE_ELASTIC61_A3_HOLDOUT_SELECTION=PASS")
PY

python3 tests/fpe/materialize_fpe_elastic59_indicator.py   --root "$ROOT"   --output "$BUILD/mod_fpe_elastic59_reference_richards_temporal_indicator.f90" > "$BUILD/materialize.txt"
grep -Fq 'F_PE_ELASTIC59_MATERIALIZE=PASS' "$BUILD/materialize.txt" || fail "indicator materialize"

# ---------------------------------------------------------------------------
# CALIBRATION PHASE: ELASTIC59 development profiles only.
# ---------------------------------------------------------------------------
: > "$BUILD/calibration.txt"
for pid in 11060 10260 8016 3030; do
  P="$BUILD/cal_$pid"
  mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic59.py     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC59_PROFILE_PREP=PASS' "$P/prepare.txt" || fail "cal prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  OUT="$P/o2"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub "$P/stub.f90"     --target "$P/test.f90"     --external-source "$BUILD/mod_fpe_elastic59_reference_richards_temporal_indicator.f90"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt 2

  python3 tests/fpe/run_fpe_elastic61_calibrate_profile.py     --profile-id "$pid"     --exe "$OUT/rom0_test" | tee "$P/calibration.txt"
  cat "$P/calibration.txt" >> "$BUILD/calibration.txt"
done

python3 - "$BUILD/calibration.txt" "$BUILD/alpha.txt" <<'PY'
import sys
lines=[x for x in open(sys.argv[1],encoding="utf-8") if x.startswith("ELASTIC61_CAL_PROFILE|")]
if len(lines)!=4:
    raise SystemExit(f"F_PE_ELASTIC61_FAIL calibration profile count={len(lines)}")
ids=[]; vals=[]
for line in lines:
    d={}
    for p in line.strip().split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    ids.append(int(d["profile"])); vals.append(float(d["alpha_local"]))
if ids != [11060,10260,8016,3030]:
    raise SystemExit(f"F_PE_ELASTIC61_FAIL calibration ids={ids}")
alpha=max(vals)
if not (alpha>0):
    raise SystemExit("F_PE_ELASTIC61_FAIL alpha")
open(sys.argv[2],"w",encoding="utf-8").write(f"{alpha:.17e}\n")
print(f"ELASTIC61_ALPHA_D1_FROZEN={alpha:.17e}")
print("F_PE_ELASTIC61_A1_CALIBRATION_AUTHORITY=PASS")
print("F_PE_ELASTIC61_A2_ALPHA_FROZEN=PASS")
PY

ALPHA="$(cat "$BUILD/alpha.txt")"

# ---------------------------------------------------------------------------
# BLIND HOLDOUT PHASE: no alpha modification after this line.
# ---------------------------------------------------------------------------
: > "$BUILD/holdout_results.txt"
python3 - "$BUILD/holdout_selected.json" <<'PY' > "$BUILD/holdout_ids.txt"
import json,sys
for x in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(x["profile_id"]))
PY

while read -r pid; do
  P="$BUILD/hold_$pid"
  mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic59.py     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC59_PROFILE_PREP=PASS' "$P/prepare.txt" || fail "holdout prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic59_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic61_holdout_profile.py     --profile-id "$pid"     --alpha "$ALPHA"     --o0 "$P/o0/rom0_test"     --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/holdout_results.txt"
done < "$BUILD/holdout_ids.txt"

python3 - "$BUILD/holdout_results.txt" "$ALPHA" <<'PY'
import sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
rows=[x for x in lines if x.startswith("ELASTIC61_PROFILE|")]
if len(rows)!=4:
    raise SystemExit(f"F_PE_ELASTIC61_FAIL holdout profile summaries={len(rows)}")
tot={k:0 for k in ("scaled_selected","scaled_sat","scaled_head_fail","scaled_theta_fail",
                    "unscaled_selected","unscaled_sat","unscaled_head_fail","unscaled_theta_fail")}
for line in rows:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    if abs(float(d["alpha"])-float(sys.argv[2])) > 1e-15*max(1.0,abs(float(sys.argv[2]))):
        raise SystemExit("F_PE_ELASTIC61_FAIL alpha drift")
    for k in tot: tot[k]+=int(d[k])
print("ELASTIC61_TOTAL|alpha="+format(float(sys.argv[2]),".17e")+"|"+("|".join(f"{k}={v}" for k,v in tot.items())))
print("F_PE_ELASTIC61_A4_BANK=PASS")
print("F_PE_ELASTIC61_A5_O0_O2=PASS")
print("F_PE_ELASTIC61_A6_DIRECT=PASS")
print("F_PE_ELASTIC61_A8_NO_REFIT=PASS")
if tot["scaled_head_fail"] or tot["scaled_theta_fail"]:
    print("F_PE_ELASTIC61_SCALED_D1=FALSIFIED")
else:
    print("F_PE_ELASTIC61_SCALED_D1=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod: raise SystemExit("F_PE_ELASTIC61_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC61_A9_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC61_RUN=PASS"
