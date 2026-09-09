program test_fwof30_rate_parameter_bundle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_wofost_rate_parameters
  implicit none

  type(wofost_rate_scalar_parameters_t) :: scalars, view1, view2
  type(wofost_rate_parameter_tables_t) :: tables, bad_tables
  type(wofost_rate_parameter_bundle_t) :: bundle, failed_bundle
  real(real64) :: nan_value, actual
  integer :: status

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)

  call make_valid_scalars(scalars)
  call make_distinct_tables(tables)
  call construct_wofost_rate_parameter_bundle(scalars, tables, bundle, status)
  call require(status == WOFOST_RATE_PARAMETER_OK, 'valid bundle construction')
  call require(bundle%ready(), 'valid bundle ready')

  view1 = bundle%scalar_view()
  call require_scalar_bitwise_equal(view1, scalars, 'scalar view preserves admitted values')
  view1%initial_light_use_efficiency = 9.0_real64
  view2 = bundle%scalar_view()
  call require(bitwise_equal(view2%initial_light_use_efficiency, scalars%initial_light_use_efficiency), &
       'scalar view mutation must not mutate bundle')
  print '(a)', 'FWOF30_SCALAR_VIEW_COPY_AND_BUNDLE_IMMUTABILITY=PASS'

  call check_all_table_routes(bundle)
  print '(a)', 'FWOF30_ALL_TWELVE_SEMANTIC_TABLE_ROUTES=PASS'

  call make_valid_scalars(scalars)
  scalars%development_daylength_mode = 0
  scalars%daylength_upper_hours = nan_value
  scalars%daylength_lower_hours = nan_value
  call construct_wofost_rate_parameter_bundle(scalars, tables, bundle, status)
  call require(status == WOFOST_RATE_PARAMETER_OK, 'IDSL0 should ignore inactive DLO/DLC')
  view1 = bundle%scalar_view()
  call require(bitwise_equal(view1%daylength_upper_hours, 0.0_real64), 'IDSL0 upper threshold canonical zero')
  call require(bitwise_equal(view1%daylength_lower_hours, 0.0_real64), 'IDSL0 lower threshold canonical zero')
  print '(a)', 'FWOF30_IDSL0_INACTIVE_PHOTOPERIOD_CANONICALIZED=PASS'

  call make_valid_scalars(scalars)
  scalars%conversion_efficiency_storage = 0.0_real64
  call construct_wofost_rate_parameter_bundle(scalars, tables, bundle, status)
  call require(status == WOFOST_RATE_PARAMETER_OK, 'CVO=0 remains bundle-admissible before FO evaluation')
  print '(a)', 'FWOF30_CVO_ZERO_DEFERRED_TO_FO_AWARE_RATE_VALIDATION=PASS'

  call check_invalid_scalar_domains(tables, nan_value)
  print '(a)', 'FWOF30_SOURCE_BOUND_AND_DENOMINATOR_DOMAINS_FAIL_CLOSED=PASS'

  bad_tables = wofost_rate_parameter_tables_t()
  call make_valid_scalars(scalars)
  call construct_wofost_rate_parameter_bundle(scalars, bad_tables, failed_bundle, status)
  call require(status == WOFOST_RATE_PARAMETER_INVALID_TABLE, 'unready table set rejected')
  call require(.not. failed_bundle%ready(), 'failed construction remains unready')
  print '(a)', 'FWOF30_UNREADY_TABLE_SET_FAILS_CLOSED=PASS'

  call make_valid_scalars(scalars)
  call construct_wofost_rate_parameter_bundle(scalars, tables, bundle, status)
  call bundle%evaluate_maximum_assimilation(nan_value, actual, status)
  call require(status == WOFOST_RATE_PARAMETER_INVALID_QUERY, 'nonfinite semantic table query status')
  print '(a)', 'FWOF30_NONFINITE_TABLE_QUERY_FAILS_CLOSED_WITHOUT_ARITHMETIC=PASS'

  print '(a)', 'FWOF30_RATE_PARAMETER_BUNDLE_TEST PASS'

