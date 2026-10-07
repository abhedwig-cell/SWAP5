program test_solute_sorbed_pond_state
 use iso_fortran_env,only:real64
 use mod_solute_sorbed_pond_state
 implicit none
 type(solute_sorbed_pond_state_t)::s
 integer::status
 call initialize_solute_sorbed_pond_state([1d0,2d0],3d0,s,status)
 call check(status==SOLSP_OK,'init')
 call check(s%ready(2),'ready')
 call check(abs(s%total()-6d0)<1d-12,'total')
 call check(.not.s%ready(3),'node mismatch')
 call initialize_solute_sorbed_pond_state([1d0,-1d0],0d0,s,status)
 call check(status==SOLSP_INVALID,'negative invalid')
 print '(A)','SOLUTE_SORBED_POND_STATE_PASS'
contains
 subroutine check(ok,label)
  logical,intent(in)::ok;character(len=*),intent(in)::label
  if(.not.ok)then;print '(A)',trim(label)//' failed';error stop 1;end if
 end subroutine
end program
