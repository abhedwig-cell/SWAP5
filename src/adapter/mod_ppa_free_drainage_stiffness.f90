! Candidate service: derivative of the mode-7 residual term -qbot=K(h_N).
! This is not HeadCalc's iteration Jacobian and does not enable any runtime route.
module mod_ppa_free_drainage_stiffness
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t
  use mod_b110_default_mvg_directional_provider, only: evaluate_b110_default_mvg_state_direction
  implicit none
  private
  public :: evaluate_free_drainage_stiffness
contains
  subroutine evaluate_free_drainage_stiffness(provider, heads, stiffness, available)
    type(b110_default_mvg_provider_t), intent(in) :: provider
    real(real64), intent(in) :: heads(:)
    real(real64), intent(out) :: stiffness
    logical, intent(out) :: available
    real(real64), allocatable :: direction(:), water_direction(:), k_direction(:)
    character(len=96) :: route
    integer :: n
    stiffness = 0.0_real64
    available = .false.
    if (.not.associated(provider%parameters)) return
    ! The analytic sibling has no Ksatexm extension derivative contract.
    if (provider%parameters%ksatexm_extension_enabled) return
    n = provider%parameters%active_nodes
    if (n <= 0 .or. size(heads) /= n) return
    if (.not.all(ieee_is_finite(heads))) return
    allocate(direction(n),water_direction(n),k_direction(n))
    direction = 0.0_real64
    direction(n) = 1.0_real64
    call evaluate_b110_default_mvg_state_direction(provider, heads, direction, &
         water_direction, k_direction, available, route)
    if (.not.available) return
    available = ieee_is_finite(k_direction(n))
    if (.not.available) return
    available = k_direction(n) >= 0.0_real64
    if (available) stiffness = k_direction(n)
  end subroutine
end module
