program observe_restricted_reference_et
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_reference_et_demand_process
  implicit none

  integer :: failures

  failures = 0
  write(*,'(A)') 'case_id,reference_et_mm_per_day,crop_emerged,vegetation_cover_fraction,crop_factor,co2_factor,pond_factor,status,ptra_cm_per_day,peva_cm_per_day,epond_cm_per_day'

  call emit_case('zero_forcing_bare', 0.0_real64, .false., 0.0_real64, 0.0_real64, 1.0_real64, 1.2_real64)
  call emit_case('bare_5p2', 5.2_real64, .false., 0.0_real64, 0.0_real64, 1.0_real64, 1.2_real64)
  call emit_case('inactive_cover_0p30', 5.2_real64, .false., 0.30_real64, 7.0_real64, 8.0_real64, 1.2_real64)
  call emit_case('active_cover_0p25', 4.0_real64, .true., 0.25_real64, 1.0_real64, 1.0_real64, 1.0_real64)
  call emit_case('active_reference', 5.2_real64, .true., 0.65_real64, 1.1_real64, 0.9_real64, 1.2_real64)
  call emit_case('active_full_cover', 5.2_real64, .true., 1.0_real64, 1.1_real64, 0.9_real64, 1.2_real64)
  call emit_case('active_half_variable', 2.3_real64, .true., 0.5_real64, 1.4_real64, 0.8_real64, 0.7_real64)
  call emit_case('active_no_pond', 5.2_real64, .true., 0.5_real64, 1.0_real64, 1.0_real64, 0.0_real64)

  if (failures /= 0) then
    write(*,'(A,I0)') 'EB_R01_FAILURE_COUNT=', failures
    error stop 1
  end if

contains

  subroutine emit_case(case_id, reference_et, emerged, cover, crop_factor, co2_factor, pond_factor)
    character(len=*), intent(in) :: case_id
    real(real64), intent(in) :: reference_et, cover, crop_factor, co2_factor, pond_factor
    logical, intent(in) :: emerged
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_forcing_t) :: forcing
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: diagnostics

    parameters%pond_evaporation_factor = pond_factor
    forcing%reference_et_mm_per_day = reference_et
    canopy%crop_emerged = emerged
    canopy%vegetation_cover_fraction = cover
    canopy%crop_factor = crop_factor
    canopy%co2_transpiration_factor = co2_factor

    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)

    if (diagnostics%status /= REF_ET_DEMAND_OK .or. .not. diagnostics%result_produced) then
      failures = failures + 1
    end if

    write(*,'(A,",",F10.6,",",L1,",",F10.6,",",F10.6,",",F10.6,",",F10.6,",",I0,3(",",ES25.17E3))') &
      trim(case_id), reference_et, emerged, cover, crop_factor, co2_factor, pond_factor, diagnostics%status, &
      result%potential_transpiration_cm_per_day, result%potential_soil_evaporation_cm_per_day, &
      result%potential_pond_evaporation_cm_per_day
  end subroutine emit_case

end program observe_restricted_reference_et
