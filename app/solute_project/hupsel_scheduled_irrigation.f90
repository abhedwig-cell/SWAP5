! Original Hupsel potato scheduling. The incumbent management/event owners own
! timing, dose and application; this adapter binds source inputs and accepted
! previous-day stress observations. It stages a complete day, never a water trial.
module mod_hupsel_scheduled_irrigation
 use iso_fortran_env,only:real64,int8,int32
 use ieee_arithmetic,only:ieee_is_finite
 use mod_tcs1_dcs2_sprinkling_irrigation_process
 use mod_age_joint_restart_file,only:crc32
 implicit none
 private
 public::original_potato_irrigation_t,irrigation_native_view
 type::original_potato_irrigation_t
  type(tcs1_dcs2_sprinkling_parameters_t)::parameters
  type(tcs1_dcs2_sprinkling_state_t)::state
  logical::initialized=.false.,schedule_enabled=.false.
  integer::start_month_day=0,end_month_day=0
  real(real64)::calendar_origin=0d0,clock=0d0
  real(real64)::previous_potential=0d0,previous_drought=0d0,previous_salinity=0d0
  real(real64)::source_concentration=0d0
  integer(int32)::source_crc=0
 contains
  procedure::initialize
  procedure::propose_day
  procedure::interval
  procedure::commit_day
  procedure::valid
 end type
