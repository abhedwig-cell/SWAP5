program benchmark_bartholomeus_e2e
 use iso_fortran_env,only:real64,int64
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_fmr_runtime_core
 use mod_fmr_serialized_reference_backend
 use mod_transaction_reference,only:TX_TEMPORAL_MODEL_CERTIFICATE
 use mod_fmr_production_application_bootstrap
 use mod_fmr_serialized_multiswap_runtime,only:fmr_serialized_column_result_t
 use mod_b110_default_mvg_provider
 use mod_restricted_soil_temperature
 use mod_bartholomeus_parameter_contract
 use mod_crop_bartholomeus_input
 use mod_root_water_uptake_process
 use mod_bartholomeus_runtime_input,only:bartholomeus_runtime_view_t
 use mod_bartholomeus_no_stress_gate,only:bartholomeus_macro_supply_bound_no_stress
 use mod_process_hydraulic_view
 implicit none
 integer,parameter::WARM=1,REPS=200,ROUNDS=3,NREG=4,NDENS=5
 real(real64),parameter::T0=5100.1875_real64,T1=T0+1.e-5_real64,HARD_MASS_GATE=1.e-12_real64
 real(real64),parameter::REG_HEAD(NREG)=[-75._real64,-150._real64,-300._real64,-600._real64]
 real(real64),parameter::DENS_SCALE(NDENS)=[0.01_real64,0.03_real64,0.1_real64,0.3_real64,1.0_real64]
 type(fmr_production_application_config_t)::cfg,off
 type(fmr_production_application_bootstrap_t)::app,offapp
 type(fmr_serialized_column_result_t),allocatable::r(:)
 real(real64)::ton(ROUNDS),toff(ROUNDS),t0c,t1c,k
 integer::i,j,rate,status,rep,reg,ids
 type(bartholomeus_runtime_view_t)::gate_view
 real(real64),allocatable::gate_w_root(:)
 real(real64)::gate_ctop
 logical::gate_skip
 call system_clock(i,rate)
 do reg=1,NREG
  do ids=1,NDENS
   call initialize_application_config(cfg,REG_HEAD(reg),k);call add_root_thermal_oxygen(cfg)
   cfg%tiles(1)%base_forcing%crop_oxygen%root_density_kg_m3 = &
        cfg%tiles(1)%base_forcing%crop_oxygen%root_density_kg_m3*DENS_SCALE(ids)
   off=cfg;off%tiles(1)%parameters%bartholomeus%selection%oxygen_mode=0
   call build_initial_gate_diagnostic(cfg,gate_view,gate_w_root,gate_ctop,gate_skip)
   do j=1,ROUNDS
    call system_clock(i);t0c=real(i,real64)
    do rep=1,REPS
     call app%initialize(cfg,i);if(i/=FMR_APP_BOOT_OK)error stop 'active init'
     call app%run_standalone(T0,T1,r,i);if(i/=FMR_APP_BOOT_OK)error stop 'active run'
     call app%close(i)
    enddo
    call system_clock(i);t1c=real(i,real64);ton(j)=(t1c-t0c)*1.e9_real64/(real(rate,real64)*REPS)
    call system_clock(i);t0c=real(i,real64)
    do rep=1,REPS
     call offapp%initialize(off,i);if(i/=FMR_APP_BOOT_OK)error stop 'off init'
     call offapp%run_standalone(T0,T1,r,i);if(i/=FMR_APP_BOOT_OK)error stop 'off run'
     call offapp%close(i)
    enddo
    call system_clock(i);t1c=real(i,real64);toff(j)=(t1c-t0c)*1.e9_real64/(real(rate,real64)*REPS)
   enddo
   call sort_values(ton);call sort_values(toff)
   print '(a,es12.4,a,es10.3,a,l1,a,es14.6,a,es14.6,a,es14.6)','E2E_MATRIX_HEAD=',REG_HEAD(reg), &
        ' DENS_SCALE=',DENS_SCALE(ids),' SKIP=',gate_skip,' ON_NS=',ton(2),' OFF_NS=',toff(2),' RATIO=',ton(2)/toff(2)
  enddo
 enddo
