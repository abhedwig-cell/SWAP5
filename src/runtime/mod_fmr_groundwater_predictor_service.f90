module mod_fmr_groundwater_predictor_service
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t, soil_water_parameter_set_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t, &
       groundwater_interface_state_t, swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s, GW_INTERFACE_OK
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, modflow6_swap_predictor_response_t
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_modflow6_swap_predictor_tangent_adapter, only: modflow6_swap_predictor_tangent_endpoint_t, &
       build_modflow6_swap_predictor_tangent_endpoint, MODFLOW6_TANGENT_ENDPOINT_OK
  use mod_modflow6_swap_predictor_origin, only: modflow6_swap_predictor_origin_t, &
       capture_modflow6_swap_predictor_origin, MODFLOW6_PREDICTOR_ORIGIN_OK
  use mod_modflow6_swap_predictor_candidate_assembler, only: assemble_modflow6_swap_predictor_response, &
       MODFLOW6_PREDICTOR_ASSEMBLER_OK
  implicit none
  private

  integer, parameter, public :: FMR_GW_PREDICTOR_OK = 0
  integer, parameter, public :: FMR_GW_PREDICTOR_INVALID_REQUEST = 1
  integer, parameter, public :: FMR_GW_PREDICTOR_LINEAGE_MISMATCH = 2
  integer, parameter, public :: FMR_GW_PREDICTOR_ORIGIN_STATE_FAILED = 3
  integer, parameter, public :: FMR_GW_PREDICTOR_ORIGIN_INTERFACE_MISMATCH = 4
  integer, parameter, public :: FMR_GW_PREDICTOR_CHECKPOINT_FAILED = 5
  integer, parameter, public :: FMR_GW_PREDICTOR_TRIAL_FAILED = 6
  integer, parameter, public :: FMR_GW_PREDICTOR_CANDIDATE_STATE_FAILED = 7
  integer, parameter, public :: FMR_GW_PREDICTOR_TANGENT_FAILED = 8
  integer, parameter, public :: FMR_GW_PREDICTOR_ORIGIN_CAPTURE_FAILED = 9
  integer, parameter, public :: FMR_GW_PREDICTOR_ASSEMBLY_FAILED = 10

  public :: build_fmr_groundwater_predictor_response

