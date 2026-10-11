program test_fvq37_crop_et_canopy_view_independent
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_value, ieee_quiet_nan
  use mod_crop_et_canopy_view_provider
  implicit none

  integer :: failures
  integer(int64) :: grid_cases, edge_cases

  failures = 0
  grid_cases = 0_int64
  edge_cases = 0_int64

  call verify_active_oracle_grid(failures, grid_cases)
  call verify_co2_disabled_grid(failures, grid_cases)
  call verify_nonemerged_semantics(failures, grid_cases)
  call verify_fail_closed_and_trap_edges(failures, edge_cases)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FVQ37_FAILURE_COUNT=', failures
    error stop 1
  end if

  write(*,'(A,I0)') 'FVQ37_INDEPENDENT_GRID_CASES=', grid_cases
  write(*,'(A,I0)') 'FVQ37_INDEPENDENT_EDGE_CASES=', edge_cases
  write(*,'(A)') 'FVQ37_FROZEN_SOURCE_VCOVER_ORACLE=PASS'
  write(*,'(A)') 'FVQ37_FROZEN_SOURCE_CF_AFGEN_ORACLE=PASS'
  write(*,'(A)') 'FVQ37_FROZEN_SOURCE_FCO2TRA_ORACLE=PASS'
  write(*,'(A)') 'FVQ37_FIXED_WOFOST_SEMANTIC_PARAMETER_PROFILES=PASS'
  write(*,'(A)') 'FVQ37_NONEMERGED_COVER_AND_INACTIVE_DEPENDENCIES=PASS'
  write(*,'(A)') 'FVQ37_CO2_DISABLED_DEPENDENCY_MINIMALITY=PASS'
  write(*,'(A)') 'FVQ37_AFGEN_ENDPOINT_AND_INTERPOLATION=PASS'
  write(*,'(A)') 'FVQ37_FAIL_CLOSED_FP_TRAP_EDGES=PASS'
  write(*,'(A)') 'FVQ37_INDEPENDENT_CROP_ET_CANOPY_QUALIFICATION PASS'

