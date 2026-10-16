module mod_bartholomeus_temperature
   use iso_fortran_env, only : real64
   implicit none
   private
   public :: BartholomeusTemperatureResult
   public :: bartholomeus_temperature_parameters

   type :: BartholomeusTemperatureResult
      real(real64) :: d_o2_in_water
      real(real64) :: d_root
      real(real64) :: d_gas_free_air
      real(real64) :: surface_tension_water
      real(real64) :: bunsen_coeff
   end type BartholomeusTemperatureResult

contains
   pure function bartholomeus_temperature_parameters(soil_temp_k) result(r)
      real(real64), intent(in) :: soil_temp_k
      type(BartholomeusTemperatureResult) :: r
      real(real64), parameter :: d_o2_water_ref = 1.0e-5_real64*1.2_real64/(100.0_real64*100.0_real64)
      real(real64), parameter :: seconds_per_day = 24.0_real64*3600.0_real64
      real(real64), parameter :: tref3 = 1.0_real64/(293.0_real64**3)

      r%d_o2_in_water = seconds_per_day*d_o2_water_ref*exp(0.026_real64*(soil_temp_k-273.0_real64))
      r%d_root = 0.4_real64*r%d_o2_in_water
      r%d_gas_free_air = 1.74528_real64*(soil_temp_k**3)*tref3
      r%surface_tension_water = 0.07275_real64*(1.0_real64-0.002_real64*(soil_temp_k-291.0_real64))
      r%bunsen_coeff = (1413.0_real64*exp(-144.397_real64+7775.18_real64/soil_temp_k + &
                       18.3977_real64*log(soil_temp_k)+0.0094437_real64*soil_temp_k))*273.15_real64/soil_temp_k
   end function
end module mod_bartholomeus_temperature
