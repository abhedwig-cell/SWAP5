module COST15
implicit none
integer,save::nvec=0,njac=0,nrate=0,nderiv=0,nback=0,nfresh=0,attempts=0,steps=0,u
real(8),save::macro_cpu=0,macro_tick=0,head_cpu=0,head_wall=0,hcpu,lastcpu,firstcpu
integer(8),save::hclock,lastclock,firstclock,rate,logclock
real(8),save::logwall=0d0
contains
subroutine start()
call cpu_time(firstcpu);lastcpu=firstcpu
call system_clock(firstclock,rate);lastclock=firstclock
open(newunit=u,file='cost_trace.txt',status='replace')
end subroutine
subroutine head_start()
attempts=attempts+1
call cpu_time(hcpu);call system_clock(hclock)
end subroutine
subroutine head_end()
real(8)::x
integer(8)::tick
call cpu_time(x);call system_clock(tick)
head_cpu=head_cpu+x-hcpu;head_wall=head_wall+dble(tick-hclock)/dble(rate)
end subroutine
subroutine commit()
use variables,only:t1900,dt,numbit
implicit none
real(8)::x,elapsed
integer(8)::tick
integer::v
call cpu_time(x);call system_clock(tick);elapsed=dble(tick-firstclock)/dble(rate)
steps=steps+1
write(u,*) steps,t1900,dt,numbit,attempts,nvec,njac,nrate,nderiv,nback,nfresh,head_cpu,macro_cpu,x-lastcpu,head_wall,dble(tick-lastclock)/dble(rate),elapsed,logwall
flush(u)
if(steps>=700.or.elapsed>=16d0) then
 close(u)
 open(newunit=v,file='outcome.txt',status='replace');write(v,*) 'COST15_BOUNDED_DIAGNOSTIC',steps,elapsed;close(v)
 stop 0
end if
nvec=0;njac=0;nrate=0;nderiv=0;nback=0;nfresh=0;attempts=0;logwall=0;head_cpu=0;head_wall=0;macro_cpu=0
call cpu_time(lastcpu);call system_clock(lastclock)
end subroutine
end module
subroutine cost15_start()
use COST15,only:start
call start()
end subroutine
subroutine cost15_head_start()
use COST15,only:head_start
call head_start()
end subroutine
subroutine cost15_head_end()
use COST15,only:head_end
call head_end()
end subroutine
subroutine cost15_commit()
use COST15,only:commit
call commit()
end subroutine

subroutine cost15_log_start()
use COST15,only:logclock
call system_clock(logclock)
end subroutine
subroutine cost15_log_end()
use COST15,only:logclock,logwall,rate
integer(8)::tick
call system_clock(tick)
logwall=logwall+dble(tick-logclock)/dble(rate)
end subroutine
