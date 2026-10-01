module mod_fmr_top_surface_exchange
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: FMR_TOP_EXCHANGE_OK=0, FMR_TOP_EXCHANGE_INVALID=1
  type, public :: fmr_top_surface_exchange_t
    integer :: status=FMR_TOP_EXCHANGE_INVALID
    logical :: available=.false.
    real(real64) :: runoff_to_external_cm=0.0_real64
    real(real64) :: residual_external_supply_cm=0.0_real64
    real(real64) :: signed_swap_to_external_cm=0.0_real64
    real(real64) :: closure_residual_cm=0.0_real64
  end type
  public :: materialize_fmr_top_surface_exchange
contains
  pure subroutine materialize_fmr_top_surface_exchange(s0,s1,atmosphere,evaporation,soil_entry,runoff,result)
    real(real64),intent(in)::s0,s1,atmosphere,evaporation,soil_entry,runoff
    type(fmr_top_surface_exchange_t),intent(out)::result
    real(real64)::x,ds
    result=fmr_top_surface_exchange_t()
    if(.not.all(ieee_is_finite([s0,s1,atmosphere,evaporation,soil_entry,runoff])))return
    if(s0<0._real64.or.s1<0._real64.or.atmosphere<0._real64.or.evaporation<0._real64.or.runoff<0._real64)return
    ds=s1-s0
    x=ds-atmosphere+evaporation+soil_entry+runoff
    result%runoff_to_external_cm=runoff
    result%residual_external_supply_cm=x
    result%signed_swap_to_external_cm=runoff-x
    result%closure_residual_cm=ds-(atmosphere+x-evaporation-soil_entry-runoff)
    if(.not.ieee_is_finite(result%signed_swap_to_external_cm).or..not.ieee_is_finite(result%closure_residual_cm))return
    result%status=FMR_TOP_EXCHANGE_OK
    result%available=.true.
  end subroutine
end module
