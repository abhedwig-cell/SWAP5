program test_mig431_reference_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_irrigation_process, only: irrigation_state_t, irrigation_flux_result_t, &
       irrigation_diagnostics_t, IRRIGATION_APPLICATION_SSDI
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_irrigation_reference_binding
  implicit none
  type(fmr_b110_physical_forcing_t) :: base, candidate
  type(irrigation_flux_result_t) :: flux
  type(irrigation_diagnostics_t) :: diagnostics
  type(irrigation_state_t) :: committed, proposed
  type(fmr_serialized_column_result_t) :: result
  logical :: published
  integer :: status

  base%top_flux = 3.0_real64
  base%subsurface_irrigation_source = [0.1_real64,0.2_real64,0.0_real64]
  flux%applied = .true.
  flux%application_type = IRRIGATION_APPLICATION_SSDI
  flux%subsurface_source = [0.0_real64,2.0_real64,0.0_real64]
  flux%active_duration = 0.25_real64
  flux%external_inflow_amount = 0.5_real64
  call fmr_bind_ssdi_reference_candidate(base,flux,diagnostics,candidate,status)
  if (status /= FMR_IRR_REFERENCE_OK) error stop 1
  if (any(candidate%subsurface_irrigation_source /= [0.1_real64,2.2_real64,0.0_real64])) error stop 2
  if (candidate%top_flux /= base%top_flux .or. &
      any(base%subsurface_irrigation_source /= [0.1_real64,0.2_real64,0.0_real64])) error stop 3
  flux%external_inflow_amount = 0.6_real64
  call fmr_bind_ssdi_reference_candidate(base,flux,diagnostics,candidate,status)
  if (status /= FMR_IRR_REFERENCE_INVALID) error stop 4

  proposed%next_fixed_event_index = 2
  call fmr_publish_accepted_irrigation_state(committed,proposed,result,11_int64,100.25_real64,published)
  if (published .or. committed%next_fixed_event_index /= 1) error stop 5
  result%committed = .true.
  result%completed = .true.
  result%mass%complete = .true.
  result%final_committed_time_bound = .true.
  result%final_committed_time = 100.25_real64
  result%column_id = 12_int64
  call fmr_publish_accepted_irrigation_state(committed,proposed,result,11_int64,100.25_real64,published)
  if (published .or. committed%next_fixed_event_index /= 1) error stop 6
  result%column_id = 11_int64
  call fmr_publish_accepted_irrigation_state(committed,proposed,result,11_int64,100.5_real64,published)
  if (published .or. committed%next_fixed_event_index /= 1) error stop 7
  result%mass%complete = .false.
  call fmr_publish_accepted_irrigation_state(committed,proposed,result,11_int64,100.25_real64,published)
  if (published .or. committed%next_fixed_event_index /= 1) error stop 8
  result%mass%complete = .true.
  call fmr_publish_accepted_irrigation_state(committed,proposed,result,11_int64,100.25_real64,published)
  if (.not. published .or. committed%next_fixed_event_index /= 2) error stop 6
  print '(a)', 'F_MIG431_REFERENCE_SOURCE_AND_ACCEPTANCE_BINDING=PASS'
end program
