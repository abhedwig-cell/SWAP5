#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-temporal09-${GITHUB_RUN_ID:-local}-$$"
N="${TEMPORAL09_N:-10000}"
REPS="${TEMPORAL09_REPS:-5}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

IND_SRC="$BUILD/mod_reference_richards_temporal_indicator_temporal09.f90"
BACKEND_SRC="$BUILD/mod_fmr_serialized_reference_backend_temporal09.f90"
APP_SRC="$BUILD/mod_fmr_groundwater_application_context_temporal09.f90"

python3 - "$IND_SRC" <<'PY'
from pathlib import Path
import sys
s=Path("src/solver/mod_reference_richards_temporal_indicator.f90").read_text()

s=s.replace(
"module mod_reference_richards_temporal_indicator\n",
"module mod_reference_richards_temporal_indicator\n  use omp_lib, only: omp_get_wtime, omp_get_thread_num\n",
1)

anchor="  public :: evaluate_reference_richards_temporal_indicator\n\ncontains\n"
repl="""  real(real64), save :: temporal09_indicator_total(0:63) = 0.0_real64
  real(real64), save :: temporal09_constitutive(0:63) = 0.0_real64
  real(real64), save :: temporal09_assembly(0:63) = 0.0_real64
  real(real64), save :: temporal09_tridag(0:63) = 0.0_real64

  public :: evaluate_reference_richards_temporal_indicator
  public :: temporal09_reset_indicator_timers, temporal09_read_indicator_timers

contains

  subroutine temporal09_reset_indicator_timers()
    temporal09_indicator_total = 0.0_real64
    temporal09_constitutive = 0.0_real64
    temporal09_assembly = 0.0_real64
    temporal09_tridag = 0.0_real64
  end subroutine temporal09_reset_indicator_timers

  subroutine temporal09_read_indicator_timers(total_max, total_sum, constitutive_max, constitutive_sum, &
       assembly_max, assembly_sum, tridag_max, tridag_sum)
    real(real64), intent(out) :: total_max, total_sum, constitutive_max, constitutive_sum
    real(real64), intent(out) :: assembly_max, assembly_sum, tridag_max, tridag_sum
    total_max = maxval(temporal09_indicator_total)
    total_sum = sum(temporal09_indicator_total)
    constitutive_max = maxval(temporal09_constitutive)
    constitutive_sum = sum(temporal09_constitutive)
    assembly_max = maxval(temporal09_assembly)
    assembly_sum = sum(temporal09_assembly)
    tridag_max = maxval(temporal09_tridag)
    tridag_sum = sum(temporal09_tridag)
  end subroutine temporal09_read_indicator_timers

"""
if anchor not in s: raise SystemExit("TEMPORAL09 indicator public anchor missing")
s=s.replace(anchor,repl,1)

anchor="    real(real64) :: scale, water_diff\n"
repl=anchor+"    real(real64) :: temporal09_t0, temporal09_phase_t0\n    integer :: temporal09_tid\n"
if anchor not in s: raise SystemExit("TEMPORAL09 indicator decl anchor missing")
s=s.replace(anchor,repl,1)

anchor="    indicator_result = soil_water_temporal_indicator_result_t()\n"
repl="""    indicator_result = soil_water_temporal_indicator_result_t()
    temporal09_tid = min(63, max(0, omp_get_thread_num()))
    temporal09_t0 = omp_get_wtime()
"""
if anchor not in s: raise SystemExit("TEMPORAL09 indicator start anchor missing")
s=s.replace(anchor,repl,1)

# Constitutive reevaluation block
start=s.index("    allocate(water_base(n), conductivity_base(n), capacity_base(n), dkdh_base(n))")
sel=s.index("    select type (constitutive => request%evaluation%constitutive)", start)
end=s.index("    end select", sel)+len("    end select")
block=s[start:end]
s=s[:start]+"    temporal09_phase_t0 = omp_get_wtime()\n"+block+"\n    temporal09_constitutive(temporal09_tid) = temporal09_constitutive(temporal09_tid) + (omp_get_wtime() - temporal09_phase_t0)"+s[end:]

# Operator assembly through rhs/gamma setup
start=s.index("    allocate(mass_weight(n), lower(n), diagonal(n), upper(n), rhs(n), delta(n), gamma(n), e_raw(n))")
end_marker="    gamma = 0.0_real64\n"
end=s.index(end_marker,start)+len(end_marker)
block=s[start:end]
s=s[:start]+"    temporal09_phase_t0 = omp_get_wtime()\n"+block+"    temporal09_assembly(temporal09_tid) = temporal09_assembly(temporal09_tid) + (omp_get_wtime() - temporal09_phase_t0)\n"+s[end:]

