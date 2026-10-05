program test_mig431_reference_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_irrigation_process, only: irrigation_state_t, irrigation_flux_result_t, &
       irrigation_diagnostics_t, IRRIGATION_APPLICATION_SSDI, scheduled_irrigation_parameters_t, &
       scheduled_irrigation_request_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_irrigation_reference_binding
  use mod_kernel_transactions, only: kernel_committed_state_t
  implicit none
  type(fmr_b110_physical_forcing_t) :: base, candidate
  type(irrigation_flux_result_t) :: flux
  type(irrigation_diagnostics_t) :: diagnostics
  type(irrigation_state_t) :: committed, proposed
  type(fmr_serialized_column_result_t) :: result
  type(fmr_b110_physical_state_t) :: physical
  type(fmr_b110_physical_parameters_t) :: physical_parameters
  type(kernel_committed_state_t) :: committed_physical
  type(scheduled_irrigation_parameters_t) :: scheduled_parameters
  type(scheduled_irrigation_request_t) :: request
  type(irrigation_flux_result_t) :: scheduled_flux
  type(irrigation_diagnostics_t) :: scheduled_diagnostics
  type(irrigation_state_t) :: scheduled_candidate
  logical :: physical_ready
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

  physical%active_nodes = 3
  allocate(physical%pressure_head(3),physical%water_content(3))
  physical%pressure_head = [-50.0_real64,-150.0_real64,-250.0_real64]
  physical%water_content = [0.30_real64,0.25_real64,0.20_real64]
  physical_parameters%active_nodes = 3
  allocate(physical_parameters%z(3))
  physical_parameters%z = [-10.0_real64,-20.0_real64,-30.0_real64]
  call fmr_new_b110_committed_state(committed_physical,101_int64,physical,20.0_real64,physical_ready)
  if (.not. physical_ready) error stop 9
  call committed_physical%current_time(request%t0,physical_ready)
  if (.not. physical_ready) error stop 10
  request%t1 = request%t0 + 0.1_real64
  request%dvs = 1.0_real64
  request%selection_opportunity = .true.
  request%irrigation_enabled = .true.
  request%schedule_enabled = .true.
  request%crop_emerged = .true.
  request%irrigation_window_open = .true.
  scheduled_parameters%scheduled_irrigation_enabled = .true.
  scheduled_parameters%timing_criterion = 7
  scheduled_parameters%depth_criterion = 2
  scheduled_parameters%application_type = IRRIGATION_APPLICATION_SSDI
  scheduled_parameters%single_ssdi_node = 3
  scheduled_parameters%irr_rate_cm_per_day = 0.1_real64
  scheduled_parameters%tcs7_knot_count = 2
  scheduled_parameters%tcs7_dvs(1:2) = [0.0_real64,2.0_real64]
  scheduled_parameters%tcs7_pressure_head(1:2) = [-100.0_real64,-100.0_real64]
  scheduled_parameters%dcs2_knot_count = 2
  scheduled_parameters%dcs2_dvs(1:2) = [0.0_real64,2.0_real64]
  scheduled_parameters%dcs2_depth_cm(1:2) = [0.02_real64,0.02_real64]
  result%column_id = 101_int64
  result%completed = .true.
  result%committed = .true.
  result%mass%complete = .true.
  result%final_committed_time_bound = .true.
  result%final_committed_time = request%t0
  result%requested_t1 = request%t0
  result%final_revision = committed_physical%current_revision()
  call fmr_prepare_scheduled_irrigation_from_accepted(physical_parameters,committed_physical,result, &
       15.0_real64,irrigation_state_t(),request,scheduled_parameters,scheduled_candidate,scheduled_flux, &
       scheduled_diagnostics,status)
  if (status /= FMR_IRR_REFERENCE_OK .or. scheduled_diagnostics%status /= 0 .or. &
      .not. scheduled_diagnostics%triggered .or. .not. scheduled_flux%event_started) error stop 11

  physical%pressure_head(2) = -50.0_real64
  call fmr_new_b110_committed_state(committed_physical,102_int64,physical,20.0_real64,physical_ready)
  if (.not. physical_ready) error stop 12
  result%column_id = 102_int64
  result%final_revision = committed_physical%current_revision()
  call fmr_prepare_scheduled_irrigation_from_accepted(physical_parameters,committed_physical,result, &
       15.0_real64,irrigation_state_t(),request,scheduled_parameters,scheduled_candidate,scheduled_flux, &
       scheduled_diagnostics,status)
  if (status /= FMR_IRR_REFERENCE_OK .or. scheduled_diagnostics%triggered .or. scheduled_flux%applied) error stop 13

  result%requested_t1 = request%t0 + 0.5_real64
  call fmr_prepare_scheduled_irrigation_from_accepted(physical_parameters,committed_physical,result, &
       15.0_real64,irrigation_state_t(),request,scheduled_parameters,scheduled_candidate,scheduled_flux, &
       scheduled_diagnostics,status)
  if (status /= FMR_IRR_REFERENCE_INVALID) error stop 14

  result%requested_t1 = request%t0
  result%final_revision = result%final_revision + 1_int64
  call fmr_prepare_scheduled_irrigation_from_accepted(physical_parameters,committed_physical,result, &
       15.0_real64,irrigation_state_t(),request,scheduled_parameters,scheduled_candidate,scheduled_flux, &
       scheduled_diagnostics,status)
  if (status /= FMR_IRR_REFERENCE_INVALID) error stop 15
  print '(a)', 'F_MIG431_REFERENCE_SOURCE_AND_ACCEPTANCE_BINDING=PASS'
end program
