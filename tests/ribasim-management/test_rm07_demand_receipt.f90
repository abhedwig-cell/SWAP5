program test_rm07_demand_receipt
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_candidate_state_t, kernel_executor_t, &
       kernel_result_t, kernel_diagnostics_t
  use mod_tcs1_dcs2_sprinkling_irrigation_process, only: tcs1_dcs2_sprinkling_parameters_t, &
       tcs1_dcs2_sprinkling_state_t, tcs1_dcs2_sprinkling_request_t
  use mod_rutter_interception_process, only: rutter_state_t, rutter_interval_input_t
  use mod_fmr_hupsel_management_transaction
  use mod_fmr_hupsel_management_demand_receipt
  implicit none

  integer(int64), parameter :: lineage = 710007_int64
  integer(int64), parameter :: management_revision = 5_int64
  integer(int64), parameter :: crop_revision = 91_int64
  real(real64), parameter :: t0 = 301.0_real64
  real(real64), parameter :: t1 = 302.0_real64
  real(real64), parameter :: tol = 1.0e-13_real64

  type(tcs1_dcs2_sprinkling_parameters_t) :: p
  type(tcs1_dcs2_sprinkling_request_t) :: request, no_event_request
  type(tcs1_dcs2_sprinkling_state_t) :: irrigation_before
  type(rutter_state_t) :: rutter_before
  type(fmr_hupsel_management_persistence_t) :: accepted, active_origin
  type(fmr_hupsel_management_demand_receipt_t) :: a, b, zero_demand, invalid
  type(fmr_hupsel_management_state_t) :: physical
  type(fmr_hupsel_management_parameters_t) :: management_parameters
  type(fmr_hupsel_management_forcing_t) :: forcing
  type(fmr_hupsel_management_model_t), target :: model
  type(fmr_hupsel_management_observation_t) :: observation
  type(rutter_interval_input_t) :: rutter_template
  type(kernel_committed_state_t) :: committed
  type(kernel_candidate_state_t) :: candidate
  type(kernel_executor_t) :: executor
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(canonical_numerical_config_t) :: config
  class(transaction_state_t), allocatable :: initial
  integer :: status
  logical :: ok, available

  call setup_parameters(p)
  call setup_request(request)
  call setup_accepted(accepted)
  irrigation_before = accepted%irrigation
  rutter_before = accepted%rutter

  call derive_fmr_hupsel_management_demand(p, accepted, request, lineage, management_revision, crop_revision, a, status)
  call require(status == FMR_RM_DEMAND_OK, 'first demand status')
  available = a%ready()
  call require(available, 'first demand ready')
  call require(a%irrigation_requested, 'irrigation requested')
  call require(abs(a%requested_depth_cm-2.0_real64) <= tol, 'requested depth')
  call require(abs(a%gross_application_rate_cm_per_day-36.0_real64) <= tol, 'gross rate')
  call require(abs(a%event_duration_day-2.0_real64/36.0_real64) <= tol, 'event duration')
  call require(abs(a%application_t1-(t0+2.0_real64/36.0_real64)) <= tol, 'split application end')
  call require(a%management_lineage_id == lineage, 'lineage bound')
  call require(a%management_origin_revision == management_revision, 'management revision bound')
  call require(a%crop_origin_revision == crop_revision, 'crop revision bound')

  call require(same_irrigation(accepted%irrigation, irrigation_before), 'accepted irrigation nonmutating')
  call require(same_rutter(accepted%rutter, rutter_before), 'accepted Rutter nonmutating')

  call derive_fmr_hupsel_management_demand(p, accepted, request, lineage, management_revision, crop_revision, b, status)
  call require(status == FMR_RM_DEMAND_OK, 'replay demand status')
  call require(same_receipt(a,b), 'same-origin receipt replay identity')

  ! Bind the receipt forward into the already qualified RM06 transaction.
  call initialize_fmr_hupsel_management_state(accepted%irrigation, accepted%rutter, physical, status)
  call require(status == FMR_RM_OK, 'management state initialization')
  call construct_fmr_hupsel_management_parameters(p, management_parameters, status)
  call require(status == FMR_RM_OK, 'management parameter construction')
  call setup_rutter(rutter_template)
  call prepare_fmr_hupsel_management_forcing(request, rutter_template, crop_revision, &
       a%requested_depth_cm, a%requested_depth_cm, forcing, status)
  call require(status == FMR_RM_OK, 'receipt-bound full realization forcing')

  call physical%clone(initial)
  call committed%initialize(lineage, initial, ok, initial_time=t0)
  call require(ok, 'kernel origin initialization')
  call setup_config(config)
  call executor%bind_model(model)
  call executor%advance_interval(management_parameters, committed, forcing, config, t0, t1, &
       result, candidate, diagnostics)
  call require(result%completed, 'RM06 transaction completed from receipt')
  available = candidate%ready()
  call require(available, 'RM06 candidate from receipt')
  call model%observation(observation)
  call require(observation%decision_evaluated, 'RM06 decision evaluated')
  call require(observation%irrigation_requested .eqv. a%irrigation_requested, 'receipt/RM06 trigger identity')
  call require(same_real(observation%requested_depth_cm,a%requested_depth_cm), 'receipt/RM06 request identity')
  call require(observation%crop_origin_revision == a%crop_origin_revision, 'receipt/RM06 crop origin identity')
  call executor%rollback_candidate(candidate, diagnostics)
  call require(committed%current_revision() == 0_int64, 'receipt-bound trial remains provisional')

  ! A valid no-stress boundary produces an explicit zero request.
  no_event_request = request
  no_event_request%dry_reduction_day_cm = 0.0_real64
  call derive_fmr_hupsel_management_demand(p, accepted, no_event_request, lineage, management_revision, &
       crop_revision, zero_demand, status)
  call require(status == FMR_RM_DEMAND_OK, 'zero-demand status')
  available = zero_demand%ready()
  call require(available, 'zero-demand receipt ready')
  call require(.not. zero_demand%irrigation_requested, 'zero-demand no event')
  call require(abs(zero_demand%requested_depth_cm) <= tol, 'zero-demand amount')
  call require(abs(zero_demand%application_t1-t0) <= tol, 'zero-demand application boundary')

  ! Active-event origins are deliberately outside the first coupling profile.
  active_origin = accepted
  active_origin%irrigation%active_event = .true.
  active_origin%irrigation%active_event_start = t0
  active_origin%irrigation%active_event_end = t0 + 0.01_real64
  call derive_fmr_hupsel_management_demand(p, active_origin, request, lineage, management_revision, &
       crop_revision, invalid, status)
  call require(status == FMR_RM_DEMAND_ACTIVE_EVENT_NOT_ADMITTED, 'active event fail closed')
  available = invalid%ready()
  call require(.not. available, 'active event produces no receipt')

  write(*,'(A)') 'RM07_ACCEPTED_ORIGIN_NONMUTATING=PASS'
  write(*,'(A)') 'RM07_ORIGIN_IDENTITY_BOUND=PASS'
  write(*,'(A)') 'RM07_SPLIT_EVENT_RECEIPT=PASS'
  write(*,'(A)') 'RM07_SAME_ORIGIN_REPLAY_IDENTITY=PASS'
  write(*,'(A)') 'RM07_RECEIPT_RM06_REQUEST_IDENTITY=PASS'
  write(*,'(A)') 'RM07_ZERO_DEMAND_EXPLICIT=PASS'
  write(*,'(A)') 'RM07_ACTIVE_EVENT_FAIL_CLOSED=PASS'
  write(*,'(A)') 'RM07 DEMAND RECEIPT QUALIFICATION PASS'