anchor="    call reference_tridag(n, lower, diagonal, upper, rhs, delta, gamma, ierr)\n"
repl="""    temporal09_phase_t0 = omp_get_wtime()
    call reference_tridag(n, lower, diagonal, upper, rhs, delta, gamma, ierr)
    temporal09_tridag(temporal09_tid) = temporal09_tridag(temporal09_tid) + (omp_get_wtime() - temporal09_phase_t0)
"""
if anchor not in s: raise SystemExit("TEMPORAL09 tridag anchor missing")
s=s.replace(anchor,repl,1)

anchor="    indicator_result%available = .true.\n"
repl="""    temporal09_indicator_total(temporal09_tid) = temporal09_indicator_total(temporal09_tid) + (omp_get_wtime() - temporal09_t0)
    indicator_result%available = .true.
"""
if anchor not in s: raise SystemExit("TEMPORAL09 indicator end anchor missing")
s=s.replace(anchor,repl,1)

Path(sys.argv[1]).write_text(s)
PY

python3 - "$BACKEND_SRC" <<'PY'
from pathlib import Path
import sys
s=Path("src/runtime/mod_fmr_serialized_reference_backend.f90").read_text()

s=s.replace(
"module mod_fmr_serialized_reference_backend\n",
"module mod_fmr_serialized_reference_backend\n  use omp_lib, only: omp_get_wtime, omp_get_thread_num\n",
1)

anchor="  integer, parameter, public :: B110_SWBOTB2_OK = 0\n"
state="""  real(real64), save :: temporal09_service_total(0:63) = 0.0_real64
  real(real64), save :: temporal09_service_pre(0:63) = 0.0_real64
  real(real64), save :: temporal09_service_post(0:63) = 0.0_real64

"""
if anchor not in s: raise SystemExit("TEMPORAL09 backend state anchor missing")
s=s.replace(anchor,state+anchor,1)

anchor="  public :: fmr_new_b110_boesten_evaporation_committed_state\n\ncontains\n"
repl="""  public :: fmr_new_b110_boesten_evaporation_committed_state
  public :: temporal09_reset_service_timers, temporal09_read_service_timers

contains

  subroutine temporal09_reset_service_timers()
    temporal09_service_total = 0.0_real64
    temporal09_service_pre = 0.0_real64
    temporal09_service_post = 0.0_real64
  end subroutine temporal09_reset_service_timers

  subroutine temporal09_read_service_timers(total_max, total_sum, pre_max, pre_sum, post_max, post_sum)
    real(real64), intent(out) :: total_max, total_sum, pre_max, pre_sum, post_max, post_sum
    total_max = maxval(temporal09_service_total)
    total_sum = sum(temporal09_service_total)
    pre_max = maxval(temporal09_service_pre)
    pre_sum = sum(temporal09_service_pre)
    post_max = maxval(temporal09_service_post)
    post_sum = sum(temporal09_service_post)
  end subroutine temporal09_read_service_timers

"""
if anchor not in s: raise SystemExit("TEMPORAL09 backend public anchor missing")
s=s.replace(anchor,repl,1)

anchor="    integer :: n\n"
# This occurs in evaluate_temporal_history_service as desired after unique previous context.
pos=s.index("subroutine evaluate_temporal_history_service")
decl=s.index(anchor,pos)
s=s[:decl]+s[decl:].replace(anchor,anchor+"    real(real64) :: temporal09_t0, temporal09_phase_t0\n    integer :: temporal09_tid\n",1)

anchor="    ok = .false.\n    n = request%parameters%active_nodes\n"
pos=s.index(anchor,pos)
repl="""    ok = .false.
    temporal09_tid = min(63, max(0, omp_get_thread_num()))
    temporal09_t0 = omp_get_wtime()
    temporal09_phase_t0 = temporal09_t0
    n = request%parameters%active_nodes
"""
s=s[:pos]+s[pos:].replace(anchor,repl,1)

anchor="    call self%solver%evaluate_temporal_indicator(request, solve_result, indicator_request, self%workspace, indicator_result)\n"
pos=s.index(anchor,pos)
repl="""    temporal09_service_pre(temporal09_tid) = temporal09_service_pre(temporal09_tid) + (omp_get_wtime() - temporal09_phase_t0)
    call self%solver%evaluate_temporal_indicator(request, solve_result, indicator_request, self%workspace, indicator_result)
    temporal09_phase_t0 = omp_get_wtime()
"""
s=s[:pos]+s[pos:].replace(anchor,repl,1)