contains

  subroutine build_fmr_groundwater_predictor_response(backend, column, template, parameters, committed, base_forcing, &
       numerical, datum, window, qbot_predictor_cm_per_day, accepted_interface, lineage, response, status)
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(canonical_numerical_config_t), intent(in) :: numerical
    type(groundwater_head_datum_t), intent(in) :: datum
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: qbot_predictor_cm_per_day
    type(groundwater_interface_state_t), intent(in) :: accepted_interface
    type(modflow6_swap_predictor_lineage_t), intent(in) :: lineage
    type(modflow6_swap_predictor_response_t), intent(out) :: response
    integer, intent(out) :: status

    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_b110_physical_forcing_t) :: predictor_forcing
    type(soil_water_physical_state_t) :: origin_state, candidate_state
    type(soil_water_parameter_set_t) :: solver_parameters
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    type(modflow6_prescribed_qbot_bottom_face_t) :: origin_face
    type(modflow6_swap_predictor_tangent_endpoint_t) :: endpoint
    type(modflow6_swap_predictor_origin_t) :: origin
    real(real64), allocatable :: theta(:), conductivity(:), capacity(:), dkdh(:)
    real(real64) :: committed_time, q_swap_expected
    logical :: available, checkpoint_ok, candidate_ready
    integer :: face_status, interface_status, tangent_status, origin_status, assembler_status

    response = modflow6_swap_predictor_response_t()
    status = FMR_GW_PREDICTOR_INVALID_REQUEST

    if (column%column_id <= 0_int64) return
    if (column%template_id /= template%template_id) return
    if (.not. committed%ready()) return
    if (.not. window%valid() .or. .not. datum%valid()) return
    if (.not. ieee_is_finite(qbot_predictor_cm_per_day)) return
    if (.not. accepted_interface%finite()) return
    if (.not. lineage%valid()) return
    if (.not. numerical%accepted_trajectory_direction%requested) return
    if (numerical%accepted_trajectory_direction%control_coordinate /= SW_STEP_CONTROL_BOTTOM_FLUX) return

    status = FMR_GW_PREDICTOR_LINEAGE_MISMATCH
    if (lineage%swap_lineage_id /= committed%current_lineage_id()) return
    if (lineage%swap_lineage_id /= column%column_id) return
    if (lineage%swap_origin_revision /= committed%current_revision()) return
    call committed%current_time(committed_time, available)
    if (.not. available) return
    if (.not. same_real(committed_time, window%t0)) return

    status = FMR_GW_PREDICTOR_ORIGIN_STATE_FAILED
    call materialize_committed_solver_view(committed, parameters, origin_state, solver_parameters, available)
    if (.not. available) return

    call initialize_b110_default_mvg_parameters(hydraulic_parameters, parameters%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, window%t1-window%t0)
    allocate(theta(origin_state%active_nodes), conductivity(origin_state%active_nodes), &
         capacity(origin_state%active_nodes), dkdh(origin_state%active_nodes))
    call constitutive%evaluate(origin_state%pressure_head, theta, conductivity, capacity, dkdh)
    if (any(.not. ieee_is_finite(conductivity))) return
    if (conductivity(origin_state%active_nodes) <= 0.0_real64) return

    call materialize_modflow6_prescribed_qbot_bottom_face(origin_state%pressure_head(origin_state%active_nodes), &
         conductivity(origin_state%active_nodes), qbot_predictor_cm_per_day, &
         0.5_real64*solver_parameters%dz(origin_state%active_nodes), datum, origin_face, face_status)
    if (face_status /= MODFLOW6_BOTTOM_FACE_OK .or. .not. origin_face%valid) return

    status = FMR_GW_PREDICTOR_ORIGIN_INTERFACE_MISMATCH
    if (.not. same_real(origin_face%hydraulic_head_m, accepted_interface%h_swap_m)) return
    call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(qbot_predictor_cm_per_day, q_swap_expected, interface_status)
    if (interface_status /= GW_INTERFACE_OK) return
    if (.not. same_real(q_swap_expected, accepted_interface%q_swap_m_per_s)) return

    status = FMR_GW_PREDICTOR_CHECKPOINT_FAILED
    call fmr_capture_checkpoint(committed, checkpoint, checkpoint_ok)
    if (.not. checkpoint_ok .or. .not. checkpoint%ready()) return

    predictor_forcing = base_forcing
    predictor_forcing%bottom_flux = qbot_predictor_cm_per_day

    status = FMR_GW_PREDICTOR_TRIAL_FAILED
    call backend%run_trial(column, template, parameters, committed, predictor_forcing, numerical, &
         window%t0, window%t1, checkpoint, result, candidate, diagnostics)
    candidate_ready = candidate%ready()
    if (.not. result%completed .or. .not. candidate_ready) then
      if (candidate_ready) call backend%discard_trial_candidate(candidate, diagnostics)
      return
    end if
    if (.not. result%accepted_trajectory_direction%available) then
      call backend%discard_trial_candidate(candidate, diagnostics)
      return
    end if

    status = FMR_GW_PREDICTOR_CANDIDATE_STATE_FAILED
    call materialize_candidate_solver_view(candidate, parameters, candidate_state, solver_parameters, available)
    if (.not. available) then
      call backend%discard_trial_candidate(candidate, diagnostics)
      return
    end if

    status = FMR_GW_PREDICTOR_TANGENT_FAILED
    call build_modflow6_swap_predictor_tangent_endpoint(candidate_state, solver_parameters, constitutive, &
         result%accepted_trajectory_direction, qbot_predictor_cm_per_day, datum, &
         .false., parameters%root_extraction_active, parameters%drainage_response_active, &
         .false., endpoint, tangent_status)
    if (tangent_status /= MODFLOW6_TANGENT_ENDPOINT_OK .or. .not. endpoint%authoritative) then
      call backend%discard_trial_candidate(candidate, diagnostics)
      return
    end if

    status = FMR_GW_PREDICTOR_ORIGIN_CAPTURE_FAILED
    call capture_modflow6_swap_predictor_origin(accepted_interface, window%t0, lineage, .true., origin, origin_status)
    if (origin_status /= MODFLOW6_PREDICTOR_ORIGIN_OK .or. .not. origin%structurally_valid()) then
      call backend%discard_trial_candidate(candidate, diagnostics)
      return
    end if

    status = FMR_GW_PREDICTOR_ASSEMBLY_FAILED
    call assemble_modflow6_swap_predictor_response(origin, window, candidate, result, endpoint, response, assembler_status)
    call backend%discard_trial_candidate(candidate, diagnostics)
    if (assembler_status /= MODFLOW6_PREDICTOR_ASSEMBLER_OK .or. .not. response%valid) return

    status = FMR_GW_PREDICTOR_OK
  end subroutine build_fmr_groundwater_predictor_response

  subroutine materialize_committed_solver_view(committed, parameters, state, solver_parameters, ok)
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(soil_water_physical_state_t), intent(out) :: state
    type(soil_water_parameter_set_t), intent(out) :: solver_parameters
    logical, intent(out) :: ok

    class(transaction_state_t), allocatable :: snapshot
    logical :: available

    ok = .false.
    call committed%snapshot(snapshot, available)
    if (.not. available .or. .not. allocated(snapshot)) return
    call materialize_snapshot_solver_view(snapshot, parameters, state, solver_parameters, ok)
  end subroutine materialize_committed_solver_view

  subroutine materialize_candidate_solver_view(candidate, parameters, state, solver_parameters, ok)
    type(kernel_candidate_state_t), intent(in) :: candidate
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(soil_water_physical_state_t), intent(out) :: state
    type(soil_water_parameter_set_t), intent(out) :: solver_parameters
    logical, intent(out) :: ok

    class(transaction_state_t), allocatable :: snapshot
    logical :: available

    ok = .false.
    call candidate%snapshot(snapshot, available)
    if (.not. available .or. .not. allocated(snapshot)) return
    call materialize_snapshot_solver_view(snapshot, parameters, state, solver_parameters, ok)
  end subroutine materialize_candidate_solver_view

  subroutine materialize_snapshot_solver_view(snapshot, parameters, state, solver_parameters, ok)
    class(transaction_state_t), intent(in) :: snapshot
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(soil_water_physical_state_t), intent(out) :: state
    type(soil_water_parameter_set_t), intent(out) :: solver_parameters
    logical, intent(out) :: ok

    integer :: n

    ok = .false.
    select type (physical => snapshot)
    class is (fmr_b110_physical_state_t)
      n = physical%active_nodes
      if (n <= 0 .or. parameters%active_nodes /= n) return
      if (.not. allocated(physical%pressure_head) .or. .not. allocated(physical%water_content)) return
      if (size(physical%pressure_head) /= n .or. size(physical%water_content) /= n) return
      if (.not. allocated(parameters%z) .or. .not. allocated(parameters%dz) .or. &
          .not. allocated(parameters%node_distance)) return
      if (size(parameters%z) /= n .or. size(parameters%dz) /= n .or. size(parameters%node_distance) /= n) return

      state%active_nodes = n
      allocate(state%pressure_head(n), state%water_content(n))
      state%pressure_head = physical%pressure_head
      state%water_content = physical%water_content
      state%ponding_depth = physical%ponding_depth
      state%groundwater_level = physical%groundwater_level

      solver_parameters%parameter_set_id = parameters%parameter_set_id
      solver_parameters%active_nodes = n
      allocate(solver_parameters%z(n), solver_parameters%dz(n), solver_parameters%node_distance(n))
      solver_parameters%z = parameters%z
      solver_parameters%dz = parameters%dz
      solver_parameters%node_distance = parameters%node_distance
      ok = .true.
    class default
      return
    end select
  end subroutine materialize_snapshot_solver_view

  pure logical function same_real(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 128.0_real64*epsilon(1.0_real64)*scale
  end function same_real

end module mod_fmr_groundwater_predictor_service
