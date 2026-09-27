#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi03-p0-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

BASE="tests/fpe/run_fpe_multi02_p0_worker_local.sh"
OUTRUN="$BUILD/run.sh"
cp "$BASE" "$OUTRUN"

python3 - "$OUTRUN" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()

# The MULTI03 candidate is generated only in this research copy.
s=s.replace(
"  use omp_lib, only: omp_get_num_threads\n",
"  use omp_lib, only: omp_get_num_threads, omp_get_thread_num\n",1)

old="  integer :: n,workers,i,w,rep,status,participant_status,active,maxsim,team_seen\n"
new=("  integer :: n,workers,i,w,rep,status,participant_status,active,maxsim,team_seen,order_code,schedule_code,wi,j,best,tmpi\n"
     "  integer, allocatable :: owner(:),sort_index(:),assigned_count(:)\n"
     "  real(real64), allocatable :: history_rate(:),predicted_load(:)\n"
     "  real(real64) :: best_load,tmpc,mean_load,predicted_ratio\n")
if old not in s: raise SystemExit("MULTI03 declaration seam missing")
s=s.replace(old,new,1)

old="""  if(command_argument_count()<2 .or. command_argument_count()>3) error stop 'usage N WORKERS [MIXED|MIXED_BALANCED]'
  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,arg); read(arg,*) workers
  mixed=.false.; mixed_balanced=.false.; mode=''
  if(command_argument_count()==3)then
    call get_command_argument(3,mode)
    mixed=trim(mode)=='MIXED' .or. trim(mode)=='MIXED_BALANCED'
    mixed_balanced=trim(mode)=='MIXED_BALANCED'
    if(.not.mixed) error stop 'bad mode'
  end if
  if(n<=0 .or. .not.(workers==1 .or. workers==2 .or. workers==4)) error stop 'bad args'
"""
new="""  if(command_argument_count()/=4) error stop 'usage N WORKERS ORDER SCHEDULE'
  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,arg); read(arg,*) workers
  call get_command_argument(3,arg); read(arg,*) order_code
  call get_command_argument(4,arg); read(arg,*) schedule_code
  mixed=.false.; mixed_balanced=.false.; mode=''
  if(n<=0 .or. .not.(workers==1 .or. workers==2 .or. workers==4)) error stop 'bad args'
  if(order_code/=0 .and. order_code/=1) error stop 'bad order'
  if(schedule_code/=0 .and. schedule_code/=1) error stop 'bad schedule'
"""
if old not in s: raise SystemExit("MULTI03 args seam missing")
s=s.replace(old,new,1)

old="  allocate(columns(n),committed(n),forcings(n),materializers(n),handles(n),target_head(n))\n"
new=(old+
"  allocate(owner(n),sort_index(n),assigned_count(workers),history_rate(n),predicted_load(workers))\n"
"  do i=1,n\n"
"    history_rate(i)=history_rate_for_tile(i,n,order_code)\n"
"    sort_index(i)=i\n"
"  end do\n"
"  owner=1; assigned_count=0; predicted_load=0.0_real64\n"
"  if(schedule_code==0)then\n"
"    do i=1,n\n"
"      owner(i)=1+mod(i-1,workers)\n"
"    end do\n"
"  else\n"
"    ! Deterministic descending-cost list scheduling. Ties preserve tile index;\n"
"    ! equal-load worker ties choose the lowest worker id.\n"
"    do i=1,n-1\n"
"      best=i\n"
"      do j=i+1,n\n"
"        if(history_rate(sort_index(j))>history_rate(sort_index(best))) best=j\n"
"      end do\n"
"      if(best/=i)then\n"
"        tmpi=sort_index(i); sort_index(i)=sort_index(best); sort_index(best)=tmpi\n"
"      end if\n"
"    end do\n"
"    do j=1,n\n"
"      i=sort_index(j)\n"
"      w=1; best_load=predicted_load(1)\n"
"      do wi=2,workers\n"
"        if(predicted_load(wi)<best_load)then\n"
"          w=wi; best_load=predicted_load(wi)\n"
"        end if\n"
"      end do\n"
"      owner(i)=w\n"
"      predicted_load(w)=predicted_load(w)+history_rate(i)\n"
"    end do\n"
"  end if\n"
"  if(schedule_code==0)then\n"
"    predicted_load=0.0_real64\n"
"    do i=1,n\n"
"      predicted_load(owner(i))=predicted_load(owner(i))+history_rate(i)\n"
"    end do\n"
"  end if\n"
"  assigned_count=0\n"
"  do i=1,n\n"
"    assigned_count(owner(i))=assigned_count(owner(i))+1\n"
"  end do\n"
"  mean_load=sum(predicted_load)/real(workers,real64)\n"
"  if(mean_load>0.0_real64)then\n"
"    predicted_ratio=maxval(predicted_load)/mean_load\n"
"  else\n"
"    predicted_ratio=1.0_real64\n"
"  end if\n")
if old not in s: raise SystemExit("MULTI03 allocation seam missing")
s=s.replace(old,new,1)

