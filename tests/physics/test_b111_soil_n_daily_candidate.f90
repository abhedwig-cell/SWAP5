program test_b111_soil_n_daily_candidate
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_n_pool_state
  use mod_b111_soil_organic_turnover
  use mod_b111_soil_n_daily_exchange
  use mod_b111_soil_n_daily_candidate
  implicit none

  type(soil_n_inventory_parameters_t)::p
  type(soil_n_pool_state_t)::s,c
  type(b111_organic_turnover_parameters_t)::tp
  type(b111_soil_n_exchange_forcing_t)::xf
  type(b111_soil_n_rate_environment_t)::env
  type(b111_soil_n_daily_candidate_result_t)::r
  integer::status
  real(real64)::n0

  p%depth_m=0.5_real64
  p%nfrac_fom=[0.02_real64]
  p%nfrac_biomass=0.04_real64
  p%nfrac_humus=0.05_real64
  call initialize_soil_n_pool_state(p,[20.0_real64],5.0_real64,10.0_real64,1.0_real64,1.0_real64,s,status)
  call check(status==SOIL_N_OK,'init')
  n0=s%nitrogen_total(p)

  tp%ratecon_fom=[0.2_real64]
  tp%asfa_fom_bio=[0.2_real64]
  tp%asfa_fom_hum=[0.3_real64]
  tp%ratecon_bio=0.1_real64
  tp%ratecon_hum=0.03_real64
  tp%asfa_bio=0.1_real64
  tp%asfa_hum=0.2_real64

  xf%dt_day=1.0_real64
  xf%wfrac_t=0.45_real64
  xf%wfrac_t0=0.45_real64
  xf%tcsf_n=0.0_real64
  xf%root_depth_cm=50.0_real64
  xf%drybd=1.2_real64
  xf%sorpcoef=0.4_real64
  xf%crop_n_demand_kg_m2=0.0_real64

  env%temperature_c=20.0_real64
  env%temperature_reference_c=20.0_real64
  env%wfrac_sat=0.5_real64
  env%wfpscrit2=0.6_real64
  env%cdissi_half_kg_m2=0.05_real64
  env%nitrification_ref_per_day=0.0_real64
  env%denitrification_ref_per_day=0.0_real64

  call evaluate_b111_soil_n_daily_candidate(p,s,tp,[0.45_real64],0.50_real64,0.55_real64,env,xf,c,r)
  call check(r%status==B111_NDAY_OK,'organic-only daily candidate')
  call near(c%nitrogen_total(p),n0,'organic-only whole N conservation')
  call check(r%organic%nitrogen%mineralized_n_kg_m2>0.0_real64,'organic mineralization positive')
  call near(r%exchange%external_output_kg_m2,0.0_real64,'organic-only no external output')
  call near(r%owner_receipt%balance_residual_kg_m2,0.0_real64,'organic-only owner closure')

  env%denitrification_ref_per_day=0.2_real64
  call evaluate_b111_soil_n_daily_candidate(p,s,tp,[0.45_real64],0.50_real64,0.55_real64,env,xf,c,r)
  call check(r%status==B111_NDAY_OK,'organic plus denitrification candidate')
  call check(r%exchange%no3_denitrified_kg_m2>0.0_real64,'denitrification positive')
  call near(c%nitrogen_total(p),n0-r%exchange%external_output_kg_m2,'whole N external loss closure')
  call near(r%owner_receipt%external_n_output_kg_m2,r%exchange%external_output_kg_m2,'owner external output identity')
  call near(r%owner_receipt%balance_residual_kg_m2,0.0_real64,'denitrification owner closure')

  print '(A)','B111_SOIL_N_DAILY_CANDIDATE_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=8e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
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
