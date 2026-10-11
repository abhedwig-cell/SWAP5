#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-phys01-${GITHUB_RUN_ID:-local}-$$"
N="${PHYS01_N:-10000}"
REPS="${PHYS01_REPS:-5}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_PHYS01_FAIL $*" >&2; exit 1; }

BACKEND_SRC="$BUILD/mod_fmr_serialized_reference_backend_phys01.f90"
APP_SRC="$BUILD/mod_fmr_groundwater_application_context_phys01.f90"

python3 - "$BACKEND_SRC" <<'PY'
from pathlib import Path
import sys
s=Path("src/runtime/mod_fmr_serialized_reference_backend.f90").read_text()

s=s.replace(
"module mod_fmr_serialized_reference_backend\n",
"module mod_fmr_serialized_reference_backend\n  use omp_lib, only: omp_get_wtime, omp_get_thread_num\n",
1)

anchor="  integer, parameter, public :: B110_SWBOTB2_OK = 0\n"
state="""  real(real64), save :: phys01_backend_seconds(0:63) = 0.0_real64
  real(real64), save :: phys01_advance_seconds(0:63) = 0.0_real64
  real(real64), save :: phys01_solver_seconds(0:63) = 0.0_real64
  real(real64), save :: phys01_temporal_seconds(0:63) = 0.0_real64

"""
if anchor not in s: raise SystemExit("PHYS01 backend state anchor missing")
s=s.replace(anchor,state+anchor,1)

anchor="  public :: fmr_new_b110_boesten_evaporation_committed_state\n\ncontains\n"
repl="""  public :: fmr_new_b110_boesten_evaporation_committed_state
  public :: phys01_reset_timers, phys01_read_timers

contains

  subroutine phys01_reset_timers()
    phys01_backend_seconds = 0.0_real64
    phys01_advance_seconds = 0.0_real64
    phys01_solver_seconds = 0.0_real64
    phys01_temporal_seconds = 0.0_real64
  end subroutine phys01_reset_timers

  subroutine phys01_read_timers(backend_max, backend_sum, advance_max, advance_sum, solver_max, solver_sum, temporal_max, temporal_sum)
    real(real64), intent(out) :: backend_max, backend_sum, advance_max, advance_sum
    real(real64), intent(out) :: solver_max, solver_sum, temporal_max, temporal_sum
    backend_max = maxval(phys01_backend_seconds)
    backend_sum = sum(phys01_backend_seconds)
    advance_max = maxval(phys01_advance_seconds)
    advance_sum = sum(phys01_advance_seconds)
    solver_max = maxval(phys01_solver_seconds)
    solver_sum = sum(phys01_solver_seconds)
    temporal_max = maxval(phys01_temporal_seconds)
    temporal_sum = sum(phys01_temporal_seconds)
  end subroutine phys01_read_timers

"""
if anchor not in s: raise SystemExit("PHYS01 backend public anchor missing")
s=s.replace(anchor,repl,1)

# backend run_trial timer
anchor="    logical :: bottom_thermal_ok, top_sensible_ok\n\n"
repl=anchor+"    real(real64) :: phys01_t0\n    integer :: phys01_tid\n\n"
if anchor not in s: raise SystemExit("PHYS01 run_trial decl anchor missing")
s=s.replace(anchor,repl,1)

anchor="""    call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
         result, candidate, diagnostics)
"""
repl="""    phys01_tid = min(63, max(0, omp_get_thread_num()))
    phys01_t0 = omp_get_wtime()
    call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
         result, candidate, diagnostics)
    phys01_backend_seconds(phys01_tid) = phys01_backend_seconds(phys01_tid) + (omp_get_wtime() - phys01_t0)
"""
if anchor not in s: raise SystemExit("PHYS01 checkpoint call anchor missing")
s=s.replace(anchor,repl,1)

# advance timer declarations
anchor="    character(len=64) :: drainage_direction_route\n"
repl=anchor+"    real(real64) :: phys01_advance_t0, phys01_phase_t0\n    integer :: phys01_tid\n"
if anchor not in s: raise SystemExit("PHYS01 advance decl anchor missing")
s=s.replace(anchor,repl,1)

anchor="    outcome = trial_outcome_t()\n"
repl="""    outcome = trial_outcome_t()
    phys01_tid = min(63, max(0, omp_get_thread_num()))
    phys01_advance_t0 = omp_get_wtime()
"""
if anchor not in s: raise SystemExit("PHYS01 advance start anchor missing")
s=s.replace(anchor,repl,1)

