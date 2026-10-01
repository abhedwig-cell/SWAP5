program test_sw_rib_top01_flood_classifier
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_external_top_flooding_classifier
  implicit none
  type(external_top_flooding_result_t)::r
  real(real64)::nan
  nan=ieee_value(0.0_real64,ieee_quiet_nan)
  call classify_external_top_flooding(0.9_real64,1.0_real64,0.2_real64,r); call req(.not.r%active,'below sill')
  call classify_external_top_flooding(1.0_real64,1.0_real64,0.2_real64,r); call req(.not.r%active,'equal sill')
  call classify_external_top_flooding(1.2_real64,1.0_real64,1.2_real64,r); call req(.not.r%active,'equal local')
  call classify_external_top_flooding(1.2_real64,1.0_real64,0.8_real64,r)
  call req(r%active.and.abs(r%imposed_surface_head_cm-1.2_real64)<1e-15_real64,'active')
  call classify_external_top_flooding(nan,1.0_real64,0.0_real64,r); call req(r%status==EXT_FLOOD_INVALID,'nan')
  write(*,'(A)')'SW_RIB_TOP01_D_CLASSIFIER=PASS'
contains
  subroutine req(x,m); logical,intent(in)::x; character(*),intent(in)::m; if(.not.x)error stop m; end subroutine
end program
