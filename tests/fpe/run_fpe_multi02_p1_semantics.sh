#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi02-p1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/mod"
trap 'rm -rf "$BUILD"' EXIT

cp src/runtime/mod_fmr_groundwater_swap_participant.f90 "$BUILD/participant.f90"
cp src/runtime/mod_fmr_groundwater_participant_registry.f90 "$BUILD/registry.f90"

python3 - "$BUILD/participant.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
anchor="    procedure, public :: tangent_cache_counts => fmr_swap_tangent_cache_counts\n"
repl=anchor+"    procedure, public :: multi02_diagnostics => fmr_swap_multi02_diagnostics\n"
if anchor not in s: raise SystemExit("participant procedure seam")
s=s.replace(anchor,repl,1)
needle="end module mod_fmr_groundwater_swap_participant"
insert="""
  subroutine fmr_swap_multi02_diagnostics(self,transaction_calls,accepted_substeps,attempts,retries, &
       solver_rejections,temporal_rejections,nonlinear_iterations,backtracking_attempts)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    integer, intent(out) :: transaction_calls,accepted_substeps,attempts,retries
    integer, intent(out) :: solver_rejections,temporal_rejections,nonlinear_iterations,backtracking_attempts
    transaction_calls=self%diagnostics%transaction_calls
    accepted_substeps=self%diagnostics%accepted_substeps
    attempts=self%diagnostics%attempts
    retries=self%diagnostics%retries
    solver_rejections=self%diagnostics%solver_rejections
    temporal_rejections=self%diagnostics%temporal_rejections
    nonlinear_iterations=self%diagnostics%nonlinear_iterations
    backtracking_attempts=self%diagnostics%backtracking_attempts
  end subroutine fmr_swap_multi02_diagnostics

"""
if needle not in s: raise SystemExit("participant end seam")
s=s.replace(needle,insert+needle,1)
p.write_text(s)
PY

python3 - "$BUILD/registry.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
anchor="    procedure, public :: quiescent => registry_quiescent\n"
repl=anchor+"    procedure, public :: multi02_diagnostics => registry_multi02_diagnostics\n"
if anchor not in s: raise SystemExit("registry procedure seam")
s=s.replace(anchor,repl,1)
needle="  subroutine resolve_handle(self, handle, idx, status)\n"
insert="""
  subroutine registry_multi02_diagnostics(self,handle,transaction_calls,accepted_substeps,attempts,retries, &
       solver_rejections,temporal_rejections,nonlinear_iterations,backtracking_attempts,status)
    class(fmr_groundwater_participant_registry_t), intent(in) :: self
    integer(int64), intent(in) :: handle
    integer, intent(out) :: transaction_calls,accepted_substeps,attempts,retries
    integer, intent(out) :: solver_rejections,temporal_rejections,nonlinear_iterations,backtracking_attempts
    integer, intent(out) :: status
    integer :: idx
    transaction_calls=0; accepted_substeps=0; attempts=0; retries=0
    solver_rejections=0; temporal_rejections=0; nonlinear_iterations=0; backtracking_attempts=0
    call resolve_handle_const(self,handle,idx,status)
    if(status/=FMR_GW_REGISTRY_OK)return
    call self%slots(idx)%participant%multi02_diagnostics(transaction_calls,accepted_substeps,attempts,retries, &
         solver_rejections,temporal_rejections,nonlinear_iterations,backtracking_attempts)
    status=FMR_GW_REGISTRY_OK
  end subroutine registry_multi02_diagnostics

"""
if needle not in s: raise SystemExit("registry insertion seam")
s=s.replace(needle,insert+needle,1)
p.write_text(s)
PY

python3 - tests/fpe/run_fpe_multi02_p0_worker_local.sh "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
txt=Path(sys.argv[1]).read_text()
start=txt.index("cat > \"$BUILD/test.f90\" <<'F90'\n")+len("cat > \"$BUILD/test.f90\" <<'F90'\n")
end=txt.index("\nF90\n",start)
s=txt[start:end]

old="  integer :: n,workers,i,w,rep,status,participant_status,active,maxsim,team_seen\n"
new="""  integer :: n,workers,i,w,rep,status,participant_status,active,maxsim,team_seen
  integer :: tc,asub,att,ret,srej,trej,nlit,bt
  integer :: serial_tc,serial_asub,serial_att,serial_ret,serial_srej,serial_trej,serial_nlit,serial_bt
  integer :: parallel_tc,parallel_asub,parallel_att,parallel_ret,parallel_srej,parallel_trej,parallel_nlit,parallel_bt
  integer :: wi, worker_att(4), worker_nlit(4), worker_bt(4)
  real(real64) :: worker_ratio
"""
if old not in s: raise SystemExit("test declaration seam")
s=s.replace(old,new,1)

