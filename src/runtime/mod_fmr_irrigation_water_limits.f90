module mod_fmr_irrigation_water_limits
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_tillage_constitutive_process, only: tillage_vg_parameters_t
  implicit none
  private
  integer, parameter, public :: IRRIGATION_LIMITS_OK = 0
  integer, parameter, public :: IRRIGATION_LIMITS_INVALID = 1
  public :: derive_irrigation_water_limits
contains
  pure subroutine derive_irrigation_water_limits(vg,layer_bottom_node,field_capacity_head_cm, &
       medium_head_cm,wilting_head_cm,field_capacity,middle,wilting,status)
    type(tillage_vg_parameters_t), intent(in) :: vg(:)
    integer, intent(in) :: layer_bottom_node(:)
    real(real64), intent(in) :: field_capacity_head_cm,medium_head_cm,wilting_head_cm
    real(real64), allocatable, intent(out) :: field_capacity(:),middle(:),wilting(:)
    integer, intent(out) :: status
    integer :: n,layer,first,last,representative
    real(real64) :: fc,mid,wp
    status = IRRIGATION_LIMITS_INVALID
    n = size(vg)
    if (n < 1 .or. size(layer_bottom_node) < 1) return
    if (.not. all(ieee_is_finite([field_capacity_head_cm,medium_head_cm,wilting_head_cm]))) return
    if (field_capacity_head_cm < medium_head_cm .or. medium_head_cm < wilting_head_cm) return
    first = 1
    do layer=1,size(layer_bottom_node)
      last = layer_bottom_node(layer)
      if (last < first .or. last > n) return
      first = last+1
    end do
    if (first /= n+1) return
    allocate(field_capacity(n),middle(n),wilting(n))
    first = 1
    do layer=1,size(layer_bottom_node)
      representative = layer_bottom_node(layer)
      last = representative
      if (.not. valid_vg(vg(representative))) then
        deallocate(field_capacity,middle,wilting)
        return
      end if
      fc = retention(vg(representative),field_capacity_head_cm)
      mid = retention(vg(representative),medium_head_cm)
      wp = retention(vg(representative),wilting_head_cm)
      if (.not. all(ieee_is_finite([fc,mid,wp]))) then
        deallocate(field_capacity,middle,wilting)
        return
      end if
      field_capacity(first:last) = fc
      middle(first:last) = mid
      wilting(first:last) = wp
      first = last+1
    end do
    status = IRRIGATION_LIMITS_OK
  end subroutine

  pure logical function valid_vg(vg)
    type(tillage_vg_parameters_t), intent(in) :: vg
    valid_vg = .false.
    if (.not. all(ieee_is_finite([vg%theta_residual,vg%theta_saturated,vg%alpha,vg%n,vg%m]))) return
    if (vg%theta_residual < 0.0_real64 .or. vg%theta_saturated <= vg%theta_residual .or. &
        vg%theta_saturated > 1.0_real64 .or. vg%alpha <= 0.0_real64 .or. vg%n <= 1.0_real64) return
    if (abs(vg%m-(1.0_real64-1.0_real64/vg%n)) > 1.e-12_real64) return
    valid_vg = .true.
  end function

  pure real(real64) function retention(vg,head_cm)
    type(tillage_vg_parameters_t), intent(in) :: vg
    real(real64), intent(in) :: head_cm
    if (head_cm >= 0.0_real64) then
      retention = vg%theta_saturated
    else
      retention = vg%theta_residual+(vg%theta_saturated-vg%theta_residual)* &
           (1.0_real64+(vg%alpha*abs(head_cm))**vg%n)**(-vg%m)
    end if
  end function
end module