solver_block="""    if (self%soil_water_selection%uses_rossfast()) then
      call self%soil_water_selection%solve(request, solve_result)
    else if (trajectory_request_ok) then
      if (self%drainage_qbot_smooth_freatic_projection .and. .not. drainage_direction_available) then
        call self%solver%solve(request, self%workspace, solve_result)
        direction_result = soil_water_accepted_step_direction_result_t()
        direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
        direction_result%control_coordinate = self%trajectory_request_workspace%control_coordinate
        direction_result%route = drainage_direction_route
      else
        call solve_with_accepted_step_direction(self%solver, request, self%workspace, self%trajectory_request_workspace, &
             solve_result, direction_result)
        trajectory_solver_used = .true.
      end if
      call stage_trajectory_step_result(self%trajectory_direction, direction_token, direction_result, trajectory_stage_ok)
    else
      call self%solver%solve(request, self%workspace, solve_result)
    end if

"""
if solver_block not in s: raise SystemExit("PHYS01 solver block anchor missing")
s=s.replace(solver_block,
"""    phys01_phase_t0 = omp_get_wtime()
"""+solver_block+"""    phys01_solver_seconds(phys01_tid) = phys01_solver_seconds(phys01_tid) + (omp_get_wtime() - phys01_phase_t0)

""",1)

temporal_block="""    else if (self%temporal_indicator_history_enabled) then
      call evaluate_temporal_history_service(self, state, request, solve_result, outcome, temporal_history_ok)
      if (.not. temporal_history_ok) return
    end if
"""
if temporal_block not in s: raise SystemExit("PHYS01 temporal block anchor missing")
s=s.replace(temporal_block,
"""    else if (self%temporal_indicator_history_enabled) then
      phys01_phase_t0 = omp_get_wtime()
      call evaluate_temporal_history_service(self, state, request, solve_result, outcome, temporal_history_ok)
      phys01_temporal_seconds(phys01_tid) = phys01_temporal_seconds(phys01_tid) + (omp_get_wtime() - phys01_phase_t0)
      if (.not. temporal_history_ok) return
    end if
""",1)

anchor="    outcome%solver_ok = .true.\n"
repl="""    phys01_advance_seconds(phys01_tid) = phys01_advance_seconds(phys01_tid) + (omp_get_wtime() - phys01_advance_t0)
    outcome%solver_ok = .true.
"""
if anchor not in s: raise SystemExit("PHYS01 advance end anchor missing")
s=s.replace(anchor,repl,1)

Path(sys.argv[1]).write_text(s)
PY

python3 - "$APP_SRC" <<'PY'
from pathlib import Path
import sys
s=Path("src/runtime/mod_fmr_groundwater_application_context.f90").read_text()

old="""  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t
"""
new="""  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t, &
       phys01_reset_timers, phys01_read_timers
"""
if old not in s: raise SystemExit("PHYS01 app backend use anchor missing")
s=s.replace(old,new,1)

anchor="    real(real64) :: mean_load, best_load\n"
repl=anchor+"""    real(real64) :: phys_backend_max, phys_backend_sum, phys_advance_max, phys_advance_sum
    real(real64) :: phys_solver_max, phys_solver_sum, phys_temporal_max, phys_temporal_sum
"""
if anchor not in s: raise SystemExit("PHYS01 app decl anchor missing")
s=s.replace(anchor,repl,1)

anchor="""    self%last_parallel_schedule = FMR_GW_PARALLEL_SCHEDULE_SERIAL
    self%last_static_load_ratio = 1.0_real64
    self%last_selected_load_ratio = 1.0_real64

"""
repl=anchor+"""    call phys01_reset_timers()

"""
if anchor not in s: raise SystemExit("PHYS01 app reset anchor missing")
s=s.replace(anchor,repl,1)

anchor="""    if (.not. all(self%trial_valid)) then
      status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
"""
repl="""    call phys01_read_timers(phys_backend_max, phys_backend_sum, phys_advance_max, phys_advance_sum, &
         phys_solver_max, phys_solver_sum, phys_temporal_max, phys_temporal_sum)
    write(*,'(A,I0,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16)') &
         'PHYS01_PHASE|W=', self%worker_count, '|BACKEND_MAX=', phys_backend_max, '|BACKEND_SUM=', phys_backend_sum, &
         '|ADVANCE_MAX=', phys_advance_max, '|ADVANCE_SUM=', phys_advance_sum, '|SOLVER_MAX=', phys_solver_max, &
         '|SOLVER_SUM=', phys_solver_sum, '|TEMPORAL_MAX=', phys_temporal_max, '|TEMPORAL_SUM=', phys_temporal_sum

    if (.not. all(self%trial_valid)) then
      status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
"""
if anchor not in s: raise SystemExit("PHYS01 app summary anchor missing")
s=s.replace(anchor,repl,1)

