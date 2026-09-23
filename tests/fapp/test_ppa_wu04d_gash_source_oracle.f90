program test_ppa_wu04d_gash_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_vonhhbraden_interception, only: vonhhbraden_source_window_t, VONHHBRADEN_AVAILABLE
  use mod_gash_interception, only: gash_parameters_t, evaluate_gash_source_window
  implicit none

  integer, parameter :: vector_count = 100000
  type(gash_parameters_t) :: parameters
  type(vonhhbraden_source_window_t) :: source
  real(real64) :: actual, expected, value, tolerance
  integer(int64) :: random_state
  integer :: i, status

  random_state = 20260923_int64
  do i = 1, vector_count
    call random_unit(random_state, value)
    parameters%free_throughfall = 0.10_real64+0.35_real64*value
    call random_unit(random_state, value)
    parameters%stemflow = 0.02_real64+0.15_real64*value
    call random_unit(random_state, value)
    parameters%canopy_storage_cm = 0.001_real64+0.199_real64*value
    call random_unit(random_state, value)
    parameters%average_evaporation = 0.01_real64+0.39_real64*value
    call random_unit(random_state, value)
    parameters%average_precipitation = 0.10_real64+0.90_real64*value

    call random_unit(random_state, value)
    source%gross_rain_cm_per_day = 3.0_real64*value
    call random_unit(random_state, value)
    source%sprinkling_irrigation_cm_per_day = 3.0_real64*value
    call random_unit(random_state, value)
    source%leaf_area_index = 6.0_real64*value
    source%sprinkling_is_intercepted = modulo(i,2) == 0
    source%snow_present = modulo(i,17) == 0

    expected = source_gash(parameters, source)
    call evaluate_gash_source_window(parameters, source, actual, status)
    call require(status == VONHHBRADEN_AVAILABLE, 1)
    tolerance = 64.0_real64*epsilon(expected)*max(1.0_real64,abs(expected))
    call require(abs(actual-expected) <= tolerance, 2)
  end do

  print '(A)', 'PPA_WU04D_GASH_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_WU04D_GASH_GATES_AND_PIECEWISE_BRANCHES=PASS'

contains

  pure real(real64) function source_gash(p, s) result(interception)
    type(gash_parameters_t), intent(in) :: p
    type(vonhhbraden_source_window_t), intent(in) :: s
    real(real64) :: c, rpd, canopy_storage, average_evaporation, saturation_precipitation

    interception = 0.0_real64
    rpd = s%gross_rain_cm_per_day
    if (s%sprinkling_is_intercepted) rpd = rpd+s%sprinkling_irrigation_cm_per_day
    if (s%leaf_area_index < 1.0e-3_real64 .or. rpd < 1.0e-5_real64 .or. s%snow_present) return
    c = 1.0_real64-p%free_throughfall-p%stemflow
    canopy_storage = p%canopy_storage_cm/c
    average_evaporation = p%average_evaporation/c
    if (1.0_real64-average_evaporation/p%average_precipitation > 1.0e-4_real64) then
      saturation_precipitation = -p%average_precipitation*canopy_storage/average_evaporation* &
        log(1.0_real64-average_evaporation/p%average_precipitation)
    else
      saturation_precipitation = p%average_precipitation*canopy_storage/average_evaporation
    end if
    if (rpd < saturation_precipitation) then
      interception = c*rpd
    else
      interception = c*(saturation_precipitation+average_evaporation*c/p%average_precipitation* &
        (rpd-saturation_precipitation))
    end if
  end function source_gash

  subroutine random_unit(state, result)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: result
    state = modulo(state*48271_int64, 2147483647_int64)
    result = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*,'(A,I0)') 'PPA_WU04D_GASH_SOURCE_ORACLE_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu04d_gash_source_oracle
