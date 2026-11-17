program test_age_effluent_observer
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_age_effluent_observer
  implicit none
  type(age_effluent_result_t)::r,before,second
  real(real64)::c(2),root(2),drain(2,2),mean
  integer::status
  c=[2d0,8d0];root=[.5d0,.25d0];drain=reshape([.25d0,-.5d0,.5d0,.125d0],[2,2])
  call evaluate_age_effluent(.5d0,c,root,drain,-.25d0,r,status)
  call require(status==AGE_EFFLUENT_OK,'valid real provider')
  call require(all(r%water_cm==[.125d0,.375d0,.375d0,.0625d0]),'actual exported water including signed levels')
  call require(all(r%age_amount_cm_day==[1d0,1.5d0,2.25d0,.5d0]),'cm day amounts')
  call require(all(r%mean_age_day==[8d0,4d0,6d0,8d0]),'water weighted effluent ages')
  ! Legacy age amount / elapsed time is dimensionally and numerically different.
  call require(abs(r%age_amount_cm_day(3)/.5d0-r%mean_age_day(3))>1d0,'legacy time denominator counterexample')
  before=r
  call evaluate_age_effluent(.25d0,c,root,drain,-.25d0,second,status)
  call require(status==AGE_EFFLUENT_OK.and.all(second%mean_age_day==r%mean_age_day),'age independent of duration at fixed mixture')
  call evaluate_age_effluent(.5d0,c,root,drain,-.25d0,r,status)
  call require(all(r%age_amount_cm_day==before%age_amount_cm_day),'A B A independent')
  c(1)=ieee_value(0d0,ieee_quiet_nan)
  call evaluate_age_effluent(.5d0,c,root,drain,-.25d0,r,status)
  call require(status==AGE_EFFLUENT_INVALID.and.all(r%water_cm==before%water_cm),'nonfinite refusal preserves result')
  c=[2d0,8d0];root(1)=-1d0
  call evaluate_age_effluent(.5d0,c,root,drain,-.25d0,r,status)
  call require(status==AGE_EFFLUENT_INVALID.and.all(r%mean_age_day==before%mean_age_day),'invalid forcing preserves result')
  mean=77d0;call age_effluent_mean(1d0,0d0,mean,status)
  call require(status/=AGE_EFFLUENT_OK.and.mean==77d0,'orphan amount refused without output mutation')
  call age_effluent_mean(huge(1d0),tiny(1d0),mean,status)
  call require(status==AGE_EFFLUENT_UNREPRESENTABLE.and.mean==77d0,'ratio overflow refused before division')
  call age_effluent_mean(0d0,0d0,mean,status)
  call require(status==AGE_EFFLUENT_OK.and.mean==0d0,'no export is explicit zero amount and water')
  print *,'AGE_EFFLUENT_WATER_WEIGHTED_UNITS_ABA_AND_REFUSALS=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 'age effluent observer'
    end if
  end subroutine
end program
