program test_soil_n_reaction_transfer
 use iso_fortran_env, only: real64
 use mod_soil_n_pool_state
 use mod_soil_n_reaction_transfer
 implicit none
 type(soil_n_pool_state_t)::s,c
 type(soil_n_transfer_t)::t
 type(soil_n_receipt_t)::r
 integer::status
 call initialize_soil_n_pool_state([4d0,6d0],[10d0,20d0],[1d0,2d0],[3d0,4d0],s,status)
 call check(status==SOIL_N_OK,'init')
 call build_nitrification_transfer([1d0,2d0],t,status)
 call check(status==SOIL_N_REACTION_OK,'nitrification build')
 call apply_soil_n_transfer(s,t,c,r)
 call check(r%status==SOIL_N_OK,'nitrification apply')
 call check(abs(sum(c%ammonium)-7d0)<1d-12,'nh4 debit')
 call check(abs(sum(c%nitrate)-33d0)<1d-12,'no3 credit')
 call check(abs(c%total()-s%total())<1d-12,'nitrification conservation')
 call build_denitrification_transfer([2d0,3d0],t,status)
 call check(status==SOIL_N_REACTION_OK,'denitrification build')
 call apply_soil_n_transfer(s,t,c,r)
 call check(r%status==SOIL_N_OK,'denitrification apply')
 call check(abs(r%external_output-5d0)<1d-12,'denitrification output booked')
 call check(abs(c%total()-(s%total()-5d0))<1d-12,'denitrification balance')
 call build_nitrification_transfer([100d0,0d0],t,status)
 call apply_soil_n_transfer(s,t,c,r)
 call check(r%status==SOIL_N_NEGATIVE,'overdraw rollback')
 call check(abs(c%total()-s%total())<1d-12,'overdraw identity')
 print '(A)','SOIL_N_REACTION_TRANSFER_PASS'
contains
 subroutine check(ok,label)
  logical,intent(in)::ok;character(len=*),intent(in)::label
  if(.not.ok)then;print '(A)',trim(label)//' failed';error stop 1;end if
 end subroutine
end program
