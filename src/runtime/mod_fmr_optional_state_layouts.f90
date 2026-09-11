module mod_fmr_optional_state_layouts
  use, intrinsic :: iso_fortran_env, only: int64
  implicit none
  private

  ! Feature-scoped physical optional-state identity.  Numerical continuation
  ! remains a separate template axis and must never be encoded here.
  integer(int64), parameter, public :: FMR_OPTIONAL_STATE_FIXED_WEIR_SURFACE_WATER = 43107_int64

end module mod_fmr_optional_state_layouts