anchor="  qdiff=0.0_real64; tdiff=0.0_real64\n"
repl=anchor+"""  serial_tc=0; serial_asub=0; serial_att=0; serial_ret=0; serial_srej=0; serial_trej=0; serial_nlit=0; serial_bt=0
  parallel_tc=0; parallel_asub=0; parallel_att=0; parallel_ret=0; parallel_srej=0; parallel_trej=0; parallel_nlit=0; parallel_bt=0
  worker_att=0; worker_nlit=0; worker_bt=0; worker_ratio=1.0_real64
"""
if anchor not in s: raise SystemExit("test init seam")
s=s.replace(anchor,repl,1)

old="""      call registry%trial_from_origin(handles(i),window,target_head(i),serial_trials(i),participant_status,status)
      if(status/=FMR_GW_REGISTRY_OK .or. participant_status/=GW_SWAP_PARTICIPANT_OK .or. .not.serial_trials(i)%valid) &
           error stop 'serial trial'
"""
new=old+"""      call registry%multi02_diagnostics(handles(i),tc,asub,att,ret,srej,trej,nlit,bt,status)
      if(status/=FMR_GW_REGISTRY_OK) error stop 'serial diagnostics'
      if(rep==1)then
        serial_tc=serial_tc+tc; serial_asub=serial_asub+asub; serial_att=serial_att+att
        serial_ret=serial_ret+ret; serial_srej=serial_srej+srej; serial_trej=serial_trej+trej
        serial_nlit=serial_nlit+nlit; serial_bt=serial_bt+bt
      end if
"""
if old not in s: raise SystemExit("serial trial seam")
s=s.replace(old,new,1)

anchor="""    if(team_seen/=workers) error stop 'omp team mismatch'
    if(any(rstatus/=FMR_GW_REGISTRY_OK) .or. any(pstatus/=GW_SWAP_PARTICIPANT_OK) .or. &
       any(.not.parallel_trials%valid)) error stop 'parallel trial'
"""
repl=anchor+"""    if(rep==1)then
      do i=1,n
        call registry%multi02_diagnostics(handles(i),tc,asub,att,ret,srej,trej,nlit,bt,status)
        if(status/=FMR_GW_REGISTRY_OK) error stop 'parallel diagnostics'
        parallel_tc=parallel_tc+tc; parallel_asub=parallel_asub+asub; parallel_att=parallel_att+att
        parallel_ret=parallel_ret+ret; parallel_srej=parallel_srej+srej; parallel_trej=parallel_trej+trej
        parallel_nlit=parallel_nlit+nlit; parallel_bt=parallel_bt+bt
        wi=1+mod(i-1,workers)
        worker_att(wi)=worker_att(wi)+att
        worker_nlit(wi)=worker_nlit(wi)+nlit
        worker_bt(wi)=worker_bt(wi)+bt
      end do
    end if
"""
if anchor not in s: raise SystemExit("parallel diagnostics seam")
s=s.replace(anchor,repl,1)

anchor="""  if(tdiff>256.0_real64*epsilon(1.0_real64)*max(1.0_real64,maxval(abs(serial_trials%dq_swap_dh_per_s)))) &
       error stop 'tangent semantic drift'

"""
repl=anchor+"""  if(workers>0 .and. sum(worker_nlit(1:workers))>0) worker_ratio= &
       real(maxval(worker_nlit(1:workers)),real64)/(real(sum(worker_nlit(1:workers)),real64)/real(workers,real64))
  if(serial_tc/=parallel_tc .or. serial_asub/=parallel_asub .or. serial_att/=parallel_att .or. &
     serial_ret/=parallel_ret .or. serial_srej/=parallel_srej .or. serial_trej/=parallel_trej .or. &
     serial_nlit/=parallel_nlit .or. serial_bt/=parallel_bt) error stop 'discrete trajectory drift'

"""
if anchor not in s: raise SystemExit("trajectory compare seam")
s=s.replace(anchor,repl,1)

