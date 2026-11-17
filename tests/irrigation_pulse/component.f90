program pulse_component
 use variables
 use MOD_swap_base
 use MOD_irrigation,only:gird,dt_irr_event
 implicit none
 real(8)::used,total,largest_off,largest_on,cap
 integer::i,pulse_steps
 swscre=0;swmacro=0;swsolve=1;swmetdetail=0;swrain=0;swrunon=0
 swheader=0;swres=0;swirfix=0;swinco=0
 dtmin=1d-6;dtmax=0.04d0;dt=dtmax
 ! Absent, full-day and subsurface/no-surface-rate controls retain proposal.
 gird=0d0;dt_irr_event=1d0/12d0;call TimeControl(9)
 if(dt/=dtmax)stop 11
 gird=28.8d0;dt_irr_event=1d0;call TimeControl(9)
 if(dt/=dtmax)stop 12
 dt_irr_event=1d0/12d0;cap=dt_irr_event/2048d0;call TimeControl(9)
 if(dt/=cap)stop 13
 flDayStart=.true.;flDayEnd=.false.;flRunEnd=.false.;flZeroIntr=.false.;flZeroCumu=.false.
 flprintshort=.false.;flprintdt=.false.;floutput=.false.;flbaloutput=.false.;fldtmin=.false.
 nprintday=1;nprintcount=1;ioutdat=1;ioutdatint=1;outdat=1d6;outdatint=1d6
 cntper=0;period=100;outper=0d0
 t1900=37260d0;tstart=t1900;tend=t1900+2d0;timjan1=37256d0;tcum=0d0;t=4d0
 daynr=5;daycum=5;iyear=2002;imonth=1;isteps=0;msteps=100000
 numbit=1;numbit_crit=3;maxit=10;fact_dt_increase=2d0;fact_dt_decrease=0.5d0
 total=0d0;largest_on=0d0;largest_off=0d0;pulse_steps=0
 do i=1,10000
  used=dt;total=total+used
  if(gird>0d0)then
   largest_on=max(largest_on,used);pulse_steps=pulse_steps+1
   if(used>cap)stop 14
  else
   largest_off=max(largest_off,used)
  endif
  call TimeControl(3)
  if(flDayEnd)exit
 enddo
 if(i>10000.or.pulse_steps<2047.or.pulse_steps>2049)stop 15
 if(abs(total-1d0)>1d-8.or.largest_off<=100d0*cap)stop 16
 write(*,'(a,2i8,4es25.16)')'PULSE_COMPONENT_PASS',i,pulse_steps,total,largest_on,largest_off,cap
end program