Path(sys.argv[1]).write_text(s)
PY

python3 - "$BUILD/runner.sh" "$BACKEND_SRC" "$APP_SRC" "$ROOT" <<'PY'
from pathlib import Path
import sys
runner=Path("tests/fpe/run_fpe_multi04_p1c_application_context_scaling.sh").read_text()
backend=Path(sys.argv[2]).resolve()
app=Path(sys.argv[3]).resolve()
root=Path(sys.argv[4]).resolve()

old_root='ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"\ncd "$ROOT"'
if old_root not in runner: raise SystemExit("PHYS01 runner root seam missing")
runner=runner.replace(old_root,f'ROOT="{root}"\ncd "$ROOT"',1)

runner=runner.replace(
'python3 - "$fixture" <<\'PY\'',
'python3 - "$fixture" "$PHYS01_BACKEND_SOURCE" "$PHYS01_APP_SOURCE" <<\'PY\'',
1)
runner=runner.replace(
'fixture=Path(sys.argv[1]).resolve()\n',
'fixture=Path(sys.argv[1]).resolve()\nbackend=Path(sys.argv[2]).resolve()\napp=Path(sys.argv[3]).resolve()\n',
1)
old='''    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    else:
        print(p)
'''
new='''    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    elif p=="src/runtime/mod_fmr_serialized_reference_backend.f90":
        print(backend)
    elif p=="src/runtime/mod_fmr_groundwater_application_context.f90":
        print(app)
    else:
        print(p)
'''
if old not in runner: raise SystemExit("PHYS01 module substitution seam missing")
runner=runner.replace(old,new,1)
Path(sys.argv[1]).write_text(runner)
PY
chmod +x "$BUILD/runner.sh"

PHYS01_BACKEND_SOURCE="$BACKEND_SRC" PHYS01_APP_SOURCE="$APP_SRC" MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS"   bash "$BUILD/runner.sh" | tee "$BUILD/raw.txt"

python3 - "$N" "$BUILD/raw.txt" <<'PY'
import re, statistics, sys
n=int(sys.argv[1]); txt=open(sys.argv[2]).read()
pat=re.compile(
 r'PHYS01_PHASE\|W=(\d+)\|BACKEND_MAX=\s*([^|]+)\|BACKEND_SUM=\s*([^|]+)\|'
 r'ADVANCE_MAX=\s*([^|]+)\|ADVANCE_SUM=\s*([^|]+)\|SOLVER_MAX=\s*([^|]+)\|'
 r'SOLVER_SUM=\s*([^|]+)\|TEMPORAL_MAX=\s*([^|]+)\|TEMPORAL_SUM=\s*([^\n]+)'
)
rows={1:[],2:[],4:[]}
for m in pat.finditer(txt):
    w=int(m.group(1))
    if w in rows:
        rows[w].append(list(map(float,m.groups()[1:])))
for w in (1,4):
    if len(rows[w]) < 2:
        raise SystemExit(f"insufficient PHYS01 timing rows for worker={w}: {len(rows[w])}")
    data=rows[w][1:]
    med=[statistics.median([r[j] for r in data]) for j in range(8)]
    bmax,bsum,amax,asum,smax,ssum,tmax,tsum=med
    backend_res=max(0.0,bmax-amax)
    advance_res=max(0.0,amax-smax-tmax)
    print(
      f"PHYS01_SUMMARY|N={n}|W={w}|BACKEND_MAX={bmax:.12f}|ADVANCE_MAX={amax:.12f}|"
      f"SOLVER_MAX={smax:.12f}|TEMPORAL_MAX={tmax:.12f}|BACKEND_RESIDUAL={backend_res:.12f}|"
      f"ADVANCE_RESIDUAL={advance_res:.12f}|SOLVER_SHARE={(smax/bmax if bmax else 0):.6f}|"
      f"TEMPORAL_SHARE={(tmax/bmax if bmax else 0):.6f}|TRANSACTION_SHARE={(backend_res/bmax if bmax else 0):.6f}|"
      f"ADVANCE_RESIDUAL_SHARE={(advance_res/bmax if bmax else 0):.6f}|BACKEND_SUM={bsum:.12f}|"
      f"ADVANCE_SUM={asum:.12f}|SOLVER_SUM={ssum:.12f}|TEMPORAL_SUM={tsum:.12f}"
    )
print("FPE_PHYS01_BACKEND_DECOMPOSITION=PASS")
PY
