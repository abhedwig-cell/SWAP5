module mod_groundwater_coupling_contract
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  private

  real(real64), parameter :: CM_TO_M = 0.01_real64
  real(real64), parameter :: M_TO_CM = 100.0_real64
  real(real64), parameter :: DAY_TO_S = 86400.0_real64

  integer, parameter, public :: GW_INTERFACE_OK = 0
  integer, parameter, public :: GW_INTERFACE_INVALID_WINDOW = 1
  integer, parameter, public :: GW_INTERFACE_INVALID_DATUM = 2
  integer, parameter, public :: GW_INTERFACE_INVALID_HEAD = 3
  integer, parameter, public :: GW_INTERFACE_INVALID_FLUX = 4
  integer, parameter, public :: GW_INTERFACE_INVALID_LINEAGE = 5

  ! Canonical coupling time coordinates. Their physical calendar interpretation is
  ! owned by the caller; this contract requires only a finite, increasing window.
  type, public :: groundwater_coupling_window_t
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
  contains
    procedure :: valid => groundwater_window_valid
  end type groundwater_coupling_window_t

  ! SWAP mode 5 prescribes pressure head at the lower boundary face. Groundwater
  ! coupling uses hydraulic head. The common datum and lower-face elevation are
  ! therefore mandatory inputs to H = z + psi; pressure head is never silently
  ! reinterpreted as hydraulic head.
  type, public :: groundwater_head_datum_t
    logical :: available = .false.
    integer(int64) :: datum_id = 0_int64
    real(real64) :: bottom_boundary_elevation_m = 0.0_real64
  contains
    procedure :: valid => groundwater_datum_valid
  end type groundwater_head_datum_t

  type, public :: groundwater_interface_lineage_t
    integer(int64) :: coupling_id = 0_int64
    integer(int64) :: swap_lineage_id = 0_int64
    integer(int64) :: swap_origin_revision = -1_int64
    integer(int64) :: groundwater_lineage_id = 0_int64
    integer(int64) :: groundwater_origin_revision = -1_int64
    integer(int64) :: candidate_revision = -1_int64
  contains
    procedure :: valid => groundwater_lineage_valid
  end type groundwater_interface_lineage_t

  ! Interface convention inherited from F-GC01:
  !   q_swap > 0         water leaves SWAP through the bottom interface
  !   q_groundwater > 0  water leaves groundwater through the same interface
  ! so exact action/reaction is q_groundwater = -q_swap.
  type, public :: groundwater_interface_state_t
    real(real64) :: h_swap_m = 0.0_real64
    real(real64) :: h_groundwater_m = 0.0_real64
    real(real64) :: q_swap_m_per_s = 0.0_real64
    real(real64) :: q_groundwater_m_per_s = 0.0_real64
  contains
    procedure :: finite => groundwater_interface_state_finite
  end type groundwater_interface_state_t

  type, public :: groundwater_interface_residual_t
    real(real64) :: head_residual_m = 0.0_real64
    real(real64) :: flux_residual_m_per_s = 0.0_real64
  end type groundwater_interface_residual_t

  public :: swap_bottom_pressure_head_cm_to_interface_head_m
  public :: interface_head_m_to_swap_bottom_pressure_head_cm
  public :: swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s
  public :: interface_flux_m_per_s_to_swap_bottom_flux_cm_per_day
  public :: pair_groundwater_flux_from_swap
  public :: evaluate_groundwater_interface_residual

