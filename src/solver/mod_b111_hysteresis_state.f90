module mod_b111_hysteresis_state
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: B111_HYST_OK = 0
  integer, parameter, public :: B111_HYST_INVALID = 1
  integer, parameter, public :: B111_HYST_WETTING = 1
  integer, parameter, public :: B111_HYST_DRYING = -1

  type, public :: b111_hysteresis_parameters_t
    integer :: active_nodes = 0
    real(real64), allocatable :: theta_r(:), theta_s(:)
    real(real64), allocatable :: alpha_dry(:), alpha_wet(:)
    real(real64), allocatable :: n(:), m(:), tau(:)
  end type b111_hysteresis_parameters_t

  type, public :: b111_hysteresis_state_t
    integer :: active_nodes = 0
    integer, allocatable :: branch(:)
    real(real64), allocatable :: theta_r_scan(:), theta_s_scan(:), alpha_active(:)
    real(real64), allocatable :: accepted_head(:), accepted_theta(:)
  end type b111_hysteresis_state_t

  type, public :: b111_hysteresis_transition_t
    logical :: reversed = .false.
    logical :: head_reconstruction_required = .false.
    real(real64) :: corrected_head = 0.0_real64
  end type b111_hysteresis_transition_t

  public :: initialize_b111_hysteresis
  public :: initialize_b111_hysteresis_state
  public :: advance_b111_hysteresis_accepted

