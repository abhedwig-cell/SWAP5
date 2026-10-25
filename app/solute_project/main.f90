! Explicit native crop application. Physics/state/restart providers are shared with solute_column.
program swap5_native_project_column
  use iso_fortran_env, only: real64,int64,iostat_end
  use ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod,z,dz,disnod
  use solute_column_context, only: initialize_column_context
  use mod_transaction_reference, only: transaction_state_t,TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_pond_water_temporal_difference,only:water_flux_temporal_policy_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_fmr_runtime_core
  use mod_fmr_serialized_reference_backend
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider
  use mod_b111_reactive_solute_substep, only: b111_reactive_solute_substep_forcing_t
  use mod_b111_persistent_pond, only: pond_step_t
  use mod_restricted_surface_evaporation,only:boesten_evaporation_state_t
  use mod_fmr_drainage_response_binding,only:FMR_DRAIN_VARIANT_DRAMET3
  use mod_drainage_dramet3_response,only:initialize_dramet3_channel_control,DRAMET3_OK
  use mod_fmr_b111_matrix_solute_route
  use mod_fmr_b111_matrix_joint_application, only: matrix_joint_result_t,JOINT_OK,JOINT_WATER_REJECTED
  use mod_fmr_b111_pond_joint_application, only: run_pond_joint_interval
  use mod_fmr_b111_pond_thermal_application,only:run_pond_thermal_interval
  use mod_pond_thermal_restart_file
  use mod_soil_temperature_contract
  use mod_restricted_soil_temperature,only:initialize_soil_temperature_parameters
  use mod_column_swp_water,only:import_column_swp_water
  use mod_column_swp_heat,only:import_column_swp_heat
  use mod_column_swp_chemistry,only:import_column_swp_chemistry
  use mod_matrix_joint_restart_file
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t
  use mod_solute_compartment_state, only: solute_compartment_state_t
  use mod_crop_root_profile_static,only:materialize_static_root_profile,CROP_ROOT_PROFILE_OK
  use mod_wofost_rate_table,only:wofost_rate_table_t,construct_wofost_rate_table,WOFOST_RATE_TABLE_OK
  use mod_root_water_uptake_process,only:root_water_uptake_parameters_t,root_water_uptake_flux_result_t, &
    root_water_uptake_diagnostics_t,ROOT_UPTAKE_OK
  use mod_fmr_root_uptake_process_binding,only:fmr_root_uptake_crop_input_t,fmr_root_uptake_binding_diagnostics_t, &
    fmr_evaluate_committed_root_uptake,FMR_ROOT_UPTAKE_BINDING_OK
  use mod_process_hydraulic_view,only:process_hydraulic_view_t
  use mod_root_water_uptake_process,only:root_water_uptake_request_t,evaluate_macro_feddes_drought_uptake
  implicit none
  integer,parameter :: MAX_WINDOWS=2048,MAX_NODES=256
  integer :: nodes=4
  real(real64) :: cell_thickness_cm(MAX_NODES)=0d0
  integer :: schema=0,windows=0,u,io,j,k,stop_after,first,code
  logical :: seasonal_bottom=.false.
  logical :: cauchy3_bottom=.false.,cauchy3_half_cell=.true.
  integer :: cauchy3_count=0
  real(real64) :: cauchy3_resistance=0d0,cauchy3_dates(1024)=0d0,cauchy3_heads(1024)=0d0
  logical :: boesten_evaporation=.false.
  real(real64) :: boesten_cofred=0d0
  logical :: native_drainage=.false.
  integer :: drain_table_count=0
  real(real64) :: drain_resistance=0d0,drain_infiltration_resistance=0d0,drain_spacing_m=0d0,drain_bottom_cm=0d0
  real(real64) :: drain_legacy_origin=0d0,drain_table_times(1024)=0d0,drain_table_heads(1024)=0d0
  real(real64) :: drain_anisotropy(MAX_NODES)=0d0,drainage_amount=0d0
  integer :: bottom_year_count=0
  real(real64) :: bottom_amplitude=0d0,bottom_daymax=0d0,bottom_legacy_origin=0d0,bottom_year_starts(10)=0d0
  real(real64) :: bottom_amount
  integer,parameter :: MAX_RAIN_EVENTS=100000
  logical :: detailed_rain=.false.
  integer :: rain_count=0,accepted_count=0,rain_segments_completed=0
  real(real64) :: rain_ends(MAX_RAIN_EVENTS)=0d0,rain_rates(MAX_RAIN_EVENTS)=0d0,rain_supplied_cm=0d0
  namelist /rain_events/ rain_count,rain_ends,rain_rates
  integer :: solute_transport_scheme=0
  logical :: picard_conductivity_iteration=.false.
  logical :: continuous_mvg=.false.
  integer(int64) :: revision
  real(real64) :: initial_head=-75d0,initial_pond_cm=0d0,initial_pond_mass_mg_cm2=0d0
  real(real64) :: concentration_mg_cm3(MAX_NODES)=0d0
  real(real64) :: theta_r=0.032d0,theta_s=0.423d0,ksat_cm_day=0.00475d0
  real(real64) :: alpha_per_cm=0.0135d0,vg_n=1.455d0,pore_l=0.365d0
  real(real64) :: bulk_density=1.3d0,kf=0.2d0,dispersivity_cm=0.2d0,diffusion_cm2_day=0.05d0,tscf=0.5d0
  real(real64) :: root_cm_day(MAX_NODES)=0d0,drain_cm_day(MAX_NODES)=0d0,bottom_up_cm_day=0d0
  real(real64) :: cdrain_mg_cm3=0d0,cseep_mg_cm3=0d0
  real(real64) :: pond_max_cm=1d6,runoff_resistance_day=0d0,temporal_tolerance=1d-6
  real(real64) :: ends_day(MAX_WINDOWS)=0d0,rain_cm_day(MAX_WINDOWS)=0d0
  real(real64) :: irrigation_cm_day(MAX_WINDOWS)=0d0,runon_cm_day(MAX_WINDOWS)=0d0,evaporation_cm_day(MAX_WINDOWS)=0d0
  real(real64) :: soil_evaporation_cm_day(MAX_WINDOWS)=0d0,soil_evap_amount
  real(real64) :: rain_c=0d0,irrigation_c=0d0,runon_c=0d0,dry_mg_cm2_day=0d0
  real(real64) :: clock,t0,t1,water_amount,infiltration,runoff,runon_amount,evap_amount
  real(real64) :: surface_exfiltration_amount
  real(real64),allocatable :: theta(:),conductivity(:),capacity(:),dkdh(:)
  character(1024) :: path,restart_path,arg,message,legacy_swp
  logical :: ok,retain_accepted_step_proposal=.false.,dynamic_temperature=.false.
  logical :: water_flux_temporal=.false.
  type(water_flux_temporal_policy_t)::water_flux_policy
  logical :: implicit_pond_evaporation=.false.,swp_water_bootstrap=.false.
  logical :: swp_native_hydraulics=.false.
  logical :: swp_heat_bootstrap=.false.
  real(real64) :: air_temperature_c(MAX_WINDOWS)=20d0
  real(real64) :: observed_heat_residual_j_cm2=0d0
  real(real64) :: swp_source_pond=-1d0,swp_source_groundwater=-2d0
  logical :: historical_zero_solute_exfiltration=.false.
  real(real64),allocatable :: swp_heads(:),swp_cofgen(:,:)
  real(real64) :: freundlich_exponent=1d0,reference_concentration=1d0,decay_rate_day=0d0,gamma_temperature=0.05d0
  real(real64) :: initial_temperature_c(MAX_NODES)=20d0,surface_temperature_c(MAX_WINDOWS)=20d0
  type(soil_temperature_field_view_t) :: heat_view
  type(fmr_b110_physical_parameters_t),target :: p
  type(fmr_b110_physical_state_t) :: initial
  type(fmr_b110_physical_forcing_t) :: forcing
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t) :: provider
  type(b111_reactive_solute_substep_forcing_t) :: chemistry
  type(fmr_logical_column_t) :: column_id
  type(fmr_template_t) :: template
  type(canonical_numerical_config_t) :: numerical
  type(fmr_serialized_reference_backend_t) :: backend
  type(fixed_flux_top_boundary_provider_t),target :: top
  type(kernel_committed_state_t) :: water
  type(matrix_solute_state_t) :: solute
  type(matrix_joint_result_t) :: result
  type(pond_step_t) :: supply
  type(fmr_serialized_physical_observation_t) :: observation
  type(mobile_salt_state_t) :: mobile
  type(solute_compartment_state_t) :: companion
  class(transaction_state_t),allocatable :: physical
  integer,parameter::MAX_ROOT_KNOTS=500
  integer::root_table_points=0,upper_layer_bottom_node=0
  real(real64)::maximum_root_depth_cm=0d0,root_relative_depth(MAX_ROOT_KNOTS)=0d0,root_density(MAX_ROOT_KNOTS)=0d0
  real(real64)::hlim3l=0d0,hlim3h=0d0,hlim4=0d0,adcrl=0d0,adcrh=0d0,hlim1=0d0,hlim2u=0d0,hlim2l=0d0
  logical::empirical_oxygen_enabled=.false.,crop_active(MAX_WINDOWS)=.false.
  real(real64)::potential_transpiration_cm_day(MAX_WINDOWS)=0d0,root_depth_cm(MAX_WINDOWS)=0d0
  real(real64)::transpiration_amount,expected_transpiration,drought_amount,oxygen_amount,potential_amount
  logical::substep_root_stress=.false.
  type(wofost_rate_table_t)::density_table
  type(root_water_uptake_parameters_t)::root_parameters
  type(fmr_root_uptake_crop_input_t)::crop_input
  type(root_water_uptake_flux_result_t)::root_fluxes
  type(root_water_uptake_diagnostics_t)::root_diagnostics
  type(fmr_root_uptake_binding_diagnostics_t)::root_binding
  type project_root_profile_t
    integer::points=0
    real(real64)::relative_depth(MAX_ROOT_KNOTS)=0d0,density(MAX_ROOT_KNOTS)=0d0
    type(root_water_uptake_parameters_t)::parameters
  end type
  type(project_root_profile_t)::profiles(64)
  type(wofost_rate_table_t)::profile_tables(64)
  integer::profile_count=0,profile_index(MAX_WINDOWS)=0,profile_number
  namelist /rotation/ profile_count,profile_index,profiles
  namelist /crop/ root_table_points,upper_layer_bottom_node,maximum_root_depth_cm,root_relative_depth,root_density, &
    hlim3l,hlim3h,hlim4,adcrl,adcrh,hlim1,hlim2u,hlim2l,empirical_oxygen_enabled,crop_active, &
    potential_transpiration_cm_day,root_depth_cm,substep_root_stress
  namelist /column/ schema,nodes,cell_thickness_cm,initial_head,initial_pond_cm,initial_pond_mass_mg_cm2,concentration_mg_cm3, &
    theta_r,theta_s,ksat_cm_day,alpha_per_cm,vg_n,pore_l,bulk_density,kf,dispersivity_cm,diffusion_cm2_day,tscf, &
    root_cm_day,drain_cm_day,bottom_up_cm_day,cdrain_mg_cm3,cseep_mg_cm3,pond_max_cm,runoff_resistance_day,temporal_tolerance, &
    retain_accepted_step_proposal,water_flux_temporal,dynamic_temperature,freundlich_exponent,reference_concentration, &
    decay_rate_day,gamma_temperature,initial_temperature_c,implicit_pond_evaporation,swp_water_bootstrap,solute_transport_scheme, &
    historical_zero_solute_exfiltration,swp_native_hydraulics,swp_heat_bootstrap, &
    picard_conductivity_iteration,continuous_mvg,seasonal_bottom,bottom_year_count, &
    cauchy3_bottom,cauchy3_half_cell,cauchy3_count,cauchy3_resistance,cauchy3_dates,cauchy3_heads, &
    bottom_amplitude,bottom_daymax,bottom_legacy_origin,bottom_year_starts,detailed_rain,boesten_evaporation,boesten_cofred, &
    native_drainage,drain_resistance,drain_infiltration_resistance,drain_spacing_m,drain_bottom_cm,drain_legacy_origin, &
    drain_table_count,drain_table_times,drain_table_heads,drain_anisotropy
  namelist /surface/ windows,ends_day,rain_cm_day,irrigation_cm_day,runon_cm_day,evaporation_cm_day, &
    rain_c,irrigation_c,runon_c,dry_mg_cm2_day,surface_temperature_c,soil_evaporation_cm_day,air_temperature_c
  call get_command_argument(1,path)
  call get_command_argument(2,restart_path)
  call get_command_argument(4,legacy_swp)
  call get_command_argument(3,arg)
  stop_after=MAX_WINDOWS
  if(len_trim(arg)>0)then
    read(arg,*,iostat=io)stop_after
    call require(io==0,'invalid stop-after window')
  end if
  open(newunit=u,file=trim(path),status='old',action='read',iostat=io)
  call require(io==0,'cannot open input')
  read(u,nml=column,iostat=io,iomsg=message)
  if(io/=0)write(*,'(A)')trim(message)
  call require(io==0,'invalid column namelist')
  read(u,nml=surface,iostat=io,iomsg=message)
  if(io/=0)write(*,'(A)')trim(message)
  call require(io==0,'invalid surface namelist')
  read(u,nml=crop,iostat=io,iomsg=message)
  if(io/=0)write(*,'(A)')trim(message)
  call require(io==0,'invalid crop namelist')
  read(u,nml=rotation,iostat=io,iomsg=message)
  if(io/=0)write(*,'(A)')trim(message)
  call require(io==0,'invalid rotation namelist')
  if(detailed_rain)then
    read(u,nml=rain_events,iostat=io,iomsg=message)
    call require(io==0,'invalid detailed rain namelist')
    call require(rain_count>=1.and.rain_count<=MAX_RAIN_EVENTS,'detailed rain capacity')
    call require(all(ieee_is_finite(rain_ends)).and.all(ieee_is_finite(rain_rates)),'nonfinite detailed rain')
    call require(rain_ends(1)>0d0.and.rain_ends(rain_count)>=ends_day(windows),'detailed rain calendar coverage')
    call require(all(rain_ends(2:rain_count)>rain_ends(1:rain_count-1)),'detailed rain order')
    call require(all(rain_rates(:rain_count)>=0d0).and.all(rain_rates(:rain_count)<=5d5),'detailed rain rate')
    call require(all(rain_rates(rain_count+1:)==0d0).and.all(rain_ends(rain_count+1:)==0d0),'inactive rain data')
  end if
  ! The explicit project application requires the complete immutable period map.
  do
    read(u,'(A)',iostat=io)message
    if(io==iostat_end)exit
    call require(io==0,'input read failure')
    message=adjustl(message)
    call require(len_trim(message)==0.or.message(1:1)=='!','unexpected trailing input')
  end do
  close(u)
  call require(schema==1.or.schema==2,'unsupported schema')
  call require(all(ieee_is_finite(air_temperature_c)),'nonfinite air temperature')
  call require(all(air_temperature_c>=-50d0).and.all(air_temperature_c<=60d0),'air temperature outside domain')
  call require(swp_heat_bootstrap.or.all(air_temperature_c==20d0),'air forcing requires native heat')
  if(swp_heat_bootstrap)then
    call require(swp_native_hydraulics.and.dynamic_temperature,'native heat requires native hydraulics and dynamic heat')
    call require(all(initial_temperature_c==20d0).and.all(surface_temperature_c==20d0),'duplicate native heat owner')
    call require(.not.retain_accepted_step_proposal, &
      'native heat project composition not selected')
  end if
  call require(.not.swp_native_hydraulics.or.swp_water_bootstrap,'native hydraulics requires SWP water bootstrap')
  if(swp_water_bootstrap)then
    call require(len_trim(legacy_swp)>0,'SWP water bootstrap requires --swp')
    call require(schema==2.and.nodes==0.and.all(cell_thickness_cm==0d0),'SWP water bootstrap forbids a second grid')
    call require(initial_head==-75d0.and.theta_r==.032d0.and.theta_s==.423d0.and.ksat_cm_day==.00475d0.and. &
      alpha_per_cm==.0135d0.and.vg_n==1.455d0.and.pore_l==.365d0,'SWP water bootstrap forbids hydraulic overrides')
    if(swp_native_hydraulics)then
      ! The project adapter has already resolved and validated the external BBC.
      ! Initialization uses that same physical bottom owner, without a second file.
      call import_column_swp_water(trim(legacy_swp),nodes,cell_thickness_cm,swp_heads,swp_cofgen, &
        source_pond=swp_source_pond,initial_bottom_mode=merge(3,2,cauchy3_bottom), &
        source_groundwater=swp_source_groundwater,allow_ksatexm=.true.)
      if(swp_source_pond>=0d0)then
        call require(initial_pond_cm==0d0,'SWINCO2 forbids a second initial pond depth')
        call require(any(swp_heads < -1d-5),'fully saturated SWINCO2 project execution is not qualified')
        initial_pond_cm=swp_source_pond
      end if
    else
      call import_column_swp_water(trim(legacy_swp),nodes,cell_thickness_cm,swp_heads,swp_cofgen)
    end if
  end if
  call require(nodes>=2.and.nodes<=MAX_NODES,'invalid node count')
  call require(all(ieee_is_finite(cell_thickness_cm)),'nonfinite grid')
  if(schema==1)then
    call require(nodes==4.and.all(cell_thickness_cm==0d0),'schema1 grid override rejected')
    cell_thickness_cm(1:4)=[0.5d0,0.5d0,1d0,1d0]
  end if
  call require(all(cell_thickness_cm(1:nodes)>=1d-4).and.all(cell_thickness_cm(1:nodes)<=1d4).and. &
    sum(cell_thickness_cm(1:nodes))<=1d6,'invalid cell thickness')
  call require(all(cell_thickness_cm(nodes+1:)==0d0).and.all(concentration_mg_cm3(nodes+1:)==0d0).and. &
    all(root_cm_day(nodes+1:)==0d0).and.all(drain_cm_day(nodes+1:)==0d0),'nonzero inactive grid entry')
  call initialize_column_context(cell_thickness_cm(1:nodes))
  call require(windows>=1.and.windows<=MAX_WINDOWS,'invalid window count')
  call require(stop_after>=1,'stop-after must be positive')
  stop_after=min(stop_after,windows)
  call require(all(ieee_is_finite([initial_head,initial_pond_cm,initial_pond_mass_mg_cm2, &
    concentration_mg_cm3,theta_r,theta_s,ksat_cm_day,alpha_per_cm,vg_n,pore_l,bulk_density,kf, &
    dispersivity_cm,diffusion_cm2_day,tscf,root_cm_day,drain_cm_day,bottom_up_cm_day,cdrain_mg_cm3, &
    cseep_mg_cm3,pond_max_cm,runoff_resistance_day,temporal_tolerance,rain_c,irrigation_c,runon_c,dry_mg_cm2_day])), &
    'nonfinite column input')
  call require(initial_head>=-1d6.and.initial_head<=0d0,'initial head outside domain')
  call require(theta_r>=0d0.and.theta_s>theta_r.and.theta_s<=1d0,'invalid retention limits')
  call require(ksat_cm_day>0d0.and.ksat_cm_day<=1d4.and.alpha_per_cm>0d0.and.alpha_per_cm<=1d0, &
    'invalid hydraulic scale')
  call require(vg_n>1d0.and.vg_n<=5d0.and.abs(pore_l)<=10d0,'invalid MvG exponents')
  call require(min(initial_pond_cm,pond_max_cm,runoff_resistance_day)>=0d0.and. &
    max(initial_pond_cm,pond_max_cm)<=1d6.and.runoff_resistance_day<=1d3,'invalid pond parameters')
  call require(minval(concentration_mg_cm3)>=0d0.and.maxval(concentration_mg_cm3)<=1d6,'invalid initial concentration')
  call require(initial_pond_mass_mg_cm2>=0d0.and.initial_pond_mass_mg_cm2<=1d12,'invalid pond mass')
  call require(minval(root_cm_day)>=0d0.and.maxval(root_cm_day)<=1d3.and. &
    maxval(abs(drain_cm_day))<=1d3.and.abs(bottom_up_cm_day)<=1d3,'invalid water sources')
  call require(bulk_density>0d0.and.bulk_density<=10d0.and.kf>=0d0.and.kf<=1d3,'invalid sorption')
  call require(dispersivity_cm>=0d0.and.dispersivity_cm<=1d3.and.diffusion_cm2_day>=0d0.and. &
    diffusion_cm2_day<=1d3.and.tscf>=0d0.and.tscf<=1d0,'invalid transport parameters')
  call require(min(cdrain_mg_cm3,cseep_mg_cm3,rain_c,irrigation_c,runon_c,dry_mg_cm2_day)>=0d0.and. &
    max(cdrain_mg_cm3,cseep_mg_cm3,rain_c,irrigation_c,runon_c,dry_mg_cm2_day)<=1d6,'invalid source chemistry')
  call require(temporal_tolerance>0d0.and.temporal_tolerance<=1d-2,'invalid temporal tolerance')
  call require(ieee_is_finite(boesten_cofred),'nonfinite Boesten parameter')
  if(boesten_evaporation)then
    call require(boesten_cofred>0d0.and.boesten_cofred<=1d0,'invalid Boesten COFRED')
    call require((.not.dynamic_temperature.or.swp_heat_bootstrap).and..not.implicit_pond_evaporation.and. &
      .not.retain_accepted_step_proposal, &
      'Boesten numerical/thermal combination not qualified')
  else
    call require(boesten_cofred==0d0,'inactive Boesten parameter')
  end if
  t0=0d0
  do j=1,windows
    call require(all(ieee_is_finite([ends_day(j),rain_cm_day(j),irrigation_cm_day(j),runon_cm_day(j), &
      evaporation_cm_day(j),soil_evaporation_cm_day(j)])),'nonfinite surface input')
    call require(ends_day(j)>t0.and.ends_day(j)-t0<=1d3.and.ends_day(j)<=1d6,'invalid reporting window')
    call require(min(rain_cm_day(j),irrigation_cm_day(j),runon_cm_day(j),evaporation_cm_day(j),soil_evaporation_cm_day(j))>=0d0.and. &
      max(rain_cm_day(j),irrigation_cm_day(j),runon_cm_day(j),evaporation_cm_day(j),soil_evaporation_cm_day(j))<=5d5,'invalid surface rate')
    t0=ends_day(j)
  end do
  call require(all(ieee_is_finite([freundlich_exponent,reference_concentration,decay_rate_day,gamma_temperature, &
    initial_temperature_c,surface_temperature_c])),'nonfinite reactive/heat input')
  call require(freundlich_exponent>=0.5d0.and.freundlich_exponent<=2d0.and. &
    reference_concentration>=1d-8.and.reference_concentration<=1d6,'invalid Freundlich parameters')
  call require(decay_rate_day>=0d0.and.decay_rate_day<=1d3.and.gamma_temperature>=0d0.and. &
    gamma_temperature<=1d0,'invalid decay parameters')
  call require(all(initial_temperature_c>=-50d0).and.all(initial_temperature_c<=60d0).and. &
    all(surface_temperature_c>=-50d0).and.all(surface_temperature_c<=60d0),'heat outside admitted domain')
  call require(dynamic_temperature.or.decay_rate_day==0d0,'decay requires explicit dynamic heat activation')
  call require(.not.(dynamic_temperature.and.retain_accepted_step_proposal),'thermal proposal combination not qualified')
  call require(.not.implicit_pond_evaporation.or.(.not.dynamic_temperature.and. &
    .not.retain_accepted_step_proposal.and.freundlich_exponent==1d0),'implicit pond combination not qualified')
  call require(.not.any(soil_evaporation_cm_day>0d0).or.((.not.dynamic_temperature.or.swp_heat_bootstrap).and. &
    .not.implicit_pond_evaporation),'soil evaporation combination not qualified')
  call require((.not.dynamic_temperature.or.swp_heat_bootstrap).and..not.implicit_pond_evaporation,'crop combination not admitted')
  call require(.not.retain_accepted_step_proposal.or.(.not.picard_conductivity_iteration.and. &
    .not.continuous_mvg.and..not.seasonal_bottom.and..not.cauchy3_bottom.and..not.detailed_rain.and.solute_transport_scheme==0),'native proposal numerical combination not qualified')
  call require(.not.water_flux_temporal.or.(retain_accepted_step_proposal.and..not.boesten_evaporation), &
    'water/flux temporal metric requires native plain-evaporation proposal route')
  call require(.not.water_flux_temporal.or.temporal_tolerance==1d-3, &
    'water/flux temporal metric uses explicit fixed .001 depth and rate budgets')
  call require(swp_water_bootstrap.and.all(root_cm_day==0d0),'native crop forbids prescribed second root sink')
  call require(root_table_points>=2.and.root_table_points<=MAX_ROOT_KNOTS,'root knot count')
  call require(all(ieee_is_finite([maximum_root_depth_cm,root_relative_depth,root_density, &
    hlim3l,hlim3h,hlim4,adcrl,adcrh,hlim1,hlim2u,hlim2l,root_depth_cm,potential_transpiration_cm_day])), &
    'nonfinite crop configuration')
  call require(maximum_root_depth_cm>0d0.and.maximum_root_depth_cm<=sum(dz),'maximum roots outside profile')
  call require(all(root_relative_depth>=0d0).and.all(root_relative_depth<=1d0).and. &
    all(root_density>=0d0).and.all(root_density<=100d0),'root table domain')
  call require(root_relative_depth(1)==0d0.and.root_relative_depth(root_table_points)==1d0,'root table extent')
  call require(all(root_relative_depth(root_table_points+1:)==0d0).and. &
    all(root_density(root_table_points+1:)==0d0),'inactive root knots')
  call construct_wofost_rate_table(root_relative_depth(:root_table_points),root_density(:root_table_points),density_table,code)
  call require(code==WOFOST_RATE_TABLE_OK,'root density table')
  call require(all(potential_transpiration_cm_day>=0d0).and.all(potential_transpiration_cm_day<=20d0).and. &
    all(root_depth_cm>=0d0).and.all(root_depth_cm<=maximum_root_depth_cm),'crop demand/depth domain')
  call require(.not.any(crop_active(windows+1:)).and.all(root_depth_cm(windows+1:)==0d0).and. &
    all(potential_transpiration_cm_day(windows+1:)==0d0),'inactive crop windows')
  call require(profile_count>=1.and.profile_count<=64,'root profile capacity')
  call require(all(profile_index>=0).and.all(profile_index<=profile_count),'root profile index')
  call require(all(profile_index(windows+1:)==0),'inactive root profile entries')
  call require(all(crop_active.eqv.(profile_index>0)),'active crop/profile identity')
  do profile_number=1,profile_count
    associate(q=>profiles(profile_number))
      call require(q%points>=2.and.q%points<=MAX_ROOT_KNOTS,'profile knot count')
      call require(all(ieee_is_finite(q%relative_depth)).and.all(ieee_is_finite(q%density)),'finite profile')
      call require(q%relative_depth(1)==0d0.and.q%relative_depth(q%points)==1d0,'profile extent')
      call require(all(q%relative_depth>=0d0).and.all(q%relative_depth<=1d0).and.all(q%density>=0d0).and. &
        all(q%density<=100d0),'profile domain')
      call require(all(q%relative_depth(q%points+1:)==0d0).and.all(q%density(q%points+1:)==0d0),'inactive profile knots')
      call construct_wofost_rate_table(q%relative_depth(:q%points),q%density(:q%points),profile_tables(profile_number),code)
      call require(code==WOFOST_RATE_TABLE_OK,'profile density table')
      call require(q%parameters%active_nodes==0,'physical node count cannot be prescribed by crop')
      q%parameters%active_nodes=numnod
      call evaluate_macro_feddes_drought_uptake(q%parameters,process_hydraulic_view_t(),root_water_uptake_request_t(), &
        root_fluxes,root_diagnostics)
      call require(root_diagnostics%status==ROOT_UPTAKE_OK,'profile stress parameters')
    end associate
  end do
  do j=1,windows
    call select_project_profile(profile_index(j))
    if(.not.crop_active(j))then
      call require(root_depth_cm(j)==0d0.and.potential_transpiration_cm_day(j)==0d0,'fallow root demand must be zero')
    else
      ! Validate the complete immutable crop plan before any prefix can be
      ! published, including an invalid future root profile after a fallow day.
      call materialize_static_root_profile(density_table,z-.5d0*dz,maximum_root_depth_cm,root_depth_cm(j), &
        crop_input%rooted_nodes,crop_input%cumulative_root_fraction,code)
      call require(code==CROP_ROOT_PROFILE_OK,'crop plan root geometry')
      call require(crop_input%rooted_nodes>0.or.potential_transpiration_cm_day(j)==0d0,'crop plan demand without roots')
    end if
  end do
  crop_input=fmr_root_uptake_crop_input_t()
  root_parameters=root_water_uptake_parameters_t(numnod,hlim3l,hlim3h,hlim4,adcrl,adcrh, &
    empirical_oxygen_enabled,upper_layer_bottom_node,hlim1,hlim2u,hlim2l)
  p%parameter_set_id=670001_int64;p%active_nodes=numnod
  call require(.not.continuous_mvg.or.picard_conductivity_iteration,'continuous MvG requires explicit Picard route')
  if(continuous_mvg)p%parameter_set_id=670002_int64
  p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod)
  allocate(p%cofgen(24,numnod));p%cofgen=0d0
  p%cofgen(1,:)=theta_r;p%cofgen(2,:)=theta_s;p%cofgen(3,:)=ksat_cm_day
  p%cofgen(4,:)=alpha_per_cm;p%cofgen(5,:)=pore_l;p%cofgen(6,:)=vg_n
  p%cofgen(7,:)=1d0-1d0/vg_n;p%cofgen(8,:)=alpha_per_cm
  p%cofgen(10,:)=ksat_cm_day;p%cofgen(11,:)=0.999d0;p%cofgen(12,:)=0.99d0*ksat_cm_day
  p%cofgen(22,:)=-1d6;p%cofgen(23,:)=1d-12
  if(swp_water_bootstrap)p%cofgen=swp_cofgen
  p%ksatexm_extension_active=swp_native_hydraulics.and.any(p%cofgen(10,:)>p%cofgen(3,:))
  p%bottom_mode=2;p%swkimpl=0;p%swkmean=1;p%max_iterations=8;p%max_backtracking=4
  if(cauchy3_bottom)p%bottom_mode=3
  p%picard_conductivity_iteration=picard_conductivity_iteration
  if(picard_conductivity_iteration)p%max_iterations=64
  p%root_extraction_active=.true.
  initial%active_nodes=numnod;initial%pressure_head=spread(initial_head,1,numnod)
  if(swp_water_bootstrap)initial%pressure_head=swp_heads
  allocate(initial%water_content(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod))
  call initialize_b110_default_mvg_parameters(hp,p%cofgen,enable_ksatexm_extension=p%ksatexm_extension_active)
  if(continuous_mvg)then
    hp%continuous_saturation_conductivity=.true.
    p%prepared_default_mvg=hp;p%prepared_default_mvg_available=.true.
  end if
  call bind_b110_default_mvg_provider(provider,hp,ends_day(1))
  call provider%evaluate(initial%pressure_head,initial%water_content,conductivity,capacity,dkdh)
  initial%ponding_depth=initial_pond_cm;initial%groundwater_level=-2d0
  if(swp_native_hydraulics)initial%groundwater_level=swp_source_groundwater
  forcing%top_flux=0d0;forcing%top_head=initial_head;forcing%bottom_flux=bottom_up_cm_day
  if(seasonal_bottom)then
    call require(.not.cauchy3_bottom,'mutually exclusive bottom controls')
    call require(bottom_year_count>=2.and.bottom_year_count<=10,'seasonal bottom calendar capacity')
    allocate(forcing%legacy_swbotb2_control)
    call forcing%legacy_swbotb2_control%initialize_sine(0d0,bottom_legacy_origin, &
      bottom_year_starts(:bottom_year_count),bottom_up_cm_day,bottom_amplitude,bottom_daymax,code)
    call require(code==B110_SWBOTB2_OK,'seasonal bottom initialization')
  end if
  if(cauchy3_bottom)then
    call require(cauchy3_count>=2.and.cauchy3_count<=1024,'Cauchy3 table capacity')
    allocate(forcing%legacy_swbotb3_implicit_control)
    call forcing%legacy_swbotb3_implicit_control%initialize_table(0d0,bottom_legacy_origin, &
      cauchy3_dates(:cauchy3_count),cauchy3_heads(:cauchy3_count),cauchy3_resistance,cauchy3_half_cell,code)
    call require(code==0,'valid Cauchy3 table control')
  end if
  allocate(forcing%drainage_flux_by_level(1,numnod))
  forcing%drainage_flux_by_level(1,:)=drain_cm_day(1:numnod)
  if(native_drainage)then
    call require((.not.dynamic_temperature.or.swp_heat_bootstrap).and..not.retain_accepted_step_proposal,'drainage composition outside scope')
    call require(all(drain_cm_day==0d0),'duplicate drainage owner')
    call require(drain_table_count>=1.and.drain_table_count<=1024,'drainage table capacity')
    call require(all(ieee_is_finite([drain_resistance,drain_infiltration_resistance,drain_spacing_m, &
      drain_bottom_cm,drain_legacy_origin,drain_table_times,drain_table_heads,drain_anisotropy])),'finite drainage')
    call require(drain_spacing_m>=1d0.and.drain_spacing_m<=1d5,'drain spacing domain')
    call require(all(drain_anisotropy(:numnod)>=.0001d0).and.all(drain_anisotropy(:numnod)<=1000d0), &
      'drain anisotropy domain')
    call require(all(drain_anisotropy(numnod+1:)==0d0),'inactive drainage geometry')
    p%drainage_response_active=.true.;p%drainage_qbot_smooth_freatic_projection=.not.cauchy3_bottom
    allocate(p%drainage_response_levels(1),p%drainage_trial_distribution,forcing%drainage_response_controls(1))
    deallocate(forcing%drainage_flux_by_level)
    p%drainage_response_levels(1)%variant=FMR_DRAIN_VARIANT_DRAMET3
    p%drainage_response_levels(1)%dramet3%drain_bottom_cm=drain_bottom_cm
    p%drainage_response_levels(1)%dramet3%drainage_resistance_day=drain_resistance
    p%drainage_response_levels(1)%dramet3%infiltration_resistance_day=drain_infiltration_resistance
    p%drainage_response_levels(1)%dramet3%allocation_mode=3
    p%drainage_response_levels(1)%dramet3%drain_type=1
    call initialize_dramet3_channel_control(p%drainage_response_levels(1)%dramet3_channel,0d0,drain_legacy_origin, &
      drain_table_times(:drain_table_count),drain_table_heads(:drain_table_count),code)
    call require(code==DRAMET3_OK,'channel initialization')
    p%drainage_trial_distribution%active_nodes=numnod
    p%drainage_trial_distribution%dz=dz;p%drainage_trial_distribution%zbotcp=z-.5d0*dz
    p%drainage_trial_distribution%saturated_conductivity=p%cofgen(3,:)
    p%drainage_trial_distribution%horizontal_anisotropy_factor=drain_anisotropy(:numnod)
    ! Historical L1 is metres; DIVDRA geometry and hydraulic view use cm.
    p%drainage_trial_distribution%drain_spacing=100d0*drain_spacing_m
  end if
  forcing%root_extraction_sink=root_cm_day(1:numnod);forcing%subsurface_irrigation_source=spread(0d0,1,numnod)
  if(boesten_evaporation)then
    p%boesten_evaporation_active=.true.;allocate(p%boesten_evaporation,forcing%boesten_evaporation)
    p%boesten_evaporation%cofred=boesten_cofred
    forcing%boesten_evaporation%ponding_max_cm=pond_max_cm
    forcing%boesten_evaporation%runoff_resistance_day=runoff_resistance_day
  else
    allocate(forcing%pond_input)
    forcing%pond_input%ponding_max_cm=pond_max_cm;forcing%pond_input%runoff_resistance_day=runoff_resistance_day
    forcing%pond_input%implicit_pond_evaporation=implicit_pond_evaporation
  end if
  chemistry%dz_cm=dz;chemistry%theta=initial%water_content
  chemistry%transport_scheme=solute_transport_scheme
  chemistry%bulk_density=spread(bulk_density,1,numnod);chemistry%kf=spread(kf,1,numnod)
  chemistry%frexp=freundlich_exponent;chemistry%cref_mg_cm3=reference_concentration
  chemistry%temperature_active=dynamic_temperature;chemistry%temperature_c=spread(0d0,1,numnod)
  chemistry%gampar=spread(merge(gamma_temperature,0d0,dynamic_temperature),1,numnod);chemistry%rtheta=spread(0.3d0,1,numnod)
  chemistry%bexp=spread(1d0,1,numnod);chemistry%decpot=spread(decay_rate_day,1,numnod)
  chemistry%fdepth=spread(1d0,1,numnod);chemistry%face_distance_cm=disnod(2:numnod)
  chemistry%face_left_weight=0.5d0*dz(2:numnod)/chemistry%face_distance_cm
  chemistry%face_right_weight=0.5d0*dz(1:numnod-1)/chemistry%face_distance_cm
  chemistry%theta_sat_left=spread(theta_s,1,numnod-1)
  if(swp_water_bootstrap)chemistry%theta_sat_left=p%cofgen(2,1:numnod-1)
  chemistry%dispersivity_cm=spread(dispersivity_cm,1,numnod-1)
  chemistry%molecular_diffusion_cm2_day=diffusion_cm2_day;chemistry%tscf=tscf
  chemistry%cdrain_mg_cm3=cdrain_mg_cm3;chemistry%cseep_mg_cm3=cseep_mg_cm3
  if(len_trim(legacy_swp)>0)then
    call import_column_swp_chemistry(trim(legacy_swp),dz,z,dynamic_temperature,chemistry, &
      concentration_mg_cm3(1:numnod),rain_c,cdrain_mg_cm3,cseep_mg_cm3)
  end if
  ! Proposal trajectories with positive tracer require separate qualification.
  call require(.not.retain_accepted_step_proposal.or.(all(concentration_mg_cm3==0d0).and. &
    initial_pond_mass_mg_cm2==0d0.and.rain_c==0d0.and.irrigation_c==0d0.and.runon_c==0d0.and. &
    cdrain_mg_cm3==0d0.and.cseep_mg_cm3==0d0.and.dry_mg_cm2_day==0d0), &
    'native proposal requires zero tracer')
  call require(.not.implicit_pond_evaporation.or.(chemistry%frexp==1d0.and. &
    .not.chemistry%temperature_active),'implicit pond imported chemistry not qualified')
  column_id%column_id=660101_int64;column_id%template_id=660201_int64
  column_id%parameter_ref=1_int64;column_id%state_handle=1_int64;column_id%forcing_handle=1_int64
  column_id%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  template%template_id=column_id%template_id;template%physics_topology_id=660210_int64
  template%vertical_layout_id=660220_int64;template%state_layout_id=660230_int64
  template%solver_interface_id=660240_int64;template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  if(boesten_evaporation)template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION
  if(dynamic_temperature)then
    if(.not.boesten_evaporation)template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
    p%soil_temperature_active=.true.
    allocate(p%soil_temperature,initial%soil_temperature,forcing%soil_temperature)
    if(swp_heat_bootstrap)then
      call import_column_swp_heat(trim(legacy_swp),dz,z,disnod(1:numnod),p%cofgen(2,:), &
        p%soil_temperature,initial%soil_temperature,forcing%soil_temperature)
    else
    call initialize_soil_temperature_parameters(dz,disnod(1:numnod),p%cofgen(2,:), &
      spread(.3d0,1,numnod),spread(.2d0,1,numnod),spread(.04d0,1,numnod),p%soil_temperature,code)
    call require(code==0,'thermal parameter initialization')
    call initialize_soil_temperature_state(initial_temperature_c(1:numnod),initial%soil_temperature,code)
    call require(code==0,'thermal state initialization')
    end if
  end if
  numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
  numerical%transaction%temporal_tolerance=temporal_tolerance
  numerical%retain_accepted_step_proposal=retain_accepted_step_proposal
  numerical%transaction%mass_tolerance=1d-10;numerical%transaction%max_retries=30
  numerical%transaction%retry_scale=0.5d0;numerical%max_committed_substeps=100000
  water_flux_policy%enabled=water_flux_temporal
  call backend%initialize(top,water_flux_policy)
  if(trim(restart_path)/='-')then
    if(dynamic_temperature)then
      call read_pond_thermal_restart(trim(restart_path),column_id,template,p%parameter_set_id,9001_int64, &
        p,chemistry,water,solute,code)
    else
    call read_matrix_joint_restart_file(trim(restart_path),column_id,template,p%parameter_set_id,9001_int64, &
      chemistry,water,solute,code,allow_surface_mass=.true.)
    end if
    call require(code==JOINT_OK,'restart rejected')
  else
    if(boesten_evaporation)then
      if(dynamic_temperature)then
        call fmr_new_b110_boesten_evaporation_committed_state(water,column_id%column_id,initial, &
          boesten_evaporation_state_t(),0d0,ok,p)
      else
        call fmr_new_b110_boesten_evaporation_committed_state(water,column_id%column_id,initial, &
          boesten_evaporation_state_t(),0d0,ok)
      end if
    else if(dynamic_temperature)then
      call fmr_new_b110_committed_state(water,column_id%column_id,initial,0d0,ok,parameters=p)
    else
      call fmr_new_b110_committed_state(water,column_id%column_id,initial,0d0,ok)
    end if
    call require(ok,'water initialization failed')
    call initialize_matrix_solute(chemistry,9001_int64,0d0,initial%water_content,concentration_mg_cm3(1:numnod),solute,code)
    call require(code==MATRIX_OK,'chemical initialization failed')
    call solute%snapshot(clock,theta,mobile,companion,revision)
    call reconstruct_matrix_solute_trusted(chemistry,9001_int64,revision,clock,theta,mobile%concentration_mg_cm3, &
      mobile%mass_mg_cm2,companion%sorbed_matrix_mass,solute,code,surface_mass=initial_pond_mass_mg_cm2)
    call require(code==MATRIX_OK,'pond initialization failed')
  end if
  call water%current_time(clock,ok);call require(ok,'missing committed clock')
  first=1
  if(clock/=0d0)then
    first=0
    do j=1,windows
      if(clock==ends_day(j))first=j+1
    end do
    call require(first>0,'restart is not at an input window boundary')
  end if
  call require(first<=stop_after,'no requested windows remain')
  open(newunit=u,file='budget.csv',status='new',action='write',iostat=io)
  call require(io==0,'cannot create budget output')
  write(u,'(A)',advance='no')'window,t0_day,t1_day,water_start_cm,water_end_cm,water_in_cm,water_out_cm,water_residual_cm,'// &
    'solute_start_mg_cm2,solute_end_mg_cm2,solute_in_mg_cm2,solute_out_mg_cm2,solute_residual_mg_cm2,'// &
    'infiltration_cm,runon_cm,runoff_cm,pond_evaporation_cm,accepted_substeps'
  if(any(soil_evaporation_cm_day>0d0))write(u,'(A)',advance='no')',soil_evaporation_cm'
  write(u,'(A)',advance='no')',potential_transpiration_cm,actual_transpiration_cm,drought_reduction_cm,oxygen_reduction_cm'
  if(historical_zero_solute_exfiltration)write(u,'(A)',advance='no') &
    ',surface_exfiltration_cm,surface_solute_exfiltration_mg_cm2'
  if(seasonal_bottom.or.cauchy3_bottom)write(u,'(A)',advance='no')',bottom_up_cm'
  if(native_drainage)write(u,'(A)',advance='no')',drainage_cm'
  if(detailed_rain)write(u,'(A)',advance='no')',rain_supplied_cm,rain_segments'
  if(dynamic_temperature)write(u,'(A)',advance='no')',observed_heat_residual_j_cm2'
  write(u,'(A)')''
  do j=first,stop_after
    t0=clock;t1=ends_day(j)
    call select_project_profile(profile_index(j))
    crop_input=fmr_root_uptake_crop_input_t();crop_input%crop_emerged=crop_active(j)
    crop_input%potential_transpiration=potential_transpiration_cm_day(j)
    if(crop_active(j))then
      call materialize_static_root_profile(density_table,z-.5d0*dz,maximum_root_depth_cm,root_depth_cm(j), &
        crop_input%rooted_nodes,crop_input%cumulative_root_fraction,code)
      call require(code==CROP_ROOT_PROFILE_OK,'crop root geometry')
      call require(crop_input%rooted_nodes>0.or.potential_transpiration_cm_day(j)==0d0,'positive demand without roots')
    end if
    call fmr_evaluate_committed_root_uptake(water,root_parameters,crop_input,root_fluxes,root_diagnostics,root_binding)
    call require(root_binding%status==FMR_ROOT_UPTAKE_BINDING_OK.and.root_diagnostics%status==ROOT_UPTAKE_OK, &
      'committed crop root binding')
    forcing%root_extraction_sink=root_fluxes%root_extraction_sink
    expected_transpiration=sum(root_fluxes%root_extraction_sink)*(t1-t0)
    if(substep_root_stress)then
      if(allocated(forcing%substep_root))deallocate(forcing%substep_root)
      allocate(forcing%substep_root)
      forcing%substep_root%parameters=root_parameters
      forcing%substep_root%request%potential_transpiration=crop_input%potential_transpiration
      forcing%substep_root%request%rooted_nodes=crop_input%rooted_nodes
      if(allocated(crop_input%cumulative_root_fraction)) &
        forcing%substep_root%request%cumulative_root_fraction=crop_input%cumulative_root_fraction
      forcing%root_extraction_sink=0d0
    end if
    if(boesten_evaporation)then
      forcing%boesten_evaporation%precipitation_rate_cm_per_day=rain_cm_day(j)
      forcing%boesten_evaporation%irrigation_rate_cm_per_day=irrigation_cm_day(j)
      forcing%boesten_evaporation%runon_rate_cm_per_day=runon_cm_day(j)
      forcing%boesten_evaporation%potential_bare_soil_evaporation_cm_per_day=soil_evaporation_cm_day(j)
      forcing%boesten_evaporation%potential_pond_evaporation_cm_per_day=evaporation_cm_day(j)
    else
      forcing%pond_input%rain_rate_cm_day=rain_cm_day(j)
      forcing%pond_input%irrigation_rate_cm_day=irrigation_cm_day(j)
      forcing%pond_input%runon_rate_cm_day=runon_cm_day(j)
      forcing%pond_input%potential_bare_soil_evaporation_cm_day=soil_evaporation_cm_day(j)
      forcing%pond_input%potential_pond_evaporation_cm_day=evaporation_cm_day(j)
    end if
    supply=pond_step_t();supply%t0=t0;supply%t1=t1;supply%rain_rate=rain_cm_day(j)
    supply%rain_c=rain_c;supply%irrigation_rate=irrigation_cm_day(j);supply%irrigation_c=irrigation_c
    supply%runon_rate=runon_cm_day(j);supply%runon_c=runon_c;supply%dry_deposition_rate=dry_mg_cm2_day
    supply%exact_empty_pool_chemistry=any(soil_evaporation_cm_day>0d0)
    supply%implicit_pond_evaporation=implicit_pond_evaporation
    supply%historical_zero_solute_exfiltration=historical_zero_solute_exfiltration
    if(swp_heat_bootstrap)forcing%soil_temperature%air_temperature_c=air_temperature_c(j)
    if(detailed_rain)then
      call run_detailed_rain_day(t0,t1,result)
    else if(dynamic_temperature)then
      if(.not.swp_heat_bootstrap)forcing%soil_temperature%prescribed_surface_temperature_c=surface_temperature_c(j)
      call run_pond_thermal_interval(backend,column_id,template,p,water,forcing,numerical,solute,supply,t0,t1,result)
    else
    call run_pond_joint_interval(backend,column_id,template,p,water,forcing,numerical,solute,supply,t0,t1,result)
    end if
    if(retain_accepted_step_proposal.and.result%status==JOINT_WATER_REJECTED)then
      ! The failed joint trial leaves both committed states unchanged. Retry
      ! this complete interval once through the incumbent numerical policy.
      write(*,*)'SWAP5_PROJECT_STEP_PROPOSAL_FALLBACK',j,result%water%status, &
        result%diagnostics%attempts,result%diagnostics%solver_rejections, &
        result%diagnostics%temporal_rejections,result%diagnostics%headcalc_calls
      numerical%retain_accepted_step_proposal=.false.
      call run_pond_joint_interval(backend,column_id,template,p,water,forcing,numerical,solute,supply,t0,t1,result)
      numerical%retain_accepted_step_proposal=.true.
    end if
    if(result%status/=JOINT_OK)then
      write(*,*)'joint status/water/chemical: ',result%status,result%water%status,result%chemical%status
      write(*,*)'rejected window/process/completed:',j,result%chemical%process_status,result%chemical%completed_substeps
      write(*,*)'rejected attempts/solver/temporal/mass:',result%diagnostics%attempts, &
        result%diagnostics%solver_rejections,result%diagnostics%temporal_rejections,result%diagnostics%mass_rejections
      write(*,*)'rejected chemical mass:',result%chemical%mass_before,result%chemical%mass_after, &
        result%chemical%external_in,result%chemical%external_out,result%chemical%residual
      if(dynamic_temperature)then
        observation=backend%observation()
        write(*,*)'rejected thermal status:',observation%soil_temperature_status
        call write_pond_thermal_restart('diagnostic-rejected.bin',column_id,template,p%parameter_set_id, &
          p,water,solute,code)
      else
        call write_matrix_joint_restart_file('diagnostic-rejected.bin',column_id,template,p%parameter_set_id, &
          water,solute,code,allow_surface_mass=.true.)
      end if
      call require(code==JOINT_OK,'rejected committed-state diagnostic export failed')
    end if
    call require(result%status==JOINT_OK,'joint interval rejected')
    call require(result%water%mass%complete,'incomplete water accounting')
    call require(abs(result%water%mass%residual)<=1d-10.and.abs(result%chemical%residual)<=1d-10,'balance rejected')
    if(.not.detailed_rain)then
      observation=backend%observation()
      call require(observation%accepted_water_flux_trace_available,'accepted trace unavailable')
      call reset_day_totals()
      call accumulate_fluxes(observation)
    end if

    if(substep_root_stress)then
      call require(abs(potential_amount-transpiration_amount-drought_amount-oxygen_amount)<=1d-12, &
        'accepted substep root reconciliation')
      call require(abs(potential_amount-potential_transpiration_cm_day(j)*(t1-t0))<=1d-12, &
        'accepted substep potential demand mismatch')
    else
      call require(abs(transpiration_amount-expected_transpiration)<=1d-12,'accepted root carrier mismatch')
      drought_amount=root_diagnostics%drought_reduction_total*(t1-t0)
      oxygen_amount=root_diagnostics%oxygen_reduction_total*(t1-t0)
    end if
    write(u,'(I0,16(",",ES25.17E3),",",I0)',advance='no')j,t0,t1,result%water%mass%storage_start,result%water%mass%storage_end, &
      result%water%mass%total_in,result%water%mass%total_out,result%water%mass%residual, &
      result%chemical%mass_before,result%chemical%mass_after,result%chemical%external_in, &
      result%chemical%external_out,result%chemical%residual,infiltration,runon_amount,runoff,evap_amount, &
      accepted_count
    if(any(soil_evaporation_cm_day>0d0))write(u,'(A,ES25.17E3)',advance='no')',',soil_evap_amount
    write(u,'(4(A,ES25.17E3))',advance='no')',',potential_transpiration_cm_day(j)*(t1-t0),',',transpiration_amount, &
      ',',drought_amount,',',oxygen_amount
    if(historical_zero_solute_exfiltration)write(u,'(2(A,ES25.17E3))',advance='no') &
      ',',surface_exfiltration_amount,',',0d0
    if(seasonal_bottom.or.cauchy3_bottom)write(u,'(A,ES25.17E3)',advance='no')',',bottom_amount
    if(native_drainage)write(u,'(A,ES25.17E3)',advance='no')',',drainage_amount
    if(detailed_rain)write(u,'(A,ES25.17E3,A,I0)',advance='no')',',rain_supplied_cm,',',rain_segments_completed
    if(dynamic_temperature)write(u,'(A,ES25.17E3)',advance='no')',',observed_heat_residual_j_cm2
    write(u,'(A)')''
    clock=t1
  end do
  close(u)
  if(dynamic_temperature)then
    call write_pond_thermal_restart('restart.bin',column_id,template,p%parameter_set_id,p,water,solute,code)
  else
  call write_matrix_joint_restart_file('restart.bin',column_id,template,p%parameter_set_id,water,solute,code,allow_surface_mass=.true.)
  end if
  call require(code==JOINT_OK,'restart output failed')
  call water%snapshot(physical,ok);call require(ok,'water endpoint unavailable')
  call solute%snapshot(clock,theta,mobile,companion,revision)
  open(newunit=u,file='state.csv',status='new',action='write',iostat=io)
  call require(io==0,'cannot create state output')
  write(u,'(A)')'node,z_cm,dz_cm,head_cm,theta,concentration_mg_cm3,dissolved_mg_cm2,sorbed_mg_cm2'
  select type(q=>physical)
  class is(fmr_b110_physical_state_t)
    do j=1,numnod
      write(u,'(I0,7(",",ES25.17E3))')j,z(j),dz(j),q%pressure_head(j),theta(j), &
        mobile%concentration_mg_cm3(j),mobile%mass_mg_cm2(j),companion%sorbed_matrix_mass(j)
    end do
    water_amount=sum(theta*dz)+q%ponding_depth
    close(u)
    open(newunit=u,file='endpoint.csv',status='new',action='write',iostat=io)
    call require(io==0,'cannot create endpoint output')
    write(u,'(A)')'time_day,pond_cm,pond_solute_mg_cm2,total_water_cm,total_solute_mg_cm2'
    write(u,'(ES25.17E3,4(",",ES25.17E3))')clock,q%ponding_depth,companion%pond_mass,water_amount, &
      sum(mobile%mass_mg_cm2)+companion%solute_total()
    close(u)
    if(dynamic_temperature)then
      call build_soil_temperature_field_view(q%soil_temperature,heat_view,code)
      call require(code==0,'heat output view')
      open(newunit=u,file='temperature.csv',status='new',action='write',iostat=io)
      call require(io==0,'temperature output')
      write(u,'(A)')'node,temperature_c'
      do j=1,numnod
        write(u,'(I0,",",ES25.17E3)')j,heat_view%temperature_c(j)
      end do
      close(u)
    end if
  class default
    error stop 'unexpected physical owner'
  end select
  print '(A)','SWAP5_SOLUTE_COLUMN_COMPLETED'
  if(dynamic_temperature.and.boesten_evaporation)then
    select type(q=>physical)
    type is(fmr_b110_boesten_evaporation_state_t)
      write(*,'(A,2(1X,ES25.17E3))')'SWAP5_COMMITTED_BOESTEN_PAIR=',q%boesten_evaporation%spev,q%boesten_evaporation%saev
    end select
  end if
