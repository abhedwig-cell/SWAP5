#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-agg01-${GITHUB_RUN_ID:-local}-$$"
N="${AGG01_N:-10000}"
REPS="${AGG01_REPS:-5}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_AGG01_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/candidate_context.f90" <<'PY'
from pathlib import Path
import sys
p=Path("src/runtime/mod_fmr_groundwater_application_context.f90")
s=p.read_text()

anchor="""    self%last_parallel_schedule = FMR_GW_PARALLEL_SCHEDULE_SERIAL
    self%last_static_load_ratio = 1.0_real64
    self%last_selected_load_ratio = 1.0_real64

    if (self%worker_count == 1) then
"""
replacement="""    self%last_parallel_schedule = FMR_GW_PARALLEL_SCHEDULE_SERIAL
    self%last_static_load_ratio = 1.0_real64
    self%last_selected_load_ratio = 1.0_real64

    allocate(exchanges(maxval(self%cells%tile_count)))

    if (self%worker_count == 1) then
"""
if anchor not in s:
    raise SystemExit("AGG01 allocation anchor missing")
s=s.replace(anchor,replacement,1)

needle="        allocate(exchanges(self%cells(i)%tile_count))\n"
count=s.count(needle)
if count != 2:
    raise SystemExit(f"AGG01 expected 2 per-cell allocations, found {count}")
s=s.replace(needle,"",2)

s=s.replace(
"        call aggregate_groundwater_cell_tiles(self%cells(i)%topology%groundwater_cell_id, exchanges, aggregate, local_status)",
"        call aggregate_groundwater_cell_tiles(self%cells(i)%topology%groundwater_cell_id, &\n             exchanges(1:self%cells(i)%tile_count), aggregate, local_status)",
2)

needle="        deallocate(exchanges)\n"
count=s.count(needle)
if count != 3:
    raise SystemExit(f"AGG01 expected 3 deallocations in trial path, found {count}")
s=s.replace(needle,"",3)

Path(sys.argv[1]).write_text(s)
PY

python3 - "$BUILD/candidate_runner.sh" "$BUILD/candidate_context.f90" "$ROOT" <<'PY'
from pathlib import Path
import sys
runner=Path("tests/fpe/run_fpe_multi04_p1c_application_context_scaling.sh").read_text()
context=Path(sys.argv[2]).resolve()
root=Path(sys.argv[3]).resolve()

old_root='ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"\ncd "$ROOT"'
new_root=f'ROOT="{root}"\ncd "$ROOT"'
if old_root not in runner:
    raise SystemExit("AGG01 runner root seam missing")
runner=runner.replace(old_root,new_root,1)

old='''    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    else:
        print(p)
'''
new='''    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    elif p=="src/runtime/mod_fmr_groundwater_application_context.f90":
        print(context)
    else:
        print(p)
'''
if old not in runner:
    raise SystemExit("AGG01 module substitution seam missing")
runner=runner.replace("python3 - \"$fixture\" <<'PY'","python3 - \"$fixture\" \"$AGG01_CONTEXT_SOURCE\" <<'PY'",1)
runner=runner.replace("fixture=Path(sys.argv[1]).resolve()\n", "fixture=Path(sys.argv[1]).resolve()\ncontext=Path(sys.argv[2]).resolve()\n",1)
runner=runner.replace(old,new,1)
Path(sys.argv[1]).write_text(runner)
PY
chmod +x "$BUILD/candidate_runner.sh"

MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS"   bash tests/fpe/run_fpe_multi04_p1c_application_context_scaling.sh | tee "$BUILD/baseline.txt"

AGG01_CONTEXT_SOURCE="$BUILD/candidate_context.f90" MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS"   bash "$BUILD/candidate_runner.sh" | tee "$BUILD/candidate.txt"

python3 - "$N" "$BUILD/baseline.txt" "$BUILD/candidate.txt" <<'PY'
import re,sys
n=int(sys.argv[1])

def parse(path):
    txt=open(path).read()
    m=re.search(
        r'MULTI04_P1C_SUMMARY\|N=(\d+)\|W1_SECONDS=([^|]+)\|W2_SECONDS=([^|]+)\|W4_SECONDS=([^|]+)\|'
        r'SPEEDUP2=([^|]+)\|SPEEDUP4=([^|]+)\|QSUM=([^|]+)\|TSUM=(.+)',txt)
    if not m:
        raise SystemExit(f"missing summary {path}")
    return dict(n=int(m.group(1)),w1=float(m.group(2)),w2=float(m.group(3)),w4=float(m.group(4)),
                s2=float(m.group(5)),s4=float(m.group(6)),q=float(m.group(7)),t=float(m.group(8)))

b=parse(sys.argv[2]); c=parse(sys.argv[3])
if b["n"]!=n or c["n"]!=n:
    raise SystemExit("N mismatch")
if b["q"]!=c["q"] or b["t"]!=c["t"]:
    raise SystemExit("semantic checksum mismatch")
speed1=b["w1"]/c["w1"]
speed4=b["w4"]/c["w4"]
ratio4=c["w4"]/b["w4"]
print(
    f"AGG01_SUMMARY|N={n}|BASE_W1={b['w1']:.12f}|CAND_W1={c['w1']:.12f}|W1_SPEEDUP={speed1:.6f}|"
    f"BASE_W4={b['w4']:.12f}|CAND_W4={c['w4']:.12f}|W4_SPEEDUP={speed4:.6f}|"
    f"QSUM={b['q']:.17e}|TSUM={b['t']:.17e}"
)
if n==1000 and ratio4>1.02:
    raise SystemExit(f"N=1000 no-regression gate failed: {ratio4}")
if n==10000 and speed4<1.05:
    raise SystemExit(f"N=10000 speed gate failed: {speed4}")
if n==40000 and speed4<1.10:
    raise SystemExit(f"N=40000 speed gate failed: {speed4}")
print("FPE_AGG01=PASS")
PY
