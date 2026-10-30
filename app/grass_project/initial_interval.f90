! Original Grassgrowth startup through existing Reference process/state owners.
! Source grass growth, potential biomass, root depth and water publish atomically.
! Source selectors/parameters are read natively; no original model core is linked.
program grass_initial_interval
 use iso_fortran_env,only:real64,int64
 use MOD_grid,only:numnod,z,dz,disnod
 use solute_column_context,only:initialize_column_context
 use mod_column_swp_water
 use mod_column_swp_heat
 use mod_b110_default_mvg_provider
 use mod_bartholomeus_parameter_contract
 use mod_root_water_uptake_process
 use mod_crop_root_profile_static
 use mod_wofost_rate_parameters
 use mod_wofost_rate_table
 use mod_wofost_emergence_initialization
 use mod_wofost_crop_owner_state
 use mod_wofost_one_day_rate_state_view
 use mod_wofost_one_day_structural_evolution
 use mod_wofost_prepare_assimilation
 use mod_wofost_grass_development
 use mod_wofost_potential_shadow_state
 use mod_crop_root_depth_rate_owner
 use mod_wofost_grass_daily_growth
 use mod_wofost_finalize_rates,only:wofost_finalize_rate_forcing_t
 use mod_wofost_oxygen_respiration
 use mod_crop_root_biomass_distribution
 use mod_crop_bartholomeus_input
 use mod_crop_solar_geometry
 use mod_pmdirect_swetr0_process
 use mod_grass_prefix_restart_file
 use mod_daily_rain_duration
 use mod_fmr_runtime_core
 use mod_fmr_serialized_reference_backend
 use mod_fmr_drainage_response_binding,only:FMR_DRAIN_VARIANT_DRAMET3
 use mod_drainage_dramet3_response,only:initialize_dramet3_channel_control
 use mod_restricted_surface_evaporation,only:boesten_evaporation_state_t
 use mod_fixed_flux_top_boundary_provider
 use mod_canonical_contracts
 use mod_kernel_transactions
 use mod_transaction_reference,only:TX_TEMPORAL_EXTERNAL_FULL_HALF
 use mod_transaction_reference,only:transaction_state_t
 use mod_soil_temperature_contract
 implicit none
 type(fmr_b110_physical_parameters_t),target::p
 type(fmr_b110_physical_state_t)::initial
 type(fmr_b110_physical_forcing_t)::forcing
 type(fmr_serialized_reference_backend_t)::backend
 type(fixed_flux_top_boundary_provider_t),target::top
 type(kernel_committed_state_t)::water,day_water
 type(kernel_checkpoint_t)::checkpoint
 type(kernel_candidate_state_t)::candidate
 type(kernel_result_t)::result
 type(kernel_diagnostics_t)::diagnostic
 type(canonical_numerical_config_t)::numerical
 type(fmr_logical_column_t)::column
 type(fmr_template_t)::template
 type(fmr_serialized_physical_observation_t)::observation
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t)::hydraulic
 type(wofost_rate_scalar_parameters_t)::scalars
 type(wofost_rate_parameter_tables_t)::tables
 type(wofost_rate_parameter_bundle_t)::bundle
 type(wofost_crop_owner_state_t)::crop,prepared,crop_candidate,day_crop
 type(wofost_potential_shadow_state_t)::potential,day_potential_crop
 type(wofost_crop_owner_state_t)::potential_owner,potential_prepared,potential_candidate
 type(wofost_one_day_rate_state_view_t)::potential_view
 type(wofost_one_day_window_context_t)::potential_context
 type(wofost_prepare_assimilation_result_t)::potential_assimilation
 type(wofost_one_day_rate_packet_t)::potential_rates
 type(wofost_accepted_window_aggregates_t)::potential_aggregates
 type(crop_root_depth_rate_parameters_t)::root_parameters
 type(crop_root_depth_rate_state_t)::root_state,day_roots
 type(crop_root_depth_rate_daily_forcing_t)::root_forcing
 type(crop_root_depth_rate_diagnostics_t)::root_diagnostic
 real(real64)::potential_management_factor,deepest_oxygen_integral
 integer::crop_log
 type(grass_development_parameters_t)::development_parameters
 type(grass_management_continuation_t)::management,day_management,potential_management
 type(grass_development_candidate_t)::development,potential_development
 type(wofost_one_day_update_parameters_t)::updates
 type(wofost_accepted_window_aggregates_t)::aggregates
 type(wofost_one_day_rate_packet_t)::rates
 type(wofost_finalize_rate_forcing_t)::crop_forcing
 type(wofost_one_day_forcing_t)::crop_weather
 type(wofost_one_day_window_context_t)::crop_day
 type(wofost_one_day_rate_state_view_t)::crop_view
 type(wofost_prepare_assimilation_forcing_t)::assimilation_forcing
 type(wofost_prepare_assimilation_result_t)::assimilation
 type(wofost_oxygen_respiration_t)::respiration
 type(crop_root_biomass_distribution_t)::roots
 type(wofost_rate_table_t)::root_table,height_table,delay_table
 type(crop_solar_geometry_t)::solar
 type(pmdirect_swetr0_weather_t)::weather
 type(pmdirect_swetr0_site_t)::site
 type(pmdirect_swetr0_canopy_t)::canopy
 type(pmdirect_swetr0_daily_result_t)::et
 type(pmdirect_swetr0_interval_result_t)::interception
 type(pmdirect_swetr0_diagnostics_t)::et_diagnostic
 class(transaction_state_t),allocatable::accepted
 type(soil_temperature_field_view_t)::heat_view
 real(real64)::width(256),source_pond,source_gwl,origin,limit,wet_duration,rain_rate,tdwi,ssa,spa,kdir,rdi,rdc
 real(real64)::times(1024),levels(1024),flat(2048),sand(256),organic(256),density(256),ani(256),root_srl
 real(real64)::metrad(10000),tmn(10000),tmx(10000),humidity(10000),wind(10000),rain(10000),wet(10000)
 real(real64)::surface_resistance,spacing,depth,drainres,infres,date_time,first_end
 real(real64)::clock,cursor,edge,day_end,step_dt,heat_residual,day_residual,day_in,day_out,day_start_water,day_final_water
 real(real64)::day_potential,day_actual,day_drought,day_oxygen
 integer::day_index,weather_count,budget,accepted_steps,trace_index,source_maxit,source_maxbacktrack
 real(real64)::source_dtmax,segment_rain_rate,project_end,mowing_residual,harvested,potential_harvested,delay_value
 real(real64)::harvest_dates(1024),season_start(16),season_end(16)
 integer::season_count,season_index,harvest_count,harvest_types(1024),day_of_year
 real(real64)::year_origin
 real(real64),allocatable::heads(:),cofgen(:,:),conductivity(:),capacity(:),derivative(:),theta100(:),theta500(:)
 real(real64),allocatable::node_sand(:),node_organic(:),node_density(:),cumulative(:)
 integer::nodes,n,m,i,j,k,code,rooted,layers(256),counts(256),node_layer(256),dd(10000),mm(10000),yyyy(10000),date(6),mode,u
 logical::available,committed,rdinqr
 character(64)::arg
 character(1024)::restart_path
 limit=.01d0
 call get_command_argument(1,arg)
 if(len_trim(arg)>0)read(arg,*)limit
 call get_command_argument(2,arg)
 call require(len_trim(arg)==0.or.trim(arg)=='retain-step','unknown numerical execution policy')
 numerical%retain_accepted_step_proposal=trim(arg)=='retain-step'
 call require(limit>0d0.and.limit<=1827d0,'original project horizon')
 call rdinit(74,0,'input.swp')
 call expect('swcrop',1);call expect('swetr',0);call expect('swdivide',1);call expect('swrain',2)
 call expect('swmetdetail',0);call expect('swmacro',0);call expect('swsnow',0);call expect('swfrost',0)
 call expect('swsolu',0);call expect('swhyst',0);call expect('swhea',1);call expect('swcalt',2)
 call expect('swredu',2);call expect('swdra',1);call expect('swirfix',0);call expect('swpondmx',0)
 call rdstim('tstart',origin);call rdstim('tend',project_end)
 call rdatim('cropstart',season_start,16,season_count);call rdatim('cropend',season_end,16,n)
 call require(n==season_count.and.n==5,'original five grass seasons')
 call rdfint('croptype',counts,256,n);call require(n==5.and.all(counts(:n)==2),'original detailed grass rotation')
 call rdsinr('maxit',5,100,source_maxit);call rdsinr('maxbacktr',1,10,source_maxbacktrack)
 call rdsdor('dtmax',1d-7,1d0,source_dtmax)
 site%latitude_degrees=value('lat');site%altitude_m=value('alt')
 site%wind_measurement_height_m=value('altw');site%humidity_measurement_height_m=value('alth')
 site%angstrom_a=value('angstroma');site%angstrom_b=value('angstromb');site%wind_function_factor=value('fwind')
 site%soil_surface_resistance_s_m=value('rsoil')
 allocate(p%boesten_evaporation,forcing%boesten_evaporation)
 p%boesten_evaporation_active=.true.;p%boesten_evaporation%cofred=value('cofred')
 forcing%boesten_evaporation%ponding_max_cm=value('pondmx')
 forcing%boesten_evaporation%runoff_resistance_day=value('rsro')
 forcing%boesten_evaporation%runoff_exponent=value('rsroexp')
 call rdinne('ncomp',n);call rdfint('ncomp',counts,256,n);call rdfint('isoillay',layers,256,n)
 k=0
 do i=1,n
  do j=1,counts(i)
   k=k+1;node_layer(k)=layers(i)
  end do
 end do
 m=maxval(layers(:n));call rdfdou('psand',sand,256,m);call rdfdou('orgmat',organic,256,m)
 call rdfdou('bdens',density,256,m);close(74)
 call rdinit(74,0,'swap.bbc');call expect('swbotb',1)
 call rdatim('date1',times,1024,n);call rdfdou('gwlevel',levels,1024,n);close(74)
 allocate(forcing%prescribed_groundwater_control)
 call forcing%prescribed_groundwater_control%initialize(times(:n),levels(:n),0d0,origin,0d0,project_end-origin+1d0,code)
 call require(code==0,'source prescribed groundwater table')
 source_gwl=levels(1)
 call import_column_swp_water('input.swp',nodes,width,heads,cofgen,source_pond,initial_bottom_mode=1, &
   allow_ksatexm=.true.,allow_prescribed_groundwater=.true.,initial_groundwater_cm=source_gwl)
 call require(nodes==113.and.sum(width(:nodes))==600d0,'original Grassgrowth geometry')
 call initialize_column_context(width(:nodes))
 p%parameter_set_id=613001_int64;p%active_nodes=nodes;p%z=z;p%dz=dz;p%node_distance=disnod(:nodes);p%cofgen=cofgen
 p%bottom_mode=1;p%prescribed_groundwater_active=.true.;p%swkmean=1;p%max_iterations=source_maxit;p%max_backtracking=source_maxbacktrack
 p%ksatexm_extension_active=any(cofgen(10,:)>cofgen(3,:))
 call initialize_b110_default_mvg_parameters(hp,cofgen,enable_ksatexm_extension=p%ksatexm_extension_active)
 call bind_b110_default_mvg_provider(hydraulic,hp,limit)
 initial%active_nodes=nodes;initial%pressure_head=heads;initial%groundwater_level=source_gwl;initial%ponding_depth=source_pond
 allocate(initial%water_content(nodes),conductivity(nodes),capacity(nodes),derivative(nodes),theta100(nodes),theta500(nodes))
 call hydraulic%evaluate(heads,initial%water_content,conductivity,capacity,derivative)
 call hydraulic%evaluate(spread(-100d0,1,nodes),theta100,conductivity,capacity,derivative)
 call hydraulic%evaluate(spread(-500d0,1,nodes),theta500,conductivity,capacity,derivative)
 p%soil_temperature_active=.true.;allocate(p%soil_temperature,initial%soil_temperature,forcing%soil_temperature)
 call import_column_swp_heat('input.swp',dz,z,disnod(:nodes),cofgen(2,:), &
   p%soil_temperature,initial%soil_temperature,forcing%soil_temperature)
 call rdinit(74,0,'grass.crp')
 call expect('swwofost',3);call expect('swtsum',1);call expect('swcf',2);call expect('swinter',1)
 call expect('swoxygen',2);call expect('swdrought',1);call expect('swcompensate',0);call expect('swco2',0)
 call expect('swrd',2);call expect('swrdc',0)
 call expect('swdmi2rd',1);call expect('swwrtnonox',1)
 root_parameters%anaerobic_extension_gate_enabled=.true.
 root_parameters%aeration_critical_factor=value('aeratecrit')
 root_parameters%maximum_daily_extension_cm=value('rri')
 root_parameters%negligible_transpiration=1d-10;root_parameters%negligible_root_growth=1d-3
 root_parameters%negligible_extension=1d-6;root_parameters%actual_extension_mode=CROP_ROOT_RATE_WATER_SCALED
 if(rdinqr('swlrvconstant'))call expect('swlrvconstant',0)
 scalars%grass_development=.true.;scalars%diffuse_extinction_coefficient=value('kdif')
 scalars%initial_light_use_efficiency=value('eff');scalars%co2_to_dry_matter_fraction=value('cfrdm')
 scalars%attainable_yield_multiplier=value('relmf');scalars%conversion_efficiency_root=value('cvr')
 scalars%conversion_efficiency_stem=value('cvs');scalars%conversion_efficiency_leaf=value('cvl')
 scalars%conversion_efficiency_storage=value('cvo');scalars%respiration_temperature_q10=value('q10')
 scalars%maintenance_respiration_root=value('rmr');scalars%maintenance_respiration_stem=value('rms')
 scalars%maintenance_respiration_leaf=value('rml');scalars%maintenance_respiration_storage=value('rmo')
 scalars%maximum_leaf_relative_death_rate=value('perdl');scalars%leaf_age_base_temperature=value('tbase')
 scalars%maximum_relative_lai_growth_rate=value('rgrlai')
 call readtable('amaxtb',tables%maximum_assimilation);call readtable('tmpftb',tables%daytime_temperature_factor)
 call readtable('tmnftb',tables%minimum_temperature_factor);call readtable('rfsetb',tables%maintenance_respiration_factor)
 call readtable('frtb',tables%root_partition_fraction);call readtable('fltb',tables%leaf_partition_fraction)
 call readtable('fstb',tables%stem_partition_fraction);call readtable('fotb',tables%storage_partition_fraction)
 call readtable('rdrrtb',tables%relative_root_death_rate);call readtable('rdrstb',tables%relative_stem_death_rate)
 call readtable('slatb',tables%specific_leaf_area)
 call construct_wofost_rate_parameter_bundle(scalars,tables,bundle,code);call require(code==0,'native grass parameters')
 ! Original read_wofost sets DVSEND=2 for SWWOFOST3; no annual input exists.
 updates%development_stage_end=2d0;updates%leaf_lifespan=value('span');updates%grass_development=.true.
 call expect('swharvest',2);call rdatim('dateharvest',harvest_dates,1024,harvest_count)
 call rdaint('seqgrzmow',harvest_types,1024,n)
 call require(n==harvest_count.and.all(harvest_types(:n)==2),'source fixed-date mowing sequence')
 call expect('swlossmow',0);mowing_residual=value('dmrestmow');call readtable('delaymowtb',delay_table)
 tdwi=value('tdwi');ssa=value('ssa');spa=value('spa');kdir=value('kdir');rdi=value('rdi');rdc=value('rdc')
 root_parameters%initial_root_depth_cm=rdi;root_parameters%maximum_root_depth_cm=min(rdc,sum(dz))
 call initialize_crop_root_depth_rate_state(root_parameters,root_state,code);call require(code==0,'native root depth owner')
 call rdsint('swpotrelmf',mode);call require(mode==1.or.mode==2,'source potential management factor')
 potential_management_factor=1d0
 if(mode==2)potential_management_factor=scalars%attainable_yield_multiplier
 call readtable('rdctb',root_table);call readtable('chtb',height_table)
 call initialize_wofost_emergence_owner(tdwi,bundle,crop,code);call require(code==0,'native emergence owner')
 call initialize_wofost_potential_shadow_from_actual(crop,potential,code);call require(code==0,'source potential owner')
 canopy%crop_emerged=.true.;canopy%cofab_cm=value('cofab');canopy%albedo=value('albedo')
 canopy%dry_canopy_resistance_s_m=value('rsc');canopy%wet_canopy_resistance_s_m=value('rsw')
 canopy%use_crop_height_for_aerodynamics=.true.
 root_srl=value('srl');allocate(p%bartholomeus,forcing%crop_oxygen)
 p%bartholomeus%selection%oxygen_mode=2;p%bartholomeus%selection%oxygen_type=1
 if(rdinqr('swoxygentype'))call expect('swoxygentype',1)
 p%bartholomeus%specific_root_length_m_kg=root_srl
 p%bartholomeus%crop%specific_resp_humus=value('specific_resp_humus')
 p%bartholomeus%crop%q10_microbial=value('q10_microbial');p%bartholomeus%crop%root_radius_m=.01d0*value('rootradius')
 p%bartholomeus%crop%microbial_shape_m=.9d0;p%bartholomeus%crop%root_shape_m=.9d0
 allocate(forcing%substep_root)
 forcing%substep_root%parameters%active_nodes=nodes
 forcing%substep_root%parameters%hlim3l=value('hlim3l');forcing%substep_root%parameters%hlim3h=value('hlim3h')
 forcing%substep_root%parameters%hlim4=value('hlim4');forcing%substep_root%parameters%adcrl=value('adcrl')
 forcing%substep_root%parameters%adcrh=value('adcrh');close(74)
 call construct_bartholomeus_dataset(cofgen,dz,organic(node_layer(:nodes)),sand(node_layer(:nodes)), &
   density(node_layer(:nodes)),theta100,theta500,theta100,-100d0,-500d0,0,p%bartholomeus%soil,available)
 call require(available,'owner-bound original oxygen soil')
 call materialize_static_root_profile(root_table,z-.5d0*dz,rdc,rdi,rooted,cumulative,code)
 call require(code==0,'native original root geometry')
 forcing%substep_root%request%rooted_nodes=rooted;forcing%substep_root%request%cumulative_root_fraction=cumulative
 p%root_extraction_active=.true.
 call rdinit(74,0,'input.met');call rdinne('yyyy',n)
 call require(n<=10000,'native weather capacity')
 call rdfint('dd',dd,10000,n);call rdfint('mm',mm,10000,n);call rdfint('yyyy',yyyy,10000,n)
 call rdfdou('rad',metrad,10000,n);call rdfdou('tmin',tmn,10000,n);call rdfdou('tmax',tmx,10000,n)
 call rdfdou('hum',humidity,10000,n);call rdfdou('wind',wind,10000,n);call rdfdou('rain',rain,10000,n)
 call rdfdou('wet',wet,10000,n);close(74)
 weather_count=n;call require(ceiling(limit)<=weather_count,'original weather prefix available')
 date=0;date(:3)=[yyyy(1),mm(1),dd(1)];call dtardp(date,0.,date_time)
 call require(date_time==origin.and.mm(1)==1.and.dd(1)==1,'original first weather day')
 forcing%bottom_head=source_gwl;forcing%root_extraction_sink=spread(0d0,1,nodes)
 forcing%subsurface_irrigation_source=spread(0d0,1,nodes)
 call rdinit(74,0,'swap.dra');call expect('dramet',3);call expect('nrlevs',1);call expect('swdivd',1)
 call expect('swdivdinf',0);call expect('swintfl',0);call expect('swallo1',1);call expect('swdtyp1',2)
 spacing=value('l1');depth=value('zbotdr1');drainres=value('drares1');infres=value('infres1')
 call rdfdou('cofani',ani,256,m);call rdatim('datowl1',times,1024,n);call rdfdou('level1',levels,1024,n);close(74)
 p%drainage_response_active=.true.
 allocate(p%drainage_response_levels(1),p%drainage_trial_distribution,forcing%drainage_response_controls(1))
 p%drainage_response_levels(1)%variant=FMR_DRAIN_VARIANT_DRAMET3
 p%drainage_response_levels(1)%dramet3%drain_bottom_cm=depth
 p%drainage_response_levels(1)%dramet3%drainage_resistance_day=drainres
 p%drainage_response_levels(1)%dramet3%infiltration_resistance_day=infres
 p%drainage_response_levels(1)%dramet3%allocation_mode=3;p%drainage_response_levels(1)%dramet3%drain_type=2
 call initialize_dramet3_channel_control(p%drainage_response_levels(1)%dramet3_channel,0d0,origin,times(:n),levels(:n),code)
 call require(code==0,'source drainage channel')
 p%drainage_trial_distribution%active_nodes=nodes;p%drainage_trial_distribution%dz=dz
 p%drainage_trial_distribution%zbotcp=z-.5d0*dz;p%drainage_trial_distribution%saturated_conductivity=cofgen(3,:)
 p%drainage_trial_distribution%horizontal_anisotropy_factor=ani(node_layer(:nodes))
 p%drainage_trial_distribution%drain_spacing=100d0*spacing
 column%column_id=613101_int64;column%template_id=613201_int64;column%parameter_ref=1;column%state_handle=1;column%forcing_handle=1
 column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 template%template_id=column%template_id;template%physics_topology_id=613210;template%vertical_layout_id=613220
 template%state_layout_id=613230;template%solver_interface_id=613240;template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION
 numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
 numerical%transaction%temporal_tolerance=1d-4;numerical%transaction%mass_tolerance=1d-10
 numerical%transaction%max_retries=30;numerical%max_committed_substeps=100000
 call get_command_argument(3,arg)
 if(len_trim(arg)>0)read(arg,*)numerical%max_committed_substeps
 call require(numerical%max_committed_substeps>0.and.numerical%max_committed_substeps<=100000,'bounded substep policy')
 call backend%initialize(top)
 call fmr_new_b110_boesten_evaporation_committed_state(water,column%column_id,initial,boesten_evaporation_state_t(),0d0,available,p)
 call require(available,'source joint initial owner')
 call water%capture_checkpoint(checkpoint,available);call require(available,'initial checkpoint')
 write(*,*)'ORIGINAL_GRASS_READY',nodes,sum(dz),sum(initial%water_content*dz),source_gwl,crop%biomass%root_biomass
 write(*,*)'ORIGINAL_GRASS_NUMERICS',source_maxit,source_maxbacktrack,source_dtmax,numerical%retain_accepted_step_proposal
 clock=0d0
 call get_command_argument(4,restart_path)
 if(len_trim(restart_path)>0)then
  call prepare_source_day(1)
  call read_grass_prefix_restart(trim(restart_path),p,water,crop,management,clock,code,potential,root_state,root_parameters)
  call require(code==0,'bound grass prefix restart rejected')
  call require(clock<limit,'restart contains no requested remaining days')
 end if
 open(newunit=crop_log,file='crop.csv',status='replace',action='write')
 write(crop_log,'(a)')'day,dvs,tsum,lai,wrt,wlv,wst,wso,pwrt,rd,rdpot,grrt,grrtpot,oxygen_integral'
 open(newunit=budget,file='budget.csv',status='replace',action='write')
 write(budget,'(a)')'day,t1,water_start_cm,water_end_cm,input_cm,output_cm,residual_cm,potential_cm,uptake_cm,drought_cm,oxygen_cm,heat_residual_j_cm2,temperature_sum,accepted_steps'
 do day_index=int(clock)+1,ceiling(limit)
  do season_index=2,season_count
   if(origin+day_index-1==season_start(season_index))then
    ! Original initialize_wofost/initialize_grass and SWRD2 reset at source
    ! CROPSTART, while the accepted water/thermal owners continue unchanged.
    call initialize_wofost_emergence_owner(tdwi,bundle,crop,code);call require(code==0,'source new grass season')
    call initialize_wofost_potential_shadow_from_actual(crop,potential,code);call require(code==0,'new season potential')
    call initialize_crop_root_depth_rate_state(root_parameters,root_state,code);call require(code==0,'new season roots')
    management%warm_days=0;management%regrowth_delay_days=0;management%potential_regrowth_delay_days=0
    management%cut_index=1
    do while(management%cut_index<=harvest_count)
     if(harvest_dates(management%cut_index)>=season_start(season_index))exit
     management%cut_index=management%cut_index+1
    end do
    management%potential_cut_index=management%cut_index
   end if
  end do
  call prepare_source_day(day_index)
  day_water=water;day_crop=crop;day_management=management;day_potential_crop=potential;day_roots=root_state;cursor=real(day_index-1,real64);day_end=min(limit,real(day_index,real64))
  day_potential=0d0;day_actual=0d0;day_drought=0d0;day_oxygen=0d0
  deepest_oxygen_integral=0d0
  day_residual=0d0;day_in=0d0;day_out=0d0;heat_residual=0d0;accepted_steps=0
  do while(cursor<day_end)
   edge=min(day_end,cursor+source_dtmax)
   if(cursor<real(day_index-1,real64)+wet_duration)then
    edge=min(edge,real(day_index-1,real64)+wet_duration)
    segment_rain_rate=rain_rate
   else
    segment_rain_rate=0d0
   end if
   ! Close the current interval on its requested day boundary. Repeated DTMAX
   ! additions may leave a few ulps; never submit a numerically zero final trial.
   ! The full remaining duration is still integrated by this final real trial.
   if(day_end-edge<=64d0*epsilon(edge)*max(1d0,abs(day_end)))edge=day_end
   call apply_swinter1_duration_interval(weather,canopy,et,segment_rain_rate,interception,et_diagnostic)
   call require(et_diagnostic%status==0,'source interval interception')
   forcing%substep_root%request%potential_transpiration=interception%potential_transpiration_cm_per_day
   forcing%boesten_evaporation%precipitation_rate_cm_per_day=interception%net_rain_cm_per_day
   forcing%boesten_evaporation%potential_bare_soil_evaporation_cm_per_day=et%potential_soil_evaporation_cm_per_day
   forcing%boesten_evaporation%potential_pond_evaporation_cm_per_day=et%potential_pond_evaporation_cm_per_day
   call day_water%capture_checkpoint(checkpoint,available);call require(available,'source segment checkpoint')
   call backend%run_trial(column,template,p,day_water,forcing,numerical,cursor,edge,checkpoint,result,candidate,diagnostic, &
     trace_accepted_water_flux_substeps=.true.,trace_accepted_soil_n_heat=.true.)
   observation=backend%observation()
   write(*,*)'ORIGINAL_GRASS_TRIAL',day_index,cursor,edge,result%status,result%completed, &
     diagnostic%attempts,diagnostic%solver_rejections,diagnostic%temporal_rejections,diagnostic%mass_rejections
   write(*,*)'ORIGINAL_GRASS_PROGRESS',result%completed_t,diagnostic%accepted_substeps
   if(.not.result%completed.or..not.candidate%ready())then
    call write_endpoint(water,clock,0d0)
    error stop 'source segment rejected; previous committed day retained'
   end if
   call require(result%mass%complete.and.abs(result%mass%residual)<=1d-10,'original segment water balance')
   call require(observation%accepted_water_flux_trace_available,'source accepted trace')
   call require(observation%soil_temperature_energy_accounting_complete,'source heat accounting')
   heat_residual=max(heat_residual,abs(observation%soil_temperature_energy_residual_j_cm2))
   if(cursor==real(day_index-1,real64))day_start_water=result%mass%storage_start
   day_final_water=result%mass%storage_end
   day_in=day_in+result%mass%total_in;day_out=day_out+result%mass%total_out
   accepted_steps=accepted_steps+diagnostic%accepted_substeps
   do trace_index=1,size(observation%accepted_water_flux_substeps)
    associate(q=>observation%accepted_water_flux_substeps(trace_index))
     step_dt=q%t1-q%t0
     deepest_oxygen_integral=deepest_oxygen_integral+q%deepest_root_oxygen_factor*step_dt
     call require(q%substep_root_available,'source substep root carrier')
     day_potential=day_potential+q%root_potential_cm_day*step_dt
     day_actual=day_actual+sum(q%root_sink)*step_dt
     day_drought=day_drought+q%root_drought_reduction_cm_day*step_dt
     day_oxygen=day_oxygen+q%root_oxygen_reduction_cm_day*step_dt
    end associate
   end do
   call backend%commit_trial_candidate(day_water,candidate,diagnostic,committed,code)
   call require(committed,'source segment publication into staged day')
   cursor=edge
  end do
  day_residual=day_final_water-day_start_water-day_in+day_out
  call require(abs(day_residual)<=1d-10,'original day water balance')
  call require(abs(day_potential-day_actual-day_drought-day_oxygen)<=1d-10,'original uptake attribution')
  if(day_end==real(day_index,real64))then
   aggregates%potential_transpiration=day_potential;aggregates%actual_root_uptake=day_actual
   day_management=development%management
   call complete_managed_grass(prepared,crop_day,crop_view,assimilation,aggregates,development, &
     crop_candidate,rates,day_management%cut_index,day_management%regrowth_delay_days,harvested,code)
   day_management%harvested_dry_matter=management%harvested_dry_matter+harvested
   call require(code==0,'source grass day-end')
   potential_aggregates%actual_root_uptake=1d0;potential_aggregates%potential_transpiration=1d0
   potential_management=management
   potential_management%regrowth_delay_days=management%potential_regrowth_delay_days
   call prepare_grass_development_candidate(development_parameters,potential_management, &
     crop%evolution_continuation%temperature_sum,crop_forcing%average_temperature,0d0,potential_development,code)
   call require(code==0,'potential management gate')
   day_management%potential_regrowth_delay_days=potential_development%management%regrowth_delay_days
   call complete_managed_grass(potential_prepared,potential_context,potential_view,potential_assimilation, &
     potential_aggregates,potential_development,potential_candidate,potential_rates, &
     day_management%potential_cut_index,day_management%potential_regrowth_delay_days,potential_harvested,code)
   day_management%potential_harvested_dry_matter=management%potential_harvested_dry_matter+potential_harvested
   call require(code==0,'source potential grass day-end')
   call day_potential_crop%absorb_owner(potential_candidate,code);call require(code==0,'potential owner publication')
   root_forcing%potential_transpiration=day_potential;root_forcing%actual_root_uptake=day_actual
   root_forcing%actual_root_growth=rates%gross_root_growth_rate
   root_forcing%potential_root_growth=potential_rates%gross_root_growth_rate
   root_forcing%deepest_root_oxygen_factor_available=.true.
   root_forcing%deepest_root_oxygen_factor_integral=deepest_oxygen_integral
   call evaluate_crop_root_depth_rate_candidate(root_parameters,root_state,root_forcing,day_roots,root_diagnostic,code)
   call require(code==0,'source daily root extension')
   day_crop=crop_candidate
   call write_grass_prefix_restart('checkpoint.bin',day_water,day_crop,day_management,code,day_potential_crop,day_roots)
   if(code/=0)write(*,*)'GRASS_RESTART_STATUS',code
   call require(code==0,'atomic grass restart publication')
  end if
  water=day_water;crop=day_crop;management=day_management;potential=day_potential_crop;root_state=day_roots;clock=day_end
  write(crop_log,'(i0,13(a,es25.17e3))')day_index,',',crop%development_stage,',',crop%evolution_continuation%temperature_sum, &
   ',',crop_view%actual_leaf_area_index,',',crop%biomass%root_biomass,',',sum(crop%biomass%leaf_biomass), &
   ',',crop%biomass%stem_biomass,',',crop%biomass%storage_biomass,',',potential%root_biomass(), &
   ',',root_state%actual_root_depth_cm,',',root_state%potential_root_depth_cm,',',rates%gross_root_growth_rate, &
   ',',potential_rates%gross_root_growth_rate,',',deepest_oxygen_integral
  flush(crop_log)
  write(budget,'(i0,12(a,es25.17e3),a,i0)')day_index,',',clock,',',day_start_water,',',day_final_water, &
   ',',day_in,',',day_out,',',day_residual,',',day_potential,',',day_actual,',',day_drought,',',day_oxygen,',',heat_residual, &
   ',',crop%evolution_continuation%temperature_sum,',',accepted_steps
  flush(budget)
  call write_endpoint(water,clock,day_residual)
  write(*,*)'ORIGINAL_GRASS_DAY_COMMITTED',clock,day_residual,crop%development_stage,crop%evolution_continuation%temperature_sum
  flush(6)
 end do
 close(budget);close(crop_log)
 write(*,*)'ORIGINAL_GRASS_INTERVAL_COMPLETED',clock,day_residual