old="""       '|MAX_SIMULTANEOUS=',maxsim,'|OMP_TEAM=',team_seen,'|MAX_Q_DIFF=',qdiff,'|MAX_T_DIFF=',tdiff, &
       '|QSUM=',qsum,'|TSUM=',tsum,'|MIXED=',mixed,'|MIXED_BALANCED=',mixed_balanced
"""
new="""       '|MAX_SIMULTANEOUS=',maxsim,'|OMP_TEAM=',team_seen,'|MAX_Q_DIFF=',qdiff,'|MAX_T_DIFF=',tdiff, &
       '|QSUM=',qsum,'|TSUM=',tsum,'|MIXED=',mixed,'|MIXED_BALANCED=',mixed_balanced, &
       '|ATTEMPTS=',parallel_att,'|ACCEPTED_SUBSTEPS=',parallel_asub, &
       '|RETRIES=',parallel_ret,'|TEMPORAL_REJECTIONS=',parallel_trej,'|SOLVER_REJECTIONS=',parallel_srej, &
       '|NONLINEAR=',parallel_nlit,'|BACKTRACK=',parallel_bt,'|WORK_RATIO=',worker_ratio, &
       '|W1_ATT=',worker_att(1),'|W2_ATT=',worker_att(2),'|W3_ATT=',worker_att(3),'|W4_ATT=',worker_att(4), &
       '|W1_NL=',worker_nlit(1),'|W2_NL=',worker_nlit(2),'|W3_NL=',worker_nlit(3),'|W4_NL=',worker_nlit(4), &
       '|W1_BT=',worker_bt(1),'|W2_BT=',worker_bt(2),'|W3_BT=',worker_bt(3),'|W4_BT=',worker_bt(4)
  do wi=1,workers
    write(*,'(*(g0))') 'MULTI02_WORKER|N=',n,'|WORKERS=',workers,'|WORKER=',wi, &
         '|ATTEMPTS=',worker_att(wi),'|NONLINEAR=',worker_nlit(wi),'|BACKTRACK=',worker_bt(wi)
  end do
"""
if old not in s: raise SystemExit("output seam")
s=s.replace(old,new,1)
Path(sys.argv[2]).write_text(s+"\n")
PY

COMMON=(-std=f2008 -ffree-line-length-none -O3 -fopenmp)
mapfile -t MODULE_SRC < <(python3 - <<'PY'
from pathlib import Path
s=Path("tests/fpe/run_fpe_profile04_repeated_decomposition.sh").read_text()
a=s.index("MODULE_SRC=(")+len("MODULE_SRC=(")
b=s.index("\n)\n",a)
for line in s[a:b].splitlines():
    line=line.strip()
    if line: print(line)
PY
)
for i in "${!MODULE_SRC[@]}"; do
  [[ "${MODULE_SRC[$i]}" == "src/runtime/mod_fmr_groundwater_swap_participant.f90" ]] && MODULE_SRC[$i]="$BUILD/participant.f90"
  [[ "${MODULE_SRC[$i]}" == "src/runtime/mod_fmr_groundwater_participant_registry.f90" ]] && MODULE_SRC[$i]="$BUILD/registry.f90"
done

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
extra_args=()
if [[ -n "${MULTI02_MIXED_MODE:-}" ]]; then
  extra_args=("${MULTI02_MIXED_MODE}")
elif [[ "${MULTI02_MIXED:-0}" == "1" ]]; then
  extra_args=(MIXED)
fi
for n in 10 100 1000; do
  for w in 1 2 4; do
    "$BUILD/test" "$n" "$w" "${extra_args[@]}" | tee -a "$OUT"
  done
done

python3 - "$OUT" <<'PY'
import sys
rows=[]
for line in open(sys.argv[1]):
  if line.startswith("MULTI02_P0|"):
    d={}
    for p in line.strip().split("|")[1:]:
      k,v=p.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=9: raise SystemExit(f"expected 9 rows got {len(rows)}")
by={(int(r["N"]),int(r["WORKERS"])):r for r in rows}
keys=("ATTEMPTS","ACCEPTED_SUBSTEPS","RETRIES","TEMPORAL_REJECTIONS","SOLVER_REJECTIONS","NONLINEAR","BACKTRACK")
for n in (10,100,1000):
  b=by[(n,1)]
  for w in (1,2,4):
    r=by[(n,w)]
    for k in keys:
      if r[k]!=b[k]: raise SystemExit(f"trajectory drift N={n} W={w} {k} {b[k]} {r[k]}")
    print("MULTI02_P1|N=%d|WORKERS=%d|"% (n,w) + "|".join(f"{k}={r[k]}" for k in keys)
          +f"|MAX_Q_DIFF={r['MAX_Q_DIFF']}|MAX_T_DIFF={r['MAX_T_DIFF']}|WORK_RATIO={r['WORK_RATIO']}"
          +f"|W1_NL={r['W1_NL']}|W2_NL={r['W2_NL']}|W3_NL={r['W3_NL']}|W4_NL={r['W4_NL']}")
print("FPE_MULTI02_P1=PASS")
PY
