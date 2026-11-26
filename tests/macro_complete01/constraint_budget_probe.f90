
subroutine observe_constraint_budget(n,cm)
use MOD_arrays,only:madm
use MOD_macropore,only:NumDm,ICpTpSatZon,QOutMtxSatDmCp,QOutMtxUnsDmCp,QInMtxSatDmCp,QExcMpMtx,QOutDrRapCp
use MOD_swap_mp,only:GwlFlCpZo
use variables,only:h,theta,t1900,dt,numbit
use hybrid_day_window,only:budget_total,budget_step,budget_start,budget_retries
implicit none
integer,intent(in)::n
real(8),intent(in)::cm(24,madm)
integer,save::u=0,count_lower=0,count_budget=0,last_retry=0
integer::reason
reason=0
if(cm(16,1)/=1d0.and.count_lower<64)then
 reason=1;count_lower=count_lower+1
end if
if(budget_retries>last_retry.and.count_budget<128)then
 reason=reason+2;count_budget=count_budget+1
end if
last_retry=budget_retries
if(reason==0)return
if(u==0)open(newunit=u,file='constraint_budget_probe.txt',status='replace')
write(u,*)n,NumDm,t1900,dt,numbit,GwlFlCpZo,ICpTpSatZon,budget_total,budget_step,budget_start,budget_retries,reason
write(u,*)cm(:,1:NumDm),h(1:n),theta(1:n),QExcMpMtx(1:n),QOutMtxSatDmCp(1:NumDm,1:n), &
 QOutMtxUnsDmCp(1:NumDm,1:n),QInMtxSatDmCp(1:NumDm,1:n),QOutDrRapCp(1:n)
end subroutine