contains

  subroutine make_valid_scalars(s)
    type(wofost_rate_scalar_parameters_t), intent(out) :: s

    s = wofost_rate_scalar_parameters_t()
    s%development_daylength_mode = 1
    s%daylength_upper_hours = 16.0_real64
    s%daylength_lower_hours = 8.0_real64
    s%vegetative_temperature_sum_required = 1000.0_real64
    s%generative_temperature_sum_required = 800.0_real64
    s%diffuse_extinction_coefficient = 0.6_real64
    s%initial_light_use_efficiency = 0.45_real64
    s%co2_to_dry_matter_fraction = 0.4_real64
    s%attainable_yield_multiplier = 0.9_real64
    s%conversion_efficiency_root = 0.7_real64
    s%conversion_efficiency_stem = 0.65_real64
    s%conversion_efficiency_leaf = 0.72_real64
    s%conversion_efficiency_storage = 0.8_real64
    s%respiration_temperature_q10 = 2.0_real64
    s%maintenance_respiration_root = 0.01_real64
    s%maintenance_respiration_leaf = 0.02_real64
    s%maintenance_respiration_stem = 0.015_real64
    s%maintenance_respiration_storage = 0.005_real64
    s%maximum_leaf_relative_death_rate = 0.03_real64
    s%leaf_age_base_temperature = 0.0_real64
    s%maximum_relative_lai_growth_rate = 0.04_real64
  end subroutine make_valid_scalars

  subroutine make_distinct_tables(t)
    type(wofost_rate_parameter_tables_t), intent(out) :: t

    call make_table(t%temperature_sum_increment, 10.0_real64)
    call make_table(t%maximum_assimilation, 20.0_real64)
    call make_table(t%daytime_temperature_factor, 30.0_real64)
    call make_table(t%minimum_temperature_factor, 40.0_real64)
    call make_table(t%maintenance_respiration_factor, 50.0_real64)
    call make_table(t%root_partition_fraction, 60.0_real64)
    call make_table(t%leaf_partition_fraction, 70.0_real64)
    call make_table(t%stem_partition_fraction, 80.0_real64)
    call make_table(t%storage_partition_fraction, 90.0_real64)
    call make_table(t%relative_root_death_rate, 100.0_real64)
    call make_table(t%relative_stem_death_rate, 110.0_real64)
    call make_table(t%specific_leaf_area, 120.0_real64)
  end subroutine make_distinct_tables

  subroutine make_table(table, offset)
    type(wofost_rate_table_t), intent(out) :: table
    real(real64), intent(in) :: offset
    real(real64) :: x(3), y(3)
    integer :: table_status

    x = [0.0_real64, 1.0_real64, 2.0_real64]
    y = [offset, offset + 10.0_real64, offset + 20.0_real64]
    call construct_wofost_rate_table(x, y, table, table_status)
    call require(table_status == WOFOST_RATE_TABLE_OK, 'test table construction')
  end subroutine make_table

  subroutine check_all_table_routes(b)
    type(wofost_rate_parameter_bundle_t), intent(in) :: b

    call check_eval_temperature_sum(b, 15.0_real64)
    call check_eval_maximum_assimilation(b, 25.0_real64)
    call check_eval_daytime_temperature(b, 35.0_real64)
    call check_eval_minimum_temperature(b, 45.0_real64)
    call check_eval_respiration_factor(b, 55.0_real64)
    call check_eval_root_partition(b, 65.0_real64)
    call check_eval_leaf_partition(b, 75.0_real64)
    call check_eval_stem_partition(b, 85.0_real64)
    call check_eval_storage_partition(b, 95.0_real64)
    call check_eval_root_death(b, 105.0_real64)
    call check_eval_stem_death(b, 115.0_real64)
    call check_eval_sla(b, 125.0_real64)
  end subroutine check_all_table_routes

  subroutine check_eval_temperature_sum(b, expected)
    type(wofost_rate_parameter_bundle_t), intent(in) :: b
    real(real64), intent(in) :: expected
    integer :: st
    real(real64) :: v
    call b%evaluate_temperature_sum_increment(0.5_real64, v, st)
    call require(st == WOFOST_RATE_PARAMETER_OK .and. bitwise_equal(v, expected), 'DTSMTB route')
  end subroutine check_eval_temperature_sum

  subroutine check_eval_maximum_assimilation(b, expected)
    type(wofost_rate_parameter_bundle_t), intent(in) :: b
    real(real64), intent(in) :: expected
    integer :: st
    real(real64) :: v
    call b%evaluate_maximum_assimilation(0.5_real64, v, st)
    call require(st == WOFOST_RATE_PARAMETER_OK .and. bitwise_equal(v, expected), 'AMAXTB route')
  end subroutine check_eval_maximum_assimilation

  subroutine check_eval_daytime_temperature(b, expected)
    type(wofost_rate_parameter_bundle_t), intent(in) :: b
    real(real64), intent(in) :: expected
    integer :: st
    real(real64) :: v
    call b%evaluate_daytime_temperature_factor(0.5_real64, v, st)
    call require(st == WOFOST_RATE_PARAMETER_OK .and. bitwise_equal(v, expected), 'TMPFTB route')
  end subroutine check_eval_daytime_temperature

  subroutine check_eval_minimum_temperature(b, expected)
    type(wofost_rate_parameter_bundle_t), intent(in) :: b
    real(real64), intent(in) :: expected
    integer :: st
    real(real64) :: v
    call b%evaluate_minimum_temperature_factor(0.5_real64, v, st)
    call require(st == WOFOST_RATE_PARAMETER_OK .and. bitwise_equal(v, expected), 'TMNFTB route')
  end subroutine check_eval_minimum_temperature

  subroutine check_eval_respiration_factor(b, expected)
    type(wofost_rate_parameter_bundle_t), intent(in) :: b
    real(real64), intent(in) :: expected
    integer :: st
    real(real64) :: v
    call b%evaluate_maintenance_respiration_factor(0.5_real64, v, st)
    call require(st == WOFOST_RATE_PARAMETER_OK .and. bitwise_equal(v, expected), 'RFSETB route')
  end subroutine check_eval_respiration_factor

  subroutine check_eval_root_partition(b, expected)
    type(wofost_rate_parameter_bundle_t), intent(in) :: b
    real(real64), intent(in) :: expected
    integer :: st
    real(real64) :: v
    call b%evaluate_root_partition_fraction(0.5_real64, v, st)
    call require(st == WOFOST_RATE_PARAMETER_OK .and. bitwise_equal(v, expected), 'FRTB route')
  end subroutine check_eval_root_partition

  subroutine check_eval_leaf_partition(b, expected)
    type(wofost_rate_parameter_bundle_t), intent(in) :: b
    real(real64), intent(in) :: expected
    integer :: st
    real(real64) :: v
    call b%evaluate_leaf_partition_fraction(0.5_real64, v, st)
    call require(st == WOFOST_RATE_PARAMETER_OK .and. bitwise_equal(v, expected), 'FLTB route')
  end subroutine check_eval_leaf_partition

  subroutine check_eval_stem_partition(b, expected)
    type(wofost_rate_parameter_bundle_t), intent(in) :: b
    real(real64), intent(in) :: expected
    integer :: st
    real(real64) :: v
    call b%evaluate_stem_partition_fraction(0.5_real64, v, st)
    call require(st == WOFOST_RATE_PARAMETER_OK .and. bitwise_equal(v, expected), 'FSTB route')
  end subroutine check_eval_stem_partition

  subroutine check_eval_storage_partition(b, expected)
    type(wofost_rate_parameter_bundle_t), intent(in) :: b
    real(real64), intent(in) :: expected
    integer :: st
    real(real64) :: v
    call b%evaluate_storage_partition_fraction(0.5_real64, v, st)
    call require(st == WOFOST_RATE_PARAMETER_OK .and. bitwise_equal(v, expected), 'FOTB route')
  end subroutine check_eval_storage_partition

  subroutine check_eval_root_death(b, expected)
    type(wofost_rate_parameter_bundle_t), intent(in) :: b
    real(real64), intent(in) :: expected
    integer :: st
    real(real64) :: v
    call b%evaluate_relative_root_death_rate(0.5_real64, v, st)
    call require(st == WOFOST_RATE_PARAMETER_OK .and. bitwise_equal(v, expected), 'RDRRTB route')
  end subroutine check_eval_root_death

  subroutine check_eval_stem_death(b, expected)
    type(wofost_rate_parameter_bundle_t), intent(in) :: b
    real(real64), intent(in) :: expected
    integer :: st
    real(real64) :: v
    call b%evaluate_relative_stem_death_rate(0.5_real64, v, st)
    call require(st == WOFOST_RATE_PARAMETER_OK .and. bitwise_equal(v, expected), 'RDRSTB route')
  end subroutine check_eval_stem_death

  subroutine check_eval_sla(b, expected)
    type(wofost_rate_parameter_bundle_t), intent(in) :: b
    real(real64), intent(in) :: expected
    integer :: st
    real(real64) :: v
    call b%evaluate_specific_leaf_area(0.5_real64, v, st)
    call require(st == WOFOST_RATE_PARAMETER_OK .and. bitwise_equal(v, expected), 'SLATB route')
  end subroutine check_eval_sla

  subroutine check_invalid_scalar_domains(t, nan)
    type(wofost_rate_parameter_tables_t), intent(in) :: t
    real(real64), intent(in) :: nan
    type(wofost_rate_scalar_parameters_t) :: s
    type(wofost_rate_parameter_bundle_t) :: b
    integer :: st

    call make_valid_scalars(s); s%development_daylength_mode = 2
    call construct_wofost_rate_parameter_bundle(s, t, b, st)
    call require(st == WOFOST_RATE_PARAMETER_INVALID_IDSL, 'IDSL 2 rejected')

    call make_valid_scalars(s); s%daylength_upper_hours = 8.0_real64; s%daylength_lower_hours = 8.0_real64
    call construct_wofost_rate_parameter_bundle(s, t, b, st)
    call require(st == WOFOST_RATE_PARAMETER_INVALID_PHOTOPERIOD, 'DLO>DLC required')

    call make_valid_scalars(s); s%vegetative_temperature_sum_required = 0.0_real64
    call construct_wofost_rate_parameter_bundle(s, t, b, st)
    call require(st == WOFOST_RATE_PARAMETER_INVALID_SCALAR, 'TSUMEA zero rejected')

    call make_valid_scalars(s); s%generative_temperature_sum_required = 10001.0_real64
    call construct_wofost_rate_parameter_bundle(s, t, b, st)
    call require(st == WOFOST_RATE_PARAMETER_INVALID_SCALAR, 'TSUMAM legacy upper range retained')

    call make_valid_scalars(s); s%diffuse_extinction_coefficient = 0.0_real64
    call construct_wofost_rate_parameter_bundle(s, t, b, st)
    call require(st == WOFOST_RATE_PARAMETER_INVALID_SCALAR, 'KDIF zero rejected')

    call make_valid_scalars(s); s%co2_to_dry_matter_fraction = 0.0_real64
    call construct_wofost_rate_parameter_bundle(s, t, b, st)
    call require(st == WOFOST_RATE_PARAMETER_INVALID_SCALAR, 'CFRDM zero rejected')

    call make_valid_scalars(s); s%conversion_efficiency_root = 0.0_real64
    call construct_wofost_rate_parameter_bundle(s, t, b, st)
    call require(st == WOFOST_RATE_PARAMETER_INVALID_SCALAR, 'CVR zero rejected')

    call make_valid_scalars(s); s%respiration_temperature_q10 = 0.0_real64
    call construct_wofost_rate_parameter_bundle(s, t, b, st)
    call require(st == WOFOST_RATE_PARAMETER_INVALID_SCALAR, 'Q10 zero rejected')

    call make_valid_scalars(s); s%attainable_yield_multiplier = 1.1_real64
    call construct_wofost_rate_parameter_bundle(s, t, b, st)
    call require(st == WOFOST_RATE_PARAMETER_INVALID_SCALAR, 'RELMF upper range retained')

    call make_valid_scalars(s); s%initial_light_use_efficiency = nan
    call construct_wofost_rate_parameter_bundle(s, t, b, st)
    call require(st == WOFOST_RATE_PARAMETER_INVALID_SCALAR, 'nonfinite active scalar rejected')
  end subroutine check_invalid_scalar_domains

  subroutine require_scalar_bitwise_equal(a, b, label)
    type(wofost_rate_scalar_parameters_t), intent(in) :: a, b
    character(*), intent(in) :: label

    call require(a%development_daylength_mode == b%development_daylength_mode, label)
    call require(bitwise_equal(a%daylength_upper_hours, b%daylength_upper_hours), label)
    call require(bitwise_equal(a%daylength_lower_hours, b%daylength_lower_hours), label)
    call require(bitwise_equal(a%vegetative_temperature_sum_required, b%vegetative_temperature_sum_required), label)
    call require(bitwise_equal(a%generative_temperature_sum_required, b%generative_temperature_sum_required), label)
    call require(bitwise_equal(a%diffuse_extinction_coefficient, b%diffuse_extinction_coefficient), label)
    call require(bitwise_equal(a%initial_light_use_efficiency, b%initial_light_use_efficiency), label)
    call require(bitwise_equal(a%co2_to_dry_matter_fraction, b%co2_to_dry_matter_fraction), label)
    call require(bitwise_equal(a%attainable_yield_multiplier, b%attainable_yield_multiplier), label)
    call require(bitwise_equal(a%conversion_efficiency_root, b%conversion_efficiency_root), label)
    call require(bitwise_equal(a%conversion_efficiency_stem, b%conversion_efficiency_stem), label)
    call require(bitwise_equal(a%conversion_efficiency_leaf, b%conversion_efficiency_leaf), label)
    call require(bitwise_equal(a%conversion_efficiency_storage, b%conversion_efficiency_storage), label)
    call require(bitwise_equal(a%respiration_temperature_q10, b%respiration_temperature_q10), label)
    call require(bitwise_equal(a%maintenance_respiration_root, b%maintenance_respiration_root), label)
    call require(bitwise_equal(a%maintenance_respiration_leaf, b%maintenance_respiration_leaf), label)
    call require(bitwise_equal(a%maintenance_respiration_stem, b%maintenance_respiration_stem), label)
    call require(bitwise_equal(a%maintenance_respiration_storage, b%maintenance_respiration_storage), label)
    call require(bitwise_equal(a%maximum_leaf_relative_death_rate, b%maximum_leaf_relative_death_rate), label)
    call require(bitwise_equal(a%leaf_age_base_temperature, b%leaf_age_base_temperature), label)
    call require(bitwise_equal(a%maximum_relative_lai_growth_rate, b%maximum_relative_lai_growth_rate), label)
  end subroutine require_scalar_bitwise_equal

  logical function bitwise_equal(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function bitwise_equal

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fwof30_rate_parameter_bundle