# Disable head-based mixed mode; heterogeneity comes from frozen history-cost classes.
start=s.find("  target_head=href\n  if(mixed)then\n")
if start<0: raise SystemExit("MULTI03 target-head seam missing")
end=s.find("  allocate(serial_trials",start)
if end<0: raise SystemExit("MULTI03 target-head end missing")
s=s[:start]+"  target_head=href\n"+s[end:]

old="""    call initialize_committed(committed(i),initial_state,columns(i)%column_id,ok)
    if(.not.ok) error stop 'committed init'
    w=1+mod(i-1,workers)
    call registry%bind(columns(i)%column_id,backends(w),columns(i),template,parameters,committed(i),materializers(i), &
"""
new="""    call initialize_committed(committed(i),initial_state,columns(i)%column_id,history_rate(i),ok)
    if(.not.ok) error stop 'committed init'
    w=owner(i)
    call registry%bind(columns(i)%column_id,backends(w),columns(i),template,parameters,committed(i),materializers(i), &
"""
if old not in s: raise SystemExit("MULTI03 bind seam missing")
s=s.replace(old,new,1)

old="""!$omp parallel default(shared) private(i,participant_status,status) num_threads(workers)
!$omp single
    team_seen=omp_get_num_threads()
!$omp end single
!$omp do schedule(static,1)
    do i=1,n
!$omp critical(multi02_active)
      active=active+1
      maxsim=max(maxsim,active)
!$omp end critical(multi02_active)
      call registry%trial_from_origin(handles(i),window,target_head(i),parallel_trials(i),participant_status,status)
      pstatus(i)=participant_status
      rstatus(i)=status
!$omp critical(multi02_active)
      active=active-1
!$omp end critical(multi02_active)
    end do
!$omp end do
!$omp end parallel
"""
new="""!$omp parallel default(shared) private(i,wi,participant_status,status) num_threads(workers)
    wi=omp_get_thread_num()+1
!$omp single
    team_seen=omp_get_num_threads()
!$omp end single
    do i=1,n
      if(owner(i)/=wi) cycle
!$omp critical(multi02_active)
      active=active+1
      maxsim=max(maxsim,active)
!$omp end critical(multi02_active)
      call registry%trial_from_origin(handles(i),window,target_head(i),parallel_trials(i),participant_status,status)
      pstatus(i)=participant_status
      rstatus(i)=status
!$omp critical(multi02_active)
      active=active-1
!$omp end critical(multi02_active)
    end do
!$omp end parallel
"""
if old not in s: raise SystemExit("MULTI03 parallel seam missing")
s=s.replace(old,new,1)

old="""  write(*,'(*(g0))') 'MULTI02_P0|N=',n,'|WORKERS=',workers, &
       '|SERIAL_SECONDS=',serial_t(3),'|PARALLEL_SECONDS=',parallel_t(3), &
       '|SPEEDUP=',serial_t(3)/parallel_t(3),'|NS_PER_TILE=',1.0e9_real64*parallel_t(3)/real(n,real64), &
       '|MAX_SIMULTANEOUS=',maxsim,'|OMP_TEAM=',team_seen,'|MAX_Q_DIFF=',qdiff,'|MAX_T_DIFF=',tdiff, &
       '|QSUM=',qsum,'|TSUM=',tsum,'|MIXED=',mixed,'|MIXED_BALANCED=',mixed_balanced
"""
new="""  write(*,'(*(g0))') 'MULTI03_P0|N=',n,'|WORKERS=',workers,'|ORDER=',order_code,'|SCHEDULE=',schedule_code, &
       '|SERIAL_SECONDS=',serial_t(3),'|PARALLEL_SECONDS=',parallel_t(3), &
       '|SPEEDUP=',serial_t(3)/parallel_t(3),'|NS_PER_TILE=',1.0e9_real64*parallel_t(3)/real(n,real64), &
       '|MAX_SIMULTANEOUS=',maxsim,'|OMP_TEAM=',team_seen,'|MAX_Q_DIFF=',qdiff,'|MAX_T_DIFF=',tdiff, &
       '|QSUM=',qsum,'|TSUM=',tsum,'|PREDICTED_RATIO=',predicted_ratio, &
       '|W1_COUNT=',assigned_count(1),'|W2_COUNT=',merge(assigned_count(2),0,workers>=2), &
       '|W3_COUNT=',merge(assigned_count(3),0,workers>=3),'|W4_COUNT=',merge(assigned_count(4),0,workers>=4), &
       '|W1_COST=',predicted_load(1),'|W2_COST=',merge(predicted_load(2),0.0_real64,workers>=2), &
       '|W3_COST=',merge(predicted_load(3),0.0_real64,workers>=3),'|W4_COST=',merge(predicted_load(4),0.0_real64,workers>=4)
"""
if old not in s: raise SystemExit("MULTI03 output seam missing")
s=s.replace(old,new,1)
s=s.replace("  write(*,'(A)') 'FPE_MULTI02_P0=PASS'","  write(*,'(A)') 'FPE_MULTI03_P0=PASS'",1)