contains

  subroutine verify_active_oracle_grid(failures, cases)
    integer, intent(inout) :: failures
    integer(int64), intent(inout) :: cases
    real(real64), parameter :: kdir_values(5) = [0.0_real64, 0.1_real64, 0.5_real64, 1.0_real64, 2.0_real64]
    real(real64), parameter :: kdif_values(5) = [0.0_real64, 0.2_real64, 0.7_real64, 1.3_real64, 2.0_real64]
    real(real64), parameter :: lai_values(8) = [0.0_real64, 0.01_real64, 0.2_real64, 1.0_real64, &
                                               3.0_real64, 7.0_real64, 20.0_real64, 80.0_real64]
    real(real64), parameter :: dvs_values(9) = [-1.0_real64, 0.0_real64, 0.2_real64, 0.7_real64, &
                                               1.2_real64, 1.8_real64, 2.0_real64, 2.2_real64, 5.0_real64]
    real(real64), parameter :: co2_values(7) = [10.0_real64, 100.0_real64, 350.0_real64, 600.0_real64, &
                                               1000.0_real64, 2000.0_real64, 3000.0_real64]
    type(crop_et_canopy_parameters_t) :: parameters
    type(crop_et_canopy_state_view_t) :: state
    type(crop_et_canopy_forcing_t) :: forcing
    type(crop_et_canopy_view_t) :: view
    type(crop_et_canopy_diagnostics_t) :: diagnostics
    real(real64) :: cfx(4), cfy(4), co2x(4), co2y(4)
    real(real64) :: expected_cover, expected_cf, expected_co2, extinction_product
    integer :: profile, ikdir, ikdif, ilai, idvs, ico2, status

    do profile = 1, 2
      call semantic_profile(profile, cfx, cfy, co2x, co2y)
      do ikdir = 1, size(kdir_values)
        do ikdif = 1, size(kdif_values)
          call construct_crop_et_canopy_parameters(kdir_values(ikdir), kdif_values(ikdif), &
                                                   cfx, cfy, .true., parameters, status, co2x, co2y)
          call require(status == CROP_ET_CANOPY_OK, 'active-grid parameter construction', failures)
          if (status /= CROP_ET_CANOPY_OK) cycle

          extinction_product = kdir_values(ikdir) * kdif_values(ikdif)
          do ilai = 1, size(lai_values)
            expected_cover = 1.0_real64 - exp(-(extinction_product * lai_values(ilai)))
            do idvs = 1, size(dvs_values)
              expected_cf = oracle_afgen(cfx, cfy, dvs_values(idvs))
              do ico2 = 1, size(co2_values)
                expected_co2 = oracle_afgen(co2x, co2y, co2_values(ico2))

                state%crop_emerged = .true.
                state%development_stage = dvs_values(idvs)
                state%leaf_area_index = lai_values(ilai)
                forcing%atmospheric_co2_ppm = co2_values(ico2)
                call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)

                call require(diagnostics%status == CROP_ET_CANOPY_OK, 'active-grid status', failures)
                call require(diagnostics%state_consumed, 'active-grid state consumption', failures)
                call require(diagnostics%crop_factor_table_consumed, 'active-grid CF table consumption', failures)
                call require(diagnostics%co2_forcing_consumed, 'active-grid CO2 forcing consumption', failures)
                call require(diagnostics%co2_table_consumed, 'active-grid CO2 table consumption', failures)
                call require(diagnostics%result_produced, 'active-grid result production', failures)
                call require(view%crop_emerged, 'active-grid emergence', failures)
                call require(view%crop_specific_factors_valid, 'active-grid factor validity', failures)
                call require_close(view%vegetation_cover_fraction, expected_cover, 'active-grid cover', failures)
                call require_close(view%crop_factor, expected_cf, 'active-grid CF', failures)
                call require_close(view%co2_transpiration_factor, expected_co2, 'active-grid CO2 factor', failures)
                cases = cases + 1_int64
              end do
            end do
          end do
        end do
      end do
    end do
  end subroutine verify_active_oracle_grid

  subroutine verify_co2_disabled_grid(failures, cases)
    integer, intent(inout) :: failures
    integer(int64), intent(inout) :: cases
    real(real64), parameter :: kdir_values(5) = [0.0_real64, 0.1_real64, 0.5_real64, 1.0_real64, 2.0_real64]
    real(real64), parameter :: kdif_values(5) = [0.0_real64, 0.2_real64, 0.7_real64, 1.3_real64, 2.0_real64]
    real(real64), parameter :: lai_values(8) = [0.0_real64, 0.01_real64, 0.2_real64, 1.0_real64, &
                                               3.0_real64, 7.0_real64, 20.0_real64, 80.0_real64]
    real(real64), parameter :: dvs_values(9) = [-1.0_real64, 0.0_real64, 0.2_real64, 0.7_real64, &
                                               1.2_real64, 1.8_real64, 2.0_real64, 2.2_real64, 5.0_real64]
    type(crop_et_canopy_parameters_t) :: parameters
    type(crop_et_canopy_state_view_t) :: state
    type(crop_et_canopy_forcing_t) :: forcing
    type(crop_et_canopy_view_t) :: view
    type(crop_et_canopy_diagnostics_t) :: diagnostics
    real(real64) :: cfx(4), cfy(4), co2x(4), co2y(4), nan_value
    real(real64) :: expected_cover, expected_cf, extinction_product
    integer :: profile, ikdir, ikdif, ilai, idvs, status

    nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
    do profile = 1, 2
      call semantic_profile(profile, cfx, cfy, co2x, co2y)
      do ikdir = 1, size(kdir_values)
        do ikdif = 1, size(kdif_values)
          call construct_crop_et_canopy_parameters(kdir_values(ikdir), kdif_values(ikdif), &
                                                   cfx, cfy, .false., parameters, status)
          call require(status == CROP_ET_CANOPY_OK, 'CO2-off parameter construction', failures)
          if (status /= CROP_ET_CANOPY_OK) cycle
          extinction_product = kdir_values(ikdir) * kdif_values(ikdif)
          do ilai = 1, size(lai_values)
            expected_cover = 1.0_real64 - exp(-(extinction_product * lai_values(ilai)))
            do idvs = 1, size(dvs_values)
              expected_cf = oracle_afgen(cfx, cfy, dvs_values(idvs))
              state%crop_emerged = .true.
              state%development_stage = dvs_values(idvs)
              state%leaf_area_index = lai_values(ilai)
              forcing%atmospheric_co2_ppm = nan_value
              call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)

              call require(diagnostics%status == CROP_ET_CANOPY_OK, 'CO2-off grid status', failures)
              call require(.not. diagnostics%co2_forcing_consumed, 'CO2-off forcing skipped', failures)
              call require(.not. diagnostics%co2_table_consumed, 'CO2-off table skipped', failures)
              call require_close(view%vegetation_cover_fraction, expected_cover, 'CO2-off cover', failures)
              call require_close(view%crop_factor, expected_cf, 'CO2-off CF', failures)
              call require_close(view%co2_transpiration_factor, 1.0_real64, 'CO2-off factor one', failures)
              cases = cases + 1_int64
            end do
          end do
        end do
      end do
    end do
  end subroutine verify_co2_disabled_grid

  subroutine verify_nonemerged_semantics(failures, cases)
    integer, intent(inout) :: failures
    integer(int64), intent(inout) :: cases
    real(real64), parameter :: kdir_values(5) = [0.0_real64, 0.1_real64, 0.5_real64, 1.0_real64, 2.0_real64]
    real(real64), parameter :: kdif_values(5) = [0.0_real64, 0.2_real64, 0.7_real64, 1.3_real64, 2.0_real64]
    real(real64), parameter :: lai_values(8) = [0.0_real64, 0.01_real64, 0.2_real64, 1.0_real64, &
                                               3.0_real64, 7.0_real64, 20.0_real64, 80.0_real64]
    type(crop_et_canopy_parameters_t) :: parameters
    type(crop_et_canopy_state_view_t) :: state
    type(crop_et_canopy_forcing_t) :: forcing
    type(crop_et_canopy_view_t) :: view
    type(crop_et_canopy_diagnostics_t) :: diagnostics
    real(real64) :: cfx(4), cfy(4), co2x(4), co2y(4), nan_value
    real(real64) :: expected_cover, extinction_product
    integer :: ikdir, ikdif, ilai, status

    call semantic_profile(1, cfx, cfy, co2x, co2y)
    nan_value = ieee_value(0.0_real64, ieee_quiet_nan)

    do ikdir = 1, size(kdir_values)
      do ikdif = 1, size(kdif_values)
        call construct_crop_et_canopy_parameters(kdir_values(ikdir), kdif_values(ikdif), &
                                                 cfx, cfy, .true., parameters, status, co2x, co2y)
        call require(status == CROP_ET_CANOPY_OK, 'nonemerged parameter construction', failures)
        if (status /= CROP_ET_CANOPY_OK) cycle
        extinction_product = kdir_values(ikdir) * kdif_values(ikdif)
        do ilai = 1, size(lai_values)
          expected_cover = 1.0_real64 - exp(-(extinction_product * lai_values(ilai)))
          state%crop_emerged = .false.
          state%development_stage = nan_value
          state%leaf_area_index = lai_values(ilai)
          forcing%atmospheric_co2_ppm = nan_value
          call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)

          call require(diagnostics%status == CROP_ET_CANOPY_OK, 'nonemerged status', failures)
          call require(diagnostics%state_consumed, 'nonemerged cover state consumed', failures)
          call require(.not. diagnostics%crop_factor_table_consumed, 'nonemerged CF table skipped', failures)
          call require(.not. diagnostics%co2_forcing_consumed, 'nonemerged CO2 forcing skipped', failures)
          call require(.not. diagnostics%co2_table_consumed, 'nonemerged CO2 table skipped', failures)
          call require(.not. view%crop_specific_factors_valid, 'nonemerged factors invalid', failures)
          call require_close(view%vegetation_cover_fraction, expected_cover, 'nonemerged cover', failures)
          call require_close(view%crop_factor, 0.0_real64, 'nonemerged CF canonical zero', failures)
          call require_close(view%co2_transpiration_factor, 1.0_real64, 'nonemerged CO2 canonical one', failures)
          cases = cases + 1_int64
        end do
      end do
    end do
  end subroutine verify_nonemerged_semantics

  subroutine verify_fail_closed_and_trap_edges(failures, cases)
    integer, intent(inout) :: failures
    integer(int64), intent(inout) :: cases
    type(crop_et_canopy_parameters_t) :: parameters
    type(crop_et_canopy_parameters_t) :: uninitialized
    type(crop_et_canopy_state_view_t) :: state
    type(crop_et_canopy_forcing_t) :: forcing
    type(crop_et_canopy_view_t) :: view
    type(crop_et_canopy_diagnostics_t) :: diagnostics
    real(real64) :: cfx(4), cfy(4), co2x(4), co2y(4), bady(4), nan_value
    integer :: status

    call semantic_profile(2, cfx, cfy, co2x, co2y)
    nan_value = ieee_value(0.0_real64, ieee_quiet_nan)

    call construct_crop_et_canopy_parameters(-0.01_real64, 0.6_real64, cfx, cfy, .false., parameters, status)
    call require(status == CROP_ET_CANOPY_INVALID_PARAMETER, 'negative KDIR rejected', failures)
    cases = cases + 1_int64

    call construct_crop_et_canopy_parameters(0.8_real64, 2.01_real64, cfx, cfy, .false., parameters, status)
    call require(status == CROP_ET_CANOPY_INVALID_PARAMETER, 'KDIF above source domain rejected', failures)
    cases = cases + 1_int64

    call construct_crop_et_canopy_parameters(nan_value, 0.6_real64, cfx, cfy, .false., parameters, status)
    call require(status == CROP_ET_CANOPY_INVALID_PARAMETER, 'NaN KDIR rejected trap-safe', failures)
    cases = cases + 1_int64

    bady = cfy
    bady(2) = 2.01_real64
    call construct_crop_et_canopy_parameters(0.8_real64, 0.6_real64, cfx, bady, .false., parameters, status)
    call require(status == CROP_ET_CANOPY_INVALID_TABLE, 'CF factor above source domain rejected', failures)
    cases = cases + 1_int64

    call construct_crop_et_canopy_parameters(0.8_real64, 0.6_real64, cfx, cfy, .true., parameters, status)
    call require(status == CROP_ET_CANOPY_INVALID_TABLE, 'active CO2 requires table', failures)
    cases = cases + 1_int64

    call construct_crop_et_canopy_parameters(0.8_real64, 0.6_real64, cfx, cfy, .true., &
                                             parameters, status, co2x, co2y)
    call require(status == CROP_ET_CANOPY_OK, 'edge parameter construction', failures)

    state%crop_emerged = .true.
    state%development_stage = 1.0_real64
    state%leaf_area_index = 1.0_real64
    forcing%atmospheric_co2_ppm = 600.0_real64

    call evaluate_crop_et_canopy_view(uninitialized, state, forcing, view, diagnostics)
    call require(diagnostics%status == CROP_ET_CANOPY_INVALID_PARAMETER, 'uninitialized provider rejected', failures)
    call require_zero_failed_view(view, 'uninitialized zero view', failures)
    cases = cases + 1_int64

    state%leaf_area_index = nan_value
    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)
    call require(diagnostics%status == CROP_ET_CANOPY_INVALID_STATE, 'NaN LAI rejected trap-safe', failures)
    call require_zero_failed_view(view, 'NaN LAI zero view', failures)
    cases = cases + 1_int64

    state%leaf_area_index = -0.01_real64
    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)
    call require(diagnostics%status == CROP_ET_CANOPY_INVALID_STATE, 'negative LAI rejected', failures)
    cases = cases + 1_int64

    state%leaf_area_index = 1.0_real64
    state%development_stage = nan_value
    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)
    call require(diagnostics%status == CROP_ET_CANOPY_INVALID_STATE, 'NaN DVS rejected trap-safe', failures)
    call require_zero_failed_view(view, 'NaN DVS zero view', failures)
    cases = cases + 1_int64

    state%development_stage = 1.0_real64
    forcing%atmospheric_co2_ppm = 9.999_real64
    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)
    call require(diagnostics%status == CROP_ET_CANOPY_INVALID_CO2_FORCING, 'low active CO2 rejected', failures)
    call require_zero_failed_view(view, 'low CO2 zero view', failures)
    cases = cases + 1_int64

    forcing%atmospheric_co2_ppm = 3000.001_real64
    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)
    call require(diagnostics%status == CROP_ET_CANOPY_INVALID_CO2_FORCING, 'high active CO2 rejected', failures)
    cases = cases + 1_int64

    call construct_crop_et_canopy_parameters(2.0_real64, 2.0_real64, cfx, cfy, .false., parameters, status)
    call require(status == CROP_ET_CANOPY_OK, 'overflow-edge parameter construction', failures)
    state%leaf_area_index = huge(1.0_real64)
    state%development_stage = 1.0_real64
    forcing%atmospheric_co2_ppm = nan_value
    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)
    call require(diagnostics%status == CROP_ET_CANOPY_INVALID_STATE, 'true optical-depth overflow rejected', failures)
    cases = cases + 1_int64

    call construct_crop_et_canopy_parameters(0.5_real64, 0.5_real64, cfx, cfy, .false., parameters, status)
    call require(status == CROP_ET_CANOPY_OK, 'subunit extinction parameter construction', failures)
    state%leaf_area_index = huge(1.0_real64)
    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)
    call require(diagnostics%status == CROP_ET_CANOPY_OK, 'subunit extinction huge LAI trap-safe', failures)
    call require_close(view%vegetation_cover_fraction, 1.0_real64, 'subunit extinction saturated cover', failures)
    cases = cases + 1_int64
  end subroutine verify_fail_closed_and_trap_edges

  subroutine semantic_profile(profile, cfx, cfy, co2x, co2y)
    integer, intent(in) :: profile
    real(real64), intent(out) :: cfx(4), cfy(4), co2x(4), co2y(4)

    if (profile == 1) then
      ! Fixed-crop-compatible semantic parameter shape. This is not a parser-adapter test.
      cfx = [0.0_real64, 0.5_real64, 1.5_real64, 2.0_real64]
      cfy = [0.85_real64, 0.95_real64, 1.05_real64, 0.90_real64]
      co2x = [0.0_real64, 400.0_real64, 800.0_real64, 3000.0_real64]
      co2y = [1.05_real64, 1.00_real64, 0.90_real64, 0.70_real64]
    else
      ! WOFOST-compatible semantic parameter shape. This is not a parser-adapter test.
      cfx = [0.0_real64, 0.3_real64, 1.2_real64, 2.0_real64]
      cfy = [0.70_real64, 1.10_real64, 1.25_real64, 0.80_real64]
      co2x = [0.0_real64, 300.0_real64, 1000.0_real64, 3000.0_real64]
      co2y = [1.00_real64, 0.97_real64, 0.85_real64, 0.75_real64]
    end if
  end subroutine semantic_profile

  pure real(real64) function oracle_afgen(x, y, query) result(value)
    real(real64), intent(in) :: x(:), y(:), query
    integer :: i
    real(real64) :: slope

    if (query <= x(1)) then
      value = y(1)
      return
    end if
    if (query >= x(size(x))) then
      value = y(size(y))
      return
    end if

    do i = 2, size(x)
      if (query <= x(i)) then
        slope = (y(i) - y(i-1)) / (x(i) - x(i-1))
        value = y(i-1) + (query - x(i-1)) * slope
        return
      end if
    end do

    value = y(size(y))
  end function oracle_afgen

  subroutine require(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    if (.not. condition) then
      write(*,'(A,A)') 'FVQ37_ASSERT_FAIL: ', trim(label)
      failures = failures + 1
    end if
  end subroutine require

  subroutine require_close(actual, expected, label, failures)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    real(real64) :: tolerance

    if (.not. ieee_is_finite(actual)) then
      call require(.false., label, failures)
      return
    end if
    if (.not. ieee_is_finite(expected)) then
      call require(.false., label, failures)
      return
    end if

    tolerance = 32.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(expected))
    call require(abs(actual - expected) <= tolerance, label, failures)
  end subroutine require_close

  subroutine require_zero_failed_view(view, label, failures)
    type(crop_et_canopy_view_t), intent(in) :: view
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    call require(.not. view%crop_emerged, trim(label)//' emerged', failures)
    call require(.not. view%crop_specific_factors_valid, trim(label)//' valid', failures)
    call require_close(view%vegetation_cover_fraction, 0.0_real64, trim(label)//' cover', failures)
    call require_close(view%crop_factor, 0.0_real64, trim(label)//' CF', failures)
    call require_close(view%co2_transpiration_factor, 0.0_real64, trim(label)//' CO2', failures)
  end subroutine require_zero_failed_view

end program test_fvq37_crop_et_canopy_view_independent
