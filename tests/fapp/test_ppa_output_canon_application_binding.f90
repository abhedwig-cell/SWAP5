program test_ppa_output_canon_application_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_canonical_contracts, only: canonical_result_t, CANONICAL_STATUS_COMPLETED
  use mod_canonical_result_text_adapter, only: serialize_canonical_result_text
  use mod_fmr_production_application_bootstrap, only: production_application_serialize_canonical_result_text
  implicit none

  type(canonical_result_t) :: result
  character(len=:), allocatable :: direct_text, application_text, unchanged_text, changed_text

  result%status = CANONICAL_STATUS_COMPLETED
  result%completed = .true.
  result%requested_t0 = 12.0_real64
  result%requested_t1 = 13.0_real64
  result%completed_t = 13.0_real64
  result%mass%complete = .true.
  result%mass%interval_t0 = 12.0_real64
  result%mass%interval_t1 = 13.0_real64
  result%mass%total_in = 0.375_real64
  result%mass%total_out = 0.125_real64
  result%mass%residual = 0.0_real64
  result%diagnostics%attempts = 2
  result%diagnostics%committed_substeps = 1

  call serialize_canonical_result_text(result, direct_text)
  call production_application_serialize_canonical_result_text(result, application_text)
  call require(direct_text == application_text, 'application binding is byte-identical to admitted serializer')
  call require(index(application_text, 'SWAP5_CANONICAL_RESULT_SNAPSHOT' // new_line('a')) == 1, &
       'canonical result text header')
  call require(index(application_text, 'mass_total_in=') > 0, 'accepted mass fields are visible')
  print '(a)', 'PPA_OUTPUT_CANON_APPLICATION_BYTE_IDENTITY=PASS'

  call serialize_canonical_result_text(result, unchanged_text)
  call require(unchanged_text == direct_text, 'serialization leaves the accepted input unchanged')
  result%completed = .false.
  call serialize_canonical_result_text(result, changed_text)
  call require(application_text == direct_text, 'returned text is an independent snapshot')
  call require(changed_text /= application_text, 'later input change appears only in a later snapshot')
  print '(a)', 'PPA_OUTPUT_CANON_APPLICATION_READ_ONLY_SNAPSHOT=PASS'
  print '(a)', 'PPA_OUTPUT_CANON_APPLICATION_FILE_FREE=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (condition) return
    write(*, '(a)') 'PPA_OUTPUT_CANON_APPLICATION_BINDING_FAIL: ' // message
    error stop 1
  end subroutine require

end program test_ppa_output_canon_application_binding
