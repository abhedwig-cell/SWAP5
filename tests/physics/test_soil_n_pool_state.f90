program test_soil_n_pool_state
 use iso_fortran_env, only: real64
 use mod_soil_n_pool_state
 implicit none
 type(soil_n_pool_state_t)::s,c
 type(soil_n_transfer_t)::t
 type(soil_n_receipt_t)::r
 integer::status
 call initialize_soil_n_pool_state([10d0,5d0],[20d0,15d0],[30d0,25d0],[40d0,35d0],s,status)
 call check(status==SOIL_N_OK,'init')
 allocate(t%ammonium_delta(2),t%nitrate_delta(2),t%organic_fast_delta(2),t%organic_slow_delta(2))
 t%organic_fast_delta=[-2d0,-1d0]; t%ammonium_delta=[1d0,0.5d0]
 t%nitrate_delta=[1d0,0.5d0]; t%organic_slow_delta=0d0
 call apply_soil_n_transfer(s,t,c,r)
 call check(r%status==SOIL_N_OK,'internal transfer')
 call check(abs(r%balance_residual)<1d-12,'internal balance')
 call check(abs(s%total()-180d0)<1d-12,'committed immutable')
 call check(abs(c%total()-180d0)<1d-12,'candidate conserved')
 t%ammonium_delta=0d0; t%nitrate_delta=[3d0,0d0]
 t%organic_fast_delta=0d0;t%organic_slow_delta=0d0
 t%external_input=3d0;t%external_output=0d0
 call apply_soil_n_transfer(s,t,c,r)
 call check(r%status==SOIL_N_OK,'external input')
 call check(abs(c%total()-183d0)<1d-12,'input storage')
 t%external_input=0d0
 call apply_soil_n_transfer(s,t,c,r)
 call check(r%status==SOIL_N_BALANCE,'unbooked creation rejected')
 call check(abs(c%total()-s%total())<1d-12,'balance rollback')
 t%nitrate_delta=[-100d0,0d0];t%external_output=100d0
 call apply_soil_n_transfer(s,t,c,r)
 call check(r%status==SOIL_N_NEGATIVE,'overdraw rejected')
 call check(abs(c%total()-s%total())<1d-12,'negative rollback')
 print '(A)','SOIL_N_POOL_STATE_PASS'
contains
 subroutine check(ok,label)
  logical,intent(in)::ok;character(len=*),intent(in)::label
  if(.not.ok)then
    print '(A)',trim(label)//' failed'
    error stop 1
  end if
 end subroutine
end program
