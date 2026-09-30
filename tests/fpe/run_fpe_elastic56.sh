#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic56-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC56_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic55.py select   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/selected.json" | tee "$BUILD/select.txt"
grep -Fq 'F_PE_ELASTIC55_SELECT=PASS' "$BUILD/select.txt" || fail "selection"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"

python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
for x in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(x["profile_id"]))
PY

: > "$BUILD/all.txt"
while read -r pid; do
  P="$BUILD/p$pid"
  mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic55.py profile     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" > "$P/prepare.txt"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic56_profile.py     --profile-id "$pid"     --o0 "$P/o0/rom0_test"     --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all.txt" <<'PY'
import math,sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
v=[x for x in lines if x.startswith("ELASTIC56_VIOLATION|")]
if len(v)!=51:
    raise SystemExit(f"F_PE_ELASTIC56_FAIL transition count={len(v)} expected=51")
counts={"CONTIGUOUS":0,"GAP":0}
mags={"SMALL":0,"MODERATE":0,"LARGE":0}
maxrel=(-1.0,None)
paired_both=0
sequences=set()
for line in v:
    d={}
    for p in line.split("|")[1:]:
        k,val=p.split("=",1); d[k]=val
    counts[d["class"]]+=1
    mags[d["magnitude"]]+=1
    sequences.add((d["profile"],d["regime"],d["h0"],d["delta"]))
    rel=float(d["rel_increase"])
    if rel>maxrel[0]: maxrel=(rel,line)
    if d["paired0"]=="T" and d["paired1"]=="T": paired_both+=1
if len(sequences)!=15:
    raise SystemExit(f"F_PE_ELASTIC56_FAIL violating sequence count={len(sequences)} expected=15")
print(f"ELASTIC56_TOTAL|sequences={len(sequences)}|transitions={len(v)}|contiguous={counts['CONTIGUOUS']}|gap={counts['GAP']}|small={mags['SMALL']}|moderate={mags['MODERATE']}|large={mags['LARGE']}|paired_both={paired_both}|max_rel_increase={maxrel[0]:.17e}")
print("ELASTIC56_WORST="+maxrel[1])
print("F_PE_ELASTIC56_A1_SELECTION_REPLAY=PASS")
print("F_PE_ELASTIC56_A2_VIOLATION_COUNT=PASS")
print("F_PE_ELASTIC56_A4_CLASSIFICATION=PASS")
print("F_PE_ELASTIC56_A5_ALPHA_UNCHANGED=PASS")
print("F_PE_ELASTIC56=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC56_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC56_A6_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC56_RUN=PASS"
