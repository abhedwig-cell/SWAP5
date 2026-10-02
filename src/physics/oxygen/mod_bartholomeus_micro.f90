module mod_bartholomeus_micro
   use iso_fortran_env, only : real64
   implicit none
   private

   public :: BartholomeusMicroInput
   public :: bartholomeus_micro_concentration

   real(real64), parameter :: PI = 3.14159265358979323846_real64
   real(real64), parameter :: FOUR_THIRDS = 4.0_real64/3.0_real64

   type :: BartholomeusMicroInput
      real(real64) :: c_mroot
      real(real64) :: w_root
      real(real64) :: f_senes
      real(real64) :: q10_root
      real(real64) :: soil_temp_k
      real(real64) :: sat_water_content
      real(real64) :: gas_filled_porosity
      real(real64) :: d_o2_in_water
      real(real64) :: d_root
      real(real64) :: percent_org_mat
      real(real64) :: soil_density
      real(real64) :: specific_resp_humus
      real(real64) :: q10_microbial
      real(real64) :: depth_m
      real(real64) :: microbial_shape_m
      real(real64) :: root_radius_m
      real(real64) :: waterfilm_thickness_m
      real(real64) :: bunsen_coeff
   end type BartholomeusMicroInput

contains

   pure function bartholomeus_micro_concentration(p, resp_factor) result(c_min_micro)
      type(BartholomeusMicroInput), intent(in) :: p
      real(real64), intent(in) :: resp_factor
      real(real64) :: c_min_micro
      real(real64) :: r_mref, r_mroot, waterfilm_porosity, d_waterfilm, lambda
      real(real64) :: carbon_humuspools, r_microbial_z0_wf, r_microbial_volumetric_wf
      real(real64) :: r_waterfilm_lengthroot, alpha_alpha, ratio, log_ratio
      real(real64) :: c_min_micro_interphase

      r_mref = p%c_mroot*p%w_root*resp_factor
      r_mroot = p%f_senes*r_mref*(p%q10_root**(0.1_real64*(p%soil_temp_k-298.0_real64)))

      waterfilm_porosity = (p%sat_water_content-p%gas_filled_porosity) / &
                           (1.0_real64-p%gas_filled_porosity)
      waterfilm_porosity = max(0.075_real64, waterfilm_porosity)
      d_waterfilm = p%d_o2_in_water*(waterfilm_porosity**FOUR_THIRDS)
      lambda = p%d_root/d_waterfilm

      carbon_humuspools = 0.48_real64*(0.01_real64*p%percent_org_mat)*p%soil_density
      r_microbial_z0_wf = p%specific_resp_humus*carbon_humuspools * &
                          (p%q10_microbial**(0.1_real64*(p%soil_temp_k-298.0_real64)))*0.5_real64
      r_microbial_volumetric_wf = r_microbial_z0_wf*exp(-p%depth_m/p%microbial_shape_m)

      r_waterfilm_lengthroot = PI*((p%root_radius_m+p%waterfilm_thickness_m)**2-p%root_radius_m**2) * &
                               r_microbial_volumetric_wf

      if (r_waterfilm_lengthroot+r_mroot <= 0.0_real64) then
         c_min_micro = 0.0_real64
         return
      end if

      alpha_alpha = r_waterfilm_lengthroot/(r_waterfilm_lengthroot+r_mroot)
      ratio = p%waterfilm_thickness_m/p%root_radius_m
      log_ratio = log(1.0_real64+ratio)

      c_min_micro_interphase = ((r_waterfilm_lengthroot+r_mroot)/(2.0_real64*PI*p%d_root)) * &
         (0.5_real64 + ((lambda-1.0_real64)*alpha_alpha/2.0_real64) + lambda*log_ratio - &
          (lambda*alpha_alpha*(1.0_real64+ratio)**2)*log_ratio/(ratio*(2.0_real64+ratio)))

      c_min_micro = c_min_micro_interphase/p%bunsen_coeff
   end function bartholomeus_micro_concentration

end module mod_bartholomeus_micro
