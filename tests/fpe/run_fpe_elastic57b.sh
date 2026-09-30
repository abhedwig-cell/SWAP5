#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic57b-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC57B_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic55.py select \
  --artifact-dir "$ARTIFACT_DIR" --output "$BUILD/selected.json" > "$BUILD/select.txt"
python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
x=json.load(open(sys.argv[1],encoding="utf-8"))
ids=[int(v["profile_id"]) for v in x]
if ids != [11060,10260,8016,3030]:
    raise SystemExit(f"F_PE_ELASTIC57B_FAIL selection={ids}")
for pid in ids: print(pid)
PY
echo "F_PE_ELASTIC57B_B1_SELECTION=PASS"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py \
  --root "$ROOT" \
  --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90" \
  --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"

: > "$BUILD/all.txt"
while read -r pid; do
  P="$BUILD/p$pid"; mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic55.py profile \
    --repo-root "$ROOT" --artifact-dir "$ARTIFACT_DIR" --work-dir "$P/work" \
    --profile-id "$pid" --fixture "$P/test.f90" --geometry-json "$P/geometry.json" > "$P/prepare.txt"

  grep -Fq 'real(real64), parameter :: MASS_TOL=1.0e-12_real64' "$P/test.f90" || fail "mass tolerance constant $pid"
  grep -Fq 'q%compartment_balance_tolerance=MASS_TOL;q%total_balance_tolerance=MASS_TOL' "$P/test.f90" || fail "parameter mass gates $pid"
  grep -Fq 'r%numerical%compartment_balance_tolerance=MASS_TOL;r%numerical%total_balance_tolerance=MASS_TOL' "$P/test.f90" || fail "request mass gates $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py \
    --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
    --geometry-json "$P/geometry.json" --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py \
      --root "$ROOT" --stub "$P/stub.f90" --target "$P/test.f90" \
      --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90" \
      --external-source src/legacy/b1_10_port/headcalc.f90 \
      --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic57b_profile.py \
    --profile-id "$pid" --o0 "$P/o0/rom0_test" --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all.txt" <<'PY'
from collections import defaultdict
import sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
profiles=[x for x in lines if x.startswith("ELASTIC57B_PROFILE|")]
controls=[x for x in lines if x.startswith("ELASTIC57B_CONTROL|")]
metrics=[x for x in lines if x.startswith("ELASTIC57B_METRIC|")]
if len(profiles)!=4: raise SystemExit(f"F_PE_ELASTIC57B_FAIL profile rows={len(profiles)}")

def parse(line):
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    return d

p=[parse(x) for x in profiles]
eligible=sum(int(x["eligible"]) for x in p)
violating=sum(int(x["violating"]) for x in p)
mismatch=sum(int(x["safe_bounded_mismatch"]) for x in p)
chatter=sum(int(x["chatter"]) for x in p)
if eligible!=170 or violating!=15:
    raise SystemExit(f"F_PE_ELASTIC57B_FAIL replay eligible={eligible} violating={violating}")
if len(controls)!=15:
    raise SystemExit(f"F_PE_ELASTIC57B_FAIL control mappings={len(controls)}")
if mismatch or chatter:
    raise SystemExit(f"F_PE_ELASTIC57B_FAIL mismatch={mismatch} chatter={chatter}")

agg=defaultdict(lambda:defaultdict(int))
for line in metrics:
    d=parse(line)
    key=(d["scope"],d["regime"],d["controller"])
    for k in ("tests","accept","exhausted","abort","attempts","retries","unavailable","nonlinear",
              "indicator_solves","work_units","paired_accepts","envelope_fail"):
        agg[key][k]+=int(d[k])

for key in sorted(agg):
    a=agg[key]
    print("ELASTIC57B_TOTAL_METRIC|scope=%s|regime=%s|controller=%s|%s" %
          (key[0],key[1],key[2],"|".join(f"{k}={a[k]}" for k in
          ("tests","accept","exhausted","abort","attempts","retries","unavailable","nonlinear",
           "indicator_solves","work_units","paired_accepts","envelope_fail"))))

for ctl in ("C-SAFE","C-BOUNDED"):
    for key,a in agg.items():
        if key[2]==ctl and a["envelope_fail"]!=0:
            raise SystemExit(f"F_PE_ELASTIC57B_FAIL envelope {key}={a['envelope_fail']}")

naive_v=agg[("VIOLATING","ALL","C-NAIVE")]
safe_v=agg[("VIOLATING","ALL","C-SAFE")]
bounded_v=agg[("VIOLATING","ALL","C-BOUNDED")]
if naive_v["abort"]<=0:
    raise SystemExit("F_PE_ELASTIC57B_FAIL naive did not expose nonmonotone aborts")
if safe_v["abort"]!=0 or bounded_v["abort"]!=0:
    raise SystemExit("F_PE_ELASTIC57B_FAIL safeguarded abort")
if safe_v["tests"]!=bounded_v["tests"] or safe_v["accept"]!=bounded_v["accept"] or safe_v["exhausted"]!=bounded_v["exhausted"]:
    raise SystemExit("F_PE_ELASTIC57B_FAIL safe bounded aggregate decision mismatch")

# GENERATED had zero parent violations. The monotonicity guard must therefore be
# behaviorally inert in this observed regime: NAIVE and SAFE should execute the
# same decision/work totals.
ng=agg[("ALL","GENERATED","C-NAIVE")]
sg=agg[("ALL","GENERATED","C-SAFE")]
for k in ("tests","accept","exhausted","attempts","retries","unavailable","nonlinear","indicator_solves","work_units"):
    if ng[k]!=sg[k]:
        raise SystemExit(f"F_PE_ELASTIC57B_FAIL generated guard not inert {k} naive={ng[k]} safe={sg[k]}")
if ng["abort"]!=0:
    raise SystemExit("F_PE_ELASTIC57B_FAIL generated naive abort")

print(f"ELASTIC57B_TOTAL|eligible={eligible}|violating={violating}|control_mappings={len(controls)}|safe_bounded_mismatch={mismatch}|chatter={chatter}")
print("F_PE_ELASTIC57B_B1_PARENT_REPLAY=PASS")
print("F_PE_ELASTIC57B_B2_MATCHED_CONTROLS=PASS")
print("F_PE_ELASTIC57B_B3_SAFE_ACCEPTANCE=PASS")
print("F_PE_ELASTIC57B_B4_BOUNDED_TERMINATION=PASS")
print("F_PE_ELASTIC57B_B5_ENVELOPE=PASS")
print("F_PE_ELASTIC57B_B6_HARD_MASS_GATE_PRESERVED=PASS")
print("F_PE_ELASTIC57B_B7_NAIVE_CHARACTERIZED=PASS")
print("F_PE_ELASTIC57B_B8_WORK_COUNTERS=PASS")
print("F_PE_ELASTIC57B_B9_GENERATED_GUARD_INERT=PASS")
print("F_PE_ELASTIC57B_HEADCALC_CALLS=NOT_EXPOSED")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
prod=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines() if p.startswith("src/")]
if prod: raise SystemExit("F_PE_ELASTIC57B_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC57B_B10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC57B_RUN=PASS"
