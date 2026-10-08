program test_b111_soil_n_organic_mineralization_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_n_pool_state
  use mod_b111_soil_n_organic_mineralization_transfer
  implicit none
  type(soil_n_inventory_parameters_t)::p
  type(soil_n_pool_state_t)::s,c
  type(soil_n_transfer_t)::t
  type(soil_n_receipt_t)::owner_receipt
  type(b111_organic_n_mineralization_receipt_t)::r
  integer::status

  p%depth_m=0.5_real64
  p%nfrac_fom=[0.02_real64]
  p%nfrac_biomass=0.04_real64
  p%nfrac_humus=0.05_real64
  call initialize_soil_n_pool_state(p,[10.0_real64],5.0_real64,20.0_real64,2.0_real64,0.0_real64,s,status)
  call check(status==SOIL_N_OK,'init')

  call build_b111_organic_n_mineralization_transfer(p,s,[9.0_real64],5.0_real64,20.0_real64,t,r)
  call check(r%status==B111_ORGN_TRANSFER_OK,'mineralisation build')
  call near(r%mineralized_n_kg_m2,0.01_real64,'mineralisation amount')
  call apply_soil_n_transfer(p,s,t,c,owner_receipt)
  call check(owner_receipt%status==SOIL_N_OK,'mineralisation owner apply')
  call near(c%ammonium_n_kg_m2,2.01_real64,'NH4 credit')
  call near(c%nitrogen_total(p),s%nitrogen_total(p),'turnover whole N conservation')

  call build_b111_organic_n_mineralization_transfer(p,s,[11.0_real64],5.0_real64,20.0_real64,t,r)
  call check(r%status==B111_ORGN_TRANSFER_OK,'immobilisation build')
  call near(r%mineralized_n_kg_m2,-0.01_real64,'immobilisation amount')
  call apply_soil_n_transfer(p,s,t,c,owner_receipt)
  call check(owner_receipt%status==SOIL_N_OK,'immobilisation owner apply')
  call near(c%ammonium_n_kg_m2,1.99_real64,'NH4 debit')
  call near(c%nitrogen_total(p),s%nitrogen_total(p),'immobilisation whole N conservation')

  s%ammonium_n_kg_m2=0.005_real64
  call build_b111_organic_n_mineralization_transfer(p,s,[11.0_real64],5.0_real64,20.0_real64,t,r)
  call apply_soil_n_transfer(p,s,t,c,owner_receipt)
  call check(owner_receipt%status==SOIL_N_NEGATIVE,'insufficient NH4 rejects immobilisation')
  call near(c%ammonium_n_kg_m2,s%ammonium_n_kg_m2,'rejected candidate leaves NH4')
  call near(c%fom_kg_m3(1),s%fom_kg_m3(1),'rejected candidate leaves FOM')

  print '(A)','B111_SOIL_N_ORGANIC_MINERALIZATION_TRANSFER_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=1e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
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
