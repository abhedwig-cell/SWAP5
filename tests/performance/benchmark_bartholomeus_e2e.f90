program benchmark_bartholomeus_e2e
 use iso_fortran_env,only:real64
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_fmr_runtime_core
 use mod_fmr_production_application_bootstrap
 use mod_fmr_serialized_multiswap_runtime,only:fmr_serialized_column_result_t
 use mod_b110_default_mvg_provider
 use mod_restricted_soil_temperature
 use mod_bartholomeus_parameter_contract
 use mod_crop_bartholomeus_input
 use mod_root_water_uptake_process
 use mod_process_hydraulic_view
 implicit none
 integer,parameter::WARM=100,REPS=2000,ROUNDS=7
 real(real64),parameter::T0=5100.1875_real64,T1=T0+1.e-5_real64
 type(fmr_production_application_config_t)::cfg,off
 type(fmr_production_application_bootstrap_t)::app,offapp
 type(fmr_serialized_column_result_t),allocatable::r(:)
 real(real64)::ton(ROUNDS),toff(ROUNDS),t0c,t1c,k
 integer::i,j,rate,status
 call initialize_application_config(cfg,-75._real64,k);call add_root_thermal_oxygen(cfg)
 off=cfg;off%tiles(1)%parameters%bartholomeus%selection%oxygen_mode=0
 call app%initialize(cfg,status);if(status/=FMR_APP_BOOT_OK)error stop 'active init'
 call offapp%initialize(off,status);if(status/=FMR_APP_BOOT_OK)error stop 'off init'
 do i=1,WARM
  call app%run_standalone(T0,T1,r,status);if(status/=FMR_APP_BOOT_OK)error stop 'active warm'
  call offapp%run_standalone(T0,T1,r,status);if(status/=FMR_APP_BOOT_OK)error stop 'off warm'
 end do
 do j=1,ROUNDS
  if(mod(j,2)==1)then
   call timed_active(ton(j));call timed_off(toff(j))
  else
   call timed_off(toff(j));call timed_active(ton(j))
  endif
  print '(a,i0,a,es24.16,a,es24.16,a,es24.16)','E2E_ROUND=',j,' ON_NS=',ton(j),' OFF_NS=',toff(j),' RATIO=',ton(j)/toff(j)
 enddo
 call app%close(status);call offapp%close(status)
contains
 subroutine timed_active(ns)
  real(real64),intent(out)::ns
  integer::q
  call system_clock(q,rate);t0c=real(q,real64)
  do i=1,REPS
   call app%run_standalone(T0,T1,r,status);if(status/=FMR_APP_BOOT_OK)error stop 'active'
  enddo
  call system_clock(q);t1c=real(q,real64);ns=(t1c-t0c)*1.e9_real64/(real(rate,real64)*REPS)
 end subroutine
 subroutine timed_off(ns)
  real(real64),intent(out)::ns
  integer::q
  call system_clock(q,rate);t0c=real(q,real64)
  do i=1,REPS
   call offapp%run_standalone(T0,T1,r,status);if(status/=FMR_APP_BOOT_OK)error stop 'off'
  enddo
  call system_clock(q);t1c=real(q,real64);ns=(t1c-t0c)*1.e9_real64/(real(rate,real64)*REPS)
 end subroutine
 subroutine add_root_thermal_oxygen(value)
  type(fmr_production_application_config_t),intent(inout)::value
  type(b110_default_mvg_parameters_t),target::hp
  type(b110_default_mvg_provider_t)::hydraulic
  type(root_water_uptake_parameters_t)::rp
  type(root_water_uptake_request_t)::rq
  type(root_water_uptake_flux_result_t)::rf
  type(root_water_uptake_diagnostics_t)::rd
  type(process_hydraulic_view_t)::view
  real(real64)::heads(numnod),w100(numnod),w500(numnod),conductivity(numnod),capacity(numnod),dk(numnod)
  integer::s;logical::valid
  value%tiles(1)%ledger_id=0
  value%tiles(1)%parameters%root_extraction_active=.true.;value%tiles(1)%parameters%soil_temperature_active=.true.
  value%tiles(1)%template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  allocate(value%tiles(1)%parameters%soil_temperature,value%tiles(1)%initial_state%soil_temperature,value%tiles(1)%base_forcing%soil_temperature,value%tiles(1)%parameters%bartholomeus,value%tiles(1)%base_forcing%crop_oxygen)
  call initialize_soil_temperature_parameters(dz,disnod(1:numnod),value%tiles(1)%parameters%cofgen(2,:),spread(.3_real64,1,numnod),spread(.2_real64,1,numnod),spread(.04_real64,1,numnod),value%tiles(1)%parameters%soil_temperature,s)
  call initialize_soil_temperature_state(spread(20._real64,1,numnod),value%tiles(1)%initial_state%soil_temperature,s)
  value%tiles(1)%base_forcing%soil_temperature%prescribed_surface_temperature_c=20
  call initialize_b110_default_mvg_parameters(hp,value%tiles(1)%parameters%cofgen);call bind_b110_default_mvg_provider(hydraulic,hp,T1-T0)
  heads=-100;call hydraulic%evaluate(heads,w100,conductivity,capacity,dk);heads=-500;call hydraulic%evaluate(heads,w500,conductivity,capacity,dk)
  associate(p=>value%tiles(1)%parameters%bartholomeus)
   p%selection%oxygen_mode=2;p%selection%oxygen_type=1;p%specific_root_length_m_kg=1
   call construct_bartholomeus_dataset(value%tiles(1)%parameters%cofgen,dz,spread(.02_real64,1,numnod),spread(.6_real64,1,numnod),spread(1300._real64,1,numnod),w100,w500,w100,-100._real64,-500._real64,0,p%soil,valid)
   p%crop%c_mroot=1e-5;p%crop%f_senes=1;p%crop%q10_root=2;p%crop%specific_resp_humus=1e-6;p%crop%q10_microbial=2;p%crop%microbial_shape_m=.9;p%crop%root_shape_m=.9;p%crop%root_radius_m=.0002;p%crop%max_resp_factor=2
  end associate
  call publish_crop_bartholomeus_input([1._real64,.8_real64,.6_real64],20._real64,value%tiles(1)%base_forcing%crop_oxygen,valid)
  rp%active_nodes=numnod;rp%hlim3l=-500;rp%hlim3h=-100;rp%hlim4=-16000;rp%hlim2u=-25;rp%hlim2l=-25
  call bind_process_hydraulic_view(value%tiles(1)%initial_state,view,valid);rq%potential_transpiration=0.2_real64;rq%root_fraction=0;rq%root_fraction(1:3)=[.4_real64,.35_real64,.25_real64]
  call evaluate_root_water_uptake(rp,rq,view,rf,rd);value%tiles(1)%base_forcing%root_extraction_sink=rf%extraction_sink
 end subroutine
end program
