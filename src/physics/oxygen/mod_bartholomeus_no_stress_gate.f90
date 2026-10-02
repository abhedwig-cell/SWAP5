module mod_bartholomeus_no_stress_gate
 use iso_fortran_env,only:real64
 use mod_bartholomeus_runtime_input,only:bartholomeus_runtime_view_t
 use mod_bartholomeus_parameter_contract
 use mod_bartholomeus_temperature,only:BartholomeusTemperatureResult,bartholomeus_temperature_parameters
 use mod_bartholomeus_soil_diffusivity,only:bartholomeus_soil_diffusivity
 use mod_bartholomeus_microbial,only:bartholomeus_microbial_respiration
 use mod_bartholomeus_micro,only:BartholomeusMicroInput,bartholomeus_micro_concentration
 use mod_bartholomeus_waterfilm,only:BartholomeusWaterfilmMvgInput,bartholomeus_waterfilm_mvg_integrand,bartholomeus_waterfilm_from_length_density
 implicit none
 private
 public::bartholomeus_macro_supply_bound_no_stress
contains
 pure logical function bartholomeus_macro_supply_bound_no_stress(view,data,crop,w_root_z0,atmospheric_ctop) result(skip)
  type(bartholomeus_runtime_view_t),intent(in)::view
  type(BartholomeusImmutableDataset),intent(in)::data
  type(BartholomeusCropParameters),intent(in)::crop
  real(real64),intent(in)::w_root_z0(:),atmospheric_ctop
  type(BartholomeusTemperatureResult)::t
  type(BartholomeusMicroInput)::mi
  type(BartholomeusWaterfilmMvgInput)::wf
  real(real64)::ctop,gfp,mp,dsoil,rm,a,b,demand,cmacro,ilower,film_ub,cmicro_ub
  integer::i
  skip=.false.;ctop=atmospheric_ctop
  if(size(w_root_z0)/=view%rooted_nodes)return
  do i=1,view%rooted_nodes
   gfp=max(0._real64,data%soil(i)%saturated_water_content-view%water_content(i))
   if(view%pressure_head_cm(i)>=0._real64)gfp=0._real64
   if(gfp<1.e-4_real64)return
   t=bartholomeus_temperature_parameters(view%soil_temperature_k(i))
   dsoil=bartholomeus_soil_diffusivity(t%d_gas_free_air,gfp,data%soil(i)%diffusivity)
   if(dsoil<=0._real64)return
   mp=-view%pressure_head_cm(i)*100._real64
   rm=bartholomeus_microbial_respiration(view%soil_temperature_k(i),data%soil(i)%percent_org_mat,data%soil(i)%soil_density, &
       data%soil(i)%percent_sand,mp,crop%specific_resp_humus,crop%q10_microbial)
   a=crop%microbial_shape_m**2*rm/dsoil
   b=crop%root_shape_m**2*(crop%f_senes*crop%c_mroot*w_root_z0(i)*crop%max_resp_factor * &
       crop%q10_root**(.1_real64*(view%soil_temperature_k(i)-298._real64)))/dsoil
   demand=a+b
   if(demand>=ctop)return
   cmacro=ctop-a*(1._real64-exp(-data%soil(i)%depth_m/crop%microbial_shape_m)) - &
               b*(1._real64-exp(-data%soil(i)%depth_m/crop%root_shape_m))
   if(cmacro<=0._real64)return
   wf%capac_term=data%soil(i)%waterfilm_capac_term;wf%n_minus_1=data%soil(i)%waterfilm_n_minus_1
   wf%m_plus_1=data%soil(i)%waterfilm_m_plus_1;wf%alpha_per_pa=data%soil(i)%waterfilm_alpha_per_pa
   wf%gen_n=data%soil(i)%waterfilm_gen_n;wf%surface_tension_water=t%surface_tension_water
   ! Positive integrand lower bound: for n<=2 it is increasing, so the integral
   ! over the upper half interval is at least (H/2)*f(H/2). This lower bound on
   ! length density yields an upper bound on film thickness, the conservative
   ! direction because MICRO demand increases with film thickness.
   if(wf%gen_n>2._real64)return
   ilower=.5_real64*mp*bartholomeus_waterfilm_mvg_integrand(.5_real64*mp,wf)
   if(ilower<=0._real64)return
   film_ub=bartholomeus_waterfilm_from_length_density(ilower,mp,t%surface_tension_water)
   if(.not.(film_ub>0._real64))return
   mi%c_mroot=crop%c_mroot;mi%w_root=w_root_z0(i);mi%f_senes=crop%f_senes;mi%q10_root=crop%q10_root
   mi%soil_temp_k=view%soil_temperature_k(i);mi%sat_water_content=data%soil(i)%saturated_water_content
   mi%gas_filled_porosity=gfp;mi%d_o2_in_water=t%d_o2_in_water;mi%d_root=t%d_root
   mi%percent_org_mat=data%soil(i)%percent_org_mat;mi%soil_density=data%soil(i)%soil_density
   mi%specific_resp_humus=crop%specific_resp_humus;mi%q10_microbial=crop%q10_microbial
   mi%depth_m=data%soil(i)%depth_m;mi%microbial_shape_m=crop%microbial_shape_m;mi%root_radius_m=crop%root_radius_m
   mi%waterfilm_thickness_m=film_ub;mi%bunsen_coeff=t%bunsen_coeff
   cmicro_ub=bartholomeus_micro_concentration(mi,crop%max_resp_factor)
   if(cmacro<cmicro_ub)return
   ctop=cmacro
  enddo
  skip=.true.
 end function
end module
