program test_b111_soil_n_daily_exchange
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_soil_n_daily_exchange
  implicit none
  type(b111_soil_n_exchange_forcing_t)::f
  type(b111_soil_n_exchange_result_t)::r
  real(real64)::m0,m1,expected

  f%depth_m=0.5_real64
  f%dt_day=1.0_real64
  f%wfrac_t=0.3_real64
  f%wfrac_t0=0.3_real64
  f%tcsf_n=0.0_real64
  f%root_depth_cm=50.0_real64

  call evaluate_b111_soil_n_daily_exchange(f,1.0_real64,2.0_real64,r)
  call check(r%status==B111_NEXCHANGE_OK,'no-op status')
  call near(r%cnh4_end,1.0_real64,'no-op NH4')
  call near(r%cno3_end,2.0_real64,'no-op NO3')
  call near(r%nsupply_total_kg_m2_day,0.0_real64,'no-op supply')
  call near(r%external_input_kg_m2,0.0_real64,'no-op input')
  call near(r%external_output_kg_m2,0.0_real64,'no-op output')

  f%ratecon_nitrif=0.2_real64
  f%ratecon_denitr=0.0_real64
  call evaluate_b111_soil_n_daily_exchange(f,1.0_real64,0.0_real64,r)
  call check(r%status==B111_NEXCHANGE_OK,'nitrification status')
  m0=0.3_real64*1.0_real64*f%depth_m
  m1=0.3_real64*(r%cnh4_end+r%cno3_end)*f%depth_m
  call near(m1,m0,'nitrification mineral N conservation')
  call near(r%nh4_nitrified_kg_m2,0.3_real64*r%cno3_end*f%depth_m,'nitrification receipt')
  call near(r%external_output_kg_m2,0.0_real64,'nitrification internal only')

  f%ratecon_nitrif=0.0_real64
  f%ratecon_denitr=0.1_real64
  call evaluate_b111_soil_n_daily_exchange(f,0.0_real64,1.0_real64,r)
  call check(r%status==B111_NEXCHANGE_OK,'denitrification status')
  m0=0.3_real64*1.0_real64*f%depth_m
  m1=0.3_real64*r%cno3_end*f%depth_m
  expected=m0-m1
  call near(r%no3_denitrified_kg_m2,expected,'denitrification receipt')
  call near(r%external_output_kg_m2,expected,'denitrification external output')
  call near(r%nsupply_total_kg_m2_day,0.0_real64,'denitrification no crop supply')

  print '(A)','B111_SOIL_N_DAILY_EXCHANGE_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=5e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
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
