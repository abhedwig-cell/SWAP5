#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-orch01-${GITHUB_RUN_ID:-local}-$$"
N="${ORCH01_N:-10000}"
REPS="${ORCH01_REPS:-5}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_ORCH01_FAIL $*" >&2; exit 1; }

APP_SRC="$BUILD/mod_fmr_groundwater_application_context_orch01.f90"
PART_SRC="$BUILD/mod_fmr_groundwater_swap_participant_orch01.f90"

python3 - "$PART_SRC" <<'PY'
from pathlib import Path
import sys
p=Path("src/runtime/mod_fmr_groundwater_swap_participant.f90")
s=p.read_text()

s=s.replace(
"module mod_fmr_groundwater_swap_participant\n",
"module mod_fmr_groundwater_swap_participant\n  use omp_lib, only: omp_get_wtime, omp_get_thread_num\n",
1)

anchor="  public :: resolve_fmr_groundwater_temporal_budget\n"
repl=anchor+"  public :: orch01_reset_backend_timers, orch01_read_backend_timers\n"
if anchor not in s: raise SystemExit("ORCH01 participant public anchor missing")
s=s.replace(anchor,repl,1)

anchor="  type, public :: fmr_groundwater_temporal_budget_policy_t\n"
state="""  real(real64), save :: orch01_backend_seconds(0:63) = 0.0_real64

"""
if anchor not in s: raise SystemExit("ORCH01 participant state anchor missing")
s=s.replace(anchor,state+anchor,1)

anchor="contains\n\n"
helpers="""contains

  subroutine orch01_reset_backend_timers()
    orch01_backend_seconds = 0.0_real64
  end subroutine orch01_reset_backend_timers

  subroutine orch01_read_backend_timers(max_seconds, sum_seconds)
    real(real64), intent(out) :: max_seconds, sum_seconds
    max_seconds = maxval(orch01_backend_seconds)
    sum_seconds = sum(orch01_backend_seconds)
  end subroutine orch01_read_backend_timers

"""
if anchor not in s: raise SystemExit("ORCH01 participant contains anchor missing")
s=s.replace(anchor,helpers,1)

anchor="    real(real64) :: duration_day, qbot_mean_cm_per_day, dq_swap_dh_per_s, effective_temporal_budget\n"
repl=anchor+"    real(real64) :: orch01_t0\n    integer :: orch01_tid\n"
if anchor not in s: raise SystemExit("ORCH01 participant decl anchor missing")
s=s.replace(anchor,repl,1)

anchor="    select type (typed_forcing => forcing)\n"
repl="    orch01_tid = min(63, max(0, omp_get_thread_num()))\n    orch01_t0 = omp_get_wtime()\n"+anchor
if anchor not in s: raise SystemExit("ORCH01 participant backend start anchor missing")
s=s.replace(anchor,repl,1)

anchor="    end select\n\n    if (.not. accepted_whole_window"
repl="    end select\n    orch01_backend_seconds(orch01_tid) = orch01_backend_seconds(orch01_tid) + (omp_get_wtime() - orch01_t0)\n\n    if (.not. accepted_whole_window"
if anchor not in s: raise SystemExit("ORCH01 participant backend end anchor missing")
s=s.replace(anchor,repl,1)
Path(sys.argv[1]).write_text(s)
PY

python3 - "$APP_SRC" <<'PY'
from pathlib import Path
import sys
p=Path("src/runtime/mod_fmr_groundwater_application_context.f90")
s=p.read_text()

s=s.replace(
"module mod_fmr_groundwater_application_context\n",
"module mod_fmr_groundwater_application_context\n  use omp_lib, only: omp_get_wtime\n",
1)

anchor="  use mod_fmr_groundwater_participant_registry, only: fmr_groundwater_participant_registry_t, &\n       FMR_GW_REGISTRY_OK\n"
repl=anchor+"  use mod_fmr_groundwater_swap_participant, only: orch01_reset_backend_timers, orch01_read_backend_timers\n"
if anchor not in s: raise SystemExit("ORCH01 app use anchor missing")
s=s.replace(anchor,repl,1)

anchor="    real(real64) :: mean_load, best_load\n"
repl=anchor+"""    real(real64) :: orch_total_t0, orch_phase_t0, orch_total, orch_map, orch_cost, orch_sched
    real(real64) :: orch_trial, orch_validate, orch_agg, orch_backend_max, orch_backend_sum
"""
if anchor not in s: raise SystemExit("ORCH01 app declaration anchor missing")
s=s.replace(anchor,repl,1)

anchor="""    self%last_parallel_schedule = FMR_GW_PARALLEL_SCHEDULE_SERIAL
    self%last_static_load_ratio = 1.0_real64
    self%last_selected_load_ratio = 1.0_real64

"""
repl=anchor+"""    orch_total = 0.0_real64
    orch_map = 0.0_real64
    orch_cost = 0.0_real64
    orch_sched = 0.0_real64
    orch_trial = 0.0_real64
    orch_validate = 0.0_real64
    orch_agg = 0.0_real64
    orch_backend_max = 0.0_real64
    orch_backend_sum = 0.0_real64
    call orch01_reset_backend_timers()
    orch_total_t0 = omp_get_wtime()

"""
if anchor not in s: raise SystemExit("ORCH01 app timer init anchor missing")
s=s.replace(anchor,repl,1)

