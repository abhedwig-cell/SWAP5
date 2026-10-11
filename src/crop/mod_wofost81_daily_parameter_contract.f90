module mod_wofost81_daily_parameter_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_rate_table, only: wofost_rate_table_t, WOFOST_RATE_TABLE_OK
  use mod_wofost81_parameter_contract, only: wofost81_parameter_contract_t, WOFOST81_PARAMETER_OK
  implicit none
  private

  integer, parameter, public :: WOFOST81_DAILY_PARAMETER_OK = 0
  integer, parameter, public :: WOFOST81_DAILY_PARAMETER_INVALID_BASE = 1
  integer, parameter, public :: WOFOST81_DAILY_PARAMETER_INVALID_TABLE = 2
  integer, parameter, public :: WOFOST81_DAILY_PARAMETER_INVALID_QUERY = 3
  integer, parameter, public :: WOFOST81_DAILY_PARAMETER_INVALID_RESULT = 4

  type, public :: wofost81_daily_parameter_tables_t
    type(wofost_rate_table_t) :: light_use_efficiency          ! EFFTB(TAVD)
    type(wofost_rate_table_t) :: diffuse_extinction_coefficient ! KDIFTB(DVS)
    type(wofost_rate_table_t) :: maximum_leaf_n_concentration   ! NMAXLV_TB(DVS)
    type(wofost_rate_table_t) :: leaf_ageing_n_stress_multiplier ! NSLLV_TB(stress index)
  contains
    procedure, public :: validate => validate_daily_tables
  end type wofost81_daily_parameter_tables_t

  type, public :: wofost81_daily_parameter_contract_t
    type(wofost81_parameter_contract_t) :: base
    type(wofost81_daily_parameter_tables_t) :: tables
  contains
    procedure, public :: validate => validate_daily_contract
    procedure, public :: evaluate_light_use_efficiency
    procedure, public :: evaluate_diffuse_extinction_coefficient
    procedure, public :: evaluate_maximum_leaf_n_concentration
    procedure, public :: evaluate_leaf_ageing_n_stress_multiplier
  end type wofost81_daily_parameter_contract_t

contains

  integer function validate_daily_tables(self) result(status)
    class(wofost81_daily_parameter_tables_t), intent(in) :: self
    status = WOFOST81_DAILY_PARAMETER_INVALID_TABLE
    if (.not. self%light_use_efficiency%ready()) return
    if (.not. self%diffuse_extinction_coefficient%ready()) return
    if (.not. self%maximum_leaf_n_concentration%ready()) return
    if (.not. self%leaf_ageing_n_stress_multiplier%ready()) return
    status = WOFOST81_DAILY_PARAMETER_OK
  end function validate_daily_tables

  integer function validate_daily_contract(self) result(status)
    class(wofost81_daily_parameter_contract_t), intent(in) :: self
    status = WOFOST81_DAILY_PARAMETER_INVALID_BASE
    if (self%base%validate() /= WOFOST81_PARAMETER_OK) return
    status = self%tables%validate()
  end function validate_daily_contract

  subroutine evaluate_light_use_efficiency(self, query, value, status)
    class(wofost81_daily_parameter_contract_t), intent(in) :: self
    real(real64), intent(in) :: query
    real(real64), intent(out) :: value
    integer, intent(out) :: status
    call evaluate_table(self, self%tables%light_use_efficiency, query, value, .false., status)
  end subroutine evaluate_light_use_efficiency

  subroutine evaluate_diffuse_extinction_coefficient(self, query, value, status)
    class(wofost81_daily_parameter_contract_t), intent(in) :: self
    real(real64), intent(in) :: query
    real(real64), intent(out) :: value
    integer, intent(out) :: status
    call evaluate_table(self, self%tables%diffuse_extinction_coefficient, query, value, .true., status)
  end subroutine evaluate_diffuse_extinction_coefficient

  subroutine evaluate_maximum_leaf_n_concentration(self, query, value, status)
    class(wofost81_daily_parameter_contract_t), intent(in) :: self
    real(real64), intent(in) :: query
    real(real64), intent(out) :: value
    integer, intent(out) :: status
    call evaluate_table(self, self%tables%maximum_leaf_n_concentration, query, value, .true., status)
  end subroutine evaluate_maximum_leaf_n_concentration

  subroutine evaluate_leaf_ageing_n_stress_multiplier(self, query, value, status)
    class(wofost81_daily_parameter_contract_t), intent(in) :: self
    real(real64), intent(in) :: query
    real(real64), intent(out) :: value
    integer, intent(out) :: status
    call evaluate_table(self, self%tables%leaf_ageing_n_stress_multiplier, query, value, .false., status)
  end subroutine evaluate_leaf_ageing_n_stress_multiplier

  subroutine evaluate_table(self, table, query, value, require_positive, status)
    class(wofost81_daily_parameter_contract_t), intent(in) :: self
    type(wofost_rate_table_t), intent(in) :: table
    real(real64), intent(in) :: query
    real(real64), intent(out) :: value
    logical, intent(in) :: require_positive
    integer, intent(out) :: status
    integer :: table_status

    value = 0.0_real64
    status = WOFOST81_DAILY_PARAMETER_INVALID_BASE
    if (self%base%validate() /= WOFOST81_PARAMETER_OK) return
    status = WOFOST81_DAILY_PARAMETER_INVALID_TABLE
    if (.not. table%ready()) return
    status = WOFOST81_DAILY_PARAMETER_INVALID_QUERY
    if (.not. ieee_is_finite(query)) return
    call table%evaluate(query, value, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK) then
      value = 0.0_real64
      return
    end if
    status = WOFOST81_DAILY_PARAMETER_INVALID_RESULT
    if (.not. ieee_is_finite(value)) then
      value = 0.0_real64
      return
    end if
    if (require_positive) then
      if (value <= 0.0_real64) then
        value = 0.0_real64
        return
      end if
    else
      if (value < 0.0_real64) then
        value = 0.0_real64
        return
      end if
    end if
    status = WOFOST81_DAILY_PARAMETER_OK
  end subroutine evaluate_table

end module mod_wofost81_daily_parameter_contract
