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

python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_sets.txt"
import json,sys
ids=[int(v["profile_id"]) for v in json.load(open(sys.argv[1],encoding="utf-8"))]
expected=[11060,10260,8016,3030]
if ids!=expected:
    raise SystemExit(f"F_PE_ELASTIC59_FAIL selection={ids}")
for pid in ids:
    print(pid, "HOLDOUT" if pid==3030 else "TRAIN")
PY
echo "F_PE_ELASTIC59_A1_SPLIT=PASS"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"
grep -Fq 'F_PE_ELASTIC53_MATERIALIZE=PASS' "$BUILD/indicator.txt" || fail "indicator materialize"

: > "$BUILD/all.txt"
while read -r pid setname; do
  P="$BUILD/p$pid"; mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic59.py     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC59_PREP=PASS' "$P/prepare.txt" || fail "profile prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic59_profile.py     --profile-id "$pid" --set "$setname"     --o0 "$P/o0/rom0_test" --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all.txt"
done < "$BUILD/profile_sets.txt"

python3 - "$BUILD/all.txt" <<'PY'
import math,sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
rows=[]
for line in lines:
    if not line.startswith("ELASTIC59_QUALIFIED|"): continue
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    d["profile"]=int(d["profile"])
    for k in ("h0","delta","dt","hreal","horacle","binf","ebound"):
        d[k]=float(d[k])
    d["safe"]=d["safe"]=="T"
    rows.append(d)
train=[r for r in rows if r["set"]=="TRAIN"]
hold=[r for r in rows if r["set"]=="HOLDOUT"]
if not train: raise SystemExit("F_PE_ELASTIC59_FAIL no oracle-qualified training")
if not hold: raise SystemExit("F_PE_ELASTIC59_FAIL no oracle-qualified holdout")
if any(r["profile"]==3030 for r in train): raise SystemExit("F_PE_ELASTIC59_FAIL holdout leaked into training")
if any(r["profile"]!=3030 for r in hold): raise SystemExit("F_PE_ELASTIC59_FAIL training leaked into holdout")

unsafe_train=[r for r in train if not r["safe"]]
if unsafe_train:
    threshold=min(r["ebound"] for r in unsafe_train)*(1.0-1e-12)
    threshold_origin="FIRST_UNSAFE_BOUND"
else:
    threshold=max(r["ebound"] for r in train)
    threshold_origin="MAX_QUALIFIED_TRAIN_BOUND"

if not math.isfinite(threshold) or threshold<0:
    raise SystemExit("F_PE_ELASTIC59_FAIL invalid threshold")

train_accept=[r for r in train if r["ebound"]<=threshold]
train_false=[r for r in train_accept if not r["safe"]]
if train_false:
    raise SystemExit(f"F_PE_ELASTIC59_FAIL unsafe training accepted={len(train_false)}")

hold_safe=[r for r in hold if r["safe"]]
hold_unsafe=[r for r in hold if not r["safe"]]
hold_accept=[r for r in hold if r["ebound"]<=threshold]
false_accept=[r for r in hold_accept if not r["safe"]]
false_reject=[r for r in hold_safe if r["ebound"]>threshold]

print(f"ELASTIC59_THRESHOLD|value_cm={threshold:.17e}|origin={threshold_origin}")
print(f"ELASTIC59_TRAIN|qualified={len(train)}|safe={sum(r['safe'] for r in train)}|unsafe={len(unsafe_train)}|accepted={len(train_accept)}|unsafe_accepted={len(train_false)}")
print(f"ELASTIC59_HOLDOUT|qualified={len(hold)}|safe={len(hold_safe)}|unsafe={len(hold_unsafe)}|accepted={len(hold_accept)}|false_accept={len(false_accept)}|false_reject={len(false_reject)}|accept_fraction={len(hold_accept)/len(hold):.17e}|safe_reject_fraction={(len(false_reject)/len(hold_safe) if hold_safe else 0.0):.17e}")

for r in false_accept:
    print("ELASTIC59_FALSE_ACCEPT|"+("|".join(f"{k}={r[k]}" for k in ("profile","regime","h0","delta","dt","hreal","horacle","ebound"))))
for r in false_reject[:30]:
    print("ELASTIC59_FALSE_REJECT|"+("|".join(f"{k}={r[k]}" for k in ("profile","regime","h0","delta","dt","hreal","horacle","ebound"))))

if false_accept:
    print("F_PE_ELASTIC59_HOLDOUT=FALSIFIED")
else:
    print("F_PE_ELASTIC59_HOLDOUT=PASS")
print("F_PE_ELASTIC59_A4_ORACLE_SELF=PASS")
print("F_PE_ELASTIC59_A5_TRAIN_ONLY=PASS")
print("F_PE_ELASTIC59_A6_HOLDOUT_BLIND=PASS")
print("F_PE_ELASTIC59_A7_HOLDOUT_SAFETY=PASS" if not false_accept else "F_PE_ELASTIC59_A7_HOLDOUT_SAFETY=FAIL")
PY

grep -Fq 'F_PE_ELASTIC59_HOLDOUT=PASS' "$BUILD/all.txt" 2>/dev/null || true

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
prod=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines() if p.startswith("src/")]
if prod: raise SystemExit("F_PE_ELASTIC59_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC59_A9_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC59_RUN=PASS"
