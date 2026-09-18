module mod_rossfast_d3r_soil_water_solver
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: trial_outcome_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_interval_t, canonical_numerical_config_t
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, validate_soil_water_request, &
       SW_SOLVE_CONVERGED, SW_SOLVE_FAILED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_rossfast_d3r_execution_policy, only: apply_rossfast_d3r_retry_policy
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_model_t, rossfast_d3r_material_t, &
       rossfast_d3r_state_t, rossfast_d3r_forcing_t, rossfast_d3r_material_from_id, &
       bind_rossfast_d3r_model, ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, &
       ROSSFAST_D3R_HARD_MASS_TOL_CM
  use mod_rossfast_d3r_table_kernel, only: rossfast_d3r_table_kernel_t
  use mod_rossfast_d3r_table_provider, only: rossfast_d3r_table_registry_t, &
       bind_rossfast_d3r_table_registry, ROSSFAST_TABLE_PROVIDER_OK, &
       ROSSFAST_TABLE_PROVIDER_MATERIAL
  implicit none
  private

  integer, parameter :: ROSSFAST_BOTTOM_MODE_PRESCRIBED_FLUX = 2
  integer, parameter :: ROSSFAST_INTERNAL_SUBSTEPS = 2

  type, extends(soil_water_solver_workspace_base_t), public :: rossfast_d3r_soil_water_workspace_t
  end type rossfast_d3r_soil_water_workspace_t

  type, extends(soil_water_solver_t), public :: rossfast_d3r_soil_water_solver_t
    private
    type(rossfast_d3r_table_kernel_t), pointer :: kernel => null()
    type(rossfast_d3r_model_t) :: model
    type(rossfast_d3r_material_t) :: material
    logical :: configured = .false.
    logical :: last_temporal_certificate_available = .false.
    real(real64) :: last_temporal_indicator = huge(0.0_real64)
  contains
    procedure, public :: initialize => rossfast_soil_water_initialize
    procedure, public :: solve => rossfast_soil_water_solve
    procedure, public :: temporal_certificate_snapshot => rossfast_temporal_certificate_snapshot
  end type rossfast_d3r_soil_water_solver_t

