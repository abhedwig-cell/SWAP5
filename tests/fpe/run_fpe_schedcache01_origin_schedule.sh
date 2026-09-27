#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-schedcache01-${GITHUB_RUN_ID:-local}-$$"
N="${SCHEDCACHE01_N:-10000}"
REPS="${SCHEDCACHE01_REPS:-5}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_SCHEDCACHE01_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/candidate_context.f90" <<'PY'
from pathlib import Path
import sys

s=Path("src/runtime/mod_fmr_groundwater_application_context.f90").read_text()

type_anchor="""    real(real64) :: last_selected_load_ratio = 1.0_real64
    type(groundwater_interface_mass_ledger_t), pointer :: ledgers(:) => null()
"""
type_repl="""    real(real64) :: last_selected_load_ratio = 1.0_real64
    logical :: parallel_schedule_cached = .false.
    integer, allocatable :: cached_owner(:)
    type(groundwater_interface_mass_ledger_t), pointer :: ledgers(:) => null()
"""
if type_anchor not in s:
    raise SystemExit("SCHEDCACHE01 type anchor missing")
s=s.replace(type_anchor,type_repl,1)

bind_anchor="""    allocate(self%prepared_ledgers(size(tiles)))
    allocate(self%ledger_prepared(size(tiles)))

    self%participant_handles = participant_handles
"""
bind_repl="""    allocate(self%prepared_ledgers(size(tiles)))
    allocate(self%ledger_prepared(size(tiles)))
    if (self%worker_count > 1) allocate(self%cached_owner(size(tiles)))

    self%participant_handles = participant_handles
"""
if bind_anchor not in s:
    raise SystemExit("SCHEDCACHE01 bind anchor missing")
s=s.replace(bind_anchor,bind_repl,1)

capture_anchor="""    if (any(self%ledger_prepared)) then
      status = FMR_GW_APP_CONTEXT_PREPARED_BUSY
      return
    end if

    do i = 1, size(self%participant_handles)
"""
capture_repl="""    if (any(self%ledger_prepared)) then
      status = FMR_GW_APP_CONTEXT_PREPARED_BUSY
      return
    end if

    self%parallel_schedule_cached = .false.

    do i = 1, size(self%participant_handles)
"""
if capture_anchor not in s:
    raise SystemExit("SCHEDCACHE01 capture invalidation anchor missing")
s=s.replace(capture_anchor,capture_repl,1)

reset_anchor="""    self%last_parallel_schedule = FMR_GW_PARALLEL_SCHEDULE_SERIAL
    self%last_static_load_ratio = 1.0_real64
    self%last_selected_load_ratio = 1.0_real64

    if (self%worker_count == 1) then
"""
reset_repl="""    if (self%worker_count == 1 .or. .not. self%parallel_schedule_cached) then
      self%last_parallel_schedule = FMR_GW_PARALLEL_SCHEDULE_SERIAL
      self%last_static_load_ratio = 1.0_real64
      self%last_selected_load_ratio = 1.0_real64
    end if

    if (self%worker_count == 1) then
"""
if reset_anchor not in s:
    raise SystemExit("SCHEDCACHE01 diagnostics reset anchor missing")
s=s.replace(reset_anchor,reset_repl,1)

sched_start="""      worker_load = 0.0_real64
      do idx = 1, size(self%tiles)
"""
sched_end="""        self%last_parallel_schedule = FMR_GW_PARALLEL_SCHEDULE_COST_AWARE
      end if

!$omp parallel do default(shared) private(w,idx,participant_status,local_status) schedule(static,1) num_threads(self%worker_count)
"""
a=s.index(sched_start,s.index("  subroutine application_context_trial_cell_heads"))
b=s.index(sched_end,a)
original=s[a:b+len("""        self%last_parallel_schedule = FMR_GW_PARALLEL_SCHEDULE_COST_AWARE
      end if
""")]
wrapped="""      if (.not. allocated(self%cached_owner) .or. size(self%cached_owner) /= size(self%tiles)) then
        status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
        return
      end if

      if (.not. self%parallel_schedule_cached) then
""" + original + """
        self%cached_owner = owner
        self%parallel_schedule_cached = .true.
      else
        owner = self%cached_owner
      end if
"""
s=s[:a]+wrapped+s[b+len("""        self%last_parallel_schedule = FMR_GW_PARALLEL_SCHEDULE_COST_AWARE
      end if
"""):]

Path(sys.argv[1]).write_text(s)
PY

# Build a runner that substitutes only the candidate application-context module.
python3 - "$BUILD/candidate_runner.sh" "$BUILD/candidate_context.f90" "$ROOT" <<'PY'
from pathlib import Path
import sys
runner=Path("tests/fpe/run_fpe_multi04_p1c_application_context_scaling.sh").read_text()
context=Path(sys.argv[2]).resolve()
root=Path(sys.argv[3]).resolve()

old_root='ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"\ncd "$ROOT"'
new_root=f'ROOT="{root}"\ncd "$ROOT"'
if old_root not in runner:
    raise SystemExit("SCHEDCACHE01 root seam missing")
runner=runner.replace(old_root,new_root,1)

old_map='mapfile -t MODULE_SRC < <(python3 - "$fixture" <<\'PY\'\nfrom pathlib import Path\nimport sys,re\nfixture=Path(sys.argv[1]).resolve()'
new_map='mapfile -t MODULE_SRC < <(python3 - "$fixture" "$SCHEDCACHE01_CONTEXT_SOURCE" <<\'PY\'\nfrom pathlib import Path\nimport sys,re\nfixture=Path(sys.argv[1]).resolve()\ncontext=Path(sys.argv[2]).resolve()'
if old_map not in runner:
    raise SystemExit("SCHEDCACHE01 module-list argv seam missing")
runner=runner.replace(old_map,new_map,1)

old="""    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    else:
        print(p)
"""
new="""    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    elif p=="src/runtime/mod_fmr_groundwater_application_context.f90":
        print(context)
    else:
        print(p)
"""
if old not in runner:
    raise SystemExit("SCHEDCACHE01 module substitution seam missing")
runner=runner.replace(old,new,1)
Path(sys.argv[1]).write_text(runner)
PY
chmod +x "$BUILD/candidate_runner.sh"

MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS"   bash tests/fpe/run_fpe_multi04_p1c_application_context_scaling.sh | tee "$BUILD/baseline.txt"

SCHEDCACHE01_CONTEXT_SOURCE="$BUILD/candidate_context.f90" MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS"   bash "$BUILD/candidate_runner.sh" | tee "$BUILD/candidate.txt"

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
speed4=b["w4"]/c["w4"]
ratio4=c["w4"]/b["w4"]
print(
    f"SCHEDCACHE01_SUMMARY|N={n}|BASE_W4={b['w4']:.12f}|CAND_W4={c['w4']:.12f}|"
    f"W4_SPEEDUP={speed4:.6f}|BASE_W1={b['w1']:.12f}|CAND_W1={c['w1']:.12f}|"
    f"QSUM={b['q']:.17e}|TSUM={b['t']:.17e}"
)
if n==1000 and ratio4>1.02:
    raise SystemExit(f"N=1000 no-regression gate failed: {ratio4}")
if n==10000 and speed4<1.05:
    raise SystemExit(f"N=10000 speed gate failed: {speed4}")
if n==40000 and speed4<1.08:
    raise SystemExit(f"N=40000 speed gate failed: {speed4}")
print("FPE_SCHEDCACHE01=PASS")
PY
