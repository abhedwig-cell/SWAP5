module mod_bartholomeus_soil_diffusivity
   use iso_fortran_env, only : real64
   implicit none
   private
   public :: BartholomeusSoilDiffusivityPrecompute
   public :: bartholomeus_soil_diffusivity

   type :: BartholomeusSoilDiffusivityPrecompute
      real(real64) :: term1
      real(real64) :: exponent
      real(real64) :: gfp100
   end type

contains
   pure function bartholomeus_soil_diffusivity(d_gas_free_air,gas_filled_porosity,p) result(d_soil)
      real(real64), intent(in) :: d_gas_free_air,gas_filled_porosity
      type(BartholomeusSoilDiffusivityPrecompute), intent(in) :: p
      real(real64) :: d_soil

      if (gas_filled_porosity <= 0.0_real64 .or. p%gfp100 <= 0.0_real64) then
         d_soil = 0.0_real64
      else
         d_soil = d_gas_free_air*p%term1*(gas_filled_porosity/p%gfp100)**p%exponent
      end if
   end function
end module mod_bartholomeus_soil_diffusivity
