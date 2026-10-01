module mod_external_top_flooding_classifier
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: EXT_FLOOD_OK=0, EXT_FLOOD_INVALID=1
  type, public :: external_top_flooding_result_t
    integer :: status=EXT_FLOOD_INVALID
    logical :: active=.false.
    real(real64) :: imposed_surface_head_cm=0.0_real64
  end type
  public :: classify_external_top_flooding
contains
  pure subroutine classify_external_top_flooding(external_head_cm,sill_head_cm,local_surface_head_cm,result)
    real(real64),intent(in)::external_head_cm,sill_head_cm,local_surface_head_cm
    type(external_top_flooding_result_t),intent(out)::result
    result=external_top_flooding_result_t()
    if(.not.all(ieee_is_finite([external_head_cm,sill_head_cm,local_surface_head_cm]))) return
    result%status=EXT_FLOOD_OK
    result%active=external_head_cm>sill_head_cm .and. external_head_cm>local_surface_head_cm
    if(result%active) result%imposed_surface_head_cm=external_head_cm
  end subroutine
end module
