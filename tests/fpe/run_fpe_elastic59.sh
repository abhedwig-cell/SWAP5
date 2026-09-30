#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic59-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC59_FAIL $*" >&2; exit 1; }

python3 tests/fpe/select_fpe_elastic59_profiles.py   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/selected.json" | tee "$BUILD/select.txt"
grep -Fq 'F_PE_ELASTIC59_SELECT=PASS' "$BUILD/select.txt" || fail "selection"

python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
x=json.load(open(sys.argv[1],encoding="utf-8"))
if len(x)!=4: raise SystemExit("F_PE_ELASTIC59_FAIL selected count")
for v in x: print(int(v["profile_id"]))
PY
echo "F_PE_ELASTIC59_A1_SELECTION=PASS"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"

: > "$BUILD/all.txt"
while read -r pid; do
  P="$BUILD/p$pid"; mkdir -p "$P/work"

  python3 tests/fpe/prepare_fpe_elastic55.py profile     --repo-root "$ROOT" --artifact-dir "$ARTIFACT_DIR" --work-dir "$P/work"     --profile-id "$pid" --fixture "$P/test.f90" --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC55_PROFILE_PREP=PASS' "$P/prepare.txt" || fail "profile prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json" --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT" --stub "$P/stub.f90" --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic59_profile.py     --profile-id "$pid" --o0 "$P/o0/rom0_test" --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all.txt" <<'PY'
import math,sys
lines=[x for x in open(sys.argv[1],encoding="utf-8").read().splitlines() if x.startswith("ELASTIC59_PROFILE_FRONTIER|")]
if len(lines)!=8:
    raise SystemExit(f"F_PE_ELASTIC59_FAIL frontier rows={len(lines)}")
agg={}
for line in lines:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    b=float(d["budget"])
    a=agg.setdefault(b,dict(accepted=0,exhausted=0,paired=0,seq=0,attempt_weight=0.0,
                            max_hinf=0.0,max_util=0.0,max_env=0.0,
                            off=0,fixed=0,generated=0,unsat=0,sat=0))
    accepted=int(d["accepted"]); exhausted=int(d["exhausted"])
    a["accepted"]+=accepted; a["exhausted"]+=exhausted; a["paired"]+=int(d["paired"])
    a["seq"]+=accepted+exhausted
    a["attempt_weight"]+=float(d["mean_attempts"])*(accepted+exhausted)
    for k,src in (("off","off_accept"),("fixed","fixed_accept"),("generated","generated_accept"),
                  ("unsat","unsat_accept"),("sat","sat_accept")):
        a[k]+=int(d[src])
    for k,src in (("max_hinf","max_hinf"),("max_util","max_hinf_over_budget"),("max_env","max_envelope_util")):
        v=float(d[src])
        if math.isfinite(v): a[k]=max(a[k],v)

for b in sorted(agg):
    a=agg[b]
    if a["seq"]!=240:
        raise SystemExit(f"F_PE_ELASTIC59_FAIL sequence total {b} {a['seq']}")
    if a["max_env"]>1+1e-12:
        raise SystemExit(f"F_PE_ELASTIC59_FAIL frozen envelope {b}")
    print(
      f"ELASTIC59_TOTAL|budget={b:.17e}|accepted={a['accepted']}|exhausted={a['exhausted']}"
      f"|accept_fraction={a['accepted']/a['seq']:.17e}|paired={a['paired']}"
      f"|mean_attempts={a['attempt_weight']/a['seq']:.17e}|max_hinf={a['max_hinf']:.17e}"
      f"|max_hinf_over_budget={a['max_util']:.17e}|max_envelope_util={a['max_env']:.17e}"
      f"|off_accept={a['off']}|fixed_accept={a['fixed']}|generated_accept={a['generated']}"
      f"|unsat_accept={a['unsat']}|sat_accept={a['sat']}"
    )
if agg[1.0]["accepted"] < agg[0.3]["accepted"]:
    raise SystemExit("F_PE_ELASTIC59_FAIL candidate accepts fewer than comparator")
print("F_PE_ELASTIC59_A4_CSAFE=PASS")
print("F_PE_ELASTIC59_A5_ENVELOPE=PASS")
print("F_PE_ELASTIC59_A6_ALPHA_NO_REFIT=PASS")
print("F_PE_ELASTIC59_A7_COMPARATOR=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
prod=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines() if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC59_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC59_A8_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC59_RUN=PASS"
