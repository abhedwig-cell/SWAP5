module mod_fmr_surface_evaporation_runtime_materialization
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_provider_t, &
       surface_evaporation_capacity_result_t, SURFACE_EVAP_CAPACITY_AVAILABLE
  use mod_restricted_surface_evaporation, only: surface_evaporation_demand_t, &
       surface_evaporation_hydraulic_input_t, surface_evaporation_result_t, &
       evaluate_restricted_surface_evaporation, SURFACE_EVAP_AVAILABLE
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, &
       FMR_REFERENCE_ET_BINDING_OK
  use mod_fmr_process_hydraulic_view_binding, only: fmr_detach_committed_soil_water_state
  implicit none
  private

  real(real64), parameter, public :: FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM = 1.0e-10_real64

  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_OK = 0
  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_DEMAND_REJECTED = 1
  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED = 2
  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED = 3
  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_PROCESS_REJECTED = 4

  type, public :: fmr_surface_evaporation_runtime_diagnostics_t
    integer :: status = FMR_SURFACE_EVAP_RUNTIME_OK
    integer :: capacity_status = 0
    integer :: process_status = 0
    logical :: demand_accepted = .false.
    logical :: committed_view_built = .false.
    logical :: capacity_called = .false.
    logical :: process_called = .false.
    logical :: surface_is_ponded = .false.
    logical :: result_produced = .false.
    real(real64) :: base_ponding_depth = 0.0_real64
    real(real64) :: raw_evaporation_capacity = 0.0_real64
    character(len=48) :: route = 'not-run'
  end type fmr_surface_evaporation_runtime_diagnostics_t

  public :: fmr_materialize_restricted_surface_evaporation

contains

  subroutine fmr_materialize_restricted_surface_evaporation(committed, et_result, et_diagnostics, &
                                                              capacity_provider, result, diagnostics)
    type(kernel_committed_state_t), intent(in) :: committed
    type(reference_et_demand_result_t), intent(in) :: et_result
    type(fmr_reference_et_binding_diagnostics_t), intent(in) :: et_diagnostics
    class(surface_evaporation_capacity_provider_t), intent(in) :: capacity_provider
    type(surface_evaporation_result_t), intent(out) :: result
    type(fmr_surface_evaporation_runtime_diagnostics_t), intent(out) :: diagnostics

    type(soil_water_physical_state_t) :: base_state
    type(surface_evaporation_capacity_result_t) :: capacity
    type(surface_evaporation_demand_t) :: demand
    type(surface_evaporation_hydraulic_input_t) :: hydraulic
    logical :: ok

    result = surface_evaporation_result_t()
    diagnostics = fmr_surface_evaporation_runtime_diagnostics_t()

    if (et_diagnostics%status /= FMR_REFERENCE_ET_BINDING_OK .or. .not. et_diagnostics%result_produced) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_DEMAND_REJECTED
      diagnostics%route = 'demand-not-qualified'
      return
    end if
    diagnostics%demand_accepted = .true.

    ! F-PE11 retains the committed-state clone boundary but transfers ownership
    ! of that detached clone's profile arrays instead of copying the full profile
    ! through an owning hydraulic view and then copying it back into base_state.
    call fmr_detach_committed_soil_water_state(committed, base_state, ok)
    if (.not. ok) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED
      diagnostics%route = 'committed-view-rejected'
      return
    end if
    diagnostics%committed_view_built = .true.
    diagnostics%base_ponding_depth = base_state%ponding_depth
    if (.not. ieee_is_finite(base_state%ponding_depth)) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED
      diagnostics%route = 'nonfinite-base-ponding'
      return
    end if

    call validate_detached_state(base_state, ok)
    if (.not. ok) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED
      diagnostics%route = 'hydraulic-view-invalid'
      return
    end if

    diagnostics%capacity_called = .true.
    call capacity_provider%evaluate(base_state, capacity)
    diagnostics%capacity_status = capacity%status
    diagnostics%raw_evaporation_capacity = capacity%evaporation_capacity
    if (capacity%status /= SURFACE_EVAP_CAPACITY_AVAILABLE .or. &
        .not. ieee_is_finite(capacity%evaporation_capacity)) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED
      diagnostics%route = 'capacity-rejected'
      return
    end if

    demand%bare_soil_demand = et_result%potential_soil_evaporation_cm_per_day
    demand%ponded_water_demand = et_result%potential_pond_evaporation_cm_per_day
    hydraulic%surface_is_ponded = base_state%ponding_depth > FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM
    hydraulic%evaporation_capacity = capacity%evaporation_capacity
    diagnostics%surface_is_ponded = hydraulic%surface_is_ponded

    diagnostics%process_called = .true.
    call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
    diagnostics%process_status = result%status
    if (result%status /= SURFACE_EVAP_AVAILABLE) then
      result = surface_evaporation_result_t()
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_PROCESS_REJECTED
      diagnostics%route = 'process-rejected'
      return
    end if

    diagnostics%result_produced = .true.
    diagnostics%route = result%route
  end subroutine fmr_materialize_restricted_surface_evaporation

  subroutine validate_detached_state(state, ok)
    type(soil_water_physical_state_t), intent(in) :: state
    logical, intent(out) :: ok
    integer :: n

    ok = .false.
    n = state%active_nodes
    if (n <= 0) return
    if (.not. allocated(state%pressure_head) .or. .not. allocated(state%water_content)) return
    if (size(state%pressure_head) /= n .or. size(state%water_content) /= n) return
    if (.not. all(ieee_is_finite(state%pressure_head))) return
    if (.not. all(ieee_is_finite(state%water_content))) return
    if (.not. ieee_is_finite(state%groundwater_level)) return
    ok = .true.
  end subroutine validate_detached_state

end module mod_fmr_surface_evaporation_runtime_materialization