contains
 subroutine initialize(self,crp,origin,nodes,status)
  class(original_potato_irrigation_t),intent(inout)::self
  character(*),intent(in)::crp
  real(real64),intent(in)::origin
  integer,intent(in)::nodes
  integer,intent(out)::status
  integer::flag,calendar(2),n,u,io
  logical::rdinqr
  integer(int8),allocatable::raw(:)
  real(real64)::x(7),v(7)
  status=1
  if(nodes<1.or..not.ieee_is_finite(origin))return
  inquire(file=crp,size=n,iostat=io);if(io/=0.or.n<1.or.n>10485760)return
  allocate(raw(n));open(newunit=u,file=crp,access='stream',form='unformatted',status='old',iostat=io)
  if(io/=0)return
  read(u,iostat=io)raw;close(u);if(io/=0)return
  self%source_crc=crc32(raw)
  self%calendar_origin=origin
  self%parameters=tcs1_dcs2_sprinkling_parameters_t();self%state=tcs1_dcs2_sprinkling_state_t()
  self%clock=0d0;self%previous_potential=0d0;self%previous_drought=0d0;self%previous_salinity=0d0
  call rdinit(74,0,crp);call rdsint('schedule',flag)
  if(flag/=0.and.flag/=1)then;close(74);return;end if
  self%schedule_enabled=flag==1;self%parameters%enabled=self%schedule_enabled
  if(flag==0)then;close(74);self%initialized=.true.;status=0;return;end if
  call rdsint('tcs',flag);if(flag/=1)then;close(74);return;end if
  call rdsint('dcs',flag);if(flag/=2)then;close(74);return;end if
  call rdsint('isuas',flag)
  if(flag/=0)then;close(74);return;end if
  call rdsdou('cirrs',self%source_concentration)
  n=2;call rdfint('startirr',calendar,2,n)
  if(n/=2)then;close(74);return;end if
  if(.not.calendar_date_valid(calendar))then;close(74);return;end if
  self%start_month_day=100*calendar(2)+calendar(1)
  n=2;call rdfint('endirr',calendar,2,n)
  if(n/=2)then;close(74);return;end if
  if(.not.calendar_date_valid(calendar))then;close(74);return;end if
  self%end_month_day=100*calendar(2)+calendar(1)
  call rdsint('tcsfix',flag);if(flag/=0.and.flag/=1)then;close(74);return;end if
  self%parameters%minimum_interval_enabled=flag==1
  if(flag==1)call rdsint('irgdayfix',self%parameters%minimum_interval_days)
  call rdsint('dcslim',flag);if(flag/=0.and.flag/=1)then;close(74);return;end if
  if(flag/=0)then;close(74);return;end if
  call rdsint('swcirrthres',flag)
  ! The original potato uses0. A sensor chemical view is not silently omitted.
  if(flag/=0)then;close(74);return;end if
  ! RAITHRESHOLD applies only to sourceDCS1; read it without altering DCS2.
  call rdsdou('raithreshold',v(1))
  self%parameters%rate_cm_per_day=0d0
  if(rdinqr('irr_rate'))call rdsdou('irr_rate',self%parameters%rate_cm_per_day)
  self%parameters%rate_cm_per_day=2.4d0*self%parameters%rate_cm_per_day
  x=0d0;v=0d0
  call rdinne('dvs_tc1',n)
  if(n<1.or.n>7)then;close(74);return;end if
  call rdfdou('dvs_tc1',x,7,n);self%parameters%threshold_knot_count=n
  call rdfdou('trel',v,7,n)
  self%parameters%threshold_dvs=x;self%parameters%threshold_trel=v
  x=0d0;v=0d0
  call rdinne('dvs_dc2',n)
  if(n<1.or.n>7)then;close(74);return;end if
  call rdfdou('dvs_dc2',x,7,n);self%parameters%depth_knot_count=n
  call rdfdou('fid',v,7,n)
  self%parameters%depth_dvs=x;self%parameters%depth_cm=.1d0*v
  close(74)
  self%initialized=.true.
  if(.not.self%valid())return
  block
   type(tcs1_dcs2_sprinkling_state_t)::candidate
   type(tcs1_dcs2_sprinkling_request_t)::request
   type(tcs1_dcs2_sprinkling_result_t)::result
   type(tcs1_dcs2_sprinkling_diagnostics_t)::diagnostic
   request%t0=0d0;request%t1=1d0;request%selection_opportunity=.true.
   request%irrigation_enabled=.true.;request%schedule_enabled=.true.
   request%crop_emerged=.true.;request%irrigation_window_open=.true.
   call evaluate_tcs1_dcs2_sprinkling_interval(self%parameters,self%state,request,candidate,result,diagnostic)
   if(diagnostic%status/=TCS1_DCS2_OK)return
  end block
  status=0
 end subroutine
 pure logical function calendar_date_valid(calendar)result(ok)
  integer,intent(in)::calendar(2)
  integer,parameter::days(12)=[31,28,31,30,31,30,31,31,30,31,30,31]
  ok=.false.
  if(calendar(2)<1.or.calendar(2)>12)return
  if(calendar(1)<1.or.calendar(1)>days(calendar(2)))return
  ok=.true.
 end function
 logical function valid(self)result(ok)
  class(original_potato_irrigation_t),intent(in)::self
  ok=.false.
  if(.not.self%initialized)return
  if(.not.all(ieee_is_finite([self%calendar_origin,self%clock,self%previous_potential,self%previous_drought, &
       self%previous_salinity,self%source_concentration])))return
  if(self%clock<0d0.or.self%clock>1096d0.or.self%clock/=aint(self%clock))return
  if(min(self%previous_potential,self%previous_drought,self%previous_salinity,self%source_concentration)<0d0)return
  if(self%source_concentration>100d0)return
  if(self%previous_drought+self%previous_salinity>self%previous_potential+ &
       256d0*epsilon(1d0)*max(1d0,self%previous_potential))return
  if(self%state%dayfix<0.or.self%state%dayfix>366)return
  if(self%state%active_event)then
   if(.not.all(ieee_is_finite([self%state%active_event_start,self%state%active_event_end, &
        self%state%active_event_rate_cm_per_day])))return
   if(self%state%active_event_rate_cm_per_day<=0d0)return
   if(self%state%active_event_end<=self%state%active_event_start)return
   if(self%state%active_event_end-self%state%active_event_start>1d0)return
  else
   if(self%state%active_event_start/=0d0.or.self%state%active_event_end/=0d0.or. &
        self%state%active_event_rate_cm_per_day/=0d0)return
  end if
  ok=.true.
 end function
 subroutine interval(self,t0,t1,dvs,emerged,rain,selection,candidate,flux,split,status)
  class(original_potato_irrigation_t),intent(in)::self
  real(real64),intent(in)::t0,t1,dvs,rain
  logical,intent(in)::emerged,selection
  type(original_potato_irrigation_t),intent(out)::candidate
  type(tcs1_dcs2_sprinkling_result_t),intent(out)::flux
  real(real64),intent(out)::split
  integer,intent(out)::status
  type(tcs1_dcs2_sprinkling_request_t)::request
  type(tcs1_dcs2_sprinkling_diagnostics_t)::diagnostic
  integer::date(6),md
  real::seconds
  candidate=self;flux=tcs1_dcs2_sprinkling_result_t();split=t1;status=1
  if(.not.self%valid())return
  if(.not.all(ieee_is_finite([t0,t1,dvs,rain])))return
  if(t0<self%clock.or.t1>self%clock+1d0.or.t1<=t0)return
  call dtdpar(self%calendar_origin+t0,date,seconds);md=100*date(2)+date(3)
  request%t0=t0;request%t1=t1;request%dvs=dvs
  request%selection_opportunity=selection
  request%irrigation_enabled=self%schedule_enabled;request%schedule_enabled=self%schedule_enabled
  request%crop_emerged=emerged
  if(self%start_month_day<=self%end_month_day)then
   request%irrigation_window_open=md>=self%start_month_day.and.md<=self%end_month_day
  else
   request%irrigation_window_open=md>=self%start_month_day.or.md<=self%end_month_day
  end if
  request%potential_transpiration_day_cm=self%previous_potential
  request%dry_reduction_day_cm=self%previous_drought;request%salinity_reduction_day_cm=self%previous_salinity
  call evaluate_tcs1_dcs2_sprinkling_interval(self%parameters,self%state,request,candidate%state,flux,diagnostic)
  status=diagnostic%status
  if(diagnostic%split_required)split=diagnostic%split_time

 end subroutine
 subroutine propose_day(self,time,dvs,emerged,rain,candidate,event_end,rate,status)
  class(original_potato_irrigation_t),intent(in)::self
  real(real64),intent(in)::time,dvs,rain
  logical,intent(in)::emerged
  type(original_potato_irrigation_t),intent(out)::candidate
  real(real64),intent(out)::event_end,rate
  integer,intent(out)::status
  type(tcs1_dcs2_sprinkling_result_t)::flux
  real(real64)::split,again
  candidate=self;event_end=time;rate=0d0;status=1
  if(time/=self%clock)return
  call self%interval(time,time+1d0,dvs,emerged,rain,.true.,candidate,flux,split,status)
  if(status==TCS1_DCS2_SPLIT_REQUIRED)then
   call self%interval(time,split,dvs,emerged,rain,.true.,candidate,flux,again,status)
  end if
  if(status/=0)return
  if(flux%applied)then
   rate=flux%gross_surface_rate_cm_per_day;event_end=time+flux%event_duration_day
  end if
 end subroutine
 subroutine commit_day(self,time,potential,drought,salinity,status)
  class(original_potato_irrigation_t),intent(inout)::self
  real(real64),intent(in)::time,potential,drought,salinity
  integer,intent(out)::status
  type(original_potato_irrigation_t)::next
  status=1;if(.not.self%valid())return
  if(.not.all(ieee_is_finite([time,potential,drought,salinity])))return
  if(time/=self%clock+1d0)return
  next=self;next%clock=time;next%previous_potential=potential;next%previous_drought=drought;next%previous_salinity=salinity
  if(.not.next%valid())return
  self%clock=next%clock;self%previous_potential=potential;self%previous_drought=drought;self%previous_salinity=salinity
  status=0
 end subroutine
 subroutine irrigation_native_view(u,reading,self,io)
  integer,intent(in)::u
  logical,intent(in)::reading
  type(original_potato_irrigation_t),intent(inout)::self
  integer,intent(out)::io
  type(original_potato_irrigation_t)::next
  integer(int32)::source
  integer::active
  next=self;io=1
  if(.not.self%valid())return
  if(reading)then
   read(u,iostat=io)source,next%clock,next%previous_potential,next%previous_drought,next%previous_salinity, &
        next%state%dayfix,active,next%state%active_event_start,next%state%active_event_end, &
        next%state%active_event_rate_cm_per_day
   if(io/=0)return
   if(active/=0.and.active/=1)then;io=1;return;end if
   next%state%active_event=active==1
   if(source/=self%source_crc.or..not.next%valid())then;io=1;return;end if
   self=next
  else
   source=self%source_crc;active=merge(1,0,self%state%active_event)
   write(u,iostat=io)source,self%clock,self%previous_potential,self%previous_drought,self%previous_salinity, &
        self%state%dayfix,active,self%state%active_event_start,self%state%active_event_end, &
        self%state%active_event_rate_cm_per_day
  end if
 end subroutine
end module mod_hupsel_scheduled_irrigation
