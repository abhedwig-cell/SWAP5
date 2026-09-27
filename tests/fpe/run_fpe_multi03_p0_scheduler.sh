#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi03-p0-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

BASE="$BUILD/base.sh"
cp tests/fpe/run_fpe_multi02_p0_worker_local.sh "$BASE"

python3 - "$BASE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()

s=s.replace("use omp_lib, only: omp_get_num_threads",
            "use omp_lib, only: omp_get_num_threads, omp_get_thread_num",1)

s=s.replace(
"  integer :: n,workers,i,w,rep,status,participant_status,active,maxsim,team_seen\n",
"  integer :: n,workers,i,w,rep,status,participant_status,active,maxsim,team_seen,order_code,schedule_code\n"
"  integer, allocatable :: assigned_worker(:), order_index(:)\n"
"  real(real64), allocatable :: history_rate(:)\n"
"  real(real64) :: predicted_load(4), predicted_ratio\n",1)

old=("  if(command_argument_count()<2 .or. command_argument_count()>3) error stop 'usage N WORKERS [MIXED|MIXED_BALANCED]'\n"
"  call get_command_argument(1,arg); read(arg,*) n\n"
"  call get_command_argument(2,arg); read(arg,*) workers\n"
"  mixed=.false.; mixed_balanced=.false.; mode=''\n"
"  if(command_argument_count()==3)then\n"
"    call get_command_argument(3,mode)\n"
"    mixed=trim(mode)=='MIXED' .or. trim(mode)=='MIXED_BALANCED'\n"
"    mixed_balanced=trim(mode)=='MIXED_BALANCED'\n"
"    if(.not.mixed) error stop 'bad mode'\n"
"  end if\n"
"  if(n<=0 .or. .not.(workers==1 .or. workers==2 .or. workers==4)) error stop 'bad args'\n")
new=("  if(command_argument_count()/=4) error stop 'usage N WORKERS ORDER SCHEDULE'\n"
"  call get_command_argument(1,arg); read(arg,*) n\n"
"  call get_command_argument(2,arg); read(arg,*) workers\n"
"  call get_command_argument(3,arg); read(arg,*) order_code\n"
"  call get_command_argument(4,arg); read(arg,*) schedule_code\n"
"  mixed=.false.; mixed_balanced=.false.; mode=''\n"
"  if(n<=0 .or. .not.(workers==1 .or. workers==2 .or. workers==4)) error stop 'bad args'\n"
"  if(order_code/=0 .and. order_code/=1) error stop 'bad order'\n"
"  if(schedule_code/=0 .and. schedule_code/=1) error stop 'bad schedule'\n")
if old not in s: raise SystemExit("MULTI03 args seam")
s=s.replace(old,new,1)

old="  allocate(columns(n),committed(n),forcings(n),materializers(n),handles(n),target_head(n))\n"
new=old+"  allocate(assigned_worker(n),order_index(n),history_rate(n))\n"
if old not in s: raise SystemExit("MULTI03 allocation seam")
s=s.replace(old,new,1)

anchor="  allocate(backends(workers))\n"
insert="""  do i=1,n
    history_rate(i)=history_rate_for_tile(i,n,order_code)
  end do
  call build_assignment(n,workers,schedule_code,history_rate,assigned_worker,predicted_load)
  if(workers>0)then
    predicted_ratio=maxval(predicted_load(1:workers))/(sum(predicted_load(1:workers))/real(workers,real64))
  else
    predicted_ratio=1.0_real64
  end if
"""
if anchor not in s: raise SystemExit("MULTI03 assignment anchor")
s=s.replace(anchor,insert+anchor,1)

