module mod_detailed_interception_process
 use,intrinsic::iso_fortran_env,only:int64,real64
 use,intrinsic::ieee_arithmetic,only:ieee_is_finite
 implicit none;private
 integer,parameter,public::DETINT_OK=0,DETINT_INVALID=1,DETINT_ORDER=2
 type,public::detailed_interception_state_t
  integer(int64)::source_day_id=0_int64
  integer::next_record=1
  real(real64)::restint_cm=0d0
 end type
 type,public::detailed_interception_trial_t
  logical::ready=.false.
  integer(int64)::source_day_id=0_int64
  integer::record=0
  real(real64)::interc_cm=0d0,wfrac=0d0,next_restint_cm=0d0,gross_rain_rate_cm_per_day=0d0,net_rain_rate_cm_per_day=0d0
 end type
 public::initialize_detailed_interception_day,prepare_detailed_interception_record,accept_detailed_interception_record
contains
 subroutine initialize_detailed_interception_day(id,state,status)
  integer(int64),intent(in)::id;type(detailed_interception_state_t),intent(out)::state;integer,intent(out)::status
  state=detailed_interception_state_t();status=DETINT_INVALID;if(id<=0)return
  state%source_day_id=id;status=DETINT_OK
 end subroutine
 subroutine prepare_detailed_interception_record(state,record,daily_gross_rain_cm,record_rain_cm,daily_aintc_cm,daily_net_rain_cm,metperiod,ew0_mm_per_day,trial,status)
  type(detailed_interception_state_t),intent(in)::state;integer,intent(in)::record
  real(real64),intent(in)::daily_gross_rain_cm,record_rain_cm,daily_aintc_cm,daily_net_rain_cm,metperiod,ew0_mm_per_day
  type(detailed_interception_trial_t),intent(out)::trial;integer,intent(out)::status
  real(real64)::interc,w
  trial=detailed_interception_trial_t();status=DETINT_INVALID
  if(state%source_day_id<=0.or.record/=state%next_record)then;status=DETINT_ORDER;return;end if
  if(.not.all(ieee_is_finite([daily_gross_rain_cm,record_rain_cm,daily_aintc_cm,daily_net_rain_cm,metperiod,ew0_mm_per_day,state%restint_cm])))return
  if(any([daily_gross_rain_cm,record_rain_cm,daily_aintc_cm,daily_net_rain_cm,metperiod,ew0_mm_per_day,state%restint_cm]<0d0).or.metperiod<=0d0)return
  if(daily_gross_rain_cm<1d-12)then;interc=0d0;w=0d0
  else
   interc=state%restint_cm+daily_aintc_cm*record_rain_cm/daily_gross_rain_cm
   if(ew0_mm_per_day<0.0001d0)then;w=0d0
   else;w=max(min(interc*10d0/ew0_mm_per_day/metperiod,1d0),0d0);end if
   trial%gross_rain_rate_cm_per_day=record_rain_cm/metperiod
   trial%net_rain_rate_cm_per_day=trial%gross_rain_rate_cm_per_day*daily_net_rain_cm/daily_gross_rain_cm
  end if
  trial%ready=.true.;trial%source_day_id=state%source_day_id;trial%record=record;trial%interc_cm=interc;trial%wfrac=w
  trial%next_restint_cm=max(interc-w*metperiod*ew0_mm_per_day*0.1d0,0d0);status=DETINT_OK
 end subroutine
 subroutine accept_detailed_interception_record(state,trial,status)
  type(detailed_interception_state_t),intent(inout)::state;type(detailed_interception_trial_t),intent(in)::trial;integer,intent(out)::status
  status=DETINT_ORDER
  if(.not.trial%ready.or.trial%source_day_id/=state%source_day_id.or.trial%record/=state%next_record)return
  state%restint_cm=trial%next_restint_cm;state%next_record=state%next_record+1;status=DETINT_OK
 end subroutine
end module
