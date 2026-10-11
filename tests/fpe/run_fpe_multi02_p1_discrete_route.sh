#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi02-p1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/mod" "$BUILD/patch"
trap 'rm -rf "$BUILD"' EXIT

cp src/runtime/mod_fmr_groundwater_swap_participant.f90 "$BUILD/patch/mod_fmr_groundwater_swap_participant.f90"
cp src/runtime/mod_fmr_groundwater_participant_registry.f90 "$BUILD/patch/mod_fmr_groundwater_participant_registry.f90"

python3 - "$BUILD/patch/mod_fmr_groundwater_swap_participant.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
needle="    procedure, public :: tangent_cache_counts => fmr_swap_tangent_cache_counts\n"
repl=needle+"    procedure, public :: multi02_diagnostics => fmr_swap_multi02_diagnostics\n"
if needle not in s: raise SystemExit("participant procedure seam")
s=s.replace(needle,repl,1)
needle="end module mod_fmr_groundwater_swap_participant"
insert="""
  subroutine fmr_swap_multi02_diagnostics(self, diagnostics)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    diagnostics = self%diagnostics
  end subroutine fmr_swap_multi02_diagnostics

"""
if needle not in s: raise SystemExit("participant end seam")
s=s.replace(needle,insert+needle,1)
p.write_text(s)
PY

python3 - "$BUILD/patch/mod_fmr_groundwater_participant_registry.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
s=s.replace(
"  use mod_kernel_transactions, only: kernel_committed_state_t\n",
"  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_diagnostics_t\n",1)
needle="    procedure, public :: quiescent => registry_quiescent\n"
repl=needle+"    procedure, public :: multi02_diagnostics => registry_multi02_diagnostics\n"
if needle not in s: raise SystemExit("registry procedure seam")
s=s.replace(needle,repl,1)
needle="  subroutine resolve_handle(self, handle, idx, status)"
insert="""
  subroutine registry_multi02_diagnostics(self, handle, diagnostics, status)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self
    integer(int64), intent(in) :: handle
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status
    integer :: idx

    diagnostics = kernel_diagnostics_t()
    call resolve_handle_const(self, handle, idx, status)
    if (status /= FMR_GW_REGISTRY_OK) return
    call self%slots(idx)%participant%multi02_diagnostics(diagnostics)
    status = FMR_GW_REGISTRY_OK
  end subroutine registry_multi02_diagnostics

"""
if needle not in s: raise SystemExit("registry insertion seam")
s=s.replace(needle,insert+needle,1)
p.write_text(s)
PY

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
src=Path("tests/fpe/run_fpe_multi02_p0_worker_local.sh").read_text()
marker='cat > "$BUILD/test.f90" <<\'F90\'\n'
a=src.index(marker)+len(marker)
b=src.index("\nF90\n\nCOMMON=",a)
f=src[a:b]

f=f.replace(
"  use mod_kernel_transactions, only: kernel_committed_state_t\n",
"  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_diagnostics_t\n",1)
f=f.replace(
"  integer(int64), allocatable :: handles(:)\n"
"  type(groundwater_swap_trial_t), allocatable :: serial_trials(:), parallel_trials(:)\n",
"  integer(int64), allocatable :: handles(:)\n"
"  integer(int64) :: id_tile, id_lineage, id_revision\n"
"  logical :: id_origin, id_candidate\n"
"  type(groundwater_swap_trial_t), allocatable :: serial_trials(:), parallel_trials(:)\n"
"  type(kernel_diagnostics_t), allocatable :: serial_diag(:), parallel_diag(:)\n",1)
f=f.replace(
"  allocate(serial_trials(n),parallel_trials(n),pstatus(n),rstatus(n))\n",
"  allocate(serial_trials(n),parallel_trials(n),serial_diag(n),parallel_diag(n),pstatus(n),rstatus(n))\n",1)

