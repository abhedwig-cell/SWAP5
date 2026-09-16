module mod_fpe11_timing_capacity_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_provider_t, &
       surface_evaporation_capacity_result_t, SURFACE_EVAP_CAPACITY_AVAILABLE, &
       SURFACE_EVAP_CAPACITY_INVALID_INPUT
  implicit none
  private

  type, extends(surface_evaporation_capacity_provider_t), public :: fpe11_timing_provider_t
  contains
    procedure :: evaluate => fpe11_timing_capacity_evaluate
  end type fpe11_timing_provider_t

contains

  subroutine fpe11_timing_capacity_evaluate(self, base_state, result)
    class(fpe11_timing_provider_t), intent(in) :: self
    type(soil_water_physical_state_t), intent(in) :: base_state
    type(surface_evaporation_capacity_result_t), intent(out) :: result
    integer :: n

    result = surface_evaporation_capacity_result_t()
    n = base_state%active_nodes
    if (n <= 0 .or. .not. allocated(base_state%pressure_head) .or. &
        .not. allocated(base_state%water_content)) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'fpe11-invalid'
      return
    end if
    if (size(base_state%pressure_head) /= n .or. size(base_state%water_content) /= n) then
      result%status = SURFACE_EVAP_CAPACITY_INVALID_INPUT
      result%route = 'fpe11-invalid'
      return
    end if

    ! Keep the provider deliberately cheap so the measured signal is dominated
    ! by runtime materialization, while still consuming both profile arrays and
    ! both scalar hydraulic fields from the abstract full-state contract.
    result%evaporation_capacity = 0.10_real64 + &
         1.0e-9_real64*abs(base_state%pressure_head(1)) + &
         1.0e-9_real64*abs(base_state%pressure_head(n)) + &
         1.0e-3_real64*base_state%water_content(1) + &
         1.0e-3_real64*base_state%water_content(n) + &
         1.0e-6_real64*abs(base_state%groundwater_level) + &
         1.0e-4_real64*base_state%ponding_depth
    result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
    result%route = 'fpe11-timing'
  end subroutine fpe11_timing_capacity_evaluate

end module mod_fpe11_timing_capacity_provider

program test_fpe11_surface_evaporation_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, FMR_REFERENCE_ET_BINDING_OK
  use mod_restricted_surface_evaporation, only: surface_evaporation_result_t
  use mod_fmr_surface_evaporation_runtime_materialization, only: &
       fmr_surface_evaporation_runtime_diagnostics_t, fmr_materialize_restricted_surface_evaporation, &
       FMR_SURFACE_EVAP_RUNTIME_OK
  use mod_fpe11_timing_capacity_provider, only: fpe11_timing_provider_t
  implicit none

  type(kernel_committed_state_t) :: committed
  type(fmr_b110_physical_state_t) :: state
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag
  type(fpe11_timing_provider_t) :: provider
  type(surface_evaporation_result_t) :: result
  type(fmr_surface_evaporation_runtime_diagnostics_t) :: diag
  character(len=64) :: arg
  integer :: n, calls, i, warmups
  integer(int64) :: c0, c1, rate
  real(real64) :: seconds, checksum
  logical :: ok

  call get_command_argument(1, arg)
  read(arg,*) n
  call get_command_argument(2, arg)
  read(arg,*) calls
  if (n <= 0 .or. calls <= 0) error stop 'FPE11 invalid timing arguments'

  state%active_nodes = n
  allocate(state%pressure_head(n), state%water_content(n))
  do i = 1, n
    state%pressure_head(i) = -25.0_real64 - 3.0_real64*real(i-1, real64)
    state%water_content(i) = 0.18_real64 + 0.08_real64*real(mod(i,7), real64)/6.0_real64
  end do
  state%ponding_depth = 0.0_real64
  state%groundwater_level = -250.0_real64
  call fmr_new_b110_committed_state(committed, 81101_int64, state, 0.0_real64, ok)
  if (.not. ok) error stop 'FPE11 committed-state initialization failed'

  et = reference_et_demand_result_t()
  et%potential_soil_evaporation_cm_per_day = 1.0_real64
  et%potential_pond_evaporation_cm_per_day = 1.0_real64
  et_diag = fmr_reference_et_binding_diagnostics_t()
  et_diag%status = FMR_REFERENCE_ET_BINDING_OK
  et_diag%result_produced = .true.

  warmups = min(1000, max(100, calls/100))
  checksum = 0.0_real64
  do i = 1, warmups
    call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, provider, result, diag)
    if (diag%status /= FMR_SURFACE_EVAP_RUNTIME_OK) error stop 'FPE11 warmup materialization failed'
    checksum = checksum + result%bare_soil_evaporation + 1.0e-3_real64*diag%raw_evaporation_capacity
  end do

  checksum = 0.0_real64
  call system_clock(c0, rate)
  do i = 1, calls
    call fmr_materialize_restricted_surface_evaporation(committed, et, et_diag, provider, result, diag)
    if (diag%status /= FMR_SURFACE_EVAP_RUNTIME_OK) error stop 'FPE11 measured materialization failed'
    checksum = checksum + result%bare_soil_evaporation + 1.0e-3_real64*diag%raw_evaporation_capacity
  end do
  call system_clock(c1)
  seconds = real(c1-c0, real64)/real(rate, real64)

  write(*,'(A,I0,A,I0,A,ES24.16,A,ES24.16)') 'FPE11_TIMING,nodes=', n, ',calls=', calls, &
       ',seconds=', seconds, ',checksum=', checksum
end program test_fpe11_surface_evaporation_timing
