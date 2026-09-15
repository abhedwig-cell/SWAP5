module mod_fpe11_current_timing_support
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_provider_t, &
       surface_evaporation_capacity_result_t, SURFACE_EVAP_CAPACITY_AVAILABLE, SURFACE_EVAP_CAPACITY_INVALID_INPUT
  use mod_restricted_surface_evaporation, only: surface_evaporation_demand_t, surface_evaporation_hydraulic_input_t, &
       surface_evaporation_result_t, evaluate_restricted_surface_evaporation, SURFACE_EVAP_AVAILABLE
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, FMR_REFERENCE_ET_BINDING_OK
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_fmr_surface_evaporation_runtime_materialization, only: fmr_surface_evaporation_runtime_diagnostics_t, &
       FMR_SURFACE_EVAP_RUNTIME_OK, FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED, &
       FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED, FMR_SURFACE_EVAP_RUNTIME_PROCESS_REJECTED, &
       FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM
  implicit none
  private

  type, extends(surface_evaporation_capacity_provider_t), public :: fpe11_current_timing_provider_t
  contains
    procedure :: evaluate => fpe11_current_timing_evaluate
  end type fpe11_current_timing_provider_t
  public :: fpe11_preoptimization_counterfactual_materialize

contains

  subroutine fpe11_current_timing_evaluate(self, base_state, result)
    class(fpe11_current_timing_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result
    integer :: n
    if (.false.) print *, same_type_as(self,self)
    result = surface_evaporation_capacity_result_t()
    n = base_state%active_nodes
    if (n <= 0 .or. .not. allocated(base_state%pressure_head) .or. &
        .not. allocated(base_state%water_content)) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'fpe11-invalid'
      return
    end if
    result%evaporation_capacity = 0.10_real64 + &
         1.0e-9_real64*abs(base_state%pressure_head(1)) + &
         1.0e-9_real64*abs(base_state%pressure_head(n)) + &
         1.0e-3_real64*base_state%water_content(1) + &
         1.0e-3_real64*base_state%water_content(n) + &
         1.0e-6_real64*abs(base_state%groundwater_level) + &
         1.0e-4_real64*base_state%ponding_depth
    result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
    result%route = 'fpe11-current-timing'
  end subroutine fpe11_current_timing_evaluate

  subroutine fpe11_preoptimization_counterfactual_materialize(committed, et_result, et_diagnostics, &
                                                                capacity_provider, result, diagnostics)
    type(kernel_committed_state_t), intent(in) :: committed
    type(reference_et_demand_result_t), intent(in) :: et_result
    type(fmr_reference_et_binding_diagnostics_t), intent(in) :: et_diagnostics
    class(surface_evaporation_capacity_provider_t), intent(in) :: capacity_provider
    type(surface_evaporation_result_t), intent(out) :: result
    type(fmr_surface_evaporation_runtime_diagnostics_t), intent(out) :: diagnostics
    type(process_hydraulic_view_t) :: view
    type(soil_water_physical_state_t) :: base_state
    type(surface_evaporation_capacity_result_t) :: capacity
    type(surface_evaporation_demand_t) :: demand
    type(surface_evaporation_hydraulic_input_t) :: hydraulic
    integer :: n
    logical :: ok

    result = surface_evaporation_result_t()
    diagnostics = fmr_surface_evaporation_runtime_diagnostics_t()
    if (et_diagnostics%status /= FMR_REFERENCE_ET_BINDING_OK .or. .not. et_diagnostics%result_produced) return
    diagnostics%demand_accepted = .true.
    call fmr_build_committed_process_hydraulic_view(committed, view, ok)
    if (.not. ok) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED
      return
    end if
    diagnostics%committed_view_built = .true.
    diagnostics%base_ponding_depth = view%ponding_depth
    if (.not. ieee_is_finite(view%ponding_depth)) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED
      return
    end if

    n = view%active_nodes
    if (n <= 0 .or. .not. allocated(view%pressure_head) .or. .not. allocated(view%water_content)) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED
      return
    end if
    if (size(view%pressure_head) /= n .or. size(view%water_content) /= n) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED
      return
    end if
    base_state%active_nodes = n
    allocate(base_state%pressure_head(n), base_state%water_content(n))
    base_state%pressure_head = view%pressure_head
    base_state%water_content = view%water_content
    base_state%ponding_depth = view%ponding_depth
    base_state%groundwater_level = view%groundwater_level

    diagnostics%capacity_called = .true.
    call capacity_provider%evaluate(base_state, capacity)
    diagnostics%capacity_status = capacity%status
    diagnostics%raw_evaporation_capacity = capacity%evaporation_capacity
    if (capacity%status /= SURFACE_EVAP_CAPACITY_AVAILABLE .or. .not. ieee_is_finite(capacity%evaporation_capacity)) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED
      return
    end if
    demand%bare_soil_demand = et_result%potential_soil_evaporation_cm_per_day
    demand%ponded_water_demand = et_result%potential_pond_evaporation_cm_per_day
    hydraulic%surface_is_ponded = view%ponding_depth > FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM
    hydraulic%evaporation_capacity = capacity%evaporation_capacity
    diagnostics%surface_is_ponded = hydraulic%surface_is_ponded
    diagnostics%process_called = .true.
    call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
    diagnostics%process_status = result%status
    if (result%status /= SURFACE_EVAP_AVAILABLE) then
      result = surface_evaporation_result_t()
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_PROCESS_REJECTED
      return
    end if
    diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_OK
    diagnostics%result_produced = .true.
    diagnostics%route = result%route
  end subroutine fpe11_preoptimization_counterfactual_materialize
end module mod_fpe11_current_timing_support

program test_fpe11_current_canonical_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, FMR_REFERENCE_ET_BINDING_OK
  use mod_restricted_surface_evaporation, only: surface_evaporation_result_t
  use mod_fmr_surface_evaporation_runtime_materialization, only: &
       fmr_surface_evaporation_runtime_diagnostics_t, fmr_materialize_restricted_surface_evaporation, &
       FMR_SURFACE_EVAP_RUNTIME_OK
  use mod_fpe11_current_kernel_view_binding, only: fpe11_initialize_committed
  use mod_fpe11_current_timing_support, only: fpe11_current_timing_provider_t, &
       fpe11_preoptimization_counterfactual_materialize
  implicit none
  type(kernel_committed_state_t) :: committed
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag
  type(fpe11_current_timing_provider_t) :: provider
  type(surface_evaporation_result_t) :: result
  type(fmr_surface_evaporation_runtime_diagnostics_t) :: diag
  character(len=64) :: arm, arg
  integer :: n, calls, i, warmups
  integer(int64) :: c0, c1, rate
  real(real64) :: seconds, checksum
  logical :: ok

  call get_command_argument(1, arm)
  call get_command_argument(2, arg); read(arg,*) n
  call get_command_argument(3, arg); read(arg,*) calls
  if (n <= 0 .or. calls <= 0) error stop 'FPE11 current timing invalid arguments'
  if (trim(arm) /= 'baseline' .and. trim(arm) /= 'candidate') error stop 'FPE11 current timing invalid arm'
  call fpe11_initialize_committed(committed, 91201_int64, n, 0.0_real64, 0.0_real64, ok)
  if (.not. ok) error stop 'FPE11 current timing committed initialization failed'
  et = reference_et_demand_result_t()
  et%potential_soil_evaporation_cm_per_day = 1.0_real64
  et%potential_pond_evaporation_cm_per_day = 1.0_real64
  et_diag = fmr_reference_et_binding_diagnostics_t()
  et_diag%status = FMR_REFERENCE_ET_BINDING_OK
  et_diag%result_produced = .true.

  warmups = min(500, max(100, calls/100))
  do i = 1, warmups
    if (trim(arm) == 'baseline') then
      call fpe11_preoptimization_counterfactual_materialize(committed, et, et_diag, provider, result, diag)
    else
      call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, provider, result, diag)
    end if
    if (diag%status /= FMR_SURFACE_EVAP_RUNTIME_OK) error stop 'FPE11 current timing warmup failed'
  end do

  checksum = 0.0_real64
  call system_clock(c0, rate)
  do i = 1, calls
    if (trim(arm) == 'baseline') then
      call fpe11_preoptimization_counterfactual_materialize(committed, et, et_diag, provider, result, diag)
    else
      call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, provider, result, diag)
    end if
    if (diag%status /= FMR_SURFACE_EVAP_RUNTIME_OK) error stop 'FPE11 current timing measured call failed'
    checksum = checksum + result%bare_soil_evaporation + 1.0e-3_real64*diag%raw_evaporation_capacity
  end do
  call system_clock(c1)
  seconds = real(c1-c0,real64)/real(rate,real64)
  write(*,'(A,A,A,I0,A,I0,A,ES24.16,A,ES24.16)') 'FPE11_CURRENT_TIMING,arm=',trim(arm),',nodes=',n, &
       ',calls=',calls,',seconds=',seconds,',checksum=',checksum
end program test_fpe11_current_canonical_timing