old="""  subroutine initialize_committed(c,s,lineage,success)
    type(kernel_committed_state_t),intent(out)::c
    type(fmr_b110_physical_state_t),intent(in)::s
    integer(int64),intent(in)::lineage
    logical,intent(out)::success
    real(real64)::history(numnod)
    history=400.0_real64
"""
new="""  subroutine initialize_committed(c,s,lineage,history_scale,success)
    type(kernel_committed_state_t),intent(out)::c
    type(fmr_b110_physical_state_t),intent(in)::s
    integer(int64),intent(in)::lineage
    real(real64),intent(in)::history_scale
    logical,intent(out)::success
    real(real64)::history(numnod)
    history=history_scale
"""
if old not in s: raise SystemExit("MULTI03 committed seam missing")
s=s.replace(old,new,1)

needle="  subroutine sort5(v)\n"
helper="""  pure real(real64) function history_rate_for_tile(index,count,ordering) result(v)
    integer,intent(in)::index,count,ordering
    real(real64),parameter::rates(4)=[100.0_real64,400.0_real64,1600.0_real64,6400.0_real64]
    integer::klass
    if(ordering==0)then
      klass=min(3,4*(index-1)/max(1,count))+1
    else
      klass=mod(index-1,4)+1
    end if
    v=rates(klass)
  end function history_rate_for_tile

"""
if needle not in s: raise SystemExit("MULTI03 helper seam missing")
s=s.replace(needle,helper+needle,1)

# Replace invocation matrix/parser with frozen N=1000 two-order, two-schedule authority.
marker='OUT="$BUILD/out.txt"; : > "$OUT"\n'
pos=s.index(marker)+len(marker)
parser=s.index('\npython3 - "$OUT" <<\'PY\'',pos)
matrix="""for order in 0 1; do
  for schedule in 0 1; do
    for w in 1 2 4; do
      "$BUILD/test" 1000 "$w" "$order" "$schedule" | tee -a "$OUT"
    done
  done
done
"""
s=s[:pos]+matrix+s[parser:]
start=s.rfind('python3 - "$OUT" <<\'PY\'')
s=s[:start]+r'''python3 - "$OUT" <<'PY'
import sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("MULTI03_P0|"): continue
    d={}
    for part in line.strip().split("|")[1:]:
        k,v=part.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=12:
    raise SystemExit(f"expected 12 MULTI03 rows, got {len(rows)}")
by={(int(r["ORDER"]),int(r["SCHEDULE"]),int(r["WORKERS"])):r for r in rows}
for order in (0,1):
    base=float(by[(order,1,1)]["PARALLEL_SECONDS"])
    for sched in (0,1):
        for w in (1,2,4):
            r=by[(order,sched,w)]
            sec=float(r["PARALLEL_SECONDS"])
            speed=base/sec
            print(f"MULTI03_P0_SUMMARY|ORDER={order}|SCHEDULE={sched}|WORKERS={w}"
                  f"|SECONDS={sec:.9f}|SPEEDUP={speed:.6f}|EFFICIENCY={speed/w:.6f}"
                  f"|PREDICTED_RATIO={float(r['PREDICTED_RATIO']):.6f}"
                  f"|MAX_Q_DIFF={r['MAX_Q_DIFF']}|MAX_T_DIFF={r['MAX_T_DIFF']}")
            if float(r["MAX_Q_DIFF"])!=0.0 or float(r["MAX_T_DIFF"])!=0.0:
                raise SystemExit(f"semantic drift order={order} schedule={sched} workers={w}")
    static4=base/float(by[(order,0,4)]["PARALLEL_SECONDS"])
    cost4=base/float(by[(order,1,4)]["PARALLEL_SECONDS"])
    ratio=float(by[(order,1,4)]["PREDICTED_RATIO"])
    print(f"MULTI03_P0_DECISION_INPUT|ORDER={order}|STATIC4={static4:.6f}|COST4={cost4:.6f}"
          f"|COST_PREDICTED_RATIO={ratio:.6f}|SPEED_GATE={cost4>=2.2}"
          f"|NOT_SLOWER_THAN_STATIC={float(by[(order,1,4)]['PARALLEL_SECONDS']) <= 1.02*float(by[(order,0,4)]['PARALLEL_SECONDS'])}")
for order in (0,1):
    c2=float(by[(order,1,1)]["PARALLEL_SECONDS"])/float(by[(order,1,2)]["PARALLEL_SECONDS"])
    c4=float(by[(order,1,1)]["PARALLEL_SECONDS"])/float(by[(order,1,4)]["PARALLEL_SECONDS"])
    if c2<1.5: raise SystemExit(f"cost-aware 2-worker gate failed order={order}: {c2}")
    if c4<2.2: raise SystemExit(f"cost-aware 4-worker gate failed order={order}: {c4}")
    if float(by[(order,1,4)]["PREDICTED_RATIO"])>1.20:
        raise SystemExit(f"predicted load ratio failed order={order}")
    if float(by[(order,1,4)]["PARALLEL_SECONDS"])>1.02*float(by[(order,0,4)]["PARALLEL_SECONDS"]):
        raise SystemExit(f"cost-aware slower than static order={order}")
print("FPE_MULTI03_P0=PASS")
PY
'''
p.write_text(s)
PY

bash "$OUTRUN"
