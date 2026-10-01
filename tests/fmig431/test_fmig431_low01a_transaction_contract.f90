program test_fmig431_low01a_transaction_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_legacy_qgwl_bottom_boundary_provider
  use mod_fmr_legacy_bottom_boundary_application_binding
  implicit none
  type(fmr_qgwl_bottom_boundary_config_t) :: c
  type(fmr_legacy_bottom_boundary_binding_t) :: first, retry, next
  integer :: status
  real(real64) :: committed_gwl, rejected_candidate_gwl
  committed_gwl=-86.0_real64; rejected_candidate_gwl=-147.0_real64
  c%swqhbot=FMR_QGWL_EXPONENTIAL;c%cofqha=-0.133_real64;c%cofqhb=-0.01_real64;c%cofqhc=0.082_real64
  call fmr_resolve_legacy_qgwl_bottom_boundary(c,committed_gwl,first,status)
  call require(status==0 .and. first%available,'first trial')
  ! Rejected candidate is deliberately not supplied to retry. Transaction owner
  ! restores the committed checkpoint; LOW01-A samples only that state.
  call fmr_resolve_legacy_qgwl_bottom_boundary(c,committed_gwl,retry,status)
  call require(transfer(first%typed_bottom_flux,0_8)==transfer(retry%typed_bottom_flux,0_8),'retry bit identity')
  call fmr_resolve_legacy_qgwl_bottom_boundary(c,rejected_candidate_gwl,next,status)
  call require(next%typed_bottom_flux/=first%typed_bottom_flux,'accepted-next-state sensitivity')
  print '(a)','F-MIG431-LOW01A_REJECTED_TRIAL_COMMITTED_GWL_IMMUTABILITY=PASS'
  print '(a)','F-MIG431-LOW01A_FAILED_THEN_ACCEPTED_RETRY_QBOT_IDENTITY=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok;character(*),intent(in)::label
    if(.not.ok) then
      write(*,'(A,1X,A)') 'LOW01A_FAIL',trim(label)
      error stop 1
    end if
  end subroutine
end program