contains
  subroutine sort_values(x)
    real(real64),intent(inout)::x(:)
    real(real64)::tmp
    integer::a,b
    do a=1,size(x)-1
      do b=a+1,size(x)
        if(x(b)<x(a)) then;tmp=x(a);x(a)=x(b);x(b)=tmp;endif
      enddo
    enddo
  end subroutine sort_values

  subroutine build_initial_gate_diagnostic(value,view,wroot,ctop,skip)
    type(fmr_production_application_config_t),intent(in)::value
    type(bartholomeus_runtime_view_t),intent(out)::view
    real(real64),allocatable,intent(out)::wroot(:)
    real(real64),intent(out)::ctop
    logical,intent(out)::skip
    integer::n
    n=size(value%tiles(1)%base_forcing%crop_oxygen%root_density_kg_m3)
    view%rooted_nodes=n
    allocate(view%pressure_head_cm(n),view%water_content(n),view%soil_temperature_k(n),wroot(n))
    view%pressure_head_cm=value%tiles(1)%initial_state%pressure_head(1:n)
    view%water_content=value%tiles(1)%initial_state%water_content(1:n)
    view%soil_temperature_k=293.0_real64
    wroot=1.0_real64/value%tiles(1)%parameters%bartholomeus%specific_root_length_m_kg
    ctop=672.0_real64/(8.314472_real64*(value%tiles(1)%base_forcing%crop_oxygen%air_temperature_c+273.0_real64))
    skip=bartholomeus_macro_supply_bound_no_stress(view,value%tiles(1)%parameters%bartholomeus%soil, &
         value%tiles(1)%parameters%bartholomeus%crop,wroot,value%tiles(1)%base_forcing%crop_oxygen%root_density_kg_m3,ctop)
  end subroutine build_initial_gate_diagnostic

  subroutine initialize_application_config(value, initial_head, conductivity0)
    type(fmr_production_application_config_t), intent(out) :: value
    real(real64), intent(in) :: initial_head
    real(real64), intent(out) :: conductivity0

    value%initial_time = T0
    value%numerical%transaction%temporal_tolerance = 0.0_real64
    value%numerical%transaction%mass_tolerance = HARD_MASS_GATE
    value%numerical%transaction%retry_scale = 0.5_real64
    value%numerical%transaction%max_retries = 2
    value%numerical%max_committed_substeps = 8
    value%numerical%progress_tolerance = 0.0_real64

    allocate(value%tiles(1))
    value%tiles(1)%tile_id = 660101_int64
    value%tiles(1)%ledger_id = 760101_int64
    value%tiles(1)%template%template_id = 660201_int64
    value%tiles(1)%template%physics_topology_id = 660210_int64
    value%tiles(1)%template%vertical_layout_id = 660220_int64
    value%tiles(1)%template%state_layout_id = 660230_int64
    value%tiles(1)%template%solver_interface_id = 660240_int64
    value%tiles(1)%template%optional_state_layout_id = 0_int64
    value%tiles(1)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    call initialize_parameters(value%tiles(1)%parameters, 670001_int64)
    call initialize_state_and_forcing(value%tiles(1)%parameters, value%tiles(1)%initial_state, &
         value%tiles(1)%base_forcing, initial_head, conductivity0)
  end subroutine initialize_application_config

  subroutine initialize_parameters(p, parameter_id)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer(int64), intent(in) :: parameter_id
    integer :: k

    p%parameter_set_id = parameter_id
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24, numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k) = 0.032_real64
      p%cofgen(2,k) = 0.423_real64
      p%cofgen(3,k) = 4.75_real64
      p%cofgen(4,k) = 0.0135_real64
      p%cofgen(5,k) = 0.365_real64
      p%cofgen(6,k) = 1.455_real64
      p%cofgen(7,k) = 1.0_real64 - 1.0_real64 / p%cofgen(6,k)
      p%cofgen(8,k) = p%cofgen(4,k)
      p%cofgen(10,k) = p%cofgen(3,k)
      p%cofgen(11,k) = 0.999_real64
      p%cofgen(12,k) = 0.99_real64 * p%cofgen(3,k)
      p%cofgen(22,k) = -1.0e6_real64
      p%cofgen(23,k) = 1.0e-12_real64
    end do
    p%bottom_mode = 2
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%max_iterations = 8
    p%max_backtracking = 4
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_state_and_forcing(p, state, forcing, initial_head, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: initial_head
    real(real64), intent(out) :: conductivity0

    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    heads = initial_head
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, T1 - T0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    forcing%top_flux=-conductivity0;forcing%top_head=initial_head;forcing%bottom_flux=-conductivity0;forcing%bottom_head=-100._real64
    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod),forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level=0;forcing%subsurface_irrigation_source=0;forcing%root_extraction_sink=0
  end subroutine initialize_state_and_forcing

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
   if(.not.valid) error stop 'oxygen dataset'
   p%crop%c_mroot=1e-5;p%crop%f_senes=1;p%crop%q10_root=2;p%crop%specific_resp_humus=1e-6;p%crop%q10_microbial=2;p%crop%microbial_shape_m=.9;p%crop%root_shape_m=.9;p%crop%root_radius_m=.0002;p%crop%max_resp_factor=2
  end associate
  call publish_crop_bartholomeus_input([1._real64,.8_real64,.6_real64],20._real64,value%tiles(1)%base_forcing%crop_oxygen,valid);if(.not.valid) error stop 'crop oxygen'
  rp%active_nodes=numnod;rp%hlim3l=-500;rp%hlim3h=-300;rp%hlim4=-16000;rp%adcrl=.1_real64;rp%adcrh=.5_real64
  rq%rooted_nodes=3;rq%potential_transpiration=.03_real64;rq%cumulative_root_fraction=[0._real64,.4_real64,.8_real64,1._real64]
  view%active_nodes=numnod;view%pressure_head=value%tiles(1)%initial_state%pressure_head;view%water_content=value%tiles(1)%initial_state%water_content
  call evaluate_macro_feddes_drought_uptake(rp,view,rq,rf,rd);if(rd%status/=ROOT_UPTAKE_OK) error stop 'drought owner';value%tiles(1)%base_forcing%root_extraction_sink=rf%root_extraction_sink
  value%tiles(1)%base_forcing%root_extraction_sink(4)=.005_real64
  value%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  value%tiles(1)%initial_right_derivative=spread(0._real64,1,numnod)
  value%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  value%numerical%transaction%temporal_tolerance=1._real64
  value%numerical%model_temporal_indicator_budget_available=.true.
  value%numerical%model_temporal_indicator_budget=.01_real64
 end subroutine
end program