# Time both aggregation calls inclusively.
needle="        call aggregate_groundwater_cell_tiles(self%cells(i)%topology%groundwater_cell_id, exchanges, aggregate, local_status)\n"
if s.count(needle) != 2: raise SystemExit(f"ORCH01 expected two aggregation calls, found {s.count(needle)}")
replacement="""        orch_phase_t0 = omp_get_wtime()
        call aggregate_groundwater_cell_tiles(self%cells(i)%topology%groundwater_cell_id, exchanges, aggregate, local_status)
        orch_agg = orch_agg + (omp_get_wtime() - orch_phase_t0)
"""
s=s.replace(needle,replacement,2)

# Parallel-path map phase.
anchor="""      do i = 1, size(self%cells)
        if (.not. ieee_is_finite(cell_heads_m(i))) return
        first = self%cells(i)%tile_begin
"""
repl="""      orch_phase_t0 = omp_get_wtime()
      do i = 1, size(self%cells)
        if (.not. ieee_is_finite(cell_heads_m(i))) return
        first = self%cells(i)%tile_begin
"""
# There are two such loops (serial and parallel); instrument the second only.
pos1=s.find(anchor)
pos2=s.find(anchor,pos1+1)
if pos2 < 0: raise SystemExit("ORCH01 parallel map start anchor missing")
s=s[:pos2]+s[pos2:].replace(anchor,repl,1)

anchor="""        tile_heads_m(first:last) = cell_heads_m(i)
      end do

      worker_load = 0.0_real64
"""
repl="""        tile_heads_m(first:last) = cell_heads_m(i)
      end do
      orch_map = omp_get_wtime() - orch_phase_t0

      orch_phase_t0 = omp_get_wtime()
      worker_load = 0.0_real64
"""
if anchor not in s: raise SystemExit("ORCH01 parallel map end anchor missing")
s=s.replace(anchor,repl,1)

anchor="""        order(idx) = idx
      end do

      mean_load = sum(worker_load) / real(self%worker_count, real64)
"""
repl="""        order(idx) = idx
      end do
      orch_cost = omp_get_wtime() - orch_phase_t0

      orch_phase_t0 = omp_get_wtime()
      mean_load = sum(worker_load) / real(self%worker_count, real64)
"""
if anchor not in s: raise SystemExit("ORCH01 cost end anchor missing")
s=s.replace(anchor,repl,1)

anchor="""        self%last_parallel_schedule = FMR_GW_PARALLEL_SCHEDULE_COST_AWARE
      end if

!$omp parallel do"""
repl="""        self%last_parallel_schedule = FMR_GW_PARALLEL_SCHEDULE_COST_AWARE
      end if
      orch_sched = omp_get_wtime() - orch_phase_t0

      orch_phase_t0 = omp_get_wtime()
!$omp parallel do"""
if anchor not in s: raise SystemExit("ORCH01 schedule end anchor missing")
s=s.replace(anchor,repl,1)

anchor="""!$omp end parallel do

      if (any(registry_status /= FMR_GW_REGISTRY_OK) .or. .not. all(self%trial_valid)) then
"""
repl="""!$omp end parallel do
      orch_trial = omp_get_wtime() - orch_phase_t0
      call orch01_read_backend_timers(orch_backend_max, orch_backend_sum)

      orch_phase_t0 = omp_get_wtime()
      if (any(registry_status /= FMR_GW_REGISTRY_OK) .or. .not. all(self%trial_valid)) then
"""
if anchor not in s: raise SystemExit("ORCH01 trial end anchor missing")
s=s.replace(anchor,repl,1)

anchor="""        return
      end if

      do i = 1, size(self%cells)
"""
repl="""        return
      end if
      orch_validate = omp_get_wtime() - orch_phase_t0

      do i = 1, size(self%cells)
"""
# Replace only the occurrence immediately after parallel validation. Find after marker.
mark="orch_phase_t0 = omp_get_wtime()\n      if (any(registry_status"
m=s.find(mark)
if m<0: raise SystemExit("ORCH01 validation marker missing")
tail=s[m:]
if anchor not in tail: raise SystemExit("ORCH01 validation end anchor missing")
tail=tail.replace(anchor,repl,1)
s=s[:m]+tail

