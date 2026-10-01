module mod_bartholomeus_response_assembly
  use iso_fortran_env, only: real64
  use mod_bartholomeus_runtime_input, only: bartholomeus_runtime_view_t
  use mod_bartholomeus_parameter_contract
  use mod_bartholomeus_temperature, only: BartholomeusTemperatureResult, bartholomeus_temperature_parameters
  use mod_bartholomeus_soil_diffusivity, only: bartholomeus_soil_diffusivity
  use mod_bartholomeus_microbial, only: bartholomeus_microbial_respiration
  use mod_bartholomeus_response, only: BartholomeusResponseInput
  implicit none
  private
  public :: assemble_bartholomeus_response_inputs

contains
  subroutine assemble_bartholomeus_response_inputs(view,data,crop,w_root,w_root_z0,waterfilm,inputs,ok)
    type(bartholomeus_runtime_view_t),intent(in)::view
    type(BartholomeusImmutableDataset),intent(in)::data
    type(BartholomeusCropParameters),intent(in)::crop
    real(real64),intent(in)::w_root(:),w_root_z0(:),waterfilm(:)
    type(BartholomeusResponseInput),allocatable,intent(out)::inputs(:)
    logical,intent(out)::ok
    type(BartholomeusTemperatureResult)::t
    real(real64)::gfp,mp,dsoil,rm
    integer::i,n

    ok=.false.; n=view%rooted_nodes
    if(.not.validate_bartholomeus_parameters(data,crop,n)) return
    if(size(w_root)/=n .or. size(w_root_z0)/=n .or. size(waterfilm)/=n) return
    allocate(inputs(n))
    do i=1,n
      if(w_root(i)<0 .or. w_root_z0(i)<0 .or. waterfilm(i)<0) return
      gfp=data%soil(i)%saturated_water_content-view%water_content(i)
      gfp=max(0.0_real64,gfp)
      ! SWAP pressure head is cm water. Legacy oxygenstress uses positive matric potential in Pa.
      mp=abs(view%pressure_head_cm(i))*98.0665_real64
      t=bartholomeus_temperature_parameters(view%soil_temperature_k(i))
      dsoil=bartholomeus_soil_diffusivity(t%d_gas_free_air,gfp,data%soil(i)%diffusivity)
      rm=bartholomeus_microbial_respiration(view%soil_temperature_k(i),data%soil(i)%percent_org_mat, &
           data%soil(i)%soil_density,data%soil(i)%percent_sand,mp,crop%specific_resp_humus,crop%q10_microbial)

      inputs(i)%max_resp_factor=crop%max_resp_factor
      inputs(i)%micro%c_mroot=crop%c_mroot
      inputs(i)%micro%w_root=w_root(i)
      inputs(i)%micro%f_senes=crop%f_senes
      inputs(i)%micro%q10_root=crop%q10_root
      inputs(i)%micro%soil_temp_k=view%soil_temperature_k(i)
      inputs(i)%micro%sat_water_content=data%soil(i)%saturated_water_content
      inputs(i)%micro%gas_filled_porosity=gfp
      inputs(i)%micro%d_o2_in_water=t%d_o2_in_water
      inputs(i)%micro%d_root=t%d_root
      inputs(i)%micro%percent_org_mat=data%soil(i)%percent_org_mat
      inputs(i)%micro%soil_density=data%soil(i)%soil_density
      inputs(i)%micro%specific_resp_humus=crop%specific_resp_humus
      inputs(i)%micro%q10_microbial=crop%q10_microbial
      inputs(i)%micro%depth_m=data%soil(i)%depth_m
      inputs(i)%micro%microbial_shape_m=crop%microbial_shape_m
      inputs(i)%micro%root_radius_m=crop%root_radius_m
      inputs(i)%micro%waterfilm_thickness_m=waterfilm(i)
      inputs(i)%micro%bunsen_coeff=t%bunsen_coeff

      inputs(i)%macro%depth_m=data%soil(i)%depth_m
      inputs(i)%macro%c_mroot=crop%c_mroot
      inputs(i)%macro%w_root_z0=w_root_z0(i)
      inputs(i)%macro%f_senes=crop%f_senes
      inputs(i)%macro%q10_root=crop%q10_root
      inputs(i)%macro%soil_temp_k=view%soil_temperature_k(i)
      inputs(i)%macro%microbial_shape_m=crop%microbial_shape_m
      inputs(i)%macro%root_shape_m=crop%root_shape_m
      inputs(i)%macro%r_microbial_z0=rm
      inputs(i)%macro%d_soil=dsoil
      ! ctop is assigned by ordered profile composition.
      inputs(i)%macro%ctop=0.0_real64
    end do
    ok=.true.
  end subroutine
end module
