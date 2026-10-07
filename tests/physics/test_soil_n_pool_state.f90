program test_soil_n_pool_state
 use iso_fortran_env,only:real64
 use mod_soil_n_pool_state
 implicit none
 type(soil_n_inventory_parameters_t)::p
 type(soil_n_pool_state_t)::s,c
 type(soil_n_transfer_t)::t
 type(soil_n_receipt_t)::r
 integer::status
 p%depth_m=.5d0;p%nfrac_fom=[.01d0,.02d0];p%nfrac_biomass=.03d0;p%nfrac_humus=.04d0
 call initialize_soil_n_pool_state(p,[10d0,20d0],5d0,40d0,2d0,3d0,s,status)
 call check(status==SOIL_N_OK,'init')
 call near(s%nitrogen_total(p),2d0+3d0+.5d0*(.1d0+.4d0+.15d0+1.6d0),'total')
 allocate(t%fom_delta_kg_m3(2));t%fom_delta_kg_m3=[-1d0,0d0]
 t%ammonium_n_delta_kg_m2=.005d0
 call apply_soil_n_transfer(p,s,t,c,r)
 call check(r%status==SOIL_N_OK,'mineralisation transfer')
 call near(r%balance_residual_kg_m2,0d0,'balance')
 call near(s%fom_kg_m3(1),10d0,'committed immutable')
 t=soil_n_transfer_t();allocate(t%fom_delta_kg_m3(2));t%fom_delta_kg_m3=0d0
 t%nitrate_n_delta_kg_m2=1d0
 call apply_soil_n_transfer(p,s,t,c,r)
 call check(r%status==SOIL_N_BALANCE,'unbooked creation')
 call near(c%nitrogen_total(p),s%nitrogen_total(p),'balance rollback')
 t%nitrate_n_delta_kg_m2=-100d0;t%external_n_output_kg_m2=100d0
 call apply_soil_n_transfer(p,s,t,c,r)
 call check(r%status==SOIL_N_NEGATIVE,'overdraw')
 print '(A)','SOIL_N_POOL_STATE_PASS'
contains
 subroutine near(x,y,label)
  real(real64),intent(in)::x,y;character(len=*),intent(in)::label
  call check(abs(x-y)<=1d-12*max(1d0,abs(x),abs(y)),label)
 end subroutine
 subroutine check(ok,label)
  logical,intent(in)::ok;character(len=*),intent(in)::label
  if(.not.ok)then;print '(A)',trim(label)//' failed';error stop 1;end if
 end subroutine
end program