contains
 subroutine prepare_source_day(day)
  integer,intent(in)::day
  date=0;date(:3)=[yyyy(day),mm(day),dd(day)];call dtardp(date,0.,date_time)
  call require(date_time==origin+day-1,'consecutive original weather')
 call materialize_static_root_profile(root_table,z-.5d0*dz,root_parameters%maximum_root_depth_cm, &
   root_state%actual_root_depth_cm,rooted,cumulative,code)
 call require(code==0,'source current root profile')
 forcing%substep_root%request%rooted_nodes=rooted;forcing%substep_root%request%cumulative_root_fraction=cumulative
 date=0;date(:3)=[yyyy(day),1,1];call dtardp(date,0.,year_origin)
 day_of_year=int(date_time-year_origin)+1
 weather%day_of_year=day_of_year;weather%radiation_j_m2_d=1000d0*metrad(day)
 weather%minimum_air_temperature_c=tmn(day);weather%maximum_air_temperature_c=tmx(day)
 weather%vapour_pressure_kpa=humidity(day);weather%wind_speed_m_s=wind(day);weather%gross_rain_cm_d=.1d0*rain(day)
 call resolve_daily_rain_duration(rain(day),wet(day),wet_duration,rain_rate,code)
 call require(code==0,'original rainfall duration')
 crop_weather%minimum_temperature=tmn(day)
 call prepare_wofost_one_day_candidate(crop,crop_weather,real(day-1,real64),real(day,real64),prepared,crop_day,code,grass_development=.true.)
 call require(code==0,'source crop day-start')
 call assemble_wofost_one_day_rate_state_view(prepared,ssa,spa,crop_view,available,code)
 call require(code==0.and.available,'source crop rate view')
 call evaluate_crop_solar_geometry(day_of_year,site%latitude_degrees,weather%radiation_j_m2_d,solar,code)
 call require(code==0,'source solar forcing')
 assimilation_forcing%daytime_mean_temperature=(tmx(day)+.5d0*(tmn(day)+tmx(day)))*.5d0
 assimilation_forcing%global_radiation=weather%radiation_j_m2_d
 assimilation_forcing%daylength_hours=solar%daylength_hours;assimilation_forcing%sine_solar_height_offset=solar%sine_offset
 assimilation_forcing%sine_solar_height_amplitude=solar%sine_amplitude
 assimilation_forcing%diffuse_irradiation_perpendicular=solar%diffuse_perpendicular
 assimilation_forcing%daily_effective_solar_height=solar%effective_solar_height
 assimilation_forcing%running_minimum_temperature=crop_day%running_minimum_temperature
 call prepare_wofost_actual_assimilation(crop_view,bundle,assimilation_forcing,assimilation,code)
 call require(code==0,'source grass assimilation')
 call potential%materialize_owner(crop,potential_owner,available,code);call require(code==0.and.available,'potential source view')
 call prepare_wofost_one_day_candidate(potential_owner,crop_weather,real(day-1,real64),real(day,real64), &
   potential_prepared,potential_context,code,grass_development=.true.)
 call require(code==0,'potential source prepare')
 call assemble_wofost_one_day_rate_state_view(potential_prepared,ssa,spa,potential_view,available,code)
 call require(code==0.and.available,'potential source assimilation view')
 call prepare_wofost_actual_assimilation(potential_view,bundle,assimilation_forcing,potential_assimilation,code, &
   attainable_multiplier_override=potential_management_factor)
 call require(code==0,'source potential grass assimilation')
 call prepare_wofost_oxygen_respiration(crop_view,bundle,assimilation,.5d0*(tmn(day)+tmx(day)), &
   management%regrowth_delay_days,respiration,code)
 call require(code==0,'source grass oxygen respiration')
 p%bartholomeus%crop%q10_root=respiration%root_q10;p%bartholomeus%crop%c_mroot=respiration%root_maintenance_coefficient
 p%bartholomeus%crop%f_senes=respiration%senescence_factor
 p%bartholomeus%crop%max_resp_factor=respiration%maximum_respiration_factor
 call prepared%derive_bartholomeus_root_input(dz(:rooted),cumulative,root_srl,.5d0*(tmn(day)+tmx(day)), &
   forcing%crop_oxygen,roots,available,code);call require(code==0.and.available,'source root oxygen publication')
 canopy%lai=crop_view%actual_leaf_area_index
 canopy%vegetation_cover_fraction=1d0-exp(-kdir*scalars%diffuse_extinction_coefficient*canopy%lai)
 call height_table%evaluate(prepared%development_stage,canopy%crop_height_cm,code)
 call require(code==0,'original height')
 call evaluate_pmdirect_swetr0_daily(weather,site,canopy,et,et_diagnostic)
 call require(et_diagnostic%status==0,'original direct PM')
 forcing%soil_temperature%air_temperature_c=.5d0*(tmn(day)+tmx(day))
 crop_forcing%average_temperature=.5d0*(tmn(day)+tmx(day))
 call prepare_grass_development_candidate(development_parameters,management, &
   crop%evolution_continuation%temperature_sum,crop_forcing%average_temperature,0d0,development,code)
 call require(code==0,'source grass development')
 end subroutine
 subroutine complete_managed_grass(base,context,view,assimilated,water_aggregates,growth, &
      next,rates_out,cut_index,delay,removed,status)
  type(wofost_crop_owner_state_t),intent(in)::base
  type(wofost_one_day_window_context_t),intent(in)::context
  type(wofost_one_day_rate_state_view_t),intent(in)::view
  type(wofost_prepare_assimilation_result_t),intent(in)::assimilated
  type(wofost_accepted_window_aggregates_t),intent(in)::water_aggregates
  type(grass_development_candidate_t),intent(in)::growth
  type(wofost_crop_owner_state_t),intent(out)::next
  type(wofost_one_day_rate_packet_t),intent(out)::rates_out
  integer,intent(inout)::cut_index,delay
  real(real64),intent(out)::removed
  integer,intent(out)::status
  logical::cut_due
  removed=0d0;cut_due=.false.
  if(cut_index<=harvest_count)cut_due=date_time+1d0>harvest_dates(cut_index).and.growth%growth_enabled
  if(cut_due)then
   call complete_grass_daily_candidate(base,context,view,bundle,assimilated,crop_forcing,updates,water_aggregates, &
     growth,next,rates_out,status,mowing_residual,removed)
   if(status/=0)return
   call delay_table%evaluate(removed,delay_value,status);if(status/=0)return
   delay=int(delay_value);cut_index=cut_index+1
  else
   call complete_grass_daily_candidate(base,context,view,bundle,assimilated,crop_forcing,updates,water_aggregates, &
     growth,next,rates_out,status)
  end if
 end subroutine
 subroutine write_endpoint(state,time,balance)
  type(kernel_committed_state_t),intent(in)::state
  real(real64),intent(in)::time,balance
 call state%snapshot(accepted,available);call require(available,'accepted physical view')
 select type(q=>accepted)
 type is(fmr_b110_boesten_evaporation_state_t)
  call build_soil_temperature_field_view(q%soil_temperature,heat_view,code)
  call require(code==0,'accepted temperature view')
  open(newunit=u,file='state.csv',status='replace',action='write')
  write(u,'(a)')'node,head_cm,water_content,temperature_c'
  do i=1,nodes
   write(u,'(i0,3(a,es25.17e3))')i,',',q%pressure_head(i),',',q%water_content(i),',',heat_view%temperature_c(i)
  end do
  close(u)
  open(newunit=u,file='endpoint.csv',status='replace',action='write')
  write(u,'(a)')'time_day,water_cm,pond_cm,groundwater_cm,boesten_spev,boesten_saev,water_residual_cm'
  write(u,'(es25.17e3,6(a,es25.17e3))')time,',',sum(q%water_content*dz)+q%ponding_depth, &
   ',',q%ponding_depth,',',q%groundwater_level,',',q%boesten_evaporation%spev,',',q%boesten_evaporation%saev,',',balance
  close(u)
 class default
  error stop 'unexpected accepted physical layout'
 end select
 end subroutine
 real(real64) function value(key)result(v)
  character(*),intent(in)::key
  call rdsdou(key,v)
 end function
 subroutine expect(key,wanted)
  character(*),intent(in)::key
  integer,intent(in)::wanted
  integer::found
  call rdsint(key,found);call require(found==wanted,'unsupported original '//key)
 end subroutine
 subroutine readtable(key,table)
  character(*),intent(in)::key
  type(wofost_rate_table_t),intent(out)::table
  real(real64)::data(2048)
  integer::length,status
  call rdinne(key,length);call require(length>=4.and.length<=2048.and.mod(length,2)==0,'table capacity '//key)
  call rdfdou(key,data,2048,length)
  call construct_wofost_rate_table(data(1:length:2),data(2:length:2),table,status)
  call require(status==0,'source table '//key)
 end subroutine
 subroutine require(ok,message)
  logical,intent(in)::ok
  character(*),intent(in)::message
  if(.not.ok)then
   print *,message
   error stop 1
  end if
 end subroutine
end program