contains

  subroutine initialize_b111_hysteresis(parameters, theta_r, theta_s, alpha_dry, alpha_wet, n, tau, status)
    type(b111_hysteresis_parameters_t), intent(out) :: parameters
    real(real64), intent(in) :: theta_r(:), theta_s(:), alpha_dry(:), alpha_wet(:), n(:), tau(:)
    integer, intent(out) :: status
    integer :: nn

    status = B111_HYST_INVALID
    nn = size(theta_r)
    if (nn <= 0) return
    if (size(theta_s) /= nn .or. size(alpha_dry) /= nn .or. size(alpha_wet) /= nn .or. &
        size(n) /= nn .or. size(tau) /= nn) return
    if (any(.not. ieee_is_finite(theta_r)) .or. any(.not. ieee_is_finite(theta_s)) .or. &
        any(.not. ieee_is_finite(alpha_dry)) .or. any(.not. ieee_is_finite(alpha_wet)) .or. &
        any(.not. ieee_is_finite(n)) .or. any(.not. ieee_is_finite(tau))) return
    if (any(theta_s <= theta_r) .or. any(alpha_dry <= 0.0_real64) .or. any(alpha_wet <= 0.0_real64) .or. &
        any(n <= 1.0_real64) .or. any(tau < 0.0_real64)) return

    parameters%active_nodes = nn
    allocate(parameters%theta_r(nn), parameters%theta_s(nn), parameters%alpha_dry(nn), parameters%alpha_wet(nn), &
             parameters%n(nn), parameters%m(nn), parameters%tau(nn))
    parameters%theta_r = theta_r
    parameters%theta_s = theta_s
    parameters%alpha_dry = alpha_dry
    parameters%alpha_wet = alpha_wet
    parameters%n = n
    parameters%m = 1.0_real64 - 1.0_real64/n
    parameters%tau = tau
    status = B111_HYST_OK
  end subroutine initialize_b111_hysteresis

  subroutine initialize_b111_hysteresis_state(parameters, mode, head, theta, state, status)
    type(b111_hysteresis_parameters_t), intent(in) :: parameters
    integer, intent(in) :: mode
    real(real64), intent(in) :: head(:), theta(:)
    type(b111_hysteresis_state_t), intent(out) :: state
    integer, intent(out) :: status
    integer :: nn

    status = B111_HYST_INVALID
    nn = parameters%active_nodes
    if ((mode /= 1 .and. mode /= 2) .or. nn <= 0 .or. size(head) /= nn .or. size(theta) /= nn) return
    if (any(.not. ieee_is_finite(head)) .or. any(.not. ieee_is_finite(theta))) return

    state%active_nodes = nn
    allocate(state%branch(nn), state%theta_r_scan(nn), state%theta_s_scan(nn), state%alpha_active(nn), &
             state%accepted_head(nn), state%accepted_theta(nn))
    state%theta_r_scan = parameters%theta_r
    state%theta_s_scan = parameters%theta_s
    state%accepted_head = head
    state%accepted_theta = theta
    if (mode == 1) then
      state%branch = B111_HYST_WETTING
      state%alpha_active = parameters%alpha_wet
    else
      state%branch = B111_HYST_DRYING
      state%alpha_active = parameters%alpha_dry
    end if
    status = B111_HYST_OK
  end subroutine initialize_b111_hysteresis_state

  subroutine advance_b111_hysteresis_accepted(parameters, state, new_head, new_theta, transition, status)
    type(b111_hysteresis_parameters_t), intent(in) :: parameters
    type(b111_hysteresis_state_t), intent(inout) :: state
    real(real64), intent(in) :: new_head(:), new_theta(:)
    type(b111_hysteresis_transition_t), intent(out) :: transition(:)
    integer, intent(out) :: status
    integer :: i, nn, newbranch
    real(real64) :: delp, sew, sed, fvalue, tr, ts, alpha, hcorr

    status = B111_HYST_INVALID
    nn = parameters%active_nodes
    if (state%active_nodes /= nn .or. size(new_head) /= nn .or. size(new_theta) /= nn .or. size(transition) /= nn) return
    if (any(.not. ieee_is_finite(new_head)) .or. any(.not. ieee_is_finite(new_theta))) return

    transition = b111_hysteresis_transition_t()
    do i = 1, nn
      delp = state%accepted_head(i) - new_head(i)
      newbranch = state%branch(i)
      if (delp/real(state%branch(i),real64) > parameters%tau(i) .and. &
          new_head(i) < -10.0_real64 .and. new_head(i) > -1000.0_real64) newbranch = -state%branch(i)

      if (newbranch /= state%branch(i) .and. &
          abs(parameters%alpha_dry(i)-parameters%alpha_wet(i)) >= 1.0e-4_real64) then
        sew = (1.0_real64 + (parameters%alpha_wet(i)*(-new_head(i)))**parameters%n(i))**(-parameters%m(i))
        sed = (1.0_real64 + (parameters%alpha_dry(i)*(-new_head(i)))**parameters%n(i))**(-parameters%m(i))
        transition(i)%reversed = .true.
        state%branch(i) = newbranch

        if (newbranch == B111_HYST_WETTING) then
          alpha = parameters%alpha_wet(i)
          ts = parameters%theta_s(i)
          fvalue = (new_theta(i)-ts*sew)/(1.0_real64-sew)
          tr = max(parameters%theta_r(i), min(parameters%theta_s(i), fvalue))
          state%theta_r_scan(i) = tr
          state%theta_s_scan(i) = ts
          state%alpha_active(i) = alpha
          if (abs(fvalue-tr) > 1.0e-10_real64) then
            hcorr = inverse_mvg(new_theta(i),tr,ts,alpha,parameters%n(i),parameters%m(i))
            transition(i)%head_reconstruction_required = .true.
            transition(i)%corrected_head = hcorr
          end if
        else
          alpha = parameters%alpha_dry(i)
          tr = parameters%theta_r(i)
          fvalue = tr + (new_theta(i)-tr)/sed
          ts = max(parameters%theta_r(i), min(parameters%theta_s(i), fvalue))
          state%theta_r_scan(i) = tr
          state%theta_s_scan(i) = ts
          state%alpha_active(i) = alpha
          if (abs(fvalue-ts) > 1.0e-10_real64) then
            hcorr = inverse_mvg(new_theta(i),tr,ts,alpha,parameters%n(i),parameters%m(i))
            transition(i)%head_reconstruction_required = .true.
            transition(i)%corrected_head = hcorr
          end if
        end if
      end if

      if (transition(i)%head_reconstruction_required) then
        state%accepted_head(i) = transition(i)%corrected_head
      else
        state%accepted_head(i) = new_head(i)
      end if
      state%accepted_theta(i) = new_theta(i)
    end do
    status = B111_HYST_OK
  end subroutine advance_b111_hysteresis_accepted

  pure real(real64) function inverse_mvg(theta, tr, ts, alpha, n, m) result(h)
    real(real64), intent(in) :: theta, tr, ts, alpha, n, m
    real(real64) :: se
    if (theta <= tr) then
      h = -huge(1.0_real64)
      return
    end if
    if (theta >= ts) then
      h = 0.0_real64
      return
    end if
    se = (theta-tr)/(ts-tr)
    h = -((se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/n))/alpha
  end function inverse_mvg

end module mod_b111_hysteresis_state
