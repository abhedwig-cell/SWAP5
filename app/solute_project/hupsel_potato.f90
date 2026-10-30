! Original Hupsel dynamic potato/grass crop adapter. Existing WOFOST transaction owns all
! actual/potential/lifecycle/root/profile state; this module translates inputs
! and binds source daily weather to that owner and the incumbent water runtime.
module mod_hupsel_potato
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_MODEL_CERTIFICATE
 use mod_kernel_transactions
 use mod_fmr_serialized_reference_backend
 use mod_fmr_wofost_crop_transaction
 use mod_fmr_wofost_accepted_window_lineage
 use mod_wofost_rate_parameters
 use mod_wofost_rate_table
 use mod_wofost_crop_owner_state
 use mod_wofost_one_day_structural_evolution
 use mod_wofost_one_day_rate_state_view
 use mod_wofost_prepare_assimilation
 use mod_wofost_oxygen_respiration
 use mod_wofost_emergence_initialization,only:initialize_wofost_emergence_owner
 use mod_wofost_grass_development,only:grass_management_parameters_t,grass_management_continuation_t
 use mod_crop_lifecycle_continuation
 use mod_crop_lifecycle_daily_composition
 use mod_crop_germination_preflight
 use mod_crop_b111_pressure_head_average
 use mod_crop_root_depth_rate_owner
 use mod_crop_adaptive_root_profile_owner
 use mod_crop_root_biomass_distribution
 use mod_crop_solar_geometry
 use mod_pmdirect_swetr0_process
 use mod_fmr_bartholomeus_contract
 use mod_bartholomeus_parameter_contract,only:construct_bartholomeus_dataset
 use mod_b110_default_mvg_provider
 use mod_root_micro_de_willigen_process
 use mod_root_uptake_compensation,only:ROOT_COMP_OFF
 use mod_interception_source_window_runtime,only:initialize_interception_window
 implicit none
 private
 public::potato_crop_t
 type::potato_crop_t
  type(fmr_wofost_crop_transaction_state_t)::state
  type(fmr_wofost_crop_transaction_parameters_t)::parameters
  type(wofost_rate_parameter_bundle_t)::rates
  type(crop_root_depth_rate_parameters_t)::depth_parameters
  type(adaptive_root_profile_configuration_t)::profile_parameters
  type(fmr_bartholomeus_parameters_t)::oxygen
  type(micro_de_willigen_parameters_t)::micro
  type(pmdirect_swetr0_site_t)::site
  type(pmdirect_swetr0_canopy_t)::canopy
  type(wofost_rate_table_t)::height
  type(wofost_one_day_forcing_t)::daily_forcing
  type(grass_management_parameters_t)::grass_parameters
  integer(int64)::crop_identity=615002_int64
  logical::grass_mode=.false.
  real(real64)::crop_start=0d0,crop_end=0d0,next_crop_start=0d0
  real(real64)::tdwi=0d0,ssa=0d0,spa=0d0,kdir=0d0,kdif=0d0,siccaplai=0d0,initial_canopy_storage=0d0
  real(real64)::germ_optimal=0d0,germ_base=0d0,germ_teff=0d0,germ_dry=0d0,germ_wet=0d0,germ_a=0d0,germ_depth=0d0
  real(real64)::last_pressure=0d0,prepared_time=-1d0,saltmax=0d0,saltslope=0d0
  integer,allocatable::horizon_first(:)
  logical::initialized=.false.,active_today=.false.,schedule_enabled=.false.
 contains
  procedure::initialize=>initialize_potato
  procedure::day_begin=>potato_day_begin
  procedure::prepare=>prepare_potato
  procedure::day_end=>complete_potato_day
  procedure::export_state=>export_potato
  procedure::restore_state=>restore_potato
 end type
