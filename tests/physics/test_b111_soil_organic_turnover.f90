program test_b111_soil_organic_turnover
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_soil_organic_turnover
  implicit none
  type(b111_organic_turnover_parameters_t)::p
  type(b111_organic_turnover_result_t)::r

  p%ratecon_fom=[0.2_real64]
  p%asfa_fom_bio=[0.0_real64]
  p%asfa_fom_hum=[0.0_real64]
  p%ratecon_bio=0.1_real64
  p%ratecon_hum=0.03_real64
  p%asfa_bio=0.0_real64
  p%asfa_hum=0.0_real64

  call evaluate_b111_organic_turnover([20.0_real64],5.0_real64,10.0_real64,2.0_real64,p,r)
  call check(r%status==B111_ORG_TURNOVER_OK,'decoupled turnover')
  call near(r%fom_kg_m3(1),20.0_real64*exp(-0.4_real64),'FOM exponential')
  call near(r%biomass_kg_m3,5.0_real64*exp(-0.2_real64),'Bio exponential')
  call near(r%humus_kg_m3,10.0_real64*exp(-0.06_real64),'Hum exponential')

  p%asfa_fom_bio=[0.2_real64]
  p%asfa_fom_hum=[0.3_real64]
  p%asfa_bio=0.1_real64
  p%asfa_hum=0.2_real64
  call evaluate_b111_organic_turnover([20.0_real64],5.0_real64,10.0_real64,1.0_real64,p,r)
  call check(r%status==B111_ORG_TURNOVER_OK,'coupled turnover')
  call check(r%fom_kg_m3(1)<20.0_real64,'FOM decreases')
  call check(r%biomass_kg_m3>=0.0_real64.and.r%humus_kg_m3>=0.0_real64,'coupled pools nonnegative')

  print '(A)','B111_SOIL_ORGANIC_TURNOVER_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=2e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed'
      error stop 1
    end if
  end subroutine
end program
