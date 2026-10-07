program test_swap431_sol01_layout_registry
 use iso_fortran_env,only:int64
 use mod_fmr_runtime_core,only:FMR_SOLUTE_STATE_LAYOUT_NONE, &
      FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED,FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_MACROPORE, &
      FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_SORBED_POND,fmr_solute_state_layout_known
 implicit none
 call check(fmr_solute_state_layout_known(FMR_SOLUTE_STATE_LAYOUT_NONE),'none')
 call check(fmr_solute_state_layout_known(FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED),'mobile')
 call check(fmr_solute_state_layout_known(FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_MACROPORE),'macro')
 call check(fmr_solute_state_layout_known(FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_SORBED_POND),'sol01')
 call check(.not.fmr_solute_state_layout_known(505006_int64),'unknown')
 print '(A)','SOL01_LAYOUT_REGISTRY_PASS'
contains
 subroutine check(ok,label)
  logical,intent(in)::ok;character(len=*),intent(in)::label
  if(.not.ok)then;print '(A)',trim(label)//' failed';error stop 1;end if
 end subroutine
end program
