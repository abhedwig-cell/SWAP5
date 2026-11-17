program test_aquifer_solute_reservoir
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_aquifer_solute_reservoir
  implicit none
  real(real64) :: p(7),original(7),saved(8),nan
  type(aquifer_solute_result) :: result
  integer :: status,i
  p=[2.0_real64,0.5_real64,8.0_real64,3.0_real64,1.0_real64,0.125_real64,0.5_real64]
  original=p;call evaluate()
  if(status/=AQ_OK)error stop 'aquifer A status'
  if(any(pack(result)/=[2.0_real64,4.0_real64,8.0_real64,8.0_real64,1.5_real64,1.0_real64,0.5_real64,0.0_real64])) &
    error stop 'aquifer A units and exact source/outflow/decay balance'
  saved=pack(result)
  p=[1.0_real64,0.5_real64,8.0_real64,2.0_real64,0.0_real64,0.0_real64,0.5_real64]
  call evaluate()
  if(status/=AQ_OK.or.result%concentration_mg_cm3/=1.25_real64.or.result%stock_after_mg_cm2/=5.0_real64 &
      .or.result%soil_input_mg_cm2/=1.0_real64.or.result%residual_mg_cm2/=0.0_real64)error stop 'aquifer B'
  p=original;call evaluate()
  if(status/=AQ_OK.or.any(pack(result)/=saved))error stop 'aquifer A/B/A hidden state'
  if(any(p/=original))error stop 'aquifer inputs mutated'
  p(4)=-1.0_real64;p(5)=-1.0_real64;call evaluate()
  if(status/=AQ_OK.or.result%concentration_mg_cm3/=1.75_real64.or.result%stock_after_mg_cm2/=7.0_real64 &
      .or.result%surface_out_mg_cm2/=0.0_real64.or.result%soil_input_mg_cm2/=-0.5_real64 &
      .or.result%residual_mg_cm2/=0.0_real64)error stop 'signed soil return flow'
  p=original;p(7)=0.0_real64;p(4:6)=huge(1.0_real64);call evaluate()
  if(status/=AQ_OK.or.result%stock_after_mg_cm2/=8.0_real64.or.result%residual_mg_cm2/=0.0_real64 &
      .or.any([result%soil_input_mg_cm2,result%surface_out_mg_cm2,result%decayed_mg_cm2]/=0.0_real64)) &
    error stop 'zero interval changed reservoir'

  p=original;nan=ieee_value(0.0_real64,ieee_quiet_nan)
  do i=1,7
    p=original;p(i)=nan;call refused(AQ_INVALID)
  end do
  p=original;p(1)=-1.0_real64;call refused(AQ_INVALID)
  p=original;p(2)=0.0_real64;call refused(AQ_INVALID)
  p=original;p(3)=0.0_real64;call refused(AQ_INVALID)
  p=original;p(6)=-1.0_real64;call refused(AQ_INVALID)
  p=original;p(7)=-1.0_real64;call refused(AQ_INVALID)
  p=original;p(4)=0.0_real64;p(6)=0.0_real64;p(7)=8.0_real64;call refused(AQ_NEGATIVE)
  p=original;p(2)=huge(1.0_real64);call refused(AQ_OVERFLOW)
  p=original;p(1)=huge(1.0_real64);call refused(AQ_OVERFLOW)
  p=[1.0_real64,1.0_real64,1.0_real64,-huge(1.0_real64),huge(1.0_real64),0.0_real64,1.0_real64]
  call refused(AQ_OVERFLOW)
  p=[1.0_real64,1.0e-300_real64,1.0_real64,huge(1.0_real64),0.0_real64,0.0_real64,1.0_real64]
  call refused(AQ_OVERFLOW)
  print '(a)','AQUIFER_SOLUTE_RESERVOIR_CONTRACT=PASS'
contains
  subroutine evaluate()
    call evaluate_aquifer_solute_reservoir(p(1),p(2),p(3),p(4),p(5),p(6),p(7),result,status)
  end subroutine
  subroutine refused(expected)
    integer,intent(in)::expected
    real(real64)::before(8)
    before=pack(result);call evaluate()
    if(status/=expected)error stop 'aquifer refusal status'
    if(any(pack(result)/=before))error stop 'refused aquifer request modified result'
  end subroutine
  function pack(r)result(values)
    type(aquifer_solute_result),intent(in)::r
    real(real64)::values(8)
    values=[r%concentration_mg_cm3,r%capacity_cm,r%stock_before_mg_cm2,r%stock_after_mg_cm2, &
            r%soil_input_mg_cm2,r%surface_out_mg_cm2,r%decayed_mg_cm2,r%residual_mg_cm2]
  end function
end program
