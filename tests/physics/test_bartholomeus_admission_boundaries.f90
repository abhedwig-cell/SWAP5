program test_bartholomeus_admission_boundaries
 use iso_fortran_env,only:real64
 use mod_bartholomeus_runtime_input
 use mod_bartholomeus_parameter_contract
 use mod_bartholomeus_factor_provider
 use mod_bartholomeus_waterfilm_provider,only:BARTHOLOMEUS_WATERFILM_REFERENCE
 use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
 implicit none
 type(bartholomeus_runtime_view_t)::v
 type(BartholomeusImmutableDataset)::d
 type(BartholomeusCropParameters)::c
 real(real64),allocatable::f(:)
 real(real64)::wr(2),wr0(2)
 logical::ok
 integer::i,failures
 failures=0
 v%rooted_nodes=2
 allocate(v%pressure_head_cm(2),v%water_content(2),v%soil_temperature_k(2))
 v%pressure_head_cm=[-100._real64,-300._real64]
 v%water_content=[.30_real64,.34_real64]
 v%soil_temperature_k=[293.15_real64,291.15_real64]
 allocate(d%soil(2))
 do i=1,2
  d%soil(i)%saturated_water_content=.45_real64
  d%soil(i)%percent_org_mat=2._real64
  d%soil(i)%percent_sand=60._real64
  d%soil(i)%soil_density=1300._real64
  d%soil(i)%depth_m=.1_real64*i
  d%soil(i)%waterfilm_capac_term=1.e-4_real64
  d%soil(i)%waterfilm_n_minus_1=.5_real64
  d%soil(i)%waterfilm_m_plus_1=1.5_real64
  d%soil(i)%waterfilm_alpha_per_pa=1.e-4_real64
  d%soil(i)%waterfilm_gen_n=1.5_real64
  d%soil(i)%diffusivity%term1=1._real64
  d%soil(i)%diffusivity%exponent=2._real64
  d%soil(i)%diffusivity%gfp100=.2_real64
 end do
 c%c_mroot=1.e-5_real64;c%f_senes=1._real64;c%q10_root=2._real64
 c%specific_resp_humus=1.e-6_real64;c%q10_microbial=2._real64
 c%microbial_shape_m=.2_real64;c%root_shape_m=.2_real64;c%root_radius_m=.0002_real64;c%max_resp_factor=2._real64
 wr=[1._real64,.8_real64];wr0=[1._real64,.8_real64]
 call evaluate_bartholomeus_factors_from_state(v,d,c,wr,wr0,.275_real64,BARTHOLOMEUS_WATERFILM_REFERENCE,f,ok)
 if(.not.ok) error stop 1
 if(size(f)/=2) error stop 2
 if(any(f<0._real64).or.any(f>1._real64)) error stop 3
 print '(a)','PPA_WU05C3A_ACTIVE_CHAIN=PASS'
 print '(a,2(es24.16,1x))','FACTORS=',f

 v%water_content=.45_real64
 v%pressure_head_cm=-1._real64
 call evaluate_bartholomeus_factors_from_state(v,d,c,wr,wr0,.275_real64,BARTHOLOMEUS_WATERFILM_REFERENCE,f,ok)
 print '(a,l1)','SATURATED_ACCEPTED=',ok
 if(.not.ok) failures=failures+1
 v%water_content=[.30_real64,.34_real64]
 v%pressure_head_cm=[-100._real64,-300._real64]
 c%root_radius_m=ieee_value(0._real64,ieee_quiet_nan)
 print '(a,l1)','NAN_PARAMETERS_ACCEPTED=',validate_bartholomeus_parameters(d,c,2)
 if(validate_bartholomeus_parameters(d,c,2)) failures=failures+1
 call evaluate_bartholomeus_factors_from_state(v,d,c,wr,wr0,.275_real64,BARTHOLOMEUS_WATERFILM_REFERENCE,f,ok)
 print '(a,l1)','NAN_PHYSICS_ACCEPTED=',ok
 if(ok) failures=failures+1
 if(ok) print '(a,2(es24.16,1x))','NAN_FACTORS=',f
print '(a,i0)','C3A_ADMISSION_BOUNDARY_FAILURES=',failures
 if(failures>0) then
  print '(a)','PPA_WU05C3A_ADMISSION_BOUNDARIES=FAIL'
  error stop 20
 end if
 print '(a)','PPA_WU05C3A_ADMISSION_BOUNDARIES=PASS'
end program
