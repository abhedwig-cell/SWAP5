program test_bartholomeus_response_assembly
  use iso_fortran_env,only:real64
  use mod_process_hydraulic_view,only:process_hydraulic_view_t
  use mod_soil_temperature_contract,only:soil_temperature_field_view_t
  use mod_bartholomeus_runtime_input
  use mod_bartholomeus_parameter_contract
  use mod_bartholomeus_response,only:BartholomeusResponseInput
  use mod_bartholomeus_response_assembly
  implicit none
  type(process_hydraulic_view_t)::h
  type(soil_temperature_field_view_t)::t
  type(bartholomeus_runtime_view_t)::v
  type(BartholomeusImmutableDataset)::d
  type(BartholomeusCropParameters)::c
  type(BartholomeusResponseInput),allocatable::p(:)
  real(real64)::wr(1),wr0(1),wf(1)
  integer::status
  logical::ok
  h%active_nodes=1; allocate(h%pressure_head(1),h%water_content(1))
  h%pressure_head=-100.0_real64; h%water_content=.30_real64
  t%active_nodes=1; allocate(t%temperature_c(1)); t%temperature_c=20.0_real64
  call build_bartholomeus_runtime_view(h,t,1,v,status)
  if(status/=BARTHOLOMEUS_INPUT_OK) error stop 1
  ! Exact B1.11 source convention is temperature_c+273, not SI +273.15.
  if(abs(v%soil_temperature_k(1)-293.0_real64)>1e-12_real64) error stop 2
  allocate(d%soil(1))
  d%soil(1)%saturated_water_content=.45_real64; d%soil(1)%percent_org_mat=3; d%soil(1)%percent_sand=60
  d%soil(1)%soil_density=1300; d%soil(1)%depth_m=.1_real64
  d%soil(1)%waterfilm_alpha_per_pa=1e-4_real64; d%soil(1)%waterfilm_gen_n=1.5_real64
  d%soil(1)%waterfilm_capac_term=1.0_real64
  d%soil(1)%waterfilm_n_minus_1=.5_real64;d%soil(1)%waterfilm_m_plus_1=4.0_real64/3.0_real64
  d%soil(1)%diffusivity%term1=1; d%soil(1)%diffusivity%exponent=2; d%soil(1)%diffusivity%gfp100=.2_real64
  c%c_mroot=1e-5_real64; c%f_senes=1; c%q10_root=2; c%specific_resp_humus=1e-6_real64
  c%q10_microbial=2; c%microbial_shape_m=.2_real64; c%root_shape_m=.2_real64;c%root_radius_m=.0002_real64;c%max_resp_factor=2
  wr=1;wr0=1;wf=1e-5_real64
  call assemble_bartholomeus_response_inputs(v,d,c,wr,wr0,wf,p,ok)
  if(.not.ok) error stop 3
  if(abs(p(1)%micro%gas_filled_porosity-.15_real64)>1e-12_real64) error stop 4
  if(abs(p(1)%micro%soil_temp_k-293.0_real64)>1e-12_real64) error stop 5
  print '(a)','PPA_WU05C3P_RESPONSE_ASSEMBLY=PASS'
end program