needle="""    call system_clock(c1)
    serial_t(rep)=real(c1-c0,real64)/real(rate,real64)
    do i=1,n
      call registry%discard_candidate(handles(i),status)
"""
repl="""    call system_clock(c1)
    serial_t(rep)=real(c1-c0,real64)/real(rate,real64)
    do i=1,n
      call registry%multi02_diagnostics(handles(i),serial_diag(i),status)
      if(status/=FMR_GW_REGISTRY_OK) error stop 'serial diagnostics'
      call registry%identity(handles(i),id_tile,id_lineage,id_revision,id_origin,id_candidate,status)
      if(status/=FMR_GW_REGISTRY_OK .or. .not.id_origin .or. .not.id_candidate .or. id_revision/=0_int64) &
           error stop 'serial candidate ownership'
    end do
    do i=1,n
      call registry%discard_candidate(handles(i),status)
"""
if needle not in f: raise SystemExit("serial insertion seam")
f=f.replace(needle,repl,1)

needle="""    if(any(rstatus/=FMR_GW_REGISTRY_OK) .or. any(pstatus/=GW_SWAP_PARTICIPANT_OK) .or. &
       any(.not.parallel_trials%valid)) error stop 'parallel trial'
    do i=1,n
      qdiff=max(qdiff,abs(parallel_trials(i)%q_swap_m_per_s-serial_trials(i)%q_swap_m_per_s))
"""
repl="""    if(any(rstatus/=FMR_GW_REGISTRY_OK) .or. any(pstatus/=GW_SWAP_PARTICIPANT_OK) .or. &
       any(.not.parallel_trials%valid)) error stop 'parallel trial'
    do i=1,n
      call registry%multi02_diagnostics(handles(i),parallel_diag(i),status)
      if(status/=FMR_GW_REGISTRY_OK) error stop 'parallel diagnostics'
      if(.not.diagnostics_equal(serial_diag(i),parallel_diag(i))) error stop 'discrete route drift'
      call registry%identity(handles(i),id_tile,id_lineage,id_revision,id_origin,id_candidate,status)
      if(status/=FMR_GW_REGISTRY_OK .or. .not.id_origin .or. .not.id_candidate .or. id_revision/=0_int64) &
           error stop 'parallel candidate ownership'
      qdiff=max(qdiff,abs(parallel_trials(i)%q_swap_m_per_s-serial_trials(i)%q_swap_m_per_s))
"""
if needle not in f: raise SystemExit("parallel insertion seam")
f=f.replace(needle,repl,1)

needle="""    do i=1,n
      call registry%discard_candidate(handles(i),status)
      if(status/=FMR_GW_REGISTRY_OK) error stop 'parallel discard'
    end do
  end do
"""
repl="""    do i=1,n
      call registry%discard_candidate(handles(i),status)
      if(status/=FMR_GW_REGISTRY_OK) error stop 'parallel discard'
      call registry%identity(handles(i),id_tile,id_lineage,id_revision,id_origin,id_candidate,status)
      if(status/=FMR_GW_REGISTRY_OK .or. .not.id_origin .or. id_candidate .or. id_revision/=0_int64) &
           error stop 'discard ownership'
    end do
    if(.not.registry%quiescent()) error stop 'registry not quiescent after discard'
  end do
"""
if needle not in f: raise SystemExit("discard insertion seam")
f=f.replace(needle,repl,1)

needle="  subroutine sort5(v)\n"
helper="""  logical function diagnostics_equal(a,b) result(equal)
    type(kernel_diagnostics_t), intent(in) :: a,b
    equal = &
      a%transaction_calls == b%transaction_calls .and. &
      a%accepted_substeps == b%accepted_substeps .and. &
      a%attempts == b%attempts .and. &
      a%retries == b%retries .and. &
      a%solver_rejections == b%solver_rejections .and. &
      a%temporal_rejections == b%temporal_rejections .and. &
      a%internal_retries == b%internal_retries .and. &
      a%nonlinear_iterations == b%nonlinear_iterations .and. &
      a%jacobian_builds == b%jacobian_builds .and. &
      a%linear_solves == b%linear_solves .and. &
      a%backtracking_attempts == b%backtracking_attempts .and. &
      a%temporal_acceptance_source == b%temporal_acceptance_source
  end function diagnostics_equal

"""
if needle not in f: raise SystemExit("helper seam")
f=f.replace(needle,helper+needle,1)
f=f.replace("MULTI02_P0|","MULTI02_P1|")
f=f.replace("FPE_MULTI02_P0=PASS","FPE_MULTI02_P1_CASE=PASS")
Path("$BUILD/test.f90").write_text(f)
PY