contains

  pure logical function groundwater_window_valid(self)
    class(groundwater_coupling_window_t), intent(in) :: self

    groundwater_window_valid = .false.
    if (.not. ieee_is_finite(self%t0)) return
    if (.not. ieee_is_finite(self%t1)) return
    if (self%t1 <= self%t0) return
    groundwater_window_valid = .true.
  end function groundwater_window_valid

  pure logical function groundwater_datum_valid(self)
    class(groundwater_head_datum_t), intent(in) :: self

    groundwater_datum_valid = .false.
    if (.not. self%available) return
    if (self%datum_id <= 0_int64) return
    if (.not. ieee_is_finite(self%bottom_boundary_elevation_m)) return
    groundwater_datum_valid = .true.
  end function groundwater_datum_valid

  pure logical function groundwater_lineage_valid(self)
    class(groundwater_interface_lineage_t), intent(in) :: self

    groundwater_lineage_valid = .false.
    if (self%coupling_id <= 0_int64) return
    if (self%swap_lineage_id <= 0_int64) return
    if (self%swap_origin_revision < 0_int64) return
    if (self%groundwater_lineage_id <= 0_int64) return
    if (self%groundwater_origin_revision < 0_int64) return
    if (self%candidate_revision < 0_int64) return
    groundwater_lineage_valid = .true.
  end function groundwater_lineage_valid

  pure logical function groundwater_interface_state_finite(self)
    class(groundwater_interface_state_t), intent(in) :: self

    groundwater_interface_state_finite = .false.
    if (.not. ieee_is_finite(self%h_swap_m)) return
    if (.not. ieee_is_finite(self%h_groundwater_m)) return
    if (.not. ieee_is_finite(self%q_swap_m_per_s)) return
    if (.not. ieee_is_finite(self%q_groundwater_m_per_s)) return
    groundwater_interface_state_finite = .true.
  end function groundwater_interface_state_finite

  pure subroutine swap_bottom_pressure_head_cm_to_interface_head_m(pressure_head_cm, datum, head_m, status)
    real(real64), intent(in) :: pressure_head_cm
    type(groundwater_head_datum_t), intent(in) :: datum
    real(real64), intent(out) :: head_m
    integer, intent(out) :: status

    head_m = 0.0_real64
    status = GW_INTERFACE_INVALID_HEAD
    if (.not. datum%valid()) then
      status = GW_INTERFACE_INVALID_DATUM
      return
    end if
    if (.not. ieee_is_finite(pressure_head_cm)) return
    head_m = datum%bottom_boundary_elevation_m + pressure_head_cm * CM_TO_M
    if (.not. ieee_is_finite(head_m)) then
      head_m = 0.0_real64
      return
    end if
    status = GW_INTERFACE_OK
  end subroutine swap_bottom_pressure_head_cm_to_interface_head_m

  pure subroutine interface_head_m_to_swap_bottom_pressure_head_cm(head_m, datum, pressure_head_cm, status)
    real(real64), intent(in) :: head_m
    type(groundwater_head_datum_t), intent(in) :: datum
    real(real64), intent(out) :: pressure_head_cm
    integer, intent(out) :: status

    pressure_head_cm = 0.0_real64
    status = GW_INTERFACE_INVALID_HEAD
    if (.not. datum%valid()) then
      status = GW_INTERFACE_INVALID_DATUM
      return
    end if
    if (.not. ieee_is_finite(head_m)) return
    pressure_head_cm = (head_m - datum%bottom_boundary_elevation_m) * M_TO_CM
    if (.not. ieee_is_finite(pressure_head_cm)) then
      pressure_head_cm = 0.0_real64
      return
    end if
    status = GW_INTERFACE_OK
  end subroutine interface_head_m_to_swap_bottom_pressure_head_cm

  pure subroutine swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(qbot_cm_per_day, q_swap_m_per_s, status)
    real(real64), intent(in) :: qbot_cm_per_day
    real(real64), intent(out) :: q_swap_m_per_s
    integer, intent(out) :: status

    q_swap_m_per_s = 0.0_real64
    status = GW_INTERFACE_INVALID_FLUX
    if (.not. ieee_is_finite(qbot_cm_per_day)) return

    ! Native SWAP qbot is positive into the SWAP soil profile. The public
    ! groundwater interface uses the opposite outward-from-SWAP convention.
    q_swap_m_per_s = -qbot_cm_per_day * CM_TO_M / DAY_TO_S
    if (.not. ieee_is_finite(q_swap_m_per_s)) then
      q_swap_m_per_s = 0.0_real64
      return
    end if
    status = GW_INTERFACE_OK
  end subroutine swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s

  pure subroutine interface_flux_m_per_s_to_swap_bottom_flux_cm_per_day(q_swap_m_per_s, qbot_cm_per_day, status)
    real(real64), intent(in) :: q_swap_m_per_s
    real(real64), intent(out) :: qbot_cm_per_day
    integer, intent(out) :: status

    qbot_cm_per_day = 0.0_real64
    status = GW_INTERFACE_INVALID_FLUX
    if (.not. ieee_is_finite(q_swap_m_per_s)) return
    qbot_cm_per_day = -q_swap_m_per_s * DAY_TO_S * M_TO_CM
    if (.not. ieee_is_finite(qbot_cm_per_day)) then
      qbot_cm_per_day = 0.0_real64
      return
    end if
    status = GW_INTERFACE_OK
  end subroutine interface_flux_m_per_s_to_swap_bottom_flux_cm_per_day

  pure subroutine pair_groundwater_flux_from_swap(q_swap_m_per_s, q_groundwater_m_per_s, status)
    real(real64), intent(in) :: q_swap_m_per_s
    real(real64), intent(out) :: q_groundwater_m_per_s
    integer, intent(out) :: status

    q_groundwater_m_per_s = 0.0_real64
    status = GW_INTERFACE_INVALID_FLUX
    if (.not. ieee_is_finite(q_swap_m_per_s)) return
    q_groundwater_m_per_s = -q_swap_m_per_s
    status = GW_INTERFACE_OK
  end subroutine pair_groundwater_flux_from_swap

  pure subroutine evaluate_groundwater_interface_residual(state, residual, status)
    type(groundwater_interface_state_t), intent(in) :: state
    type(groundwater_interface_residual_t), intent(out) :: residual
    integer, intent(out) :: status

    residual = groundwater_interface_residual_t()
    status = GW_INTERFACE_INVALID_HEAD
    if (.not. state%finite()) return
    residual%head_residual_m = state%h_swap_m - state%h_groundwater_m
    residual%flux_residual_m_per_s = state%q_swap_m_per_s + state%q_groundwater_m_per_s
    if (.not. ieee_is_finite(residual%head_residual_m)) then
      residual = groundwater_interface_residual_t()
      return
    end if
    if (.not. ieee_is_finite(residual%flux_residual_m_per_s)) then
      residual = groundwater_interface_residual_t()
      status = GW_INTERFACE_INVALID_FLUX
      return
    end if
    status = GW_INTERFACE_OK
  end subroutine evaluate_groundwater_interface_residual

end module mod_groundwater_coupling_contract