contains
  subroutine reset_day_totals()
    observed_heat_residual_j_cm2=0d0
    bottom_amount=0d0
    drainage_amount=0d0
    infiltration=0d0;runoff=0d0;runon_amount=0d0;evap_amount=0d0;soil_evap_amount=0d0
    surface_exfiltration_amount=0d0
    transpiration_amount=0d0;drought_amount=0d0;oxygen_amount=0d0;potential_amount=0d0
    accepted_count=0;rain_supplied_cm=0d0;rain_segments_completed=0
  end subroutine
  subroutine accumulate_fluxes(observation)
    type(fmr_serialized_physical_observation_t),intent(in)::observation
    integer::k
    if(dynamic_temperature)then
      call require(observation%soil_temperature_executed.and. &
        observation%soil_temperature_energy_accounting_complete,'accepted heat energy certificate unavailable')
      observed_heat_residual_j_cm2=max(observed_heat_residual_j_cm2, &
        abs(observation%soil_temperature_energy_residual_j_cm2))
    end if
    accepted_count=accepted_count+size(observation%accepted_water_flux_substeps)
    do k=1,size(observation%accepted_water_flux_substeps)
      associate(s=>observation%accepted_water_flux_substeps(k))
        bottom_amount=bottom_amount+s%bottom_flux*(s%t1-s%t0)
        drainage_amount=drainage_amount+sum(s%drainage_sink_by_level)*(s%t1-s%t0)
        transpiration_amount=transpiration_amount+sum(s%root_sink)*(s%t1-s%t0)
        if(substep_root_stress)then
          call require(s%substep_root_available,'accepted substep root diagnostics unavailable')
          drought_amount=drought_amount+s%root_drought_reduction_cm_day*(s%t1-s%t0)
          oxygen_amount=oxygen_amount+s%root_oxygen_reduction_cm_day*(s%t1-s%t0)
          potential_amount=potential_amount+s%root_potential_cm_day*(s%t1-s%t0)
        end if
        infiltration=infiltration+max(0d0,-s%top_flux)*(s%t1-s%t0)
        surface_exfiltration_amount=surface_exfiltration_amount+ &
          max(0d0,s%top_flux-s%converged_soil_evaporation_cm_day)*(s%t1-s%t0)
        runoff=runoff+s%converged_runoff_depth_cm
        runon_amount=runon_amount+s%converged_runon_rate_cm_day*(s%t1-s%t0)
        soil_evap_amount=soil_evap_amount+s%converged_soil_evaporation_cm_day*(s%t1-s%t0)
        evap_amount=evap_amount+s%converged_pond_evaporation_cm_day*(s%t1-s%t0)
      end associate
    end do
  end subroutine
  subroutine run_detailed_rain_day(day_start,day_end,day_result)
    real(real64),intent(in)::day_start,day_end
    type(matrix_joint_result_t),intent(out)::day_result
    type(matrix_joint_result_t)::part
    type(kernel_committed_state_t)::candidate_water
    type(matrix_solute_state_t)::candidate_solute
    type(fmr_b110_physical_forcing_t)::segment_forcing
    type(pond_step_t)::segment_supply
    type(fmr_serialized_physical_observation_t)::segment_observation
    real(real64)::cursor,endpoint
    integer::idx,left,right,middle,diagnostic_status
    logical::first_segment
    ! Existing owner types stage a day candidate. No persistent rain cursor or
    ! second physical state layout. Publish only after every interval succeeds.
    candidate_water=water;candidate_solute=solute
    cursor=day_start;first_segment=.true.;day_result=matrix_joint_result_t()
    call reset_day_totals()
    left=1;right=rain_count
    do while(left<right)
      middle=(left+right)/2
      if(rain_ends(middle)<=cursor)then
        left=middle+1
      else
        right=middle
      end if
    end do
    idx=left
    do while(cursor<day_end)
      endpoint=min(day_end,rain_ends(idx))
      call require(endpoint>cursor,'nonprogressing detailed rain interval')
      segment_forcing=forcing
      if(boesten_evaporation)then
        segment_forcing%boesten_evaporation%precipitation_rate_cm_per_day=rain_rates(idx)
      else
        segment_forcing%pond_input%rain_rate_cm_day=rain_rates(idx)
      end if
      segment_supply=supply;segment_supply%t0=cursor;segment_supply%t1=endpoint
      segment_supply%rain_rate=rain_rates(idx)
      if(dynamic_temperature)then
        call run_pond_thermal_interval(backend,column_id,template,p,candidate_water,segment_forcing,numerical, &
          candidate_solute,segment_supply,cursor,endpoint,part)
      else
        call run_pond_joint_interval(backend,column_id,template,p,candidate_water,segment_forcing,numerical, &
          candidate_solute,segment_supply,cursor,endpoint,part)
      end if
      if(part%status/=JOINT_OK)then
        day_result=part
        write(*,*)'detailed rain completed intervals:',rain_segments_completed
        if(dynamic_temperature)then
          call write_pond_thermal_restart('diagnostic-partial-candidate.bin',column_id,template,p%parameter_set_id, &
            p,candidate_water,candidate_solute,diagnostic_status)
        else
          call write_matrix_joint_restart_file('diagnostic-partial-candidate.bin',column_id,template,p%parameter_set_id, &
            candidate_water,candidate_solute,diagnostic_status,allow_surface_mass=.true.)
        end if
        call require(diagnostic_status==JOINT_OK,'partial day diagnostic')
        return
      end if
      call require(part%water%mass%complete,'incomplete rain interval accounting')
      call require(abs(part%water%mass%residual)<=1d-10.and.abs(part%chemical%residual)<=1d-10,'rain interval balance')
      if(first_segment)then
        day_result=part;first_segment=.false.
      else
        day_result%water%mass%storage_end=part%water%mass%storage_end
        day_result%water%mass%total_in=day_result%water%mass%total_in+part%water%mass%total_in
        day_result%water%mass%total_out=day_result%water%mass%total_out+part%water%mass%total_out
        day_result%water%mass%accepted_transaction_count=day_result%water%mass%accepted_transaction_count+ &
          part%water%mass%accepted_transaction_count
        day_result%chemical%mass_after=part%chemical%mass_after
        day_result%chemical%external_in=day_result%chemical%external_in+part%chemical%external_in
        day_result%chemical%external_out=day_result%chemical%external_out+part%chemical%external_out
        day_result%chemical%decay_out=day_result%chemical%decay_out+part%chemical%decay_out
        day_result%chemical%completed_substeps=day_result%chemical%completed_substeps+part%chemical%completed_substeps
        day_result%chemical%max_water_residual=max(day_result%chemical%max_water_residual,part%chemical%max_water_residual)
      end if
      segment_observation=backend%observation()
      call require(segment_observation%accepted_water_flux_trace_available,'detailed rain trace missing')
      call accumulate_fluxes(segment_observation)
      rain_supplied_cm=rain_supplied_cm+rain_rates(idx)*(endpoint-cursor)
      rain_segments_completed=rain_segments_completed+1
      cursor=endpoint
      if(cursor<day_end)idx=idx+1
    end do
    day_result%water%requested_t0=day_start;day_result%water%requested_t1=day_end;day_result%water%completed_t=day_end
    day_result%water%mass%interval_t0=day_start;day_result%water%mass%interval_t1=day_end
    day_result%water%mass%storage_change=day_result%water%mass%storage_end-day_result%water%mass%storage_start
    day_result%water%mass%residual=day_result%water%mass%storage_change- &
      day_result%water%mass%total_in+day_result%water%mass%total_out
    day_result%chemical%residual=day_result%chemical%mass_after-day_result%chemical%mass_before- &
      day_result%chemical%external_in+day_result%chemical%external_out
    call require(abs(day_result%water%mass%residual)<=1d-10.and.abs(day_result%chemical%residual)<=1d-10,'detailed day balance')
    water=candidate_water;solute=candidate_solute
  end subroutine
  subroutine select_project_profile(index)
    integer,intent(in)::index
    integer::selected
    selected=max(1,index)
    density_table=profile_tables(selected)
    root_parameters=profiles(selected)%parameters
  end subroutine
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(*),intent(in)::label
    if(.not.condition)then
      write(*,'(A)')trim(label)
      error stop 1
    end if
  end subroutine
end program

