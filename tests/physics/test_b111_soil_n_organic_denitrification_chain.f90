program test_b111_soil_n_organic_denitrification_chain
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_n_pool_state
  use mod_b111_soil_organic_turnover
  use mod_b111_soil_n_organic_turnover_transfer
  use mod_b111_soil_organic_dissimilation
  use mod_b111_soil_n_rate_factors
  use mod_b111_soil_n_denitrification_coupling
  implicit none

  type(soil_n_inventory_parameters_t)::p
  type(soil_n_pool_state_t)::s,after_org,after_denit
  type(b111_organic_turnover_parameters_t)::tp
  type(soil_n_transfer_t)::org_transfer,denit_transfer
  type(soil_n_receipt_t)::owner_receipt
  type(b111_organic_n_turnover_receipt_t)::org_receipt
  type(b111_organic_dissimilation_result_t)::diss
  type(b111_soil_n_rate_result_t)::rates
  type(b111_denitrification_coupling_receipt_t)::denit_receipt
  integer::status
  real(real64)::n0,n_after_org

  p%depth_m=0.5_real64
  p%nfrac_fom=[0.02_real64]
  p%nfrac_biomass=0.04_real64
  p%nfrac_humus=0.05_real64
  call initialize_soil_n_pool_state(p,[20.0_real64],5.0_real64,10.0_real64,1.0_real64,2.0_real64,s,status)
  call check(status==SOIL_N_OK,'init')
  n0=s%nitrogen_total(p)

  tp%ratecon_fom=[0.2_real64]
  tp%asfa_fom_bio=[0.2_real64]
  tp%asfa_fom_hum=[0.3_real64]
  tp%ratecon_bio=0.1_real64
  tp%ratecon_hum=0.03_real64
  tp%asfa_bio=0.1_real64
  tp%asfa_hum=0.2_real64

  call build_b111_organic_n_turnover_transfer(p,s,1.0_real64,tp,org_transfer,org_receipt)
  call check(org_receipt%status==B111_ORGN_TURNOVER_OK,'organic transfer')
  call apply_soil_n_transfer(p,s,org_transfer,after_org,owner_receipt)
  call check(owner_receipt%status==SOIL_N_OK,'organic owner apply')
  n_after_org=after_org%nitrogen_total(p)
  call near(n_after_org,n0,'organic whole N conservation')

  call evaluate_b111_organic_dissimilation(s%fom_kg_m3,s%biomass_kg_m3,s%humus_kg_m3,p%depth_m,1.0_real64,tp, &
       org_receipt%organic,[0.45_real64],0.50_real64,0.55_real64,diss)
  call check(diss%status==B111_ORG_DISS_OK,'carbon dissimilation')
  call check(diss%carbon_dissimilation_kg_m2>0.0_real64,'positive Cdissi')

  call evaluate_b111_soil_n_rate_constants(20.0_real64,20.0_real64,0.45_real64,0.45_real64,0.50_real64, &
       0.60_real64,diss%carbon_dissimilation_kg_m2,0.05_real64,0.0_real64,0.2_real64,rates)
  call check(rates%status==B111_NRATE_OK,'rate factors')
  call check(rates%denitrification_rate_constant>0.0_real64,'positive denitrification rate')

  call build_b111_denitrification_transfer(1,p%depth_m,1.0_real64,0.45_real64,0.45_real64, &
       rates%denitrification_rate_constant,1.0_real64,denit_transfer,denit_receipt)
  call check(denit_receipt%status==B111_DENITR_COUPLING_OK,'denitrification bridge')
  call apply_soil_n_transfer(p,after_org,denit_transfer,after_denit,owner_receipt)
  call check(owner_receipt%status==SOIL_N_OK,'denitrification owner apply')
  call near(owner_receipt%external_n_output_kg_m2,denit_receipt%denitrified_n_kg_m2,'external output receipt')
  call near(after_denit%nitrogen_total(p),n_after_org-denit_receipt%denitrified_n_kg_m2,'whole N after denitrification')
  call near(after_denit%ammonium_n_kg_m2,after_org%ammonium_n_kg_m2,'NH4 unchanged by denitrification')

  print '(A)','B111_SOIL_N_ORGANIC_DENITRIFICATION_CHAIN_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=4e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
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
