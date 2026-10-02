module mod_bartholomeus_no_stress_gate
 use iso_fortran_env,only:real64
 use mod_bartholomeus_runtime_input,only:bartholomeus_runtime_view_t
 use mod_bartholomeus_parameter_contract
 use mod_bartholomeus_temperature,only:BartholomeusTemperatureResult,bartholomeus_temperature_parameters
 use mod_bartholomeus_soil_diffusivity,only:bartholomeus_soil_diffusivity
 use mod_bartholomeus_microbial,only:bartholomeus_microbial_respiration
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
  real(real64)::ctop,gfp,mp,dsoil,rm,a,b,demand,cmacro
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
   ! Macro-only sufficient screen: if even the maximum-respiration macro profile
   ! has no oxygen margin, no claim is made. MICRO is deliberately not approximated.
   if(demand>=ctop)return
   cmacro=ctop-a*(1._real64-exp(-data%soil(i)%depth_m/crop%microbial_shape_m)) - &
               b*(1._real64-exp(-data%soil(i)%depth_m/crop%root_shape_m))
   ! A positive macro concentration alone cannot prove the unknown waterfilm MICRO
   ! demand is feasible, so this first bound intentionally makes no skip claim yet.
   if(cmacro<=0._real64)return
   ctop=cmacro
  enddo
  skip=.false.
 end function
end module
