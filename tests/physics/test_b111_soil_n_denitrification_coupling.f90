program test_b111_soil_n_denitrification_coupling
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_n_pool_state
  use mod_b111_soil_n_denitrification_coupling
  implicit none
  type(soil_n_inventory_parameters_t)::p
  type(soil_n_pool_state_t)::s,c
  type(soil_n_transfer_t)::t
  type(soil_n_receipt_t)::r
  type(b111_denitrification_coupling_receipt_t)::cr
  integer::status

  p%depth_m=0.5_real64
  p%nfrac_fom=[0.01_real64]
  p%nfrac_biomass=0.02_real64
  p%nfrac_humus=0.03_real64
  call initialize_soil_n_pool_state(p,[0.0_real64],0.0_real64,0.0_real64,1.0_real64,2.0_real64,s,status)
  call check(status==SOIL_N_OK,'init')

  call build_b111_denitrification_transfer(1,0.5_real64,2.0_real64,0.30_real64,0.20_real64, &
       0.4_real64,1.5_real64,t,cr)
  call check(cr%status==B111_DENITR_COUPLING_OK,'bridge status')
  call near(cr%denitrified_n_kg_m2,0.15_real64,'source amount')
  call apply_soil_n_transfer(p,s,t,c,r)
  call check(r%status==SOIL_N_OK,'owner apply')
  call near(c%ammonium_n_kg_m2,1.0_real64,'NH4 unchanged')
  call near(c%nitrate_n_kg_m2,1.85_real64,'NO3 debit')
  call near(r%external_n_output_kg_m2,0.15_real64,'external N output')
  call near(c%nitrogen_total(p),s%nitrogen_total(p)-0.15_real64,'whole N loss')

  print '(A)','B111_SOIL_N_DENITRIFICATION_COUPLING_PASS'
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