COMMON=(-std=f2008 -ffree-line-length-none -O3 -fopenmp)
mapfile -t MODULE_SRC < <(python3 - <<'PY'
from pathlib import Path
s=Path("tests/fpe/run_fpe_profile04_repeated_decomposition.sh").read_text()
a=s.index("MODULE_SRC=(")+len("MODULE_SRC=(")
b=s.index("\n)\n",a)
for line in s[a:b].splitlines():
    line=line.strip()
    if line:
        if line=="src/runtime/mod_fmr_groundwater_swap_participant.f90":
            print("$BUILD/patch/mod_fmr_groundwater_swap_participant.f90")
        elif line=="src/runtime/mod_fmr_groundwater_participant_registry.f90":
            print("$BUILD/patch/mod_fmr_groundwater_participant_registry.f90")
        else:
            print(line)
PY
)

objects=()
for src in "${MODULE_SRC[@]}"; do
  obj="$BUILD/mod/$(basename "${src%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" -c "$src" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" -c "$BUILD/test.f90" -o "$BUILD/test.o"
gfortran -O3 -fopenmp "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

OUT="$BUILD/out.txt"; : > "$OUT"
for n in 100 1000; do
  for w in 1 2 4; do
    "$BUILD/test" "$n" "$w" | tee -a "$OUT"
  done
done

python3 - "$OUT" <<'PY'
import sys
rows=[]
passes=0
for line in open(sys.argv[1]):
    if line.strip()=="FPE_MULTI02_P1_CASE=PASS": passes+=1
    if not line.startswith("MULTI02_P1|"): continue
    d={}
    for part in line.strip().split("|")[1:]:
        k,v=part.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=6 or passes!=6:
    raise SystemExit(f"expected 6 rows/passes got rows={len(rows)} passes={passes}")
by={(int(r["N"]),int(r["WORKERS"])):r for r in rows}
for n in (100,1000):
    base=float(by[(n,1)]["PARALLEL_SECONDS"])
    for w in (1,2,4):
        r=by[(n,w)]; sec=float(r["PARALLEL_SECONDS"]); speed=base/sec
        print(f"MULTI02_P1_SUMMARY|N={n}|WORKERS={w}|SECONDS={sec:.9f}|SPEEDUP={speed:.6f}|EFFICIENCY={speed/w:.6f}|MAX_Q_DIFF={r['MAX_Q_DIFF']}|MAX_T_DIFF={r['MAX_T_DIFF']}|MAX_SIMULTANEOUS={r['MAX_SIMULTANEOUS']}")
if float(by[(1000,2)]["PARALLEL_SECONDS"])<=0 or float(by[(1000,4)]["PARALLEL_SECONDS"])<=0:
    raise SystemExit("invalid timing")
s2=float(by[(1000,1)]["PARALLEL_SECONDS"])/float(by[(1000,2)]["PARALLEL_SECONDS"])
s4=float(by[(1000,1)]["PARALLEL_SECONDS"])/float(by[(1000,4)]["PARALLEL_SECONDS"])
if s2<1.5: raise SystemExit(f"2-worker gate failed {s2}")
if s4<2.2: raise SystemExit(f"4-worker gate failed {s4}")
print(f"MULTI02_P1_GATE|N=1000|SPEEDUP2={s2:.6f}|SPEEDUP4={s4:.6f}|DISCRETE_ROUTE=IDENTICAL|OWNERSHIP=PASS")
print("FPE_MULTI02_P1=PASS")
PY
