program test_b111_soil_organic_dissimilation
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_soil_organic_turnover
  use mod_b111_soil_organic_dissimilation
  implicit none
  type(b111_organic_turnover_parameters_t)::p
  type(b111_organic_turnover_result_t)::turn
  type(b111_organic_dissimilation_result_t)::d
  real(real64)::expected_bio_av,expected_hum_av,expected_cd,depth,dt

  depth=0.5_real64
  dt=2.0_real64
  p%ratecon_fom=[0.2_real64]
  p%asfa_fom_bio=[0.0_real64]
  p%asfa_fom_hum=[0.0_real64]
  p%ratecon_bio=0.1_real64
  p%ratecon_hum=0.03_real64
  p%asfa_bio=0.0_real64
  p%asfa_hum=0.0_real64

  call evaluate_b111_organic_turnover([20.0_real64],5.0_real64,10.0_real64,dt,p,turn)
  call check(turn%status==B111_ORG_TURNOVER_OK,'turnover')
  call evaluate_b111_organic_dissimilation([20.0_real64],5.0_real64,10.0_real64,depth,dt,p,turn, &
       [0.45_real64],0.5_real64,0.55_real64,d)
  call check(d%status==B111_ORG_DISS_OK,'dissimilation')

  expected_bio_av=5.0_real64*(1.0_real64-exp(-0.1_real64*dt))/(0.1_real64*dt)
  expected_hum_av=10.0_real64*(1.0_real64-exp(-0.03_real64*dt))/(0.03_real64*dt)
  expected_cd=0.45_real64*(20.0_real64-turn%fom_kg_m3(1))*depth + &
       0.5_real64*(5.0_real64-turn%biomass_kg_m3)*depth + &
       0.55_real64*(10.0_real64-turn%humus_kg_m3)*depth

  call near(d%biomass_average_kg_m3,expected_bio_av,'Bio average')
  call near(d%humus_average_kg_m3,expected_hum_av,'Hum average')
  call near(d%carbon_dissimilation_kg_m2,expected_cd,'carbon dissimilation')
  print '(A)','B111_SOIL_ORGANIC_DISSIMILATION_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=3e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
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
