module mod_fmr_tillage_hydraulic_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_tillage_constitutive_process, only: tillage_vg_parameters_t
  use mod_tillage_water_redistribution, only: redistribute_tillage_water, tillage_water_result_t, TILLAGE_WATER_OK
  implicit none
  private
  integer, parameter, public :: TILLAGE_BIND_OK = 0
  integer, parameter, public :: TILLAGE_BIND_INVALID = 1
  type, public :: tillage_hydraulic_candidate_t
    real(real64), allocatable :: water_content(:)
    real(real64), allocatable :: pressure_head_cm(:)
    real(real64) :: ponding_depth_cm = 0.0_real64
    real(real64) :: mass_residual_cm = 0.0_real64
  end type
  public :: bind_tillage_hydraulic_candidate
contains
  pure subroutine bind_tillage_hydraulic_candidate(prior_water_content, prior_pond_cm, &
       new_retention_at_old_head, thickness_cm, new_vg, redistribution_mode, candidate, status)
    real(real64), intent(in) :: prior_water_content(:), prior_pond_cm
    real(real64), intent(in) :: new_retention_at_old_head(:), thickness_cm(:)
    type(tillage_vg_parameters_t), intent(in) :: new_vg(:)
    integer, intent(in) :: redistribution_mode
    type(tillage_hydraulic_candidate_t), intent(out) :: candidate
    integer, intent(out) :: status
    real(real64), allocatable :: residual(:), saturated(:)
    type(tillage_water_result_t) :: redistribution
    real(real64) :: effective_saturation, exponent, head
    integer :: i, water_status, n

    candidate = tillage_hydraulic_candidate_t()
    status = TILLAGE_BIND_INVALID
    n = size(prior_water_content)
    if (n < 1 .or. size(new_vg) /= n .or. size(thickness_cm) /= n .or. &
        size(new_retention_at_old_head) /= n) return
    allocate(residual(n),saturated(n))
    do i = 1,n
      if (.not. all(ieee_is_finite([new_vg(i)%theta_residual,new_vg(i)%theta_saturated, &
           new_vg(i)%alpha,new_vg(i)%n,new_vg(i)%m]))) return
      if (new_vg(i)%alpha <= 0.0_real64 .or. new_vg(i)%n <= 1.0_real64 .or. &
          new_vg(i)%m <= 0.0_real64 .or. new_vg(i)%m >= 1.0_real64) return
      if (abs(new_vg(i)%m-(1.0_real64-1.0_real64/new_vg(i)%n)) > 1.e-12_real64) return
      residual(i) = new_vg(i)%theta_residual
      saturated(i) = new_vg(i)%theta_saturated
    end do
    call redistribute_tillage_water(redistribution_mode,prior_water_content,new_retention_at_old_head, &
         residual,saturated,thickness_cm,prior_pond_cm,redistribution,water_status)
    if (water_status /= TILLAGE_WATER_OK) return
    allocate(candidate%water_content(n),candidate%pressure_head_cm(n))
    candidate%water_content = redistribution%water_content
    candidate%ponding_depth_cm = redistribution%ponding_depth_cm
    candidate%mass_residual_cm = redistribution%mass_residual_cm
    do i = 1,n
      effective_saturation = (candidate%water_content(i)-residual(i))/(saturated(i)-residual(i))
      if (effective_saturation >= 1.0_real64) then
        head = 0.0_real64
      else if (effective_saturation <= 0.0_real64) then
        candidate = tillage_hydraulic_candidate_t()
        return
      else
        exponent = effective_saturation**(-1.0_real64/new_vg(i)%m)-1.0_real64
        head = -exponent**(1.0_real64/new_vg(i)%n)/new_vg(i)%alpha
      end if
      if (.not. ieee_is_finite(head)) then
        candidate = tillage_hydraulic_candidate_t()
        return
      end if
      candidate%pressure_head_cm(i) = head
    end do
    status = TILLAGE_BIND_OK
  end subroutine
end module
