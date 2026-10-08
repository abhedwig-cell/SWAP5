program test_b111_soil_n_organic_turnover_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_n_pool_state
  use mod_b111_soil_organic_turnover
  use mod_b111_soil_n_organic_turnover_transfer
  implicit none
  type(soil_n_inventory_parameters_t)::p
  type(soil_n_pool_state_t)::s,c
  type(b111_organic_turnover_parameters_t)::tp
  type(soil_n_transfer_t)::t
  type(soil_n_receipt_t)::owner_receipt
  type(b111_organic_n_turnover_receipt_t)::r
  integer::status
  real(real64)::n0

  p%depth_m=0.5_real64
  p%nfrac_fom=[0.02_real64]
  p%nfrac_biomass=0.04_real64
  p%nfrac_humus=0.05_real64
  call initialize_soil_n_pool_state(p,[20.0_real64],5.0_real64,10.0_real64,2.0_real64,0.0_real64,s,status)
  call check(status==SOIL_N_OK,'init')
  n0=s%nitrogen_total(p)

  tp%ratecon_fom=[0.2_real64]
  tp%asfa_fom_bio=[0.2_real64]
  tp%asfa_fom_hum=[0.3_real64]
  tp%ratecon_bio=0.1_real64
  tp%ratecon_hum=0.03_real64
  tp%asfa_bio=0.1_real64
  tp%asfa_hum=0.2_real64

  call build_b111_organic_n_turnover_transfer(p,s,1.0_real64,tp,t,r)
  call check(r%status==B111_ORGN_TURNOVER_OK,'turnover transfer build')
  call apply_soil_n_transfer(p,s,t,c,owner_receipt)
  call check(owner_receipt%status==SOIL_N_OK,'turnover owner apply')
  call near(c%nitrogen_total(p),n0,'whole N conserved')
  call near(c%ammonium_n_kg_m2-s%ammonium_n_kg_m2,r%nitrogen%mineralized_n_kg_m2,'NH4 equals organic N loss')
  call check(all(c%fom_kg_m3==r%organic%fom_kg_m3),'FOM candidate identity')
  call near(c%biomass_kg_m3,r%organic%biomass_kg_m3,'Bio candidate identity')
  call near(c%humus_kg_m3,r%organic%humus_kg_m3,'Hum candidate identity')

  ! Force an immobilising candidate with insufficient mineral N through the
  ! lower owner bridge; rejection must preserve every committed store.
  s%ammonium_n_kg_m2=0.0_real64
  t=soil_n_transfer_t()
  allocate(t%fom_delta_kg_m3(1))
  t%fom_delta_kg_m3=[1.0_real64]
  t%ammonium_n_delta_kg_m2=-0.01_real64
  call apply_soil_n_transfer(p,s,t,c,owner_receipt)
  call check(owner_receipt%status==SOIL_N_NEGATIVE,'immobilisation reject')
  call near(c%fom_kg_m3(1),s%fom_kg_m3(1),'rejected FOM unchanged')
  call near(c%ammonium_n_kg_m2,s%ammonium_n_kg_m2,'rejected NH4 unchanged')

  print '(A)','B111_SOIL_N_ORGANIC_TURNOVER_TRANSFER_PASS'
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
