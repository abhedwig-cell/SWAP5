program test_fwof18_reference_et_transpiration
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, CROP_ROOT_INPUT_OK, validate_crop_root_uptake_input
  use mod_crop_root_uptake_input_assembly, only: root_uptake_et_result_t, crop_root_state_view_t, &
       crop_root_uptake_assembly_diagnostics_t, assemble_crop_root_uptake_input, CROP_ROOT_ASSEMBLY_OK
  use mod_reference_et_transpiration_process, only: reference_et_forcing_t, transpiration_canopy_view_t, &
       reference_et_transpiration_diagnostics_t, evaluate_reference_et_transpiration, &
       REF_ET_TRA_OK, REF_ET_TRA_INVALID_REFERENCE_ET, REF_ET_TRA_INVALID_COVER, &
       REF_ET_TRA_INVALID_CROP_FACTOR, REF_ET_TRA_INVALID_CO2_FACTOR
  implicit none

  type(reference_et_forcing_t) :: forcing, forcing_before
  type(transpiration_canopy_view_t) :: canopy, canopy_before
  type(root_uptake_et_result_t) :: result, a1, b, a2
  type(reference_et_transpiration_diagnostics_t) :: diag
  type(crop_root_state_view_t) :: roots
  type(crop_root_uptake_input_t) :: input
  type(crop_root_uptake_assembly_diagnostics_t) :: assembly_diag
  real(real64) :: nanv, expected
  integer :: status

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  forcing%reference_et_mm_per_day = nanv
  canopy%crop_emerged = .false.
  canopy%vegetation_cover_fraction = nanv
  canopy%crop_factor = nanv
  canopy%co2_transpiration_factor = nanv
  call evaluate_reference_et_transpiration(forcing, canopy, result, diag)
  call require(diag%status == REF_ET_TRA_OK .and. diag%result_produced, 'inactive status')
  call require(.not. diag%forcing_consumed .and. .not. diag%canopy_consumed, 'inactive dependencies')
  call require(same_bits(result%potential_transpiration, 0.0_real64), 'inactive zero')
  write(*,'(A)') 'FWOF18_INACTIVE_CROP_DEPENDENCY_FREE_ZERO=PASS'

  forcing%reference_et_mm_per_day = 4.0_real64
  canopy%crop_emerged = .true.
  canopy%vegetation_cover_fraction = 0.65_real64
  canopy%crop_factor = 1.15_real64
  canopy%co2_transpiration_factor = 0.92_real64
  forcing_before = forcing
  canopy_before = canopy
  expected = legacy_b110_swetr1_swinter0_ptra(forcing%reference_et_mm_per_day, canopy%vegetation_cover_fraction, &
                                               canopy%crop_factor, canopy%co2_transpiration_factor)
  call evaluate_reference_et_transpiration(forcing, canopy, result, diag)
  call require(diag%status == REF_ET_TRA_OK .and. diag%result_produced, 'active status')
  call require(diag%forcing_consumed .and. diag%canopy_consumed, 'active dependencies')
  call require(same_bits(result%potential_transpiration, expected), 'B1.10 formula identity')
  call require(same_bits(forcing%reference_et_mm_per_day, forcing_before%reference_et_mm_per_day), 'forcing read only')
  call require(same_canopy(canopy, canopy_before), 'canopy read only')
  write(*,'(A,ES24.16E3)') 'FWOF18_B110_ORACLE_PTRA_CM_PER_DAY=', expected
  write(*,'(A)') 'FWOF18_SWETR1_SWINTER0_B110_FORMULA_IDENTITY=PASS'
  write(*,'(A)') 'FWOF18_INPUTS_READ_ONLY=PASS'

  canopy%vegetation_cover_fraction = 0.0_real64
  call evaluate_reference_et_transpiration(forcing, canopy, result, diag)
  call require(diag%status == REF_ET_TRA_OK .and. same_bits(result%potential_transpiration, 0.0_real64), 'zero cover')
  canopy%vegetation_cover_fraction = 0.65_real64
  canopy%crop_factor = 0.0_real64
  call evaluate_reference_et_transpiration(forcing, canopy, result, diag)
  call require(diag%status == REF_ET_TRA_OK .and. same_bits(result%potential_transpiration, 0.0_real64), 'zero cf')
  write(*,'(A)') 'FWOF18_ZERO_COVER_AND_CROP_FACTOR_ROUTES=PASS'

  canopy%crop_factor = 1.15_real64
  canopy%co2_transpiration_factor = 0.5_real64
  expected = legacy_b110_swetr1_swinter0_ptra(forcing%reference_et_mm_per_day, canopy%vegetation_cover_fraction, &
                                               canopy%crop_factor, canopy%co2_transpiration_factor)
  call evaluate_reference_et_transpiration(forcing, canopy, result, diag)
  call require(diag%status == REF_ET_TRA_OK .and. same_bits(result%potential_transpiration, expected), 'co2 factor')
  write(*,'(A)') 'FWOF18_CO2_TRANSPIRATION_FACTOR_APPLICATION=PASS'

  forcing%reference_et_mm_per_day = -1.0_real64
  call evaluate_reference_et_transpiration(forcing, canopy, result, diag)
  call require(diag%status == REF_ET_TRA_INVALID_REFERENCE_ET, 'negative etref')
  forcing%reference_et_mm_per_day = nanv
  call evaluate_reference_et_transpiration(forcing, canopy, result, diag)
  call require(diag%status == REF_ET_TRA_INVALID_REFERENCE_ET, 'nan etref')
  forcing%reference_et_mm_per_day = 4.0_real64

  canopy%vegetation_cover_fraction = 1.1_real64
  call evaluate_reference_et_transpiration(forcing, canopy, result, diag)
  call require(diag%status == REF_ET_TRA_INVALID_COVER, 'cover high')
  canopy%vegetation_cover_fraction = 0.65_real64
  canopy%crop_factor = -0.1_real64
  call evaluate_reference_et_transpiration(forcing, canopy, result, diag)
  call require(diag%status == REF_ET_TRA_INVALID_CROP_FACTOR, 'cf negative')
  canopy%crop_factor = 1.15_real64
  canopy%co2_transpiration_factor = -0.1_real64
  call evaluate_reference_et_transpiration(forcing, canopy, result, diag)
  call require(diag%status == REF_ET_TRA_INVALID_CO2_FACTOR, 'co2 negative')
  write(*,'(A)') 'FWOF18_INVALID_ACTIVE_INPUTS_FAIL_CLOSED=PASS'

  canopy%co2_transpiration_factor = 0.92_real64
  call evaluate_reference_et_transpiration(forcing, canopy, a1, diag)
  call require(diag%status == REF_ET_TRA_OK, 'A1')
  forcing%reference_et_mm_per_day = 6.0_real64
  call evaluate_reference_et_transpiration(forcing, canopy, b, diag)
  call require(diag%status == REF_ET_TRA_OK .and. .not. same_bits(a1%potential_transpiration, b%potential_transpiration), 'B')
  forcing%reference_et_mm_per_day = 4.0_real64
  call evaluate_reference_et_transpiration(forcing, canopy, a2, diag)
  call require(diag%status == REF_ET_TRA_OK .and. same_bits(a1%potential_transpiration, a2%potential_transpiration), 'A/B/A')
  write(*,'(A)') 'FWOF18_A_B_A_BITWISE_IDENTITY=PASS'

  roots%crop_emerged = .true.
  roots%rooted_nodes = 2
  allocate(roots%cumulative_root_fraction(3))
  roots%cumulative_root_fraction = [0.0_real64, 0.4_real64, 1.0_real64]
  call assemble_crop_root_uptake_input(roots, a1, 4, input, assembly_diag)
  call require(assembly_diag%status == CROP_ROOT_ASSEMBLY_OK .and. assembly_diag%assembled, 'F-WOF13 assembly')
  call require(same_bits(input%potential_transpiration, a1%potential_transpiration), 'assembly ptra')
  call validate_crop_root_uptake_input(input, 4, status)
  call require(status == CROP_ROOT_INPUT_OK, 'assembled contract')
  write(*,'(A,ES24.16E3)') 'FWOF18_FWO13_ASSEMBLED_PTRA=', input%potential_transpiration
  write(*,'(A)') 'FWOF18_FWO13_ET_RESULT_CONSUMPTION=PASS'
  write(*,'(A)') 'FWOF18_REFERENCE_ET_TRANSPIRATION_TEST PASS'