anchor="    ok = .true.\n  end subroutine evaluate_temporal_history_service\n"
pos=s.index(anchor,pos)
repl="""    temporal09_service_post(temporal09_tid) = temporal09_service_post(temporal09_tid) + (omp_get_wtime() - temporal09_phase_t0)
    temporal09_service_total(temporal09_tid) = temporal09_service_total(temporal09_tid) + (omp_get_wtime() - temporal09_t0)
    ok = .true.
  end subroutine evaluate_temporal_history_service
"""
s=s[:pos]+s[pos:].replace(anchor,repl,1)

Path(sys.argv[1]).write_text(s)
PY

python3 - "$APP_SRC" <<'PY'
from pathlib import Path
import sys
s=Path("src/runtime/mod_fmr_groundwater_application_context.f90").read_text()

old="  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t\n"
new="""  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t, &
       temporal09_reset_service_timers, temporal09_read_service_timers
  use mod_reference_richards_temporal_indicator, only: temporal09_reset_indicator_timers, temporal09_read_indicator_timers
"""
if old not in s: raise SystemExit("TEMPORAL09 app use anchor missing")
s=s.replace(old,new,1)

anchor="    real(real64) :: mean_load, best_load\n"
repl=anchor+"""    real(real64) :: t09_service_max, t09_service_sum, t09_pre_max, t09_pre_sum, t09_post_max, t09_post_sum
    real(real64) :: t09_ind_max, t09_ind_sum, t09_const_max, t09_const_sum
    real(real64) :: t09_asm_max, t09_asm_sum, t09_tri_max, t09_tri_sum
"""
if anchor not in s: raise SystemExit("TEMPORAL09 app decl anchor missing")
s=s.replace(anchor,repl,1)

anchor="""    self%last_parallel_schedule = FMR_GW_PARALLEL_SCHEDULE_SERIAL
    self%last_static_load_ratio = 1.0_real64
    self%last_selected_load_ratio = 1.0_real64

"""
repl=anchor+"""    call temporal09_reset_service_timers()
    call temporal09_reset_indicator_timers()

"""
if anchor not in s: raise SystemExit("TEMPORAL09 app reset anchor missing")
s=s.replace(anchor,repl,1)

anchor="""    if (.not. all(self%trial_valid)) then
      status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
"""
repl="""    call temporal09_read_service_timers(t09_service_max, t09_service_sum, t09_pre_max, t09_pre_sum, t09_post_max, t09_post_sum)
    call temporal09_read_indicator_timers(t09_ind_max, t09_ind_sum, t09_const_max, t09_const_sum, &
         t09_asm_max, t09_asm_sum, t09_tri_max, t09_tri_sum)
    write(*,'(A,I0,14(A,ES24.16))') 'TEMPORAL09_PHASE|W=', self%worker_count, &
         '|SERVICE_MAX=', t09_service_max, '|SERVICE_SUM=', t09_service_sum, &
         '|PRE_MAX=', t09_pre_max, '|PRE_SUM=', t09_pre_sum, '|POST_MAX=', t09_post_max, '|POST_SUM=', t09_post_sum, &
         '|IND_MAX=', t09_ind_max, '|IND_SUM=', t09_ind_sum, '|CONST_MAX=', t09_const_max, '|CONST_SUM=', t09_const_sum, &
         '|ASM_MAX=', t09_asm_max, '|ASM_SUM=', t09_asm_sum, '|TRI_MAX=', t09_tri_max, '|TRI_SUM=', t09_tri_sum

    if (.not. all(self%trial_valid)) then
      status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED
"""
if anchor not in s: raise SystemExit("TEMPORAL09 app summary anchor missing")
s=s.replace(anchor,repl,1)

Path(sys.argv[1]).write_text(s)
PY

