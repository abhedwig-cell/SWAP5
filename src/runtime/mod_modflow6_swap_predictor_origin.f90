module mod_modflow6_swap_predictor_origin
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_groundwater_coupling_contract, only: groundwater_interface_state_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t
  implicit none
  private

  integer, parameter, public :: MODFLOW6_PREDICTOR_ORIGIN_OK = 0
  integer, parameter, public :: MODFLOW6_PREDICTOR_ORIGIN_NOT_COMMITTED = 1
  integer, parameter, public :: MODFLOW6_PREDICTOR_ORIGIN_INVALID_LINEAGE = 2
  integer, parameter, public :: MODFLOW6_PREDICTOR_ORIGIN_INVALID_INTERFACE = 3
  integer, parameter, public :: MODFLOW6_PREDICTOR_ORIGIN_NONCONSERVATIVE_INTERFACE = 4
  integer, parameter, public :: MODFLOW6_PREDICTOR_ORIGIN_INVALID_TIME = 5

  type, public :: modflow6_swap_predictor_origin_t
    integer :: status = MODFLOW6_PREDICTOR_ORIGIN_INVALID_INTERFACE
    logical :: valid = .false.
    real(real64) :: accepted_time = 0.0_real64
    real(real64) :: h_bot_start_m = 0.0_real64
    real(real64) :: accepted_h_groundwater_m = 0.0_real64
    real(real64) :: accepted_head_residual_m = 0.0_real64
    type(modflow6_swap_predictor_lineage_t) :: lineage
    character(len=64) :: head_source = 'not-available'
  contains
    procedure :: structurally_valid => modflow6_predictor_origin_valid
  end type modflow6_swap_predictor_origin_t

  public :: capture_modflow6_swap_predictor_origin

contains

  pure logical function modflow6_predictor_origin_valid(self) result(valid)
    class(modflow6_swap_predictor_origin_t), intent(in) :: self

    valid = self%valid .and. self%status == MODFLOW6_PREDICTOR_ORIGIN_OK
    if (.not. valid) return
    if (.not. ieee_is_finite(self%accepted_time)) then
      valid = .false.
      return
    end if
    if (.not. ieee_is_finite(self%h_bot_start_m) .or. &
        .not. ieee_is_finite(self%accepted_h_groundwater_m) .or. &
        .not. ieee_is_finite(self%accepted_head_residual_m)) then
      valid = .false.
      return
    end if
    valid = self%lineage%valid()
  end function modflow6_predictor_origin_valid

  subroutine capture_modflow6_swap_predictor_origin(accepted_interface, accepted_time, lineage, &
       publication_committed, origin, status)
    type(groundwater_interface_state_t), intent(in) :: accepted_interface
    real(real64), intent(in) :: accepted_time
    type(modflow6_swap_predictor_lineage_t), intent(in) :: lineage
    logical, intent(in) :: publication_committed
    type(modflow6_swap_predictor_origin_t), intent(out) :: origin
    integer, intent(out) :: status

    real(real64) :: flux_residual, flux_scale, flux_floor

    origin = modflow6_swap_predictor_origin_t()

    status = MODFLOW6_PREDICTOR_ORIGIN_NOT_COMMITTED
    if (.not. publication_committed) then
      origin%status = status
      return
    end if

    status = MODFLOW6_PREDICTOR_ORIGIN_INVALID_LINEAGE
    if (.not. lineage%valid()) then
      origin%status = status
      return
    end if

    status = MODFLOW6_PREDICTOR_ORIGIN_INVALID_TIME
    if (.not. ieee_is_finite(accepted_time)) then
      origin%status = status
      return
    end if

    status = MODFLOW6_PREDICTOR_ORIGIN_INVALID_INTERFACE
    if (.not. accepted_interface%finite()) then
      origin%status = status
      return
    end if

    ! Groundwater Coupling v1 requires exact action/reaction before commit. Keep
    ! an epsilon-scale guard here rather than silently accepting unrelated fluxes.
    flux_residual = accepted_interface%q_swap_m_per_s + accepted_interface%q_groundwater_m_per_s
    flux_scale = max(1.0_real64, abs(accepted_interface%q_swap_m_per_s), &
         abs(accepted_interface%q_groundwater_m_per_s))
    flux_floor = 64.0_real64*epsilon(1.0_real64)*flux_scale
    status = MODFLOW6_PREDICTOR_ORIGIN_NONCONSERVATIVE_INTERFACE
    if (.not. ieee_is_finite(flux_residual) .or. abs(flux_residual) > flux_floor) then
      origin%status = status
      return
    end if

    ! Historical H_bot,start is the accepted SWAP head at the fixed coupling
    ! face. The committed groundwater head may differ within the admitted head
    ! convergence tolerance and is retained only as provenance, never substituted.
    origin%accepted_time = accepted_time
    origin%h_bot_start_m = accepted_interface%h_swap_m
    origin%accepted_h_groundwater_m = accepted_interface%h_groundwater_m
    origin%accepted_head_residual_m = accepted_interface%h_swap_m - accepted_interface%h_groundwater_m
    origin%lineage = lineage
    origin%head_source = 'committed-accepted-swap-interface-head'
    origin%status = MODFLOW6_PREDICTOR_ORIGIN_OK
    origin%valid = .true.
    status = MODFLOW6_PREDICTOR_ORIGIN_OK
  end subroutine capture_modflow6_swap_predictor_origin

end module mod_modflow6_swap_predictor_origin
