module DIAG19
implicit none
integer,save::nvec=0,njac=0,nrate=0,nderiv=0,nback=0,nfresh=0,attempts=0,steps=0,u,v
logical,save::target=.false.
integer,save::iter_index=0,node_u,op_u,raw_u,limit_u,macro_seq=0
integer,save::kind=-1,iterations=0,flags(5)=0,worst=0,prelevel=0
real(8),save::residual=0,maxres=0,trialdt=0,headwall=0,budgetwall=0,spanhead=0,spanbudget=0
integer(8),save::origin,lastclock,hclock,bclock,rate
contains
subroutine start()
call system_clock(origin,rate);lastclock=origin
open(newunit=u,file='attempt_trace.txt',status='replace')
open(newunit=v,file='cost_trace.txt',status='replace')
open(newunit=node_u,file='node_iterations.txt',status='replace')
open(newunit=op_u,file='node_operator.txt',status='replace')
open(newunit=raw_u,file='node_absorption.txt',status='replace')
open(newunit=limit_u,file='domain3_limit.txt',status='replace')
end subroutine
subroutine head_start()
use variables,only:dt
use MOD_swap_mp,only:IDecMpRat
attempts=attempts+1
iter_index=0;macro_seq=0
target=attempts==38.or.(attempts>=50.and.attempts<=52)
nvec=0;njac=0;nrate=0;nderiv=0;nback=0;nfresh=0;kind=-1;iterations=0;flags=0
trialdt=dt;prelevel=IDecMpRat
call system_clock(hclock)
end subroutine
subroutine head_end()
use variables,only:t1900,fldecdt,fldtmin,numbit
use MOD_swap_mp,only:IDecMpRat,FlDecMpRat
use MOD_macropore,only:FrReduQ
integer(8)::tick
call system_clock(tick);headwall=dble(tick-hclock)/dble(rate);spanhead=spanhead+headwall
write(u,*) attempts,steps+1,t1900,trialdt,prelevel,IDecMpRat,FrReduQ,numbit,kind, &
 merge(1,0,fldecdt),merge(1,0,FlDecMpRat),merge(1,0,fldtmin),flags,residual,maxres,worst, &
 nvec,njac,nrate,nderiv,nback,nfresh,headwall
if(target) then
 flush(node_u);flush(op_u);flush(raw_u);flush(limit_u)
end if
if(mod(attempts,128)==0) flush(u)
end subroutine
subroutine outcome(k,it,f,f1,f2,f3,fmp,s,m,w)
integer,intent(in)::k,it,w
logical,intent(in)::f,f1,f2,f3,fmp
real(8),intent(in)::s,m
kind=k;iterations=it;flags=[merge(1,0,f),merge(1,0,f1),merge(1,0,f2),merge(1,0,f3),merge(1,0,fmp)]
residual=s;maxres=m;worst=w
end subroutine
subroutine log_start()
call system_clock(bclock)
end subroutine
subroutine log_end()
integer(8)::tick
call system_clock(tick);budgetwall=dble(tick-bclock)/dble(rate);spanbudget=spanbudget+budgetwall
end subroutine
logical function commit() result(done)
use variables,only:t1900,dt,numbit
use MOD_macropore,only:FrReduQ
integer(8)::tick
integer::o
real(8)::elapsed
call system_clock(tick);elapsed=dble(tick-origin)/dble(rate);steps=steps+1
write(v,*) steps,t1900,dt,numbit,FrReduQ,attempts,spanhead,spanbudget,dble(tick-lastclock)/dble(rate),elapsed
if(mod(steps,128)==0) flush(v)
done=steps>=42.or.elapsed>=16d0
if(done) then
 close(u);close(v);close(node_u);close(op_u);close(raw_u);close(limit_u)
 open(newunit=o,file='outcome.txt',status='replace');write(o,*) 'LIMIT21_BOUNDED',steps,elapsed;close(o)
end if
spanhead=0;spanbudget=0
call system_clock(lastclock)
end function
end module