python3 - "$BUILD/runner.sh" "$IND_SRC" "$BACKEND_SRC" "$APP_SRC" "$ROOT" <<'PY'
from pathlib import Path
import sys
runner=Path("tests/fpe/run_fpe_multi04_p1c_application_context_scaling.sh").read_text()
ind=Path(sys.argv[2]).resolve(); backend=Path(sys.argv[3]).resolve(); app=Path(sys.argv[4]).resolve(); root=Path(sys.argv[5]).resolve()
old_root='ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"\ncd "$ROOT"'
if old_root not in runner: raise SystemExit("TEMPORAL09 runner root seam missing")
runner=runner.replace(old_root,f'ROOT="{root}"\ncd "$ROOT"',1)
runner=runner.replace(
'python3 - "$fixture" <<\'PY\'',
'python3 - "$fixture" "$TEMPORAL09_IND_SOURCE" "$TEMPORAL09_BACKEND_SOURCE" "$TEMPORAL09_APP_SOURCE" <<\'PY\'',
1)
runner=runner.replace(
'fixture=Path(sys.argv[1]).resolve()\n',
'fixture=Path(sys.argv[1]).resolve()\nind=Path(sys.argv[2]).resolve()\nbackend=Path(sys.argv[3]).resolve()\napp=Path(sys.argv[4]).resolve()\n',
1)
old='''    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    else:
        print(p)
'''
new='''    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    elif p=="src/solver/mod_reference_richards_temporal_indicator.f90":
        print(ind)
    elif p=="src/runtime/mod_fmr_serialized_reference_backend.f90":
        print(backend)
    elif p=="src/runtime/mod_fmr_groundwater_application_context.f90":
        print(app)
    else:
        print(p)
'''
if old not in runner: raise SystemExit("TEMPORAL09 module substitution seam missing")
runner=runner.replace(old,new,1)
Path(sys.argv[1]).write_text(runner)
PY
chmod +x "$BUILD/runner.sh"

TEMPORAL09_IND_SOURCE="$IND_SRC" TEMPORAL09_BACKEND_SOURCE="$BACKEND_SRC" TEMPORAL09_APP_SOURCE="$APP_SRC" MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS" bash "$BUILD/runner.sh" | tee "$BUILD/raw.txt"

python3 - "$N" "$BUILD/raw.txt" <<'PY'
import re, statistics, sys
n=int(sys.argv[1]); txt=open(sys.argv[2]).read()
pat=re.compile(
 r'TEMPORAL09_PHASE\|W=(\d+)\|SERVICE_MAX=\s*([^|]+)\|SERVICE_SUM=\s*([^|]+)\|'
 r'PRE_MAX=\s*([^|]+)\|PRE_SUM=\s*([^|]+)\|POST_MAX=\s*([^|]+)\|POST_SUM=\s*([^|]+)\|'
 r'IND_MAX=\s*([^|]+)\|IND_SUM=\s*([^|]+)\|CONST_MAX=\s*([^|]+)\|CONST_SUM=\s*([^|]+)\|'
 r'ASM_MAX=\s*([^|]+)\|ASM_SUM=\s*([^|]+)\|TRI_MAX=\s*([^|]+)\|TRI_SUM=\s*([^\n]+)'
)
rows={1:[],2:[],4:[]}
for m in pat.finditer(txt):
    w=int(m.group(1))
    if w in rows: rows[w].append(list(map(float,m.groups()[1:])))
for w in (1,4):
    if len(rows[w]) < 2: raise SystemExit(f"insufficient TEMPORAL09 rows W={w}: {len(rows[w])}")
    data=rows[w][1:]
    med=[statistics.median([r[j] for r in data]) for j in range(14)]
    service,ssum,pre,presum,post,postsum,ind,isum,const,csum,asm,asum,tri,trisum=med
    ind_res=max(0.0,ind-const-asm-tri)
    wrapper_res=max(0.0,service-pre-post-ind)
    def share(x): return x/service if service else 0.0
    print(
      f"TEMPORAL09_SUMMARY|N={n}|W={w}|SERVICE={service:.12f}|PRE={pre:.12f}|POST={post:.12f}|"
      f"INDICATOR={ind:.12f}|CONSTITUTIVE={const:.12f}|ASSEMBLY={asm:.12f}|TRIDAG={tri:.12f}|"
      f"INDICATOR_RESIDUAL={ind_res:.12f}|WRAPPER_RESIDUAL={wrapper_res:.12f}|"
      f"CONSTITUTIVE_SHARE={share(const):.6f}|ASSEMBLY_SHARE={share(asm):.6f}|TRIDAG_SHARE={share(tri):.6f}|"
      f"PRE_SHARE={share(pre):.6f}|POST_SHARE={share(post):.6f}|INDICATOR_RESIDUAL_SHARE={share(ind_res):.6f}"
    )
print("FPE_TEMPORAL09_SERVICE_DECOMPOSITION=PASS")
PY
