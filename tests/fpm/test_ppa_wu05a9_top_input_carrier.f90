program test_ppa_wu05a9_top_input_carrier
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_macropore_top_input
  implicit none
  type(fmr_macropore_top_input_t)::carrier
  logical::ok
  call initialize_fmr_macropore_top_input(carrier,[0.10_real64,0.05_real64],[0.02_real64,0.03_real64],ok)
  call require(ok)
  call require(carrier%valid_for_domains(2))
  call require(abs(carrier%total_rate_cm_per_day()-0.20_real64)<1.0e-15_real64)
  call initialize_fmr_macropore_top_input(carrier,[-0.1_real64],[0.0_real64],ok)
  call require(.not.ok)
  call initialize_fmr_macropore_top_input(carrier,[0.1_real64],[0.0_real64,0.1_real64],ok)
  call require(.not.ok)
  print '(a)','PPA_WU05A9_TOP_INPUT_CARRIER=PASS'
contains
  subroutine require(condition)
    logical,intent(in)::condition
    if(.not.condition)error stop 1
  end subroutine require
end program test_ppa_wu05a9_top_input_carrier
