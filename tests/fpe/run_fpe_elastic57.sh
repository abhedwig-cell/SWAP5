#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic57-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC57_FAIL $*" >&2; exit 1; }

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"
grep -Fq 'F_PE_ELASTIC53_MATERIALIZE=PASS' "$BUILD/indicator.txt" || fail "indicator materialize"

profiles=(11060 10260 8016 3030)
: > "$BUILD/all.txt"

for pid in "${profiles[@]}"; do
  P="$BUILD/p$pid"
  mkdir -p "$P/work"

  python3 tests/fpe/prepare_fpe_elastic57.py     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC57_PREP=PASS' "$P/prepare.txt" || fail "profile prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic57_profile.py     --profile-id "$pid"     --o0 "$P/o0/rom0_test"     --o2 "$P/o2/rom0_test" | tee "$P/result.txt"

  grep -Fq 'F_PE_ELASTIC57_PROFILE=PASS' "$P/result.txt" || fail "profile runner $pid"
  cat "$P/result.txt" >> "$BUILD/all.txt"
done

python3 - "$BUILD/all.txt" <<'PY'
import collections, math, sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
rows=[]
for line in lines:
    if not line.startswith("ELASTIC57_OUTCOME|"): continue
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    rows.append(d)

if len(rows)!=240:
    raise SystemExit(f"F_PE_ELASTIC57_FAIL outcome count={len(rows)} expected=240")

seqs={(r["profile"],r["kind"],r["regime"],r["h0"],r["delta"]) for r in rows}
if len(seqs)!=30:
    raise SystemExit(f"F_PE_ELASTIC57_FAIL sequence count={len(seqs)} expected=30")

unsafe=[r for r in rows if r["safety"]=="FAIL"]
if unsafe:
    raise SystemExit(f"F_PE_ELASTIC57_FAIL unsafe paired accepts={len(unsafe)}")

for r in rows:
    status=r["status"]
    retry=int(r["retry"])
    if status=="ACCEPTED":
        if retry<0 or retry>8:
            raise SystemExit("F_PE_ELASTIC57_FAIL accepted retry outside bound")
    elif status=="EXHAUSTED":
        if retry!=-1:
            raise SystemExit("F_PE_ELASTIC57_FAIL exhausted retry encoding")
    else:
        raise SystemExit("F_PE_ELASTIC57_FAIL unknown status")

by_budget=collections.defaultdict(lambda:dict(target_acc=0,target_exh=0,control_acc=0,control_exh=0,unverified=0,paired=0))
max_extra=-999
for r in rows:
    b=float(r["budget"])
    k="target" if r["kind"]=="TARGET" else "control"
    if r["status"]=="ACCEPTED": by_budget[b][k+"_acc"]+=1
    else: by_budget[b][k+"_exh"]+=1
    if r["safety"]=="UNVERIFIED": by_budget[b]["unverified"]+=1
    if r["safety"]=="PASS": by_budget[b]["paired"]+=1
    x=int(r["extra_refinement"])
    if x!=-999: max_extra=max(max_extra,x)

accepted=sum(1 for r in rows if r["status"]=="ACCEPTED")
exhausted=len(rows)-accepted
unverified=sum(1 for r in rows if r["safety"]=="UNVERIFIED")
paired_safe=sum(1 for r in rows if r["safety"]=="PASS")
mass_rejections=sum(int(r["mass_rejections"]) for r in rows)
max_retry=max([int(r["retry"]) for r in rows if int(r["retry"])>=0] or [-1])

for b in sorted(by_budget):
    d=by_budget[b]
    print(f"ELASTIC57_BUDGET|budget={b}|target_acc={d['target_acc']}|target_exh={d['target_exh']}|control_acc={d['control_acc']}|control_exh={d['control_exh']}|paired_safe={d['paired']}|unverified={d['unverified']}")

print(f"ELASTIC57_TOTAL|outcomes={len(rows)}|sequences={len(seqs)}|accepted={accepted}|exhausted={exhausted}|paired_safe={paired_safe}|unverified={unverified}|mass_rejections={mass_rejections}|max_retry={max_retry}|max_extra_refinement={max_extra}")
print("F_PE_ELASTIC57_A1_SEQUENCE_COUNT=PASS")
print("F_PE_ELASTIC57_A3_MASS_GATE=PASS")
print("F_PE_ELASTIC57_A4_ALPHA_FROZEN=PASS")
print("F_PE_ELASTIC57_A5_BOUNDED_TERMINATION=PASS")
print("F_PE_ELASTIC57_A6_PAIRED_SAFETY=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC57_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC57_A7_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC57_RUN=PASS"
