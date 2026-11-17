program original_time_event
 use variables
 use MOD_swap_base
 use MOD_irrigation, only:dt_irr_event
 implicit none
 real(8)::proposal,used,total,last
 integer::step_index,case_index
 real(8),parameter::proposals(5)=[0.0004938271604738587d0,0.125d0,0.13d0,0.2d0,0.03999999999d0]
 do case_index=1,size(proposals)
 proposal=proposals(case_index)
 swscre=0;swmacro=0;swsolve=1;swmetdetail=0;swrain=0;swrunon=0
 swheader=0;swres=0;swirfix=0;swinco=0
 dt_irr_event=1.d0
 flDayStart=.true.;flDayEnd=.false.;flRunEnd=.false.;flZeroIntr=.false.;flZeroCumu=.false.
 flprintshort=.false.;flprintdt=.false.;floutput=.false.;flbaloutput=.false.;fldtmin=.false.
 nprintday=1;nprintcount=1;ioutdat=1;ioutdatint=1;outdat=1.d6;outdatint=1.d6
 cntper=0;period=100;outper=0.d0
 t1900=37276.d0;tstart=t1900;tend=t1900+2.d0;timjan1=37256.d0;tcum=0.d0
 daynr=21;daycum=21;iyear=2002;imonth=1;isteps=0;msteps=100000
 dt=proposal;dtmin=1.d-5;dtmax=0.04d0;numbit=6;numbit_crit=3;maxit=10
 fact_dt_increase=1.25d0;fact_dt_decrease=0.5d0
 total=0.d0
 do step_index=1,100000
 used=dt;total=total+used;last=used
 call TimeControl(3)
 if(flDayEnd)exit
 enddo
 if(step_index>100000)stop 3
 write(*,'(a,i3,i8,4es26.17)')'EVENT',case_index,step_index,proposal,total,total-1.d0,last
 enddo
end program