contains

  subroutine rossfast_soil_water_initialize(self, asset_root, material_id, valid, status)
    class(rossfast_d3r_soil_water_solver_t), intent(inout) :: self
    character(len=*), intent(in) :: asset_root, material_id
    logical, intent(out) :: valid
    integer, intent(out) :: status
    type(rossfast_d3r_table_registry_t) :: registry
    real(real64) :: cell_thickness(ROSSFAST_D3R_N_CELLS)
    logical :: found, registry_valid, kernel_valid, model_valid

    valid = .false.
    status = ROSSFAST_TABLE_PROVIDER_MATERIAL
    self%configured = .false.
    self%last_temporal_certificate_available = .false.
    self%last_temporal_indicator = huge(0.0_real64)
    if (associated(self%kernel)) deallocate(self%kernel)

    call rossfast_d3r_material_from_id(material_id, self%material, found)
    if (.not. found) return
    call bind_rossfast_d3r_table_registry(registry, asset_root, registry_valid)
    if (.not. registry_valid) return

    allocate(self%kernel)
    call registry%initialize_kernel(self%kernel, self%material, kernel_valid, status)
    if (.not. kernel_valid .or. status /= ROSSFAST_TABLE_PROVIDER_OK) then
      deallocate(self%kernel)
      return
    end if

    cell_thickness = ROSSFAST_D3R_DZ_CM
    call bind_rossfast_d3r_model(self%model, self%kernel, self%material, cell_thickness, &
         ROSSFAST_INTERNAL_SUBSTEPS, model_valid)
    if (.not. model_valid) then
      deallocate(self%kernel)
      return
    end if

    self%configured = .true.
    valid = .true.
  end subroutine rossfast_soil_water_initialize

  subroutine rossfast_soil_water_solve(self, request, workspace, result)
    class(rossfast_d3r_soil_water_solver_t), intent(inout) :: self
    type(soil_water_solve_request_t), intent(in) :: request
    class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
    type(soil_water_solve_result_t), intent(out) :: result
    type(rossfast_d3r_state_t) :: state
    type(rossfast_d3r_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: numerical
    type(trial_outcome_t) :: outcome
    real(real64), allocatable :: source(:), sink(:)
    real(real64) :: storage_before, storage_after, external_transfer
    logical :: request_valid
    integer :: n

    result = soil_water_solve_result_t()
    result%status = SW_SOLVE_FAILED
    result%diagnostics%route = 'rossfast-d3r-rejected'
    self%last_temporal_certificate_available = .false.
    self%last_temporal_indicator = huge(0.0_real64)

    if (.not. self%configured .or. .not. associated(self%kernel)) return
    select type (workspace)
    type is (rossfast_d3r_soil_water_workspace_t)
      continue
    class default
      return
    end select

    call validate_soil_water_request(request, request_valid)
    if (.not. request_valid) return
    n = request%parameters%active_nodes
    if (n /= ROSSFAST_D3R_N_CELLS) return
    if (any(.not. ieee_is_finite(request%parameters%dz))) return
    if (any(request%parameters%dz /= ROSSFAST_D3R_DZ_CM)) return
    if (request%boundary%top_mode /= FSI_TOP_MODE_EXPLICIT_FLUX) return
    if (request%boundary%bottom_mode /= ROSSFAST_BOTTOM_MODE_PRESCRIBED_FLUX) return
    if (.not. ieee_is_finite(request%boundary%top_flux) .or. &
        .not. ieee_is_finite(request%boundary%bottom_flux)) return
    if (request%physical%macropore_active) return
    if (request%request_interface_sensitivity) return
    if (associated(request%evaluation%root_sink)) return
    if (associated(request%evaluation%dynamic_top_boundary)) return
    if (associated(request%evaluation%macropore)) return
    if (.not. ieee_is_finite(request%base_state%ponding_depth) .or. &
        request%base_state%ponding_depth /= 0.0_real64) return

    if (associated(request%evaluation%source_sink)) then
      allocate(source(n), sink(n))
      call request%evaluation%source_sink%evaluate(request%base_state%pressure_head, &
           request%base_state%water_content, source, sink)
      if (any(.not. ieee_is_finite(source)) .or. any(.not. ieee_is_finite(sink))) return
      if (any(source /= 0.0_real64) .or. any(sink /= 0.0_real64)) return
    end if

    state%active_nodes = n
    allocate(state%pressure_head_cm(n), state%water_content(n))
    state%pressure_head_cm = request%base_state%pressure_head
    state%water_content = request%base_state%water_content
    ! The public soil-water ABI retains native SWAP/Reference signs:
    ! qtop > 0 leaves the column, qbot > 0 enters from below. RossFast's
    ! restricted forcing uses positive values into the column at both faces.
    forcing%top_flux_cm_per_day = -request%boundary%top_flux
    forcing%bottom_flux_upward_cm_per_day = request%boundary%bottom_flux

    interval%t0 = 0.0_real64
    interval%t1 = request%step_duration
    numerical = canonical_numerical_config_t()
    numerical%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    numerical%transaction%mass_tolerance = ROSSFAST_D3R_HARD_MASS_TOL_CM
    call apply_rossfast_d3r_retry_policy(numerical)
    numerical%max_committed_substeps = 32
    numerical%progress_tolerance = 0.0_real64

    storage_before = sum(request%parameters%dz * state%water_content)
    call self%model%prepare_interval(forcing, interval, numerical)
    call self%model%advance(state, interval%t0, interval%t1, outcome)
    if (.not. outcome%solver_ok) return

    storage_after = sum(request%parameters%dz * state%water_content)
    external_transfer = request%step_duration * &
         (request%boundary%bottom_flux - request%boundary%top_flux)

    result%candidate_state%active_nodes = n
    allocate(result%candidate_state%pressure_head(n), result%candidate_state%water_content(n))
    result%candidate_state%pressure_head = state%pressure_head_cm
    result%candidate_state%water_content = state%water_content
    result%candidate_state%ponding_depth = request%base_state%ponding_depth
    result%candidate_state%groundwater_level = request%base_state%groundwater_level
    result%top_flux = request%boundary%top_flux
    result%bottom_flux = request%boundary%bottom_flux
    result%unrounded_mass_balance_residual = (storage_after - storage_before) - external_transfer
    ! RossFast's historical compatibility value is already a time-integrated
    ! water-balance residual in cm, so publish it unchanged through the typed
    ! solver-independent diagnostic. No native rate residual is synthesized.
    result%integrated_mass_balance_residual_available = .true.
    result%integrated_mass_balance_residual_cm = result%unrounded_mass_balance_residual
    result%diagnostics%linear_solves = outcome%linear_solves
    result%diagnostics%internal_retries = outcome%internal_retries
    result%diagnostics%alternative_solver_calls = outcome%alternative_solver_calls
    result%diagnostics%route = 'rossfast-d3r'
    result%status = SW_SOLVE_CONVERGED

    self%last_temporal_certificate_available = outcome%temporal_certificate_available
    self%last_temporal_indicator = outcome%temporal_indicator
  end subroutine rossfast_soil_water_solve

  subroutine rossfast_temporal_certificate_snapshot(self, available, indicator)
    class(rossfast_d3r_soil_water_solver_t), intent(in) :: self
    logical, intent(out) :: available
    real(real64), intent(out) :: indicator
    available = self%last_temporal_certificate_available
    indicator = self%last_temporal_indicator
  end subroutine rossfast_temporal_certificate_snapshot

end module mod_rossfast_d3r_soil_water_solver