contains

  real(real64) function legacy_b110_swetr1_swinter0_ptra(etr, vcover, cf, fco2tra) result(ptra)
    real(real64), intent(in) :: etr, vcover, cf, fco2tra
    real(real64) :: et0, ptra_dry, wfrac, ptra_wet

    ! Independent transcription of the relevant B1.10 execution order.
    et0 = etr * vcover * cf
    ptra_dry = max(et0 * 0.1_real64, 0.0_real64)
    ptra_dry = fco2tra * ptra_dry
    ptra_wet = 0.0_real64
    wfrac = 0.0_real64
    ptra = wfrac * ptra_wet + (1.0_real64 - wfrac) * ptra_dry
  end function legacy_b110_swetr1_swinter0_ptra

  logical function same_canopy(left, right) result(equal)
    type(transpiration_canopy_view_t), intent(in) :: left, right
    equal = (left%crop_emerged .eqv. right%crop_emerged) .and. &
            same_bits(left%vegetation_cover_fraction, right%vegetation_cover_fraction) .and. &
            same_bits(left%crop_factor, right%crop_factor) .and. &
            same_bits(left%co2_transpiration_factor, right%co2_transpiration_factor)
  end function same_canopy

  logical function same_bits(left, right) result(equal)
    real(real64), intent(in) :: left, right
    integer(int64) :: li, ri
    li = transfer(left, li)
    ri = transfer(right, ri)
    equal = li == ri
  end function same_bits

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fwof18_reference_et_transpiration
