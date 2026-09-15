module mod_fpe11_current_capacity_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_provider_t, &
       surface_evaporation_capacity_result_t, SURFACE_EVAP_CAPACITY_AVAILABLE, SURFACE_EVAP_CAPACITY_INVALID_INPUT
  implicit none
  private
  type, extends(surface_evaporation_capacity_provider_t), public :: fpe11_current_capacity_provider_t
  contains
    procedure :: evaluate => fpe11_current_capacity_evaluate
  end type fpe11_current_capacity_provider_t
contains
  subroutine fpe11_current_capacity_evaluate(self, base_state, result)
    class(fpe11_current_capacity_provider_t), intent(in) :: self
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
    result%evaporation_capacity = 0.12_real64 + 1.0e-8_real64*abs(base_state%pressure_head(1)) + &
         1.0e-8_real64*abs(base_state%pressure_head(n)) + &
         1.0e-3_real64*base_state%water_content(1) + &
         1.0e-3_real64*base_state%water_content(n) + &
         1.0e-7_real64*abs(base_state%groundwater_level)
    result%status = SURFACE_EVAP_CAPACITY_AVAILABLE
    result%route = 'fpe11-current'
  end subroutine fpe11_current_capacity_evaluate
end module mod_fpe11_current_capacity_provider

program test_fpe11_current_canonical_preservation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, FMR_REFERENCE_ET_BINDING_OK
  use mod_restricted_surface_evaporation, only: surface_evaporation_result_t
  use mod_fmr_surface_evaporation_runtime_materialization, only: &
       fmr_surface_evaporation_runtime_diagnostics_t, fmr_materialize_restricted_surface_evaporation, &
       FMR_SURFACE_EVAP_RUNTIME_OK
  use mod_fpe11_current_kernel_view_binding, only: fpe11_initialize_committed, fpe11_committed_fingerprint
  use mod_fpe11_current_capacity_provider, only: fpe11_current_capacity_provider_t
  implicit none

  type(kernel_committed_state_t) :: a, b, p
  type(reference_et_demand_result_t) :: et
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag
  type(fpe11_current_capacity_provider_t) :: provider
  type(surface_evaporation_result_t) :: ra1, rb, ra2, rp
  type(fmr_surface_evaporation_runtime_diagnostics_t) :: da1, db, da2, dp
  real(real64) :: before_a, after_a, before_b, after_b, before_p, after_p
  logical :: ok

  call fpe11_initialize_committed(a, 91101_int64, 60, 0.0_real64, 0.0_real64, ok)
  if (.not. ok) error stop 'FPE11 current A initialization failed'
  call fpe11_initialize_committed(b, 91102_int64, 60, 11.0_real64, 0.0_real64, ok)
  if (.not. ok) error stop 'FPE11 current B initialization failed'
  call fpe11_initialize_committed(p, 91103_int64, 60, 3.0_real64, 0.25_real64, ok)
  if (.not. ok) error stop 'FPE11 current ponded initialization failed'

  et = reference_et_demand_result_t()
  et%potential_soil_evaporation_cm_per_day = 1.0_real64
  et%potential_pond_evaporation_cm_per_day = 1.0_real64
  et_diag = fmr_reference_et_binding_diagnostics_t()
  et_diag%status = FMR_REFERENCE_ET_BINDING_OK
  et_diag%result_produced = .true.

  call fpe11_committed_fingerprint(a, before_a, ok)
  if (.not. ok) error stop 'FPE11 current A fingerprint before failed'
  call fmr_materialize_restricted_surface_evaporation(a, et, et_diag, provider, ra1, da1)
  if (da1%status /= FMR_SURFACE_EVAP_RUNTIME_OK .or. .not. da1%result_produced) error stop 'FPE11 A1 failed'
  call fpe11_committed_fingerprint(a, after_a, ok)
  if (.not. ok .or. transfer(before_a,0_int64) /= transfer(after_a,0_int64)) &
       error stop 'FPE11 committed A mutated'

  call fpe11_committed_fingerprint(b, before_b, ok)
  if (.not. ok) error stop 'FPE11 current B fingerprint before failed'
  call fmr_materialize_restricted_surface_evaporation(b, et, et_diag, provider, rb, db)
  if (db%status /= FMR_SURFACE_EVAP_RUNTIME_OK .or. .not. db%result_produced) error stop 'FPE11 B failed'
  call fpe11_committed_fingerprint(b, after_b, ok)
  if (.not. ok .or. transfer(before_b,0_int64) /= transfer(after_b,0_int64)) &
       error stop 'FPE11 committed B mutated'

  call fmr_materialize_restricted_surface_evaporation(a, et, et_diag, provider, ra2, da2)
  if (da2%status /= FMR_SURFACE_EVAP_RUNTIME_OK .or. .not. da2%result_produced) error stop 'FPE11 A2 failed'
  if (transfer(ra1%bare_soil_evaporation,0_int64) /= transfer(ra2%bare_soil_evaporation,0_int64)) &
       error stop 'FPE11 ABA bare result drift'
  if (transfer(da1%raw_evaporation_capacity,0_int64) /= transfer(da2%raw_evaporation_capacity,0_int64)) &
       error stop 'FPE11 ABA capacity drift'
  if (trim(ra1%route) /= trim(ra2%route)) error stop 'FPE11 ABA route drift'
  if (transfer(ra1%bare_soil_evaporation,0_int64) == transfer(rb%bare_soil_evaporation,0_int64) .and. &
      transfer(da1%raw_evaporation_capacity,0_int64) == transfer(db%raw_evaporation_capacity,0_int64)) &
       error stop 'FPE11 A/B distinction missing'

  call fpe11_committed_fingerprint(p, before_p, ok)
  if (.not. ok) error stop 'FPE11 current ponded fingerprint before failed'
  call fmr_materialize_restricted_surface_evaporation(p, et, et_diag, provider, rp, dp)
  if (dp%status /= FMR_SURFACE_EVAP_RUNTIME_OK .or. .not. dp%result_produced) error stop 'FPE11 ponded failed'
  if (rp%ponded_water_evaporation <= 0.0_real64 .or. rp%bare_soil_evaporation /= 0.0_real64) &
       error stop 'FPE11 ponded route identity failed'
  call fpe11_committed_fingerprint(p, after_p, ok)
  if (.not. ok .or. transfer(before_p,0_int64) /= transfer(after_p,0_int64)) &
       error stop 'FPE11 committed ponded state mutated'

  if (ra1%bare_soil_evaporation <= 0.0_real64 .or. ra1%ponded_water_evaporation /= 0.0_real64) &
       error stop 'FPE11 dry route identity failed'

  print *, 'FPE11_CURRENT_KERNEL_COMMITTED_IMMUTABILITY=PASS'
  print *, 'FPE11_CURRENT_KERNEL_ABA_DETERMINISM=PASS'
  print *, 'FPE11_CURRENT_DRY_PONDED_SCIENTIFIC_IDENTITY=PASS'
  print *, 'FPE11_CURRENT_NO_PERSISTENT_STATE_OR_MASS_SIDE_EFFECT=PASS'
  print *, 'FPE11_CURRENT_FUNCTIONAL_PRESERVATION=PASS'
end program test_fpe11_current_canonical_preservation