contains

  subroutine setup_parameters(x)
    type(tcs1_dcs2_sprinkling_parameters_t), intent(out) :: x
    x = tcs1_dcs2_sprinkling_parameters_t()
    x%enabled = .true.
    x%rate_cm_per_day = 36.0_real64
    x%threshold_knot_count = 2
    x%threshold_dvs(1:2) = [0.0_real64,2.0_real64]
    x%threshold_trel(1:2) = [0.85_real64,0.85_real64]
    x%depth_knot_count = 2
    x%depth_dvs(1:2) = [0.0_real64,2.0_real64]
    x%depth_cm(1:2) = [2.0_real64,2.0_real64]
    x%minimum_interval_days = 7
  end subroutine setup_parameters

  subroutine setup_request(x)
    type(tcs1_dcs2_sprinkling_request_t), intent(out) :: x
    x = tcs1_dcs2_sprinkling_request_t()
    x%t0 = t0
    x%t1 = t1
    x%dvs = 1.5060476190476193_real64
    x%potential_transpiration_day_cm = 0.31534971046284993_real64
    x%dry_reduction_day_cm = 0.11551480616973946_real64
    x%salinity_reduction_day_cm = 0.0_real64
    x%selection_opportunity = .true.
    x%irrigation_enabled = .true.
    x%schedule_enabled = .true.
    x%crop_emerged = .true.
    x%irrigation_window_open = .true.
  end subroutine setup_request

  subroutine setup_accepted(x)
    type(fmr_hupsel_management_persistence_t), intent(out) :: x
    x = fmr_hupsel_management_persistence_t()
    x%irrigation = tcs1_dcs2_sprinkling_state_t()
    x%irrigation%dayfix = 12
    x%rutter = rutter_state_t()
    x%rutter%canopy_storage_cm = 0.0_real64
    x%valid = .true.
  end subroutine setup_accepted

  subroutine setup_rutter(x)
    type(rutter_interval_input_t), intent(out) :: x
    x = rutter_interval_input_t()
    x%gross_rain_cm_per_day = 0.0_real64
    x%vegetation_cover_fraction = 0.5_real64
    x%canopy_storage_capacity_cm = 0.5_real64
    x%interception_evaporation_capacity_cm_per_day = 0.0_real64
    x%potential_transpiration_dry_cm_per_day = 0.0_real64
    x%potential_transpiration_wet_cm_per_day = 0.0_real64
    x%interval_days = 1.0_real64
  end subroutine setup_rutter

  subroutine setup_config(x)
    type(canonical_numerical_config_t), intent(out) :: x
    x = canonical_numerical_config_t()
    x%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    x%transaction%temporal_tolerance = 0.0_real64
    x%transaction%mass_tolerance = 0.0_real64
    x%transaction%retry_scale = 0.5_real64
    x%transaction%max_retries = 0
    x%max_committed_substeps = 1
    x%progress_tolerance = 0.0_real64
  end subroutine setup_config

  logical function same_irrigation(x,y)
    type(tcs1_dcs2_sprinkling_state_t), intent(in) :: x,y
    same_irrigation = x%dayfix == y%dayfix .and. (x%active_event .eqv. y%active_event) .and. &
         same_real(x%active_event_start,y%active_event_start) .and. same_real(x%active_event_end,y%active_event_end)
  end function same_irrigation

  logical function same_rutter(x,y)
    type(rutter_state_t), intent(in) :: x,y
    same_rutter = same_real(x%canopy_storage_cm,y%canopy_storage_cm)
  end function same_rutter

  logical function same_receipt(x,y)
    type(fmr_hupsel_management_demand_receipt_t), intent(in) :: x,y
    same_receipt = (x%valid .eqv. y%valid) .and. x%management_lineage_id == y%management_lineage_id .and. &
         x%management_origin_revision == y%management_origin_revision .and. x%crop_origin_revision == y%crop_origin_revision
    same_receipt = same_receipt .and. same_real(x%management_t0,y%management_t0) .and. &
         same_real(x%management_t1,y%management_t1) .and. (x%irrigation_requested .eqv. y%irrigation_requested)
    same_receipt = same_receipt .and. same_real(x%requested_depth_cm,y%requested_depth_cm) .and. &
         same_real(x%gross_application_rate_cm_per_day,y%gross_application_rate_cm_per_day) .and. &
         same_real(x%event_duration_day,y%event_duration_day) .and. same_real(x%application_t1,y%application_t1)
    same_receipt = same_receipt .and. x%candidate_dayfix == y%candidate_dayfix .and. &
         (x%candidate_active_event .eqv. y%candidate_active_event) .and. &
         same_real(x%candidate_active_event_start,y%candidate_active_event_start) .and. &
         same_real(x%candidate_active_event_end,y%candidate_active_event_end)
  end function same_receipt

  logical function same_real(x,y)
    real(real64), intent(in) :: x,y
    same_real = transfer(x,0_int64) == transfer(y,0_int64)
  end function same_real

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'RM07_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_rm07_demand_receipt
