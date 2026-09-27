#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi02-p2b-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

BASE="$BUILD/p1.sh"
cp tests/fpe/run_fpe_multi02_p1_trajectory_identity.sh "$BASE"

python3 - "$BASE" <<'PYPATCH'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
needle='bash "$RUN"\n'
if needle not in s:
    raise SystemExit("P2B insertion seam missing")
patch=r"""python3 - "$RUN" <<'PY2'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()

s=s.replace(
"  integer :: n,workers,i,w,rep,status,participant_status,active,maxsim,team_seen\n",
"  integer :: n,workers,i,w,rep,status,participant_status,active,maxsim,team_seen,order_code\n"
"  integer :: worker_att(4),worker_nlit(4),worker_bt(4)\n"
"  real(real64) :: mean_work,work_ratio\n",1)

s=s.replace(
"  if(command_argument_count()/=2) error stop 'usage N WORKERS'\n"
"  call get_command_argument(1,arg); read(arg,*) n\n"
"  call get_command_argument(2,arg); read(arg,*) workers\n"
"  if(n<=0 .or. .not.(workers==1 .or. workers==2 .or. workers==4)) error stop 'bad args'\n",
"  if(command_argument_count()/=3) error stop 'usage N WORKERS ORDER'\n"
"  call get_command_argument(1,arg); read(arg,*) n\n"
"  call get_command_argument(2,arg); read(arg,*) workers\n"
"  call get_command_argument(3,arg); read(arg,*) order_code\n"
"  if(n<=0 .or. .not.(workers==1 .or. workers==2 .or. workers==4)) error stop 'bad args'\n"
"  if(order_code/=0 .and. order_code/=1) error stop 'bad order'\n",1)

s=s.replace(
"    call initialize_committed(committed(i),initial_state,columns(i)%column_id,ok)\n",
"    call initialize_committed(committed(i),initial_state,columns(i)%column_id, &\n"
"         history_rate_for_tile(i,n,order_code),ok)\n",1)

s=s.replace(
"  subroutine initialize_committed(c,s,lineage,success)\n"
"    type(kernel_committed_state_t),intent(out)::c\n"
"    type(fmr_b110_physical_state_t),intent(in)::s\n"
"    integer(int64),intent(in)::lineage\n"
"    logical,intent(out)::success\n"
"    real(real64)::history(numnod)\n"
"    history=400.0_real64\n",
"  subroutine initialize_committed(c,s,lineage,history_rate,success)\n"
"    type(kernel_committed_state_t),intent(out)::c\n"
"    type(fmr_b110_physical_state_t),intent(in)::s\n"
"    integer(int64),intent(in)::lineage\n"
"    real(real64),intent(in)::history_rate\n"
"    logical,intent(out)::success\n"
"    real(real64)::history(numnod)\n"
"    history=history_rate\n",1)

s=s.replace(
"  qdiff=0.0_real64; tdiff=0.0_real64\n",
"  qdiff=0.0_real64; tdiff=0.0_real64\n"
"  worker_att=0; worker_nlit=0; worker_bt=0\n",1)

needle2="      call require_diag_equal(s_after(i),p_after(i))\n"
if needle2 not in s:
    raise SystemExit("P2B diagnostic delta seam missing")
s=s.replace(
needle2,
needle2+
"      if(rep==1)then\n"
"        w=1+mod(i-1,workers)\n"
"        worker_att(w)=worker_att(w)+p_after(i)%attempts\n"
"        worker_nlit(w)=worker_nlit(w)+p_after(i)%nonlinear_iterations\n"
"        worker_bt(w)=worker_bt(w)+p_after(i)%backtracking_attempts\n"
"      end if\n",1)

needle3="  subroutine sort5(v)\n"
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

'''
if needle3 not in s:
    raise SystemExit("P2B helper seam missing")
s=s.replace(needle3,helper+needle3,1)

if "  write(*,'(*(g0))') 'MULTI02_P1|N=',n,'|WORKERS=',workers, &\n" not in s:
    raise SystemExit("P2B output seam missing")
s=s.replace(
"  write(*,'(*(g0))') 'MULTI02_P1|N=',n,'|WORKERS=',workers, &\n",
"  mean_work=real(sum(worker_nlit(1:workers)),real64)/real(workers,real64)\n"
"  if(mean_work>0.0_real64)then\n"
"    work_ratio=real(maxval(worker_nlit(1:workers)),real64)/mean_work\n"
"  else\n"
"    work_ratio=1.0_real64\n"
"  end if\n"
"  write(*,'(*(g0))') 'MULTI02_P2B|N=',n,'|WORKERS=',workers,'|ORDER=',order_code, &\n",1)

s=s.replace(
"       '|QSUM=',qsum,'|TSUM=',tsum\n",
"       '|QSUM=',qsum,'|TSUM=',tsum,'|WORK_RATIO=',work_ratio, &\n"
"       '|W1_ATT=',worker_att(1),'|W2_ATT=',worker_att(2),'|W3_ATT=',worker_att(3),'|W4_ATT=',worker_att(4), &\n"
"       '|W1_NL=',worker_nlit(1),'|W2_NL=',worker_nlit(2),'|W3_NL=',worker_nlit(3),'|W4_NL=',worker_nlit(4), &\n"
"       '|W1_BT=',worker_bt(1),'|W2_BT=',worker_bt(2),'|W3_BT=',worker_bt(3),'|W4_BT=',worker_bt(4)\n",1)

old='''for n in 100 1000; do
  for w in 1 2 4; do
    "$BUILD/test" "$n" "$w" | tee -a "$OUT"
  done
done
'''
new='''n=1000
for order in 0 1; do
  for w in 1 2 4; do
    "$BUILD/test" "$n" "$w" "$order" | tee -a "$OUT"
  done
done
'''
if old not in s:
    raise SystemExit("P2B run-matrix seam missing")
s=s.replace(old,new,1)

start=s.rfind('python3 - "$OUT" <<\'PY\'')
if start<0:
    raise SystemExit("P2B aggregate parser seam missing")
s=s[:start]+r'''python3 - "$OUT" <<'PY'
import sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("MULTI02_P2B|"): continue
    d={}
    for part in line.strip().split("|")[1:]:
        k,v=part.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=6:
    raise SystemExit(f"expected 6 P2B rows, got {len(rows)}")
by={(int(r["ORDER"]),int(r["WORKERS"])):r for r in rows}
for order in (0,1):
    base=float(by[(order,1)]["PARALLEL_SECONDS"])
    for w in (1,2,4):
        r=by[(order,w)]
        sec=float(r["PARALLEL_SECONDS"])
        speed=base/sec
        ratio=float(r["WORK_RATIO"])
        print(f"MULTI02_P2B_SUMMARY|ORDER={order}|WORKERS={w}|SECONDS={sec:.9f}"
              f"|SPEEDUP={speed:.6f}|EFFICIENCY={speed/w:.6f}|WORK_RATIO={ratio:.6f}"
              f"|W1_NL={r['W1_NL']}|W2_NL={r['W2_NL']}|W3_NL={r['W3_NL']}|W4_NL={r['W4_NL']}"
              f"|MAX_Q_DIFF={r['MAX_Q_DIFF']}|MAX_T_DIFF={r['MAX_T_DIFF']}")
        if float(r["MAX_Q_DIFF"])!=0.0 or float(r["MAX_T_DIFF"])!=0.0:
            raise SystemExit(f"semantic drift order={order} workers={w}")
w2=float(by[(1,1)]["PARALLEL_SECONDS"])/float(by[(1,2)]["PARALLEL_SECONDS"])
w4=float(by[(1,1)]["PARALLEL_SECONDS"])/float(by[(1,4)]["PARALLEL_SECONDS"])
ratio4=float(by[(1,4)]["WORK_RATIO"])
decision="ADVANCE_APPLICATION_CONTEXT" if (w2>=1.5 and w4>=2.2 and ratio4<=1.20) else "SELECT_LOAD_BALANCING"
print(f"MULTI02_P2B_DECISION|W2_SPEEDUP={w2:.6f}|W4_SPEEDUP={w4:.6f}|W4_WORK_RATIO={ratio4:.6f}|DECISION={decision}")
print("FPE_MULTI02_P2B=PASS")
PY
'''
p.write_text(s)
PY2
bash "$RUN"
"""
s=s.replace(needle,patch,1)
p.write_text(s)
PYPATCH

bash "$BASE"
