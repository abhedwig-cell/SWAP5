module mod_ppa_low08_lysimeter_active_set
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW08_ACTIVE_OK = 0
  integer, parameter, public :: PPA_LOW08_ACTIVE_INVALID_INPUT = 1
  public :: evaluate_ppa_low08_lysimeter_active_set

contains

  ! Source-shaped SWBOTB=8 HeadCalc active-set decision and bottom row terms.
  ! Task 1 selects flboth strictly; task 2 reuses that decision.
  subroutine evaluate_ppa_low08_lysimeter_active_set(task, swbotb, sw_k_impl, previous_fboth, head, &
      critdz, disnod_bottom, hplate, kmean_bottom, dkdh_bottom, flboth, writes_gradient, hgrad_bottom, &
      writes_hbot, hbot_value, residual_increment, jacobian_increment, status)
    integer, intent(in) :: task, swbotb, sw_k_impl
    logical, intent(in) :: previous_fboth
    real(real64), intent(in) :: head, critdz, disnod_bottom, hplate, kmean_bottom, dkdh_bottom
    logical, intent(out) :: flboth, writes_gradient, writes_hbot
    real(real64), intent(out) :: hgrad_bottom, hbot_value, residual_increment, jacobian_increment
    integer, intent(out) :: status

    flboth = previous_fboth
    writes_gradient = .false.
    writes_hbot = .false.
    hgrad_bottom = 0.0_real64
    hbot_value = 0.0_real64
    residual_increment = 0.0_real64
    jacobian_increment = 0.0_real64
    status = PPA_LOW08_ACTIVE_INVALID_INPUT
    if (task /= 1 .and. task /= 2) return
    if (sw_k_impl < 0 .or. sw_k_impl > 1) return
    if (.not. all(ieee_is_finite([head, critdz, disnod_bottom, hplate, kmean_bottom, dkdh_bottom]))) return
    if (disnod_bottom <= 0.0_real64 .or. kmean_bottom < 0.0_real64) return

    if (task == 1) then
      if (swbotb == 8 .and. head > critdz - disnod_bottom + hplate) then
        flboth = .true.
      else
        flboth = .false.
      end if
    end if

    if (swbotb == 8 .and. flboth) then
      hgrad_bottom = (head - hplate) / disnod_bottom + 1.0_real64
      writes_gradient = .true.
      writes_hbot = .true.
      hbot_value = hplate
      residual_increment = kmean_bottom * hgrad_bottom
      jacobian_increment = kmean_bottom / disnod_bottom
      if (sw_k_impl == 1) jacobian_increment = jacobian_increment + &
          0.5_real64 * dkdh_bottom * hgrad_bottom
      if (.not. all(ieee_is_finite([hgrad_bottom, residual_increment, jacobian_increment]))) then
        flboth = .false.
        writes_gradient = .false.
        writes_hbot = .false.
        hgrad_bottom = 0.0_real64
        hbot_value = 0.0_real64
        residual_increment = 0.0_real64
        jacobian_increment = 0.0_real64
        return
      end if
    end if
    status = PPA_LOW08_ACTIVE_OK
  end subroutine evaluate_ppa_low08_lysimeter_active_set

end module mod_ppa_low08_lysimeter_active_set
