program test_fixed_crop_phenology
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_crop_fixed_phenology
  implicit none
  type(fixed_crop_parameters_t)::p,bad
  type(fixed_crop_state_t)::state,candidate,a,b,split,old,invalid
  integer::s,i,mode
  real(real64)::temperature
  do mode=1,2
    p=fixed_crop_parameters_t(mode,4,10d0,20d0,0d0)
    call initialize_fixed_crop(p,state,s);call check(s==FIXED_CROP_OK.and.state%initialized)
    old=state
    call propose_fixed_crop_day(p,state,15d0,a,s);call check(s==0)
    call check(state%development_stage==old%development_stage.and.state%completed_days==0)
    call propose_fixed_crop_day(p,state,5d0,b,s);call check(s==0)
    call propose_fixed_crop_day(p,state,15d0,candidate,s);call check(s==0)
    call same(a,candidate)
    if(mode==2)call check(a%development_stage==1.5d0) ! beginning-phase denominator
    split=state
    do i=1,12
      temperature=real(i-3,real64)
      call propose_fixed_crop_day(p,state,temperature,candidate,s);call check(s==0)
      state=candidate
      call propose_fixed_crop_day(p,split,temperature,candidate,s);call check(s==0)
      split=candidate
    end do
    call same(state,split)
    old=state
    call propose_fixed_crop_day(p,state,ieee_value(0d0,ieee_quiet_nan),candidate,s)
    call check(s==FIXED_CROP_INVALID.and..not.candidate%initialized);call same(state,old)
    invalid=state;invalid%development_stage=-1d0
    call propose_fixed_crop_day(p,invalid,10d0,candidate,s)
    call check(s==FIXED_CROP_INVALID.and..not.candidate%initialized)
  end do
  do i=1,6
    bad=p
    select case(i)
    case(1);bad%development_mode=0
    case(2);bad%emergence_anthesis_degree_days=0d0
    case(3);bad%anthesis_maturity_degree_days=-1d0
    case(4);bad%base_temperature_c=ieee_value(0d0,ieee_quiet_nan)
    case(5);bad%development_mode=1;bad%cycle_days=0
    case(6);bad%development_mode=1;bad%cycle_days=367
    end select
    call initialize_fixed_crop(bad,state,s);call check(s==FIXED_CROP_INVALID.and..not.state%initialized)
  end do
  p=fixed_crop_parameters_t(2,0,tiny(1d0),tiny(1d0),0d0)
  call initialize_fixed_crop(p,state,s);call check(s==0)
  call propose_fixed_crop_day(p,state,1d5,candidate,s)
  call check(s==0.and.candidate%development_stage==2d0)
  state%temperature_sum_degree_days=1d10
  call propose_fixed_crop_day(p,state,10d0,candidate,s)
  call check(s==FIXED_CROP_INVALID.and..not.candidate%initialized)
  print '(A)','FIXED_CROP_STATE_NONMUTATION_ABA_REJECTION_PASS'
contains
  subroutine check(ok)
    logical,intent(in)::ok
    if(.not.ok)error stop 1
  end subroutine
  subroutine same(x,y)
    type(fixed_crop_state_t),intent(in)::x,y
    call check(x%initialized.eqv.y%initialized)
    call check(x%completed_days==y%completed_days.and.x%development_stage==y%development_stage.and. &
      x%temperature_sum_degree_days==y%temperature_sum_degree_days)
  end subroutine
end program
