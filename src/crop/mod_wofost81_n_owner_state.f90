module mod_wofost81_n_owner_state
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use MOD_wofost81_nitrogen, only: WOFOST81_n_state, initialize_wofost81_n_state, WOFN81_OK
  use mod_wofost81_parameter_contract, only: wofost81_nitrogen_parameters_t, WOFOST81_PARAMETER_OK
  implicit none
  private

  integer, parameter, public :: WOFOST81_N_OWNER_OK = 0
  integer, parameter, public :: WOFOST81_N_OWNER_INVALID_PARAMETER = 1
  integer, parameter, public :: WOFOST81_N_OWNER_INVALID_INPUT = 2
  integer, parameter, public :: WOFOST81_N_OWNER_INVALID_STATE = 3
  integer, parameter, public :: WOFOST81_N_OWNER_BALANCE_FAILURE = 4

  type, extends(transaction_state_t), public :: wofost81_n_owner_state_t
    type(WOFOST81_n_state) :: value
  contains
    procedure :: clone => clone_wofost81_n_owner_state
    procedure, public :: validate => validate_wofost81_n_owner_state
  end type wofost81_n_owner_state_t

  public :: initialize_wofost81_n_owner_state

contains

  subroutine clone_wofost81_n_owner_state(self, copy)
    class(wofost81_n_owner_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(wofost81_n_owner_state_t :: copy)
    select type (typed_copy => copy)
    type is (wofost81_n_owner_state_t)
      typed_copy%value = self%value
    class default
      error stop 'WOFOST81 N owner state: clone allocation failure'
    end select
  end subroutine clone_wofost81_n_owner_state

  integer function validate_wofost81_n_owner_state(self) result(status)
    class(wofost81_n_owner_state_t), intent(in) :: self
    real(real64) :: values(8), total_now, residual, scale, tolerance
    values = [self%value%namountlv, self%value%namountst, self%value%namountrt, self%value%namountso, &
              self%value%nuptake_total, self%value%nfix_total, self%value%nlosses_total, self%value%initial_total]
    status = WOFOST81_N_OWNER_INVALID_STATE
    if (.not. all(ieee_is_finite(values))) return
    if (any(values < 0.0_real64)) return
    total_now = sum(values(1:4))
    residual = self%value%initial_total + self%value%nuptake_total + self%value%nfix_total - &
               total_now - self%value%nlosses_total
    scale = max(1.0_real64, self%value%initial_total + self%value%nuptake_total + self%value%nfix_total)
    tolerance = 2048.0_real64 * epsilon(1.0_real64) * scale
    if (abs(residual) > tolerance) then
      status = WOFOST81_N_OWNER_BALANCE_FAILURE
      return
    end if
    status = WOFOST81_N_OWNER_OK
  end function validate_wofost81_n_owner_state

  subroutine initialize_wofost81_n_owner_state(wlv, wst, wrt, nmaxlv, parameters, owner, status)
    real(real64), intent(in) :: wlv, wst, wrt, nmaxlv
    type(wofost81_nitrogen_parameters_t), intent(in) :: parameters
    type(wofost81_n_owner_state_t), intent(out) :: owner
    integer, intent(out) :: status
    integer :: kernel_status

    owner = wofost81_n_owner_state_t()
    if (parameters%validate() /= WOFOST81_PARAMETER_OK) then
      status = WOFOST81_N_OWNER_INVALID_PARAMETER
      return
    end if
    if (.not. all(ieee_is_finite([wlv, wst, wrt, nmaxlv])) .or. &
        any([wlv, wst, wrt, nmaxlv] < 0.0_real64)) then
      status = WOFOST81_N_OWNER_INVALID_INPUT
      return
    end if
    call initialize_wofost81_n_state(wlv, wst, wrt, nmaxlv, parameters%donor_view(), owner%value, kernel_status)
    if (kernel_status /= WOFN81_OK) then
      status = WOFOST81_N_OWNER_INVALID_INPUT
      return
    end if
    status = owner%validate()
  end subroutine initialize_wofost81_n_owner_state

end module mod_wofost81_n_owner_state