s=s.replace(
"    call initialize_committed(committed(i),initial_state,columns(i)%column_id,ok)\n"
"    if(.not.ok) error stop 'committed init'\n"
"    w=1+mod(i-1,workers)\n",
"    call initialize_committed(committed(i),initial_state,columns(i)%column_id,history_rate(i),ok)\n"
"    if(.not.ok) error stop 'committed init'\n"
"    w=assigned_worker(i)\n",1)

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
new="""!$omp parallel default(shared) private(i,w,participant_status,status) num_threads(workers)
!$omp single
    team_seen=omp_get_num_threads()
!$omp end single
    w=omp_get_thread_num()+1
    do i=1,n
      if(assigned_worker(i)/=w) cycle
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
if old not in s: raise SystemExit("MULTI03 parallel seam")
s=s.replace(old,new,1)

old=("  subroutine initialize_committed(c,s,lineage,success)\n"
"    type(kernel_committed_state_t),intent(out)::c\n"
"    type(fmr_b110_physical_state_t),intent(in)::s\n"
"    integer(int64),intent(in)::lineage\n"
"    logical,intent(out)::success\n"
"    real(real64)::history(numnod)\n"
"    history=400.0_real64\n")
new=("  subroutine initialize_committed(c,s,lineage,history_value,success)\n"
"    type(kernel_committed_state_t),intent(out)::c\n"
"    type(fmr_b110_physical_state_t),intent(in)::s\n"
"    integer(int64),intent(in)::lineage\n"
"    real(real64),intent(in)::history_value\n"
"    logical,intent(out)::success\n"
"    real(real64)::history(numnod)\n"
"    history=history_value\n")
if old not in s: raise SystemExit("MULTI03 history seam")
s=s.replace(old,new,1)

needle="  subroutine sort5(v)\n"
helper=r'''  real(real64) function history_rate_for_tile(index,count,ordering) result(rate)
    integer,intent(in)::index,count,ordering
    real(real64),parameter::rates(4)=[100.0_real64,400.0_real64,1600.0_real64,6400.0_real64]
    integer::klass
    if(ordering==0)then
      klass=min(3,4*(index-1)/max(1,count))+1
    else
      klass=mod(index-1,4)+1
    end if
    rate=rates(klass)
  end function history_rate_for_tile

  subroutine build_assignment(count,nworker,schedule,cost,assignment,load)
    integer,intent(in)::count,nworker,schedule
    real(real64),intent(in)::cost(count)
    integer,intent(out)::assignment(count)
    real(real64),intent(out)::load(4)
    integer::idx(count),a,b,tmp,tile,best
    real(real64)::bestload
    load=0.0_real64
    do a=1,count
      idx(a)=a
    end do
    if(schedule==0)then
      do a=1,count
        assignment(a)=1+mod(a-1,nworker)
        load(assignment(a))=load(assignment(a))+cost(a)
      end do
      return
    end if
    do a=2,count
      tmp=idx(a); b=a-1
      do while(b>=1)
        if(cost(idx(b))>cost(tmp))exit
        if(cost(idx(b))==cost(tmp) .and. idx(b)<tmp)exit
        idx(b+1)=idx(b); b=b-1
      end do
      idx(b+1)=tmp
    end do
    do a=1,count
      tile=idx(a); best=1; bestload=load(1)
      do b=2,nworker
        if(load(b)<bestload)then
          best=b; bestload=load(b)
        end if
      end do
      assignment(tile)=best
      load(best)=load(best)+cost(tile)
    end do
  end subroutine build_assignment

'''
if needle not in s: raise SystemExit("MULTI03 helper seam")
s=s.replace(needle,helper+needle,1)

old="'|QSUM=',qsum,'|TSUM=',tsum,'|MIXED=',mixed,'|MIXED_BALANCED=',mixed_balanced"
new="'|QSUM=',qsum,'|TSUM=',tsum,'|MIXED=',mixed,'|MIXED_BALANCED=',mixed_balanced, &\n       '|ORDER=',order_code,'|SCHEDULE=',schedule_code,'|PREDICTED_RATIO=',predicted_ratio"
if old not in s: raise SystemExit("MULTI03 output seam")
s=s.replace(old,new,1)

# Run only N=1000; both frozen orderings; static and cost-aware.
start=s.index('OUT="$BUILD/out.txt"; : > "$OUT"')
loop=s.index('for n in ',start)
parser=s.index('\npython3 - "$OUT" <<\'PY\'',loop)
newloop='''for order in 0 1; do
  for sched in 0 1; do
    for w in 1 2 4; do
      "$BUILD/test" 1000 "$w" "$order" "$sched" | tee -a "$OUT"
    done
  done
done
'''
s=s[:loop]+newloop+s[parser:]

# Replace aggregate parser.
start=s.rfind('python3 - "$OUT" <<\'PY\'')
s=s[:start]+r'''python3 - "$OUT" <<'PY'
import sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("MULTI02_P0|"): continue
    d={}
    for part in line.strip().split("|")[1:]:
        k,v=part.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=12: raise SystemExit(f"expected 12 rows, got {len(rows)}")
by={(int(r["ORDER"]),int(r["SCHEDULE"]),int(r["WORKERS"])):r for r in rows}
for order in (0,1):
    base=float(by[(order,1,1)]["PARALLEL_SECONDS"])
    for sched in (0,1):
        name="STATIC" if sched==0 else "COST_AWARE"
        for w in (1,2,4):
            r=by[(order,sched,w)]
            sec=float(r["PARALLEL_SECONDS"]); speed=base/sec
            print(f"MULTI03_P0|ORDER={order}|SCHEDULE={name}|WORKERS={w}|SECONDS={sec:.9f}"
                  f"|SPEEDUP={speed:.6f}|EFFICIENCY={speed/w:.6f}"
                  f"|PREDICTED_RATIO={float(r['PREDICTED_RATIO']):.6f}"
                  f"|MAX_Q_DIFF={r['MAX_Q_DIFF']}|MAX_T_DIFF={r['MAX_T_DIFF']}")
            if float(r["MAX_Q_DIFF"])!=0.0 or float(r["MAX_T_DIFF"])!=0.0:
                raise SystemExit(f"semantic drift order={order} sched={sched} workers={w}")
    static4=float(by[(order,0,4)]["PARALLEL_SECONDS"])
    aware4=float(by[(order,1,4)]["PARALLEL_SECONDS"])
    aware2=base/float(by[(order,1,2)]["PARALLEL_SECONDS"])
    aware4speed=base/aware4
    ratio=float(by[(order,1,4)]["PREDICTED_RATIO"])
    print(f"MULTI03_P0_DECISION_INPUT|ORDER={order}|AWARE2_SPEED={aware2:.6f}"
          f"|AWARE4_SPEED={aware4speed:.6f}|AWARE_VS_STATIC4={static4/aware4:.6f}"
          f"|PREDICTED_RATIO={ratio:.6f}")
print("FPE_MULTI03_P0=PASS")
PY
'''
p.write_text(s)
PY

bash "$BASE"
