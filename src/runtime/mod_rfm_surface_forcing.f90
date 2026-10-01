module mod_rfm_surface_forcing
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  type, public :: rfm_surface_forcing_t
    logical :: supplied=.false.
    ! Source-owned physical event identity for A13 tau_surface semantics.
    ! Never infer this from a flux threshold inside the RFM runtime.
    logical :: event_active=.false.
    real(real64) :: precipitation_rate_cm_per_day=0.0_real64
    real(real64) :: irrigation_rate_cm_per_day=0.0_real64
    real(real64) :: snowmelt_rate_cm_per_day=0.0_real64
    real(real64) :: runon_rate_cm_per_day=0.0_real64
    real(real64) :: potential_bare_soil_evaporation_cm_per_day=0.0_real64
    real(real64) :: potential_pond_evaporation_cm_per_day=0.0_real64
    real(real64) :: ponding_max_cm=0.0_real64
    real(real64) :: runoff_resistance_day=0.0_real64
    real(real64) :: runoff_exponent=1.0_real64
  contains
    procedure, public :: valid => rfm_surface_forcing_valid
  end type
contains
  pure logical function rfm_surface_forcing_valid(self) result(ok)
    class(rfm_surface_forcing_t),intent(in)::self
    real(real64)::v(9)
    ok=self%supplied
    if(.not.ok)return
    v=[self%precipitation_rate_cm_per_day,self%irrigation_rate_cm_per_day, &
       self%snowmelt_rate_cm_per_day,self%runon_rate_cm_per_day, &
       self%potential_bare_soil_evaporation_cm_per_day,self%potential_pond_evaporation_cm_per_day, &
       self%ponding_max_cm,self%runoff_resistance_day,self%runoff_exponent]
    ok=all(ieee_is_finite(v)).and.all(v(1:8)>=0.0_real64).and.v(9)>0.0_real64
  end function
end module mod_rfm_surface_forcing
