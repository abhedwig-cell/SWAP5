module mod_wofost_rate_parameters
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_rate_table, only: wofost_rate_table_t, WOFOST_RATE_TABLE_OK, &
       WOFOST_RATE_TABLE_INVALID_QUERY
  implicit none
  private

  integer, parameter, public :: WOFOST_RATE_PARAMETER_OK = 0
  integer, parameter, public :: WOFOST_RATE_PARAMETER_INVALID_IDSL = 1
  integer, parameter, public :: WOFOST_RATE_PARAMETER_INVALID_PHOTOPERIOD = 2
  integer, parameter, public :: WOFOST_RATE_PARAMETER_INVALID_SCALAR = 3
  integer, parameter, public :: WOFOST_RATE_PARAMETER_INVALID_TABLE = 4
  integer, parameter, public :: WOFOST_RATE_PARAMETER_INVALID_BUNDLE = 5
  integer, parameter, public :: WOFOST_RATE_PARAMETER_INVALID_QUERY = 6

  ! Construction DTO. These are parameter values, not dynamic crop state.
  ! Legacy mnemonics are documented next to their semantic field names.
  type, public :: wofost_rate_scalar_parameters_t
    integer :: development_daylength_mode = 0                    ! IDSL
    real(real64) :: daylength_upper_hours = 0.0_real64            ! DLO
    real(real64) :: daylength_lower_hours = 0.0_real64            ! DLC
    real(real64) :: vegetative_temperature_sum_required = 0.0_real64 ! TSUMEA
    real(real64) :: generative_temperature_sum_required = 0.0_real64 ! TSUMAM
    real(real64) :: diffuse_extinction_coefficient = 0.0_real64   ! KDIF
    real(real64) :: initial_light_use_efficiency = 0.0_real64     ! EFF
    real(real64) :: co2_to_dry_matter_fraction = 0.0_real64       ! CFRDM
    real(real64) :: attainable_yield_multiplier = 0.0_real64      ! RELMF
    real(real64) :: conversion_efficiency_root = 0.0_real64       ! CVR
    real(real64) :: conversion_efficiency_stem = 0.0_real64       ! CVS
    real(real64) :: conversion_efficiency_leaf = 0.0_real64       ! CVL
    real(real64) :: conversion_efficiency_storage = 0.0_real64    ! CVO
    real(real64) :: respiration_temperature_q10 = 0.0_real64      ! Q10
    real(real64) :: maintenance_respiration_root = 0.0_real64     ! RMR
    real(real64) :: maintenance_respiration_leaf = 0.0_real64     ! RML
    real(real64) :: maintenance_respiration_stem = 0.0_real64     ! RMS
    real(real64) :: maintenance_respiration_storage = 0.0_real64  ! RMO
    real(real64) :: maximum_leaf_relative_death_rate = 0.0_real64 ! PERDL
    real(real64) :: leaf_age_base_temperature = 0.0_real64        ! TBASE
    real(real64) :: maximum_relative_lai_growth_rate = 0.0_real64 ! RGRLAI
  end type wofost_rate_scalar_parameters_t

  ! Construction DTO holding already-qualified F-WOF29 compact tables.
  type, public :: wofost_rate_parameter_tables_t
    type(wofost_rate_table_t) :: temperature_sum_increment         ! DTSMTB
    type(wofost_rate_table_t) :: maximum_assimilation              ! AMAXTB
    type(wofost_rate_table_t) :: daytime_temperature_factor        ! TMPFTB
    type(wofost_rate_table_t) :: minimum_temperature_factor        ! TMNFTB
    type(wofost_rate_table_t) :: maintenance_respiration_factor    ! RFSETB
    type(wofost_rate_table_t) :: root_partition_fraction           ! FRTB
    type(wofost_rate_table_t) :: leaf_partition_fraction           ! FLTB
    type(wofost_rate_table_t) :: stem_partition_fraction           ! FSTB
    type(wofost_rate_table_t) :: storage_partition_fraction        ! FOTB
    type(wofost_rate_table_t) :: relative_root_death_rate          ! RDRRTB
    type(wofost_rate_table_t) :: relative_stem_death_rate          ! RDRSTB
    type(wofost_rate_table_t) :: specific_leaf_area                ! SLATB
  end type wofost_rate_parameter_tables_t

  type, public :: wofost_rate_parameter_bundle_t
    private
    logical :: initialized = .false.
    type(wofost_rate_scalar_parameters_t) :: scalars
    type(wofost_rate_parameter_tables_t) :: tables
  contains
    procedure, public :: ready => wofost_rate_parameter_bundle_ready
    procedure, public :: scalar_view => wofost_rate_parameter_bundle_scalar_view
    procedure, public :: evaluate_temperature_sum_increment
    procedure, public :: evaluate_maximum_assimilation
    procedure, public :: evaluate_daytime_temperature_factor
    procedure, public :: evaluate_minimum_temperature_factor
    procedure, public :: evaluate_maintenance_respiration_factor
    procedure, public :: evaluate_root_partition_fraction
    procedure, public :: evaluate_leaf_partition_fraction
    procedure, public :: evaluate_stem_partition_fraction
    procedure, public :: evaluate_storage_partition_fraction
    procedure, public :: evaluate_relative_root_death_rate
    procedure, public :: evaluate_relative_stem_death_rate
    procedure, public :: evaluate_specific_leaf_area
  end type wofost_rate_parameter_bundle_t

  public :: construct_wofost_rate_parameter_bundle

