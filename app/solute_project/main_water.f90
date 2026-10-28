! Explicit native crop application. Physics/state/restart providers are shared with solute_column.
program swap5_native_water_project
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
  use mod_column_swp_macro_configuration
  use mod_column_swp_macro_initial,only:native_macro_initial_t
  use mod_macro_water_restart
  use mod_fmr_macropore_configuration
  use mod_macropore_single_column_runtime,only:macropore_runtime_policy_t
  use mod_interception_source_window_runtime,only:initialize_interception_window,interception_source_window_t
  use mod_rutter_source_window_processor,only:initialize_rutter_canopy_state
  use mod_kernel_transactions,only:kernel_checkpoint_t,kernel_candidate_state_t,kernel_result_t,kernel_diagnostics_t
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
  integer :: solver_max_iterations=64
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
  real(real64) :: runoff_exponent=1d0
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
  namelist /column/ runoff_exponent,solver_max_iterations,schema,nodes,cell_thickness_cm,initial_head,initial_pond_cm,initial_pond_mass_mg_cm2,concentration_mg_cm3, &
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
  type(native_macro_initial_t)::macro_initial
  type(fmr_macropore_physical_config_t)::macro_config
  type(macropore_runtime_policy_t)::macro_policy
  type(interception_source_window_t)::committed_window
  type(kernel_checkpoint_t)::checkpoint
  type(kernel_candidate_state_t)::candidate
  type(kernel_result_t)::water_result
  type(kernel_diagnostics_t)::water_diagnostics
  character(1024)::macro_path
  character(16)::execution_mode='production'
  character(64)::binding
  real(real64)::canopy_capacity(MAX_WINDOWS)=0d0,transpiration_dry(MAX_WINDOWS)=0d0,transpiration_wet(MAX_WINDOWS)=0d0
  real(real64)::canopy_evaporation(MAX_WINDOWS)=0d0,vegetation_cover(MAX_WINDOWS)=0d0
  real(real64)::entry_ramp_width_cm=0d0
  real(real64)::stop_time=huge(1d0),day_start
  real(real64)::cursor,endpoint,rain_rate,day_residual,root_amount,drain_amount,rapid_amount,runoff_amount,bottom_amount_day
  real(real64)::pond_macro_amount,max_pond_depth,direct_macro_amount,max_net_source_check,net_source_check
  real(real64)::potential_root_amount,observed_heat,dt_check,delta_check,expected_check,cell_check,matrix_check,gross_check
  real(real64)::max_cell_check,max_matrix_check,max_gross_check
  integer::rain_index,step_index,uv,us,ut,up,uc,ud,part,commit_status
  real(real64)::oxygen_reduction_amount
  logical::did_commit,policy_ok,anchored_ceiling=.false.,source_surface_demand=.false.,perched_jacobian=.false.
  namelist /rutter_daily/canopy_capacity,transpiration_dry,transpiration_wet,canopy_evaporation,vegetation_cover
  call get_command_argument(10,arg)
  if(len_trim(arg)>0)execution_mode=trim(arg)
  call require(trim(execution_mode)=='production'.or.trim(execution_mode)=='experimental'.or. &
    trim(execution_mode)=='comparison','unknown execution mode')
  call get_command_argument(11,arg)
  if(len_trim(arg)>0)then
    call require(trim(arg)=='source-surface-demand','unknown source forcing variant')
    call require(trim(execution_mode)=='experimental','source surface demand requires experimental mode')
    source_surface_demand=.true.
  end if
  call get_command_argument(12,arg)
  if(len_trim(arg)>0)then
    call require(trim(arg)=='perched-jacobian','unknown numerical Jacobian policy')
    call require(trim(execution_mode)=='experimental','perched Jacobian requires experimental mode')
    perched_jacobian=.true.
  end if
  call get_command_argument(1,path)
  call get_command_argument(2,restart_path)
  call get_command_argument(4,legacy_swp)
  call get_command_argument(5,macro_path);call get_command_argument(6,binding)
  call get_command_argument(8,arg)
  if(len_trim(arg)>0)then
    call require(trim(arg)=='anchored-cauchy','unknown native execution policy')
    anchored_ceiling=.true.
  end if
  call get_command_argument(9,arg)
  if(len_trim(arg)>0)then
    read(arg,*,iostat=io)entry_ramp_width_cm
    call require(io==0,'entry transition width grammar')
    call require(ieee_is_finite(entry_ramp_width_cm),'entry transition width finite')
    call require(anchored_ceiling.and.entry_ramp_width_cm>0d0.and.entry_ramp_width_cm<=1d-3, &
      'explicit entry transition width range/policy')
  end if
  call get_command_argument(3,arg)
  stop_after=MAX_WINDOWS
  if(len_trim(arg)>0)then
    read(arg,*,iostat=io)stop_after
    call require(io==0,'invalid stop-after window')
  end if
  call get_command_argument(7,arg)
  if(len_trim(arg)>0)then
    read(arg,*,iostat=io)stop_time
    call require(io==0,'invalid stop time')
    call require(ieee_is_finite(stop_time).and.stop_time>0d0,'positive stop time')
  end if
  open(newunit=u,file=trim(path),status='old',action='read',iostat=io)
  call require(io==0,'cannot open input')
  read(u,nml=column,iostat=io,iomsg=message)
  if(io/=0)write(*,'(A)')trim(message)
  call require(io==0,'invalid column namelist')
  call require(solver_max_iterations>=1.and.solver_max_iterations<=256,'solver iteration budget range')
  call require(ieee_is_finite(runoff_exponent).and.runoff_exponent>=0.5d0.and.runoff_exponent<=2d0, &
    'experimental runoff exponent range0.5..2')
  if(runoff_exponent/=1d0)call require(trim(execution_mode)=='experimental','nonlinear runoff requires experimental mode')
  if(solver_max_iterations/=64)call require(trim(execution_mode)=='experimental', &
    'nondefault solver iteration budget requires experimental mode')
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
  read(u,nml=rutter_daily,iostat=io,iomsg=message)
  if(io/=0)print *,trim(message)
  call require(io==0,'native Rutter plan missing')
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
  call require(cauchy3_bottom.and.native_drainage.and.boesten_evaporation.and.swp_heat_bootstrap.and.substep_root_stress, &
    'native macro water requires source Cauchy3/DRAMET3/Boesten/numeric heat and substep roots')
  call require(len_trim(binding)==64.and.len_trim(macro_path)>0,'native macro descriptor/binding required')
  call require(all(concentration_mg_cm3==0d0).and.initial_pond_mass_mg_cm2==0d0,'SWSOLU0 excludes chemical state')
  call require(all(ieee_is_finite(canopy_capacity)).and.all(ieee_is_finite(transpiration_dry)).and. &
    all(ieee_is_finite(transpiration_wet)).and.all(ieee_is_finite(canopy_evaporation)).and. &
    all(ieee_is_finite(vegetation_cover)),'finite Rutter plan')
  call require(all(canopy_capacity>=0d0).and.all(transpiration_dry>=0d0).and.all(transpiration_wet>=0d0).and. &
    all(canopy_evaporation>=0d0).and.all(vegetation_cover>=0d0).and.all(vegetation_cover<=1d0),'Rutter plan limits')
  call import_column_macro_configuration(trim(macro_path),macro_initial,macro_config, &
       allow_variable_surface=trim(execution_mode)=='experimental')
  macro_config%rate_template%unsaturated%entry_transition_width_cm=entry_ramp_width_cm
  call require(macro_initial%geometry%num_nodes==numnod.and.all(macro_initial%geometry%dz==dz),'source macro/water geometry')
  p%parameter_set_id=671001_int64;p%active_nodes=numnod;p%z=z;p%dz=dz;p%node_distance=disnod(:numnod);p%cofgen=swp_cofgen
  ! Original hconduc deliberately excludes KSATEXM for SWMACRO1.
  p%ksatexm_extension_active=.false.;p%bottom_mode=3;p%swkimpl=0;p%swkmean=1
  p%max_iterations=solver_max_iterations;p%max_backtracking=24;p%root_extraction_active=.true.;p%macropore_active=.true.
  p%compartment_balance_tolerance=1d-10;p%total_balance_tolerance=1d-10
  p%head_abs_tolerance=1d-8;p%head_rel_tolerance=1d-8;p%ponding_tolerance=1d-10
  allocate(p%macropore);p%macropore=macro_config
  p%boesten_evaporation_active=.true.;allocate(p%boesten_evaporation);p%boesten_evaporation%cofred=boesten_cofred
  p%soil_temperature_active=.true.;allocate(p%soil_temperature,initial%soil_temperature,forcing%soil_temperature)
  call import_column_swp_heat(trim(legacy_swp),dz,z,disnod(:numnod),p%cofgen(2,:),p%soil_temperature, &
    initial%soil_temperature,forcing%soil_temperature)
  initial%active_nodes=numnod;initial%pressure_head=swp_heads;initial%water_content=macro_initial%theta
  initial%ponding_depth=initial_pond_cm;initial%groundwater_level=macro_initial%groundwater
  allocate(initial%macropore,initial%rutter);initial%macropore=macro_initial%state
  call initialize_rutter_canopy_state(0d0,initial%rutter,code);call require(code==0,'source initial canopy')
  p%drainage_response_active=.true.
  allocate(p%drainage_response_levels(1),p%drainage_trial_distribution,forcing%drainage_response_controls(1))
  p%drainage_response_levels(1)%variant=FMR_DRAIN_VARIANT_DRAMET3
  p%drainage_response_levels(1)%dramet3%drain_bottom_cm=drain_bottom_cm
  p%drainage_response_levels(1)%dramet3%drainage_resistance_day=drain_resistance
  p%drainage_response_levels(1)%dramet3%infiltration_resistance_day=drain_infiltration_resistance
  p%drainage_response_levels(1)%dramet3%allocation_mode=3;p%drainage_response_levels(1)%dramet3%drain_type=1
  call initialize_dramet3_channel_control(p%drainage_response_levels(1)%dramet3_channel,0d0,drain_legacy_origin, &
    drain_table_times(:drain_table_count),drain_table_heads(:drain_table_count),code)
  call require(code==DRAMET3_OK,'source drainage channel')
  p%drainage_trial_distribution%active_nodes=numnod;p%drainage_trial_distribution%dz=dz
  p%drainage_trial_distribution%zbotcp=z-.5d0*dz;p%drainage_trial_distribution%saturated_conductivity=p%cofgen(3,:)
  p%drainage_trial_distribution%horizontal_anisotropy_factor=drain_anisotropy(:numnod)
  p%drainage_trial_distribution%drain_spacing=100d0*drain_spacing_m
  allocate(forcing%legacy_swbotb3_implicit_control)
  call forcing%legacy_swbotb3_implicit_control%initialize_table(0d0,bottom_legacy_origin,cauchy3_dates(:cauchy3_count), &
    cauchy3_heads(:cauchy3_count),cauchy3_resistance,cauchy3_half_cell,code)
  call require(code==0,'source Cauchy control')
  allocate(forcing%root_extraction_sink(numnod),forcing%subsurface_irrigation_source(numnod),forcing%substep_root, &
    forcing%boesten_evaporation,forcing%rutter)
  forcing%root_extraction_sink=0d0;forcing%subsurface_irrigation_source=0d0
  forcing%experimental_empirical_oxygen=trim(execution_mode)=='experimental'
  forcing%experimental_process_combinations=trim(execution_mode)=='experimental'
  forcing%top_flux=0d0;forcing%bottom_flux=0d0
  forcing%boesten_evaporation%ponding_max_cm=pond_max_cm
  forcing%boesten_evaporation%runoff_resistance_day=runoff_resistance_day
  forcing%boesten_evaporation%runoff_exponent=runoff_exponent
  column_id%column_id=671001_int64;column_id%template_id=671010_int64;column_id%parameter_ref=p%parameter_set_id
  column_id%state_handle=1_int64;column_id%forcing_handle=1_int64;column_id%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  template%template_id=column_id%template_id;template%physics_topology_id=671020_int64
  template%vertical_layout_id=671030_int64;template%state_layout_id=671040_int64
  template%solver_interface_id=671050_int64;template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RUTTER_BOESTEN_MACROPORE
  numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
  numerical%transaction%temporal_tolerance=temporal_tolerance;numerical%transaction%mass_tolerance=1d-10
  numerical%transaction%max_retries=40;numerical%transaction%retry_scale=.5d0;numerical%max_committed_substeps=100000
  call backend%initialize(top)
  macro_policy%perched_jacobian_enabled=perched_jacobian
  macro_policy%anchored_cauchy_step_ceiling=anchored_ceiling
  macro_policy%enabled=.true.;macro_policy%inner_richards_exchange_enabled=.true.
  macro_policy%solver_mass_tolerance_cm=1d-10;macro_policy%internal_exchange_tolerance_cm=1d-10
  call backend%configure_macropore_policy(macro_policy,policy_ok);call require(policy_ok,'Reference macro policy')
  if(trim(restart_path)=='-')then
    call fmr_new_b110_boesten_macropore_committed_state(water,column_id%column_id,initial,boesten_evaporation_state_t(),0d0,ok)
    call require(ok,'source native committed initialization')
  else
    call read_macro_water_restart(trim(restart_path),binding,column_id,template,p,water,committed_window,code)
    call require(code==0,'native macro water restart rejected')
  end if
  call water%current_time(clock,ok);call require(ok,'source native clock')
  first=floor(clock)+1
  call require(clock==real(first-1,real64).or.any(rain_ends(:rain_count)==clock),'restart must be a source-event/day boundary')
  if(stop_time<huge(1d0))then
    call require(stop_time>clock.and.stop_time<=real(min(windows,stop_after),real64),'stop time extent')
    call require(any(ends_day(:windows)==stop_time).or.any(rain_ends(:rain_count)==stop_time),'stop at source-event/day boundary')
  end if
  open(newunit=uv,file='budget.csv',status='new');write(uv,'(a)') &
    'day,t0,t1,water_residual_cm,root_cm,drainage_cm,rapid_cm,runoff_cm,bottom_cm,soil_evap_cm,wet_potential_cm,observed_last_heat_residual_j_cm2,max_macro_cell_cm,max_matrix_cm,max_combined_cm,pond_to_macro_cm,max_pond_cm,direct_macro_cm,max_net_source_cm'
  open(newunit=up,file='progress.csv',status='new');write(up,'(a)')'day,segment,t0,t1,attempts,solver_rejections,temporal_rejections,mass_rejections,residual_cm'
  open(newunit=uc,file='cost.csv',status='new');write(uc,'(a)') &
    't0,t1,completed,nonlinear_iterations,headcalc_calls,linear_solves,backtracking_attempts,accepted_substeps,min_accepted_dt,max_accepted_dt'
  open(newunit=ud,file='diagnostics.csv',status='new');write(ud,'(a)')'day,t0,t1,oxygen_reduction_cm,groundwater_cm'
  rain_index=1
  do while(rain_index<rain_count.and.rain_ends(rain_index)<=clock+1d-12);rain_index=rain_index+1;end do
  daily_loop:do j=first,min(windows,stop_after)
    call select_project_profile(profile_index(j));crop_input=fmr_root_uptake_crop_input_t()
    if(crop_active(j))then
      call materialize_static_root_profile(density_table,z-.5d0*dz,maximum_root_depth_cm,root_depth_cm(j), &
        crop_input%rooted_nodes,crop_input%cumulative_root_fraction,code)
      call require(code==CROP_ROOT_PROFILE_OK,'source daily root geometry')
    end if
    forcing%substep_root%parameters=root_parameters
    forcing%substep_root%request%rooted_nodes=crop_input%rooted_nodes
    if(allocated(forcing%substep_root%request%cumulative_root_fraction))deallocate(forcing%substep_root%request%cumulative_root_fraction)
    if(allocated(crop_input%cumulative_root_fraction)) &
      forcing%substep_root%request%cumulative_root_fraction=crop_input%cumulative_root_fraction
    forcing%substep_root%request%potential_transpiration=transpiration_dry(j)
    forcing%soil_temperature%air_temperature_c=air_temperature_c(j)
    cursor=max(clock,real(j-1,real64));day_start=cursor;part=0;day_residual=0d0;root_amount=0d0;drain_amount=0d0
    oxygen_reduction_amount=0d0
    rapid_amount=0d0;runoff_amount=0d0;bottom_amount_day=0d0;evap_amount=0d0;potential_root_amount=0d0;observed_heat=0d0
    max_cell_check=0d0;max_matrix_check=0d0;max_gross_check=0d0;pond_macro_amount=0d0;max_pond_depth=0d0;direct_macro_amount=0d0;max_net_source_check=0d0
    do while(cursor<ends_day(j))
      part=part+1;endpoint=ends_day(j);rain_rate=rain_cm_day(j)
      if(detailed_rain)then
        do while(rain_index<rain_count.and.rain_ends(rain_index)<=cursor+1d-12);rain_index=rain_index+1;end do
        endpoint=min(endpoint,rain_ends(rain_index));rain_rate=rain_rates(rain_index)
      end if
      call require(endpoint>cursor,'nonprogressing source interval')
      call initialize_interception_window(1000000_int64+int(j,int64)*MAX_RAIN_EVENTS+rain_index,cursor,endpoint, &
        rain_rate*(endpoint-cursor),forcing%rutter%source_window,code)
      call require(code==0,'source rain window')
      ! DATAQUAL02: original positive demand belongs to the existing Boesten owner.
      ! Explicit corrected-source variant; literal production mapping is retained.
      if(source_surface_demand)then
        forcing%boesten_evaporation%potential_bare_soil_evaporation_cm_per_day=soil_evaporation_cm_day(j)
        forcing%boesten_evaporation%potential_pond_evaporation_cm_per_day=evaporation_cm_day(j)
      end if
      forcing%rutter%prepared=.true.
      forcing%rutter%matrix_source_area_partition=.true.
      forcing%rutter%process%vegetation_cover_fraction=vegetation_cover(j)
      forcing%rutter%process%canopy_storage_capacity_cm=canopy_capacity(j)
      forcing%rutter%process%interception_evaporation_capacity_cm_per_day=canopy_evaporation(j)
      forcing%rutter%process%potential_transpiration_dry_cm_per_day=transpiration_dry(j)
      forcing%rutter%process%potential_transpiration_wet_cm_per_day=transpiration_wet(j)
      forcing%rutter%potential_bare_soil_evaporation_cm_per_day=soil_evaporation_cm_day(j)
      forcing%rutter%potential_pond_evaporation_cm_per_day=evaporation_cm_day(j)
      forcing%rutter%ponding_max_cm=pond_max_cm;forcing%rutter%runoff_resistance_day=runoff_resistance_day
      forcing%rutter%runoff_exponent=runoff_exponent
      call water%capture_checkpoint(checkpoint,ok);call require(ok,'native committed checkpoint')
      call backend%run_trial(column_id,template,p,water,forcing,numerical,cursor,endpoint,checkpoint, &
        water_result,candidate,water_diagnostics,trace_accepted_water_flux_substeps=.true.)
      write(up,'(i0,a,i0,2(a,es25.17e3),4(a,i0),a,es25.17e3)')j,',',part,',',cursor,',',endpoint,',', &
        water_diagnostics%attempts,',',water_diagnostics%solver_rejections,',',water_diagnostics%temporal_rejections,',', &
        water_diagnostics%mass_rejections,',',water_result%mass%residual
      flush(up)
      write(uc,'(es25.17e3,a,es25.17e3,a,l1,5(a,i0),2(a,es25.17e3))')cursor,',',endpoint,',',water_result%completed, &
        ',',water_diagnostics%nonlinear_iterations,',',water_diagnostics%headcalc_calls,',',water_diagnostics%linear_solves, &
        ',',water_diagnostics%backtracking_attempts,',',water_diagnostics%accepted_substeps, &
        ',',water_diagnostics%min_accepted_substep_duration,',',water_diagnostics%max_accepted_substep_duration
      flush(uc)
      if(.not.water_result%completed)then
        call water%snapshot(physical,ok)
        select type(s=>physical)
        type is(fmr_b110_boesten_macropore_state_t)
          print *, 'NATIVE_REJECT_RUTTER_CLOCK',s%rutter%accepted_until(),cursor
        end select
        observation=backend%observation()
        print *, 'NATIVE_REJECT_DETAIL',observation%solver_status,observation%macropore_inner_richards_exchange_used, &
          observation%macropore_inner_initial_exchange_rate_cm_per_day,observation%macropore_inner_final_exchange_rate_cm_per_day
        call write_macro_water_restart('diagnostic-rejected.bin',binding,column_id,template,p,water,committed_window,code)
        write(*,*)'NATIVE_WATER_REJECTED',j,part,cursor,endpoint,water_result%status,code
        error stop 'original source water interval rejected'
      end if
      call require(candidate%ready().and.water_result%mass%complete,'native complete candidate')
      call require(abs(water_result%mass%residual)<=1d-10,'native water budget')
      observation=backend%observation();call require(observation%accepted_water_flux_trace_available,'native accepted trace')
      do step_index=1,size(observation%accepted_water_flux_substeps)
        associate(s=>observation%accepted_water_flux_substeps(step_index))
        call require(fmr_macropore_trace_receipt_valid(s,numnod),'native macro water receipt')
        call require(fmr_macropore_trace_cell_balance_valid(s,numnod),'native macro cell certificate')
        dt_check=s%t1-s%t0
        cell_check=maxval(abs(s%macropore_water_end-s%macropore_water_start-dt_check* &
          (s%macropore_vertical_face_rate(:,:numnod)-s%macropore_vertical_face_rate(:,2:)- &
           s%macropore_matrix_exchange_domain-s%macropore_external_outflow_rate)))
        call require(cell_check<=1d-10,'independent macro cell budget')
        delta_check=sum(dz*s%matrix_area_fraction*(s%water_end-s%water_start))
        expected_check=dt_check*(-s%top_flux+s%bottom_flux+sum(s%net_node_source))
        matrix_check=abs(delta_check-expected_check)
        call require(matrix_check<=1d-10,'independent matrix budget')
        call require(abs(sum(s%macropore_vertical_face_rate(:,numnod+1))*dt_check)<=1d-10,'unbooked macro export')
        call require(s%converged_surface_available,'native source surface receipt')
        delta_check=delta_check+sum(s%macropore_water_end-s%macropore_water_start)+s%pond_end_cm-s%pond_start_cm
        expected_check=dt_check*(s%converged_surface_net_potential_cm_day+s%bottom_flux+ &
          sum(s%subsurface_source-s%drainage_sink-s%root_sink))+s%macropore_surface_return_cm+ &
          s%macropore_accepted_cm-s%converged_runoff_depth_cm-s%macropore_rapid_outflow_cm
        gross_check=abs(delta_check-expected_check)
        call require(gross_check<=1d-10,'independent declared-boundary combined budget')
        call require(s%converged_gross_sources_available,'native supplied source receipt')
        expected_check=dt_check*(s%converged_rain_rate_cm_day+s%converged_irrigation_rate_cm_day+ &
          s%converged_snowmelt_rate_cm_day+s%converged_runon_rate_cm_day-s%converged_soil_evaporation_cm_day- &
          s%converged_pond_evaporation_cm_day+s%bottom_flux+sum(s%subsurface_source-s%drainage_sink-s%root_sink))- &
          s%converged_runoff_depth_cm-s%macropore_rapid_outflow_cm
        net_source_check=abs(delta_check-expected_check)
        call require(net_source_check<=1d-10,'independent supplied-source combined budget')
        max_net_source_check=max(max_net_source_check,net_source_check)
        direct_macro_amount=direct_macro_amount+s%macropore_external_top_cm
        max_cell_check=max(max_cell_check,cell_check);max_matrix_check=max(max_matrix_check,matrix_check)
        max_gross_check=max(max_gross_check,gross_check)
        oxygen_reduction_amount=oxygen_reduction_amount+s%root_oxygen_reduction_cm_day*dt_check
        root_amount=root_amount+sum(s%root_sink)*(s%t1-s%t0)
        drain_amount=drain_amount+sum(s%drainage_sink)*(s%t1-s%t0)
        pond_macro_amount=pond_macro_amount+s%macropore_pond_accepted_cm
        max_pond_depth=max(max_pond_depth,s%pond_start_cm,s%pond_end_cm)
        rapid_amount=rapid_amount+s%macropore_rapid_outflow_cm
        runoff_amount=runoff_amount+s%converged_runoff_depth_cm
        bottom_amount_day=bottom_amount_day+s%bottom_flux*(s%t1-s%t0)
        evap_amount=evap_amount+s%converged_soil_evaporation_cm_day*(s%t1-s%t0)
        potential_root_amount=potential_root_amount+s%root_potential_cm_day*(s%t1-s%t0)
        end associate
      end do
      observed_heat=max(observed_heat,abs(observation%soil_temperature_energy_residual_j_cm2))
      call backend%commit_trial_candidate(water,candidate,water_diagnostics,did_commit,commit_status)
      call require(did_commit.and.commit_status==0,'native candidate publication')
      call water%current_time(clock,ok);call require(ok.and.clock==endpoint,'native exact committed clock')
      committed_window=forcing%rutter%source_window
      day_residual=day_residual+water_result%mass%residual;cursor=endpoint
      if(cursor==stop_time)exit
    end do
    write(uv,'(i0,18(a,es25.17e3))')j,',',day_start,',',cursor,',',day_residual,',',root_amount,',',drain_amount,',',rapid_amount,',',runoff_amount, &
      ',',bottom_amount_day,',',evap_amount,',',potential_root_amount,',',observed_heat, &
      ',',max_cell_check,',',max_matrix_check,',',max_gross_check,',',pond_macro_amount,',',max_pond_depth,',',direct_macro_amount,',',max_net_source_check
    flush(uv)
    call water%snapshot(physical,ok);call require(ok,'diagnostic committed state')
    select type(s=>physical)
    type is(fmr_b110_boesten_macropore_state_t)
      write(ud,'(i0,4(a,es25.17e3))')j,',',day_start,',',cursor,',',oxygen_reduction_amount,',',s%groundwater_level
    end select
    flush(ud)
    call write_macro_water_restart('restart.bin',binding,column_id,template,p,water,committed_window,code)
    call require(code==0,'native coupled restart publication')
    write(*,'(a,i0,a,es25.17e3)')'NATIVE_WATER_ACCEPTED day=',j,' residual_cm=',day_residual
    flush(6)
    if(cursor>=stop_time)exit daily_loop
  end do daily_loop
  close(uv);close(up);close(uc);close(ud)
  call water%snapshot(physical,ok);call require(ok,'native final committed snapshot')
  select type(s=>physical)
  type is(fmr_b110_boesten_macropore_state_t)
    open(newunit=us,file='state.csv',status='new');write(us,'(a)')'node,head_cm,theta,dynamic_macro_cm'
    do k=1,numnod;write(us,'(i0,3(a,es25.17e3))')k,',',s%pressure_head(k),',',s%water_content(k),',',s%macropore%dynamic_volume_cp(k);end do
    close(us)
    call build_soil_temperature_field_view(s%soil_temperature,heat_view,code);call require(code==0,'native final heat')
    open(newunit=ut,file='temperature.csv',status='new');write(ut,'(a)')'node,temperature_c'
    do k=1,numnod;write(ut,'(i0,a,es25.17e3)')k,',',heat_view%temperature_c(k);end do;close(ut)
  class default
    error stop 'native final state layout'
  end select
  print '(a)','NATIVE_SWSOLU0_MACRO_RUTTER_HEAT_PROJECT_PASS'
contains
  subroutine select_project_profile(index)
    integer,intent(in)::index
    integer::selected
    selected=max(1,index);density_table=profile_tables(selected);root_parameters=profiles(selected)%parameters
  end subroutine
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(*),intent(in)::label
    if(.not.condition)then;print '(a)',trim(label);error stop 1;end if
  end subroutine
end program
