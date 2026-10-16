program test_bartholomeus_kernel_smoke
   use iso_fortran_env, only : real64
   use mod_bartholomeus_micro
   use mod_bartholomeus_macro
   use mod_bartholomeus_response
   implicit none
   type(BartholomeusResponseInput) :: p
   real(real64) :: rf, rwu, cmac, cmic
   logical :: ok

   p%max_resp_factor = 2.0_real64
   p%micro%c_mroot = 1.0e-7_real64
   p%micro%w_root = 0.02_real64
   p%micro%f_senes = 1.0_real64
   p%micro%q10_root = 2.0_real64
   p%micro%soil_temp_k = 293.0_real64
   p%micro%sat_water_content = 0.45_real64
   p%micro%gas_filled_porosity = 0.10_real64
   p%micro%d_o2_in_water = 2.0e-4_real64
   p%micro%d_root = 8.0e-5_real64
   p%micro%percent_org_mat = 3.0_real64
   p%micro%soil_density = 1400.0_real64
   p%micro%specific_resp_humus = 1.0e-8_real64
   p%micro%q10_microbial = 2.0_real64
   p%micro%depth_m = 0.05_real64
   p%micro%microbial_shape_m = 0.20_real64
   p%micro%root_radius_m = 5.0e-4_real64
   p%micro%waterfilm_thickness_m = 2.0e-5_real64
   p%micro%bunsen_coeff = 0.03_real64

   p%macro%depth_m = p%micro%depth_m
   p%macro%c_mroot = p%micro%c_mroot
   p%macro%w_root_z0 = 0.02_real64
   p%macro%f_senes = p%micro%f_senes
   p%macro%q10_root = p%micro%q10_root
   p%macro%soil_temp_k = p%micro%soil_temp_k
   p%macro%ctop = 0.28_real64
   p%macro%microbial_shape_m = p%micro%microbial_shape_m
   p%macro%root_shape_m = 0.20_real64
   p%macro%r_microbial_z0 = 1.0e-6_real64
   p%macro%d_soil = 1.0e-3_real64

   call bartholomeus_respiration_factor(p,rf,ok)
   if (.not.ok) error stop 1
   if (rf < 0.0_real64 .or. rf > p%max_resp_factor) error stop 2
   rwu=bartholomeus_rwu_factor(rf,p%max_resp_factor)
   if (rwu < 0.0_real64 .or. rwu > 1.0_real64) error stop 3
   cmic=bartholomeus_micro_concentration(p%micro,rf)
   cmac=bartholomeus_macro_concentration(p%macro,rf,ok)
   if (.not.ok) error stop 4
   if (abs(cmac-cmic) > 1.0e-6_real64 .and. rf > 1.0e-8_real64 .and. &
       rf < p%max_resp_factor-1.0e-8_real64) error stop 5

   print '(a)', 'PPA_WU05C3Q_KERNEL_SMOKE=PASS'
end program