contains

  subroutine construct_wofost_rate_parameter_bundle(scalars, tables, bundle, status)
    type(wofost_rate_scalar_parameters_t), intent(in) :: scalars
    type(wofost_rate_parameter_tables_t), intent(in) :: tables
    type(wofost_rate_parameter_bundle_t), intent(out) :: bundle
    integer, intent(out) :: status

    bundle = wofost_rate_parameter_bundle_t()
    status = validate_scalar_parameters(scalars)
    if (status /= WOFOST_RATE_PARAMETER_OK) return

    if (.not. all_parameter_tables_ready(tables)) then
      status = WOFOST_RATE_PARAMETER_INVALID_TABLE
      return
    end if

    bundle%scalars = scalars
    if (bundle%scalars%development_daylength_mode == 0) then
      ! DLO/DLC are inactive for IDSL=0. Canonicalize them rather than
      ! retaining irrelevant parser-era values in the shared parameter object.
      bundle%scalars%daylength_upper_hours = 0.0_real64
      bundle%scalars%daylength_lower_hours = 0.0_real64
    end if
    bundle%tables = tables
    bundle%initialized = .true.
    status = WOFOST_RATE_PARAMETER_OK
  end subroutine construct_wofost_rate_parameter_bundle

  logical function wofost_rate_parameter_bundle_ready(self) result(ready)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self

    ready = .false.
    if (.not. self%initialized) return
    if (validate_scalar_parameters(self%scalars) /= WOFOST_RATE_PARAMETER_OK) return
    if (.not. all_parameter_tables_ready(self%tables)) return
    ready = .true.
  end function wofost_rate_parameter_bundle_ready

  function wofost_rate_parameter_bundle_scalar_view(self) result(scalars)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    type(wofost_rate_scalar_parameters_t) :: scalars

    scalars = wofost_rate_scalar_parameters_t()
    if (.not. self%ready()) return
    scalars = self%scalars
  end function wofost_rate_parameter_bundle_scalar_view

  integer function validate_scalar_parameters(scalars) result(status)
    type(wofost_rate_scalar_parameters_t), intent(in) :: scalars

    status = WOFOST_RATE_PARAMETER_INVALID_SCALAR

    if (scalars%development_daylength_mode /= 0 .and. &
        scalars%development_daylength_mode /= 1) then
      status = WOFOST_RATE_PARAMETER_INVALID_IDSL
      return
    end if

    if (scalars%development_daylength_mode == 1) then
      if (.not. valid_inclusive(scalars%daylength_upper_hours, 0.0_real64, 24.0_real64)) then
        status = WOFOST_RATE_PARAMETER_INVALID_PHOTOPERIOD
        return
      end if
      if (.not. valid_inclusive(scalars%daylength_lower_hours, 0.0_real64, 24.0_real64)) then
        status = WOFOST_RATE_PARAMETER_INVALID_PHOTOPERIOD
        return
      end if
      if (scalars%daylength_upper_hours <= scalars%daylength_lower_hours) then
        status = WOFOST_RATE_PARAMETER_INVALID_PHOTOPERIOD
        return
      end if
    end if

    if (.not. valid_positive_to(scalars%vegetative_temperature_sum_required, 10000.0_real64)) return
    if (.not. valid_positive_to(scalars%generative_temperature_sum_required, 10000.0_real64)) return
    if (.not. valid_positive_to(scalars%diffuse_extinction_coefficient, 2.0_real64)) return
    if (.not. valid_inclusive(scalars%initial_light_use_efficiency, 0.0_real64, 10.0_real64)) return
    if (.not. valid_positive_to(scalars%co2_to_dry_matter_fraction, 1.0_real64)) return
    if (.not. valid_inclusive(scalars%attainable_yield_multiplier, 0.0_real64, 1.0_real64)) return
    if (.not. valid_positive_to(scalars%conversion_efficiency_root, 1.0_real64)) return
    if (.not. valid_positive_to(scalars%conversion_efficiency_stem, 1.0_real64)) return
    if (.not. valid_positive_to(scalars%conversion_efficiency_leaf, 1.0_real64)) return
    if (.not. valid_inclusive(scalars%conversion_efficiency_storage, 0.0_real64, 1.0_real64)) return
    if (.not. valid_positive_to(scalars%respiration_temperature_q10, 5.0_real64)) return
    if (.not. valid_inclusive(scalars%maintenance_respiration_root, 0.0_real64, 1.0_real64)) return
    if (.not. valid_inclusive(scalars%maintenance_respiration_leaf, 0.0_real64, 1.0_real64)) return
    if (.not. valid_inclusive(scalars%maintenance_respiration_stem, 0.0_real64, 1.0_real64)) return
    if (.not. valid_inclusive(scalars%maintenance_respiration_storage, 0.0_real64, 1.0_real64)) return
    if (.not. valid_inclusive(scalars%maximum_leaf_relative_death_rate, 0.0_real64, 3.0_real64)) return
    if (.not. valid_inclusive(scalars%leaf_age_base_temperature, -10.0_real64, 30.0_real64)) return
    if (.not. valid_inclusive(scalars%maximum_relative_lai_growth_rate, 0.0_real64, 1.0_real64)) return

    status = WOFOST_RATE_PARAMETER_OK
  end function validate_scalar_parameters

  logical function all_parameter_tables_ready(tables) result(ready)
    type(wofost_rate_parameter_tables_t), intent(in) :: tables

    ready = .false.
    if (.not. tables%temperature_sum_increment%ready()) return
    if (.not. tables%maximum_assimilation%ready()) return
    if (.not. tables%daytime_temperature_factor%ready()) return
    if (.not. tables%minimum_temperature_factor%ready()) return
    if (.not. tables%maintenance_respiration_factor%ready()) return
    if (.not. tables%root_partition_fraction%ready()) return
    if (.not. tables%leaf_partition_fraction%ready()) return
    if (.not. tables%stem_partition_fraction%ready()) return
    if (.not. tables%storage_partition_fraction%ready()) return
    if (.not. tables%relative_root_death_rate%ready()) return
    if (.not. tables%relative_stem_death_rate%ready()) return
    if (.not. tables%specific_leaf_area%ready()) return
    ready = .true.
  end function all_parameter_tables_ready

  pure logical function valid_inclusive(value, lower, upper) result(valid)
    real(real64), intent(in) :: value, lower, upper

    valid = .false.
    if (.not. ieee_is_finite(value)) return
    valid = value >= lower .and. value <= upper
  end function valid_inclusive

  pure logical function valid_positive_to(value, upper) result(valid)
    real(real64), intent(in) :: value, upper

    valid = .false.
    if (.not. ieee_is_finite(value)) return
    valid = value > 0.0_real64 .and. value <= upper
  end function valid_positive_to

  subroutine evaluate_parameter_table(self, table, query_x, value_y, status)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    type(wofost_rate_table_t), intent(in) :: table
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    integer :: table_status

    value_y = 0.0_real64
    status = WOFOST_RATE_PARAMETER_INVALID_BUNDLE
    if (.not. self%ready()) return

    call table%evaluate(query_x, value_y, table_status)
    if (table_status == WOFOST_RATE_TABLE_OK) then
      status = WOFOST_RATE_PARAMETER_OK
    else if (table_status == WOFOST_RATE_TABLE_INVALID_QUERY) then
      status = WOFOST_RATE_PARAMETER_INVALID_QUERY
    else
      status = WOFOST_RATE_PARAMETER_INVALID_TABLE
    end if
  end subroutine evaluate_parameter_table

  subroutine evaluate_temperature_sum_increment(self, query_x, value_y, status)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    call evaluate_parameter_table(self, self%tables%temperature_sum_increment, query_x, value_y, status)
  end subroutine evaluate_temperature_sum_increment

  subroutine evaluate_maximum_assimilation(self, query_x, value_y, status)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    call evaluate_parameter_table(self, self%tables%maximum_assimilation, query_x, value_y, status)
  end subroutine evaluate_maximum_assimilation

  subroutine evaluate_daytime_temperature_factor(self, query_x, value_y, status)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    call evaluate_parameter_table(self, self%tables%daytime_temperature_factor, query_x, value_y, status)
  end subroutine evaluate_daytime_temperature_factor

  subroutine evaluate_minimum_temperature_factor(self, query_x, value_y, status)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    call evaluate_parameter_table(self, self%tables%minimum_temperature_factor, query_x, value_y, status)
  end subroutine evaluate_minimum_temperature_factor

  subroutine evaluate_maintenance_respiration_factor(self, query_x, value_y, status)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    call evaluate_parameter_table(self, self%tables%maintenance_respiration_factor, query_x, value_y, status)
  end subroutine evaluate_maintenance_respiration_factor

  subroutine evaluate_root_partition_fraction(self, query_x, value_y, status)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    call evaluate_parameter_table(self, self%tables%root_partition_fraction, query_x, value_y, status)
  end subroutine evaluate_root_partition_fraction

  subroutine evaluate_leaf_partition_fraction(self, query_x, value_y, status)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    call evaluate_parameter_table(self, self%tables%leaf_partition_fraction, query_x, value_y, status)
  end subroutine evaluate_leaf_partition_fraction

  subroutine evaluate_stem_partition_fraction(self, query_x, value_y, status)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    call evaluate_parameter_table(self, self%tables%stem_partition_fraction, query_x, value_y, status)
  end subroutine evaluate_stem_partition_fraction

  subroutine evaluate_storage_partition_fraction(self, query_x, value_y, status)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    call evaluate_parameter_table(self, self%tables%storage_partition_fraction, query_x, value_y, status)
  end subroutine evaluate_storage_partition_fraction

  subroutine evaluate_relative_root_death_rate(self, query_x, value_y, status)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    call evaluate_parameter_table(self, self%tables%relative_root_death_rate, query_x, value_y, status)
  end subroutine evaluate_relative_root_death_rate

  subroutine evaluate_relative_stem_death_rate(self, query_x, value_y, status)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    call evaluate_parameter_table(self, self%tables%relative_stem_death_rate, query_x, value_y, status)
  end subroutine evaluate_relative_stem_death_rate

  subroutine evaluate_specific_leaf_area(self, query_x, value_y, status)
    class(wofost_rate_parameter_bundle_t), intent(in) :: self
    real(real64), intent(in) :: query_x
    real(real64), intent(out) :: value_y
    integer, intent(out) :: status
    call evaluate_parameter_table(self, self%tables%specific_leaf_area, query_x, value_y, status)
  end subroutine evaluate_specific_leaf_area

end module mod_wofost_rate_parameters