contains
 real(real64) function value(key)result(v)
  character(*),intent(in)::key
  call rdsdou(key,v)
 end function
 subroutine expect(key,expected)
  character(*),intent(in)::key
  integer,intent(in)::expected
  integer::v
  call rdsint(key,v)
  if(v/=expected)error stop 'original potato selector differs from implemented process'
 end subroutine
 subroutine table(key,t)
  character(*),intent(in)::key
  type(wofost_rate_table_t),intent(out)::t
  real(real64)::v(4096)
  integer::n,code
  call rdinne(key,n);call rdfdou(key,v,4096,n)
  call construct_wofost_rate_table(v(1:n:2),v(2:n:2),t,code)
  if(code/=0)error stop 'invalid original potato table'
 end subroutine
 subroutine initialize_potato(self,swp,crp,p,status,grass_mode)
  class(potato_crop_t),intent(inout)::self
  character(*),intent(in)::swp,crp
  type(fmr_b110_physical_parameters_t),intent(in)::p
  integer,intent(out)::status
  logical,intent(in),optional::grass_mode
  type(grass_management_continuation_t)::management
  type(wofost_rate_scalar_parameters_t)::s
  type(wofost_rate_parameter_tables_t)::t
  type(wofost_one_day_update_parameters_t)::updates
  type(crop_lifecycle_continuation_t)::lifecycle
  type(wofost_crop_owner_state_t)::owner
  type(b110_default_mvg_parameters_t),target::hp
  type(b110_default_mvg_provider_t)::hydraulic
  real(real64)::origin,finish,starts(64),ends(64),rds,potmul
  real(real64)::organic(256),sand(256),density(256)
  real(real64),allocatable::th100(:),th500(:),k(:),cap(:),dk(:)
  integer::counts(256),layers(256),node_layer(4096),sequence(4096),n,m,i,j,node,code,mode,crop_index
  logical::ok
  status=1;self%grass_mode=.false.;self%crop_identity=615002_int64
  if(present(grass_mode))self%grass_mode=grass_mode
  crop_index=2
  if(self%grass_mode)then
   crop_index=3;self%crop_identity=615003_int64
  end if
  if(.not.allocated(p%dz).or..not.allocated(p%z).or..not.allocated(p%cofgen))return
  n=size(p%dz);if(n<1.or.n>4096)return
  self%profile_parameters%dz_cm=p%dz;self%profile_parameters%ztop_cm=p%z+.5d0*p%dz
  self%profile_parameters%zbot_cm=p%z-.5d0*p%dz
  call rdinit(74,0,swp);call rdstim('tstart',origin);call rdatim('cropstart',starts,64,m)
  if(m<3)then;close(74);return;end if
  self%crop_start=starts(crop_index)-origin
  if(self%grass_mode)then
   call rdstim('tend',finish);self%next_crop_start=finish-origin+1d0
  else
   self%next_crop_start=starts(3)-origin
  end if
  call rdatim('cropend',ends,64,m)
  if(m<crop_index)then;close(74);return;end if
  self%crop_end=ends(crop_index)-origin
  self%site%latitude_degrees=value('lat');self%site%altitude_m=value('alt')
  self%site%wind_measurement_height_m=value('altw');self%site%humidity_measurement_height_m=value('alth')
  self%site%angstrom_a=value('angstroma');self%site%angstrom_b=value('angstromb')
  self%site%wind_function_factor=value('fwind');self%site%soil_surface_resistance_s_m=value('rsoil')
  rds=value('rds');call rdinne('ncomp',m);call rdfint('ncomp',counts,256,m);call rdfint('isoillay',layers,256,m)
  allocate(self%horizon_first(n));node=0
  do i=1,m
   do j=1,counts(i)
    node=node+1;if(node>n)then;close(74);return;end if
    node_layer(node)=layers(i);self%horizon_first(node)=node-j+1
   end do
  end do
  if(node/=n)then;close(74);return;end if
  m=maxval(node_layer(:n));call rdfdou('orgmat',organic,256,m);call rdfdou('psand',sand,256,m)
  call rdfdou('bdens',density,256,m);close(74)
  allocate(th100(n),th500(n),k(n),cap(n),dk(n))
  call initialize_b110_default_mvg_parameters(hp,p%cofgen,enable_ksatexm_extension=p%ksatexm_extension_active)
  call bind_b110_default_mvg_provider(hydraulic,hp,1d0)
  call hydraulic%evaluate(spread(-100d0,1,n),th100,k,cap,dk)
  call hydraulic%evaluate(spread(-500d0,1,n),th500,k,cap,dk)
  call construct_bartholomeus_dataset(p%cofgen,p%dz,organic(node_layer(:n)),sand(node_layer(:n)), &
       density(node_layer(:n)),th100,th500,th100,-100d0,-500d0,0,self%oxygen%soil,ok)
  if(.not.ok)return
  call rdinit(74,0,crp)
  if(self%grass_mode)then
   call expect('swwofost',3);call rdsint('swtsum',self%grass_parameters%development%temperature_start_mode)
   if(self%grass_parameters%development%temperature_start_mode/=1)then;close(74);return;end if
   s%grass_development=.true.;updates%grass_development=.true.
  else
   call expect('swprep',0);call expect('swsow',0);call expect('swgerm',2);call expect('swwofost',1)
  end if
  call expect('swcf',2);call expect('swinter',3);call expect('swrd',2);call expect('swrdc',1)
  call expect('swdmi2rd',2);call expect('swwrtnonox',1);call expect('swdrought',3)
  call expect('swoxygen',2);call expect('swsalinity',1);call expect('swco2',0);call expect('swcompensate',0)
  call expect('swo2ect',1);call expect('swalptot',1);call expect('swmxdrought',0)
  if(.not.self%grass_mode)then
   self%germ_optimal=value('tsumemeopt');self%germ_base=value('tbasem');self%germ_teff=value('teffmx')
   self%germ_dry=value('hdrygerm');self%germ_wet=value('hwetgerm');self%germ_a=value('agerm');self%germ_depth=value('zgerm')
   call rdsint('idsl',s%development_daylength_mode);s%daylength_upper_hours=value('dlo');s%daylength_lower_hours=value('dlc')
   s%vegetative_temperature_sum_required=value('tsumea');s%generative_temperature_sum_required=value('tsumam')
  end if
  s%diffuse_extinction_coefficient=value('kdif');s%initial_light_use_efficiency=value('eff')
  s%co2_to_dry_matter_fraction=value('cfrdm');s%attainable_yield_multiplier=value('relmf')
  s%conversion_efficiency_root=value('cvr');s%conversion_efficiency_leaf=value('cvl')
  s%conversion_efficiency_stem=value('cvs');s%conversion_efficiency_storage=value('cvo')
  s%respiration_temperature_q10=value('q10');s%maintenance_respiration_root=value('rmr')
  s%maintenance_respiration_leaf=value('rml');s%maintenance_respiration_stem=value('rms');s%maintenance_respiration_storage=value('rmo')
  s%maximum_leaf_relative_death_rate=value('perdl');s%leaf_age_base_temperature=value('tbase')
  s%maximum_relative_lai_growth_rate=value('rgrlai')
  if(.not.self%grass_mode)call table('dtsmtb',t%temperature_sum_increment)
  call table('amaxtb',t%maximum_assimilation)
  call table('tmpftb',t%daytime_temperature_factor);call table('tmnftb',t%minimum_temperature_factor)
  call table('rfsetb',t%maintenance_respiration_factor);call table('frtb',t%root_partition_fraction)
  call table('fltb',t%leaf_partition_fraction);call table('fstb',t%stem_partition_fraction);call table('fotb',t%storage_partition_fraction)
  call table('rdrrtb',t%relative_root_death_rate);call table('rdrstb',t%relative_stem_death_rate);call table('slatb',t%specific_leaf_area)
  call construct_wofost_rate_parameter_bundle(s,t,self%rates,code);if(code/=0)then;close(74);return;end if
  updates%development_stage_end=2d0
  if(.not.self%grass_mode)updates%development_stage_end=value('dvsend')
  updates%leaf_lifespan=value('span')
  self%tdwi=value('tdwi');self%ssa=value('ssa');self%spa=value('spa');self%kdir=value('kdir');self%kdif=s%diffuse_extinction_coefficient
  call table('chtb',self%height)
  self%depth_parameters%initial_root_depth_cm=value('rdi');self%depth_parameters%maximum_root_depth_cm=min(rds,value('rdc'))
  self%depth_parameters%maximum_daily_extension_cm=value('rri')
  self%depth_parameters%actual_extension_mode=CROP_ROOT_RATE_DROUGHT_SUPPLY
  self%depth_parameters%minimum_daily_extension_cm=value('rrimin');self%depth_parameters%extent_critical_fraction=value('extentcrit')
  self%depth_parameters%require_root_growth=.true.;self%depth_parameters%negligible_transpiration=1d-10
  self%depth_parameters%negligible_root_growth=1d-3;self%depth_parameters%negligible_extension=1d-6
  self%depth_parameters%anaerobic_extension_gate_enabled=.true.;self%depth_parameters%aeration_critical_factor=value('aeratecrit')
  self%profile_parameters%maximum_root_depth_cm=self%depth_parameters%maximum_root_depth_cm
  call table('rdctb',self%profile_parameters%initial_density)
  self%profile_parameters%adaptation%growth_adaptation_fraction=value('fgwrt')
  self%profile_parameters%adaptation%death_adaptation_fraction=value('fdwrt')
  self%profile_parameters%adaptation%minimum_root_biomass_per_cm=value('wrtmin')
  self%profile_parameters%adaptation%specific_root_length_m_per_kg=value('srl')
  self%oxygen%selection%oxygen_mode=2;self%oxygen%selection%oxygen_type=1
  self%oxygen%specific_root_length_m_kg=value('srl');self%oxygen%crop%root_radius_m=.01d0*value('rootradius')
  self%oxygen%crop%specific_resp_humus=value('specific_resp_humus');self%oxygen%crop%q10_microbial=value('q10_microbial')
  self%oxygen%crop%microbial_shape_m=.9d0;self%oxygen%crop%root_shape_m=.9d0
  self%oxygen%crop%q10_root=s%respiration_temperature_q10
  self%oxygen%crop%c_mroot=s%maintenance_respiration_root*32d0/30d0
  call self%rates%evaluate_maintenance_respiration_factor(0d0,self%oxygen%crop%f_senes,code)
  if(code/=0)then;close(74);return;end if
  self%oxygen%crop%max_resp_factor=1d0
  self%micro%root_radius_cm=value('rootradius');self%micro%root_conductance_cm_per_day=value('kroot')
  self%micro%stem_a0_per_day=value('lstem_a0');self%micro%stem_a1_per_cm=value('lstem_a1')
  self%micro%half_leaf_pressure_cm=abs(value('hlhalf'));self%micro%campbell_exponent=value('pcamp')
  self%micro%pressure_tolerance_cm=value('tol_2');self%micro%newton_tolerance_cm=value('mytolx')
  self%micro%residual_tolerance_cm_per_day=value('tolconv');call rdsint('ntrial',self%micro%max_iterations)
  self%micro%oxygen_mode=1;call rdsint('swtype_tred',self%micro%reduction_mode)
  self%saltmax=value('saltmax');self%saltslope=value('saltslope')
  self%canopy%albedo=value('albedo');self%canopy%dry_canopy_resistance_s_m=value('rsc')
  self%canopy%wet_canopy_resistance_s_m=value('rsw');self%canopy%use_crop_height_for_aerodynamics=.true.
  self%siccaplai=value('siccaplai');self%initial_canopy_storage=value('sicact')
  call rdsint('swpotrelmf',mode);potmul=1d0;if(mode==2)potmul=s%attainable_yield_multiplier
  if(self%grass_mode)then
   call expect('schedule',0);self%schedule_enabled=.false.
   call expect('swharvest',1);call expect('swlossmow',0)
   call rdinne('seqgrzmow',m)
   if(m<1.or.m>size(sequence))then;close(74);return;end if
   call rdfint('seqgrzmow',sequence,size(sequence),m)
   if(any(sequence(:m)/=2))then;close(74);return;end if
   self%grass_parameters%sequence_length=m
   call table('dmmowtb',self%grass_parameters%mowing_threshold)
   call table('delaymowtb',self%grass_parameters%regrowth_delay)
   call rdsint('mxgdmow',self%grass_parameters%max_growing_days)
   self%grass_parameters%mowing_residual=value('dmrestmow')
   if(.not.self%grass_parameters%ready())then;close(74);return;end if
  else
   call expect('schedule',1);self%schedule_enabled=.true.
  end if
  close(74)
  if(.not.self%micro%ready())return
  if(self%grass_mode)then
   call initialize_b111_crop_lifecycle(self%crop_identity,0,0,0,lifecycle,code);if(code/=0)return
   lifecycle%emerged=.true.
   if(.not.lifecycle%ready())return
   call initialize_wofost_emergence_owner(self%tdwi,self%rates,owner,code);if(code/=0)return
   call construct_fmr_wofost_crop_transaction_parameters(self%rates,updates,self%ssa,self%spa,self%parameters,code, &
        enable_potential_shadow=.true.,potential_attainable_multiplier=potmul,enable_anaerobic_root_growth_gate=.false., &
        aeration_critical_factor=self%depth_parameters%aeration_critical_factor,root_depth_parameters=self%depth_parameters, &
        root_profile_configuration=self%profile_parameters,grass_management_parameters=self%grass_parameters)
   if(code/=0)return
   call initialize_fmr_wofost_crop_transaction_state(owner,self%state,code,.true.,lifecycle,self%depth_parameters, &
        self%profile_parameters,grass_management=management)
  else
   call initialize_b111_crop_lifecycle(self%crop_identity,0,0,2,lifecycle,code);if(code/=0)return
   call construct_fmr_wofost_crop_transaction_parameters(self%rates,updates,self%ssa,self%spa,self%parameters,code, &
       enable_potential_shadow=.true.,potential_attainable_multiplier=potmul,enable_anaerobic_root_growth_gate=.false., &
       aeration_critical_factor=self%depth_parameters%aeration_critical_factor,root_depth_parameters=self%depth_parameters, &
       root_profile_configuration=self%profile_parameters)
  if(code/=0)return
  call initialize_fmr_wofost_crop_transaction_state(owner,self%state,code,.true.,lifecycle,self%depth_parameters,self%profile_parameters)
  end if
  if(code/=0)return
  self%initialized=.true.;status=0
 end subroutine initialize_potato
 subroutine potato_day_begin(self,time,water,status)
  class(potato_crop_t),intent(inout)::self
  real(real64),intent(in)::time
  type(kernel_committed_state_t),intent(in)::water
  integer,intent(out)::status
  type(crop_lifecycle_continuation_t)::lifecycle
  type(fmr_wofost_crop_transaction_state_t)::next
  type(kernel_parameter_identity_t)::identity
  class(transaction_state_t),allocatable::physical
  real(real64)::clock
  logical::ok
  integer::code
  status=1
  if(.not.self%initialized.or..not.self%state%ready().or..not.ieee_is_finite(time))return
  call water%current_time(clock,ok);if(.not.ok.or.clock/=time.or.time/=aint(time))return
  if(time<self%crop_start.or.time>=self%next_crop_start)return
  call self%state%snapshot_lifecycle(lifecycle,ok);if(.not.ok)return
  if(self%grass_mode)then
   if(.not.lifecycle%emerged.or.lifecycle%crop_identity/=self%crop_identity)return
   status=0;return
  end if
  if(lifecycle%germinated.and..not.lifecycle%emerged)then
   call prepare_fmr_wofost_morning_emergence(self%state,self%parameters,time,self%tdwi,next,code)
   if(code/=0)return
   self%state=next
  else if(.not.lifecycle%germinated.and.time<=self%crop_end)then
   call water%certified_parameter_identity(identity,ok);if(.not.ok)return
   call water%snapshot(physical,ok);if(.not.ok)return
   select type(q=>physical)
   class is(fmr_b110_physical_state_t)
    call compute_b111_pressure_head_average(self%germ_depth,identity%dz,q%pressure_head,self%last_pressure,code)
    if(code/=0)return
   class default
    return
   end select
  end if
  status=0
 end subroutine potato_day_begin
 subroutine prepare_potato(self,time,weather,p,forcing,daily,status)
  class(potato_crop_t),intent(inout)::self
  real(real64),intent(in)::time
  type(pmdirect_swetr0_weather_t),intent(in)::weather
  type(fmr_b110_physical_parameters_t),intent(inout)::p
  type(fmr_b110_physical_forcing_t),intent(inout)::forcing
  type(pmdirect_swetr0_daily_result_t),intent(out)::daily
  integer,intent(out)::status
  type(wofost_crop_owner_state_t)::owner,prepared
  type(wofost_one_day_window_context_t)::context
  type(wofost_one_day_rate_state_view_t)::view
  type(wofost_prepare_assimilation_forcing_t)::af
  type(wofost_prepare_assimilation_result_t)::assimilation
  type(wofost_oxygen_respiration_t)::respiration
  type(grass_management_continuation_t)::management
  type(crop_solar_geometry_t)::solar
  type(crop_root_depth_rate_state_t)::depth
  type(adaptive_root_profile_state_t)::profile
  type(crop_root_biomass_distribution_t)::distribution
  type(pmdirect_swetr0_diagnostics_t)::pm_status
  real(real64),allocatable::cumulative(:),lrv(:)
  logical::ok
  integer::n,rooted,code,regrowth_delay
  status=1;daily=pmdirect_swetr0_daily_result_t()
  if(.not.self%initialized.or.time<self%crop_start.or.time>=self%next_crop_start)return
  call self%state%snapshot_owner(owner,ok);if(.not.ok)return
  self%active_today=owner%crop_emerged.and.time<=self%crop_end
  n=size(p%dz);rooted=0
  self%daily_forcing=wofost_one_day_forcing_t()
  self%daily_forcing%calendar_day_of_year=weather%day_of_year
  self%daily_forcing%minimum_temperature=weather%minimum_air_temperature_c
  self%daily_forcing%average_temperature=.5d0*(weather%minimum_air_temperature_c+weather%maximum_air_temperature_c)
  self%daily_forcing%daytime_average_temperature=.5d0*(weather%maximum_air_temperature_c+self%daily_forcing%average_temperature)
  self%daily_forcing%global_radiation=weather%radiation_j_m2_d
  call evaluate_crop_solar_geometry(weather%day_of_year,self%site%latitude_degrees,weather%radiation_j_m2_d,solar,code)
  if(code/=0)return
  self%daily_forcing%daylength_hours=solar%daylength_hours;self%daily_forcing%photoperiodic_daylength_hours=solar%photoperiod_hours
  self%daily_forcing%sinld=solar%sine_offset;self%daily_forcing%cosld=solar%sine_amplitude
  self%daily_forcing%diffuse_perpendicular_radiation=solar%diffuse_perpendicular
  self%daily_forcing%daily_sine_solar_elevation_integral=solar%effective_solar_height
  self%canopy%crop_emerged=self%active_today;self%canopy%lai=0d0;self%canopy%vegetation_cover_fraction=0d0
  self%canopy%crop_height_cm=0d0
  p%root_extraction_active=.true.;p%root_compensation%method=ROOT_COMP_OFF
  p%micro_de_willigen=self%micro;p%micro_horizon_first_node=self%horizon_first
  p%bartholomeus=self%oxygen;p%root_salinity_active=.false.;p%reactive_salinity_active=.true.
  p%saltmax_mg_cm3=self%saltmax;p%saltslope_cm3_mg=self%saltslope
  if(allocated(forcing%substep_root))deallocate(forcing%substep_root)
  if(allocated(forcing%root_potential_sink))deallocate(forcing%root_potential_sink)
  forcing%root_extraction_sink=spread(0d0,1,n)
  forcing%micro_rooted_nodes=0;forcing%micro_root_length_density=spread(0d0,1,n)
  if(.not.allocated(forcing%crop_oxygen))allocate(forcing%crop_oxygen)
  forcing%crop_oxygen%air_temperature_c=self%daily_forcing%average_temperature
  forcing%crop_oxygen%root_density_kg_m3=spread(0d0,1,0)
  if(self%active_today)then
   call self%state%snapshot_root_depth(depth,ok);if(.not.ok)return
   call self%state%snapshot_root_profile(profile,ok);if(.not.ok)return
   rooted=self%profile_parameters%rooted_nodes(depth%actual_root_depth_cm);if(rooted<1)return
   call profile%cumulative_root_fraction(rooted,cumulative,code);if(code/=0)return
   call profile%root_length_density(rooted,p%dz,self%profile_parameters%adaptation,lrv,code);if(code/=0)return
   forcing%micro_rooted_nodes=rooted;forcing%micro_root_length_density=lrv
   call prepare_wofost_one_day_candidate(owner,self%daily_forcing,time,time+1d0,prepared,context,code, &
        grass_development=self%grass_mode)
   if(code/=0)return
   call assemble_wofost_one_day_rate_state_view(prepared,self%ssa,self%spa,view,ok,code)
   if(code/=0.or..not.ok)return
   af%daytime_mean_temperature=self%daily_forcing%daytime_average_temperature
   af%global_radiation=self%daily_forcing%global_radiation;af%daylength_hours=solar%daylength_hours
   af%sine_solar_height_offset=solar%sine_offset;af%sine_solar_height_amplitude=solar%sine_amplitude
   af%diffuse_irradiation_perpendicular=solar%diffuse_perpendicular;af%daily_effective_solar_height=solar%effective_solar_height
   af%running_minimum_temperature=context%running_minimum_temperature
   call prepare_wofost_actual_assimilation(view,self%rates,af,assimilation,code);if(code/=0)return
   regrowth_delay=0
   if(self%grass_mode)then
    call self%state%snapshot_grass_management(management,ok);if(.not.ok)return
    regrowth_delay=management%regrowth_delay_days
   end if
   call prepare_wofost_oxygen_respiration(view,self%rates,assimilation,self%daily_forcing%average_temperature, &
        regrowth_delay,respiration,code)
   if(code/=0)return
   p%bartholomeus%crop%q10_root=respiration%root_q10
   p%bartholomeus%crop%c_mroot=respiration%root_maintenance_coefficient
   p%bartholomeus%crop%f_senes=respiration%senescence_factor;p%bartholomeus%crop%max_resp_factor=respiration%maximum_respiration_factor
   call prepared%derive_bartholomeus_root_input(p%dz(:rooted),cumulative,self%oxygen%specific_root_length_m_kg, &
        self%daily_forcing%average_temperature,forcing%crop_oxygen,distribution,ok,code)
   if(code/=0.or..not.ok)return
   self%canopy%lai=view%actual_leaf_area_index
   self%canopy%vegetation_cover_fraction=1d0-exp(-self%kdir*self%kdif*self%canopy%lai)
   call self%height%evaluate(prepared%development_stage,self%canopy%crop_height_cm,code);if(code/=0)return
  end if
  call evaluate_pmdirect_swetr0_daily(weather,self%site,self%canopy,daily,pm_status)
  if(pm_status%status/=0)return
  forcing%root_potential_transpiration=daily%potential_transpiration_dry_cm_per_day
  forcing%root_drought_reduction_total=0d0;forcing%experimental_process_combinations=.true.
  if(.not.allocated(forcing%rutter))allocate(forcing%rutter)
  call initialize_interception_window(615200_int64+int(time,int64),time,time+1d0,weather%gross_rain_cm_d, &
       forcing%rutter%source_window,code)
  if(code/=0)return
  forcing%rutter%prepared=.true.
  forcing%rutter%process%vegetation_cover_fraction=self%canopy%vegetation_cover_fraction
  forcing%rutter%process%canopy_storage_capacity_cm=self%siccaplai*self%canopy%lai
  forcing%rutter%process%interception_evaporation_capacity_cm_per_day=daily%interception_evaporation_capacity_cm_per_day
  forcing%rutter%process%potential_transpiration_dry_cm_per_day=daily%potential_transpiration_dry_cm_per_day
  forcing%rutter%process%potential_transpiration_wet_cm_per_day=daily%potential_transpiration_wet_cm_per_day
  forcing%rutter%potential_bare_soil_evaporation_cm_per_day=daily%potential_soil_evaporation_cm_per_day
  forcing%rutter%potential_pond_evaporation_cm_per_day=daily%potential_pond_evaporation_cm_per_day
  self%prepared_time=time;status=0
 end subroutine prepare_potato
 subroutine complete_potato_day(self,time,water,window,status)
  class(potato_crop_t),intent(inout)::self
  real(real64),intent(in)::time
  type(kernel_committed_state_t),intent(in)::water
  type(fmr_wofost_accepted_window_t),intent(in)::window
  integer,intent(out)::status
  type(crop_lifecycle_continuation_t)::lifecycle
  type(crop_germination_candidate_t)::germination
  type(crop_daily_lifecycle_candidate_t)::plan
  type(fmr_wofost_crop_event_forcing_t)::event
  type(fmr_wofost_crop_transaction_model_t),target::model
  type(kernel_executor_t)::kernel
  type(kernel_committed_state_t)::committed
  type(kernel_checkpoint_t)::checkpoint
  type(kernel_candidate_state_t)::candidate
  type(kernel_result_t)::result
  type(kernel_diagnostics_t)::diagnostics
  type(canonical_numerical_config_t)::config
  class(transaction_state_t),allocatable::raw
  real(real64)::clock
  logical::ok,did_commit
  integer::code
  status=1
  if(.not.self%initialized.or.self%prepared_time/=time-1d0)return
  call water%current_time(clock,ok);if(.not.ok.or.clock/=time)return
  if(time>self%crop_end+1d0)then;status=0;return;end if
  if(.not.window%complete())return
  call self%state%snapshot_lifecycle(lifecycle,ok);if(.not.ok)return
  if(lifecycle%emerged)then
   call prepare_fmr_wofost_crop_event_forcing(window,self%daily_forcing,event,code,active_expected_revision=lifecycle%revision)
  else
   call propose_crop_germination(2,lifecycle%germination_temperature_sum,self%germ_optimal,self%germ_base,self%germ_teff, &
        self%daily_forcing%average_temperature,self%last_pressure,self%germ_dry,self%germ_wet,self%germ_a,germination,code)
   if(code/=0)return
   plan%valid=.true.;plan%initialization_profile=CROP_PROFILE_B111_TASK2
   plan%prepared=.true.;plan%sown=.true.;plan%germination_evaluated=.true.
   plan%germinated=germination%complete;plan%emergence_eligible=germination%complete
   call prepare_fmr_wofost_crop_event_forcing(window,self%daily_forcing,event,code,plan,germination,lifecycle%revision)
  end if
  if(code/=0)return
  call self%state%clone(raw);call committed%initialize(self%crop_identity,raw,ok,time-1d0);if(.not.ok)return
  call committed%capture_checkpoint(checkpoint,ok);if(.not.ok)return
  config%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE;config%transaction%temporal_tolerance=0d0
  config%transaction%mass_tolerance=0d0;config%transaction%max_retries=0;config%max_committed_substeps=1;config%progress_tolerance=0d0
  call kernel%bind_model(model)
  call kernel%advance_interval(self%parameters,committed,event,config,time-1d0,time,result,candidate,diagnostics,checkpoint)
  if(.not.result%completed.or..not.candidate%ready())then
   status=100+model%last_status_code();return
  end if
  call kernel%commit_candidate(committed,candidate,diagnostics,did_commit,code)
  if(.not.did_commit.or.code/=0)return
  call committed%snapshot(raw,ok);if(.not.ok)return
  select type(q=>raw)
  type is(fmr_wofost_crop_transaction_state_t)
   self%state=q
  class default
   return
  end select
  status=0
 end subroutine complete_potato_day
 subroutine export_potato(self,view,status)
  class(potato_crop_t),intent(in)::self
  type(fmr_wofost_crop_transaction_persistence_t),intent(out)::view
  integer,intent(out)::status
  logical::ok
  call export_fmr_wofost_crop_transaction_persistence(self%state,view,ok,status)
  if(.not.ok)status=1
 end subroutine export_potato
 subroutine restore_potato(self,view,status)
  class(potato_crop_t),intent(inout)::self
  type(fmr_wofost_crop_transaction_persistence_t),intent(in)::view
  integer,intent(out)::status
  type(fmr_wofost_crop_transaction_state_t)::candidate
  logical::ok
  status=1;if(.not.self%initialized)return
  if(view%grass_management_present.neqv.self%grass_mode)return
  if(.not.view%lifecycle_present)return
  if(view%lifecycle%crop_identity/=self%crop_identity)return
  if(self%grass_mode)then
   if(.not.view%lifecycle%emerged)return
   if(max(view%grass_management%cut_index,view%grass_management%potential_cut_index)> &
        self%grass_parameters%sequence_length)return
  end if
  call reconstruct_fmr_wofost_crop_transaction_from_persistence(view,candidate,ok,status)
  if(.not.ok.or.status/=0)return
  if(view%root_profile_present)then
   if(size(view%root_profile%root_biomass_by_node)/=size(self%profile_parameters%dz_cm))then;status=1;return;end if
  end if
  if(view%root_depth_present)then
   if(max(view%root_depth%actual_root_depth_cm,view%root_depth%potential_root_depth_cm)> &
        self%depth_parameters%maximum_root_depth_cm)then;status=1;return;end if
  end if
  self%state=candidate;status=0
 end subroutine restore_potato
end module mod_hupsel_potato