# Before successful exit, read backend timers for worker=1 too and print one row.
anchor="""    if (.not. all(self%trial_valid)) then
      status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
"""
repl="""    if (self%worker_count == 1) call orch01_read_backend_timers(orch_backend_max, orch_backend_sum)
    orch_total = omp_get_wtime() - orch_total_t0
    write(*,'(A,I0,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16)') &
         'ORCH01_PHASE|W=', self%worker_count, '|TOTAL=', orch_total, '|MAP=', orch_map, '|COST=', orch_cost, &
         '|SCHED=', orch_sched, '|TRIAL=', orch_trial, '|VALIDATE=', orch_validate, '|AGG=', orch_agg, &
         '|BACKEND_MAX=', orch_backend_max, '|BACKEND_SUM=', orch_backend_sum

    if (.not. all(self%trial_valid)) then
      status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
"""
if anchor not in s: raise SystemExit("ORCH01 summary anchor missing")
s=s.replace(anchor,repl,1)

Path(sys.argv[1]).write_text(s)
PY

# Build a temporary MULTI04 runner that substitutes only the two instrumented sources.
python3 - "$BUILD/runner.sh" "$APP_SRC" "$PART_SRC" "$ROOT" <<'PY'
from pathlib import Path
import sys
runner=Path("tests/fpe/run_fpe_multi04_p1c_application_context_scaling.sh").read_text()
app=Path(sys.argv[2]).resolve()
part=Path(sys.argv[3]).resolve()
root=Path(sys.argv[4]).resolve()

old_root='ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"\ncd "$ROOT"'
new_root=f'ROOT="{root}"\ncd "$ROOT"'
if old_root not in runner: raise SystemExit("ORCH01 runner root seam missing")
runner=runner.replace(old_root,new_root,1)

runner=runner.replace(
'python3 - "$fixture" <<\'PY\'',
'python3 - "$fixture" "$ORCH01_APP_SOURCE" "$ORCH01_PART_SOURCE" <<\'PY\'',
1)
runner=runner.replace(
'fixture=Path(sys.argv[1]).resolve()\n',
'fixture=Path(sys.argv[1]).resolve()\napp=Path(sys.argv[2]).resolve()\npart=Path(sys.argv[3]).resolve()\n',
1)
old='''    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    else:
        print(p)
'''
new='''    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    elif p=="src/runtime/mod_fmr_groundwater_application_context.f90":
        print(app)
    elif p=="src/runtime/mod_fmr_groundwater_swap_participant.f90":
        print(part)
    else:
        print(p)
'''
if old not in runner: raise SystemExit("ORCH01 module substitution seam missing")
runner=runner.replace(old,new,1)
Path(sys.argv[1]).write_text(runner)
PY
chmod +x "$BUILD/runner.sh"

ORCH01_APP_SOURCE="$APP_SRC" ORCH01_PART_SOURCE="$PART_SRC" MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS"   bash "$BUILD/runner.sh" | tee "$BUILD/raw.txt"

python3 - "$N" "$BUILD/raw.txt" <<'PY'
import re, statistics, sys
n=int(sys.argv[1]); txt=open(sys.argv[2]).read()
pat=re.compile(
 r'ORCH01_PHASE\|W=(\d+)\|TOTAL=\s*([^|]+)\|MAP=\s*([^|]+)\|COST=\s*([^|]+)\|'
 r'SCHED=\s*([^|]+)\|TRIAL=\s*([^|]+)\|VALIDATE=\s*([^|]+)\|AGG=\s*([^|]+)\|'
 r'BACKEND_MAX=\s*([^|]+)\|BACKEND_SUM=\s*([^\n]+)'
)
rows={1:[],2:[],4:[]}
for m in pat.finditer(txt):
    w=int(m.group(1))
    if w in rows:
        vals=list(map(float,m.groups()[1:]))
        rows[w].append(vals)
for w in (1,4):
    if len(rows[w]) < 2:
        raise SystemExit(f"insufficient ORCH01 timing rows for worker={w}: {len(rows[w])}")
    # Drop the first instrumented warm-up row; median remaining rows.
    data=rows[w][1:]
    med=[statistics.median([r[j] for r in data]) for j in range(9)]
    total,map_s,cost,sched,trial,valid,agg,bmax,bsum=med
    backend_share=(bmax/total) if total>0 else 0.0
    explicit_orch=map_s+cost+sched+valid+agg
    explicit_share=(explicit_orch/total) if total>0 else 0.0
    trial_residual=max(0.0,trial-bmax)
    residual_share=(trial_residual/total) if total>0 else 0.0
    print(
      f"ORCH01_SUMMARY|N={n}|W={w}|TOTAL={total:.12f}|MAP={map_s:.12f}|COST={cost:.12f}|"
      f"SCHED={sched:.12f}|TRIAL={trial:.12f}|VALIDATE={valid:.12f}|AGG={agg:.12f}|"
      f"BACKEND_MAX={bmax:.12f}|BACKEND_SUM={bsum:.12f}|BACKEND_SHARE={backend_share:.6f}|"
      f"EXPLICIT_ORCH_SHARE={explicit_share:.6f}|TRIAL_RESIDUAL_SHARE={residual_share:.6f}"
    )
print("FPE_ORCH01_DECOMPOSITION=PASS")
PY
