program test_bartholomeus_runtime_boundaries
 use iso_fortran_env,only:real64
 use mod_bartholomeus_runtime_input
 use mod_bartholomeus_parameter_contract
 use mod_bartholomeus_factor_provider
 use mod_bartholomeus_waterfilm_provider,only:BARTHOLOMEUS_WATERFILM_REFERENCE
 use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
 use mod_fmr_bartholomeus_activation
 use mod_fmr_bartholomeus_execution
 use mod_process_hydraulic_view, only: process_hydraulic_view_t
 use mod_soil_temperature_contract, only: soil_temperature_field_view_t
 use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
 implicit none
 type(bartholomeus_runtime_view_t)::v
 type(BartholomeusImmutableDataset)::d
 type(BartholomeusCropParameters)::c
 real(real64),allocatable::f(:)
 real(real64)::wr(2),wr0(2)
 logical::ok
 integer::i,status
 type(process_hydraulic_view_t)::h
 type(soil_temperature_field_view_t)::t
 type(fmr_bartholomeus_selection_t)::cfg
 type(root_water_uptake_flux_result_t)::base,out
 real(real64)::expected(3)

 v%rooted_nodes=2
 allocate(v%pressure_head_cm(2),v%water_content(2),v%soil_temperature_k(2))
 v%pressure_head_cm=[-100._real64,-300._real64]
 v%water_content=[.30_real64,.34_real64]
 v%soil_temperature_k=[293.0_real64,291.0_real64]
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

 allocate(base%root_extraction_sink(3))
 base%root_extraction_sink=[1._real64,2._real64,3._real64]
 base%actual_uptake_total=6._real64
 ! OFF must not inspect invalid/uninitialized physical owners.
 call run_runtime()
 if(status/=FMR_BARTHOLOMEUS_EXEC_OK) error stop 10
 if(any(abs(out%root_extraction_sink-base%root_extraction_sink)>0)) error stop 11
 if(abs(out%actual_uptake_total-base%actual_uptake_total)>0) error stop 12
 print '(a)','C3A_DYNAMIC_OFF=PASS'
 cfg%oxygen_mode=2;cfg%oxygen_type=1;cfg%hydraulic_waterfilm_mode=1
 call run_runtime()
 if(status/=FMR_BARTHOLOMEUS_EXEC_UNSUPPORTED) error stop 13
 if(allocated(out%root_extraction_sink)) error stop 14
 cfg%hydraulic_waterfilm_mode=0
 h%active_nodes=3;t%active_nodes=3
 allocate(h%pressure_head(3),h%water_content(3),t%temperature_c(3))
 h%pressure_head=[-100._real64,-300._real64,-100._real64]
 h%water_content=[.30_real64,.34_real64,.30_real64]
 t%temperature_c=[20._real64,18._real64,20._real64]
 expected=[f(1),2*f(2),3._real64]
 call run_runtime()
 if(status/=FMR_BARTHOLOMEUS_EXEC_OK) error stop 15
 if(any(abs(out%root_extraction_sink-expected)>1.e-14_real64)) error stop 16
 if(abs(out%actual_uptake_total-sum(expected))>1.e-14_real64) error stop 17
 print '(a)','C3A_DYNAMIC_ACTIVE_NONROOTED_SINGLE_SINK=PASS'
 ! Source shortcut and zero concentration propagation into an aerated second node.
 h%water_content(1)=.45_real64
 call run_runtime()
 if(status/=FMR_BARTHOLOMEUS_EXEC_OK) error stop 18
 if(any(abs(out%root_extraction_sink(1:2))>0)) error stop 19
 if(abs(out%root_extraction_sink(3)-3._real64)>0) error stop 20
 print '(a)','C3A_SATURATED_VERTICAL_PROPAGATION=PASS'
 h%water_content(1)=.45_real64-.5e-4_real64
 call run_runtime()
 if(status/=FMR_BARTHOLOMEUS_EXEC_OK) error stop 21
 if(any(abs(out%root_extraction_sink(1:2))>0)) error stop 22
 h%water_content(1)=.30_real64;h%pressure_head(1)=1._real64
 call run_runtime()
 if(status/=FMR_BARTHOLOMEUS_EXEC_OK) error stop 23
 if(any(abs(out%root_extraction_sink(1:2))>0)) error stop 24
 print '(a)','C3A_GFP_THRESHOLD_PRESSURE_SHORTCUT=PASS'
 h%pressure_head(1)=-100._real64
 c%root_radius_m=ieee_value(0._real64,ieee_quiet_nan)
 call run_runtime()
 if(status==FMR_BARTHOLOMEUS_EXEC_OK) error stop 25
 if(allocated(out%root_extraction_sink)) error stop 26
 c%root_radius_m=.0002_real64
 c%q10_root=ieee_value(0._real64,ieee_positive_inf)
 call run_runtime()
 if(status==FMR_BARTHOLOMEUS_EXEC_OK) error stop 27
 c%q10_root=2._real64
 h%water_content(1)=ieee_value(0._real64,ieee_quiet_nan)
 call run_runtime()
 if(status/=FMR_BARTHOLOMEUS_EXEC_INPUT) error stop 28
 h%water_content(1)=.30_real64
 print '(a)','C3A_NAN_INF_RUNTIME_REJECTION=PASS'
 ! Independent provider routes: no stress, rejected policy, malformed view and A/B/A.
 c%specific_resp_humus=0;wr=0;wr0=0
 call evaluate_bartholomeus_factors_from_state(v,d,c,wr,wr0,.275_real64,BARTHOLOMEUS_WATERFILM_REFERENCE,f,ok)
 if(.not.ok) error stop 34
 if(any(abs(f-1._real64)>0)) error stop 35
 call evaluate_bartholomeus_factors_from_state(v,d,c,wr,wr0,.275_real64,2,f,ok)
 if(ok) error stop 36
 v%rooted_nodes=3
 call evaluate_bartholomeus_factors_from_state(v,d,c,wr,wr0,.275_real64,1,f,ok)
 if(ok) error stop 37
 v%rooted_nodes=2
 c%specific_resp_humus=1.e-6_real64;wr=[1._real64,.8_real64];wr0=wr
 call evaluate_bartholomeus_factors_from_state(v,d,c,wr,wr0,.275_real64,1,f,ok)
 if(.not.ok) error stop 38
 expected(1:2)=f
 call evaluate_bartholomeus_factors_from_state(v,d,c,wr,wr0,ieee_value(0._real64,ieee_positive_inf),1,f,ok)
 if(ok) error stop 39
 call evaluate_bartholomeus_factors_from_state(v,d,c,wr,wr0,.275_real64,1,f,ok)
 if(.not.ok) error stop 40
 if(any(abs(f-expected(1:2))>0)) error stop 41
 print '(a)','C3A_NO_STRESS_POLICY_SHAPE_ABA=PASS'
 ! No demand and no roots preserve a single sink without reading unused owners.
 base%root_extraction_sink(1:2)=0;base%actual_uptake_total=3
 h%active_nodes=0
 call run_runtime()
 if(status/=FMR_BARTHOLOMEUS_EXEC_OK) error stop 29
 if(any(abs(out%root_extraction_sink-base%root_extraction_sink)>0)) error stop 30
 call fmr_apply_bartholomeus_to_root_sink(cfg,h,t,d,c,[real(real64)::],[real(real64)::], &
      .275_real64,base,out,status)
 if(status/=FMR_BARTHOLOMEUS_EXEC_OK) error stop 31
 if(any(abs(out%root_extraction_sink-base%root_extraction_sink)>0)) error stop 32
 cfg%oxygen_type=9
 call fmr_apply_bartholomeus_to_root_sink(cfg,h,t,d,c,[real(real64)::],[real(real64)::], &
      .275_real64,base,out,status)
 if(status/=FMR_BARTHOLOMEUS_EXEC_UNSUPPORTED) error stop 33
 print '(a)','C3A_NO_ROOT_ZERO_DEMAND_FAIL_CLOSED_SELECTION=PASS'
 print '(a)','PPA_WU05C3A_DYNAMIC_RUNTIME_BOUNDARIES=PASS'
contains
 subroutine run_runtime()
  call fmr_apply_bartholomeus_to_root_sink(cfg,h,t,d,c,wr,wr0,.275_real64,base,out,status)
 end subroutine
end program
