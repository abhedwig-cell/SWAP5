program test_ppa_wu05a9_fmr_top_input_trial
  use, intrinsic :: iso_fortran_env, only: int64, real64, error_unit
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_MACROPORE
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_macropore_configuration, only: initialize_fmr_macropore_standard_config, prepare_fmr_macropore_rapid_reference
  use mod_fmr_macropore_top_input, only: fmr_macropore_top_input_forcing_t
  use mod_macropore_single_column_runtime, only: macropore_runtime_policy_t
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_result_t, evaluate_macropore_geometry, &
       evaluate_macropore_geometry_return
  use mod_macropore_standard_storage, only: macropore_standard_storage_view_t, canonicalize_macropore_standard_storage
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_macropore_dynamic_shrinkage, only: dynamic_shrinkage_config_t, prepare_clay_kim_option1, &
       SHRINK_PEAT_DIRECT, SHRINK_PEAT_SEGMENTS, SHRINK_RIGID, SHRINK_KIM, &
       prepare_clay_kim_option2, prepare_peat_characteristic_points, &
       evaluate_dynamic_crack_profile, prepare_rapid_drain_reference_kd, derive_dynamic_minimum_subsidence, map_surface_crack_depth_to_node
  implicit none
  character(len=1)::constitutive_flag,fit_flag

  integer(int64),parameter :: column_id=508001_int64
  real(real64),parameter :: dt=1.0e-3_real64

  type(fmr_serialized_reference_backend_t) :: backend
  type(fmr_serialized_physical_observation_t) :: observation
  type(fixed_flux_top_boundary_provider_t),target :: top
  type(fmr_b110_physical_parameters_t),target :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_b110_physical_state_t) :: physical
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_result_t) :: result
  type(kernel_candidate_state_t) :: candidate
  type(kernel_diagnostics_t) :: diagnostics
  type(macropore_runtime_policy_t) :: policy
  type(dynamic_shrinkage_config_t) :: shrinkage
  type(macropore_geometry_result_t) :: geometry
  type(macropore_standard_storage_view_t) :: storage_view
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t) :: hyd
  class(transaction_state_t),allocatable :: snapshot
  real(real64),allocatable :: static_volume(:), domain_fraction(:,:), diameter(:)
  real(real64),allocatable :: probe_dynamic(:),probe_subsidence(:),displacement(:,:)
  real(real64),allocatable :: theta_s(:),theta_r(:),wall_correction(:),sorp_max(:),sorp_alpha(:)
  real(real64),allocatable :: conductivity(:),entry_head(:),sorp_fac_parallel(:),ksat_horizontal(:),cdarcy(:,:)
  integer,allocatable :: potential_bottom(:)
  real(real64) :: heads(numnod),water(numnod),cond(numnod),cap(numnod),dkdh(numnod)
  real(real64) :: macro_before, macro_after
  logical :: ok, did_commit, available
  logical :: probe_ok
  logical :: dynamic_enabled
  logical :: geometry_changes_expected,inner_route
  character(len=1) :: dynamic_flag
  integer :: commit_status
  integer :: nd

  fit_flag='0'
  call get_environment_variable('WU05_MIGMAC04_FIT',fit_flag)
  constitutive_flag='0'
  call get_environment_variable('WU05_MIGMAC03_LAW',constitutive_flag)
  dynamic_flag='0'
  call get_environment_variable('WU05_MIGMAC02_DYNAMIC',dynamic_flag)
  dynamic_enabled=dynamic_flag=='1' .or. dynamic_flag=='2' .or. dynamic_flag=='4' .or. dynamic_flag=='5'
  geometry_changes_expected=dynamic_flag=='1'
  inner_route=dynamic_enabled .or. dynamic_flag=='3'
  nd=1
  if(dynamic_flag=='5')nd=2
  call initialize_parameters(parameters)
  call initialize_b110_default_mvg_parameters(hp,parameters%cofgen)
  call bind_b110_default_mvg_provider(hyd,hp,dt)
  call initialize_macropore_config(parameters,ok)
  call require(ok,'physical macropore config initialized')
  call require(allocated(parameters%macropore%matrix_area_fraction),'static macro matrix-area fraction derived')
  call require(all(abs(parameters%macropore%matrix_area_fraction- &
       (1.0_real64-0.25_real64/dz))<=1.0e-14_real64),'legacy FrArMtrx default exact')
  parameters%macropore_active=.true.

  heads=-100.0_real64
  if(dynamic_flag=='4' .or. dynamic_flag=='5')heads=-1000.0_real64
  call hyd%evaluate(heads,water,cond,cap,dkdh)

  physical%active_nodes=numnod
  allocate(physical%pressure_head(numnod),physical%water_content(numnod),physical%macropore)
  physical%pressure_head=heads
  physical%water_content=water
  physical%ponding_depth=0.0_real64
  physical%groundwater_level=-1000.0_real64
  call physical%macropore%initialize(nd,numnod,ok)
  call require(ok,'macropore continuation initialized')
  physical%macropore%dynamic_volume_cp=0.0_real64
  
  call evaluate_dynamic_crack_profile(parameters%macropore%shrinkage,water,water,dz, &
       parameters%macropore%matrix_area_fraction,physical%macropore%dynamic_volume_cp, &
       probe_dynamic,probe_ok,probe_subsidence)
  call require(probe_ok,'MIGMAC02 dry accepted-state crack profile evaluates')
  if(dynamic_flag=='4' .or. dynamic_flag=='5')physical%macropore%dynamic_volume_cp=probe_dynamic
  if(geometry_changes_expected)call require(any(probe_dynamic>1.0e-12_real64),'MIGMAC02 dry accepted-state crack volume nonzero')
  call evaluate_macropore_geometry(parameters%macropore%geometry,physical%macropore%dynamic_volume_cp,geometry)
  call require(geometry%valid,'initial macropore geometry')
  physical%macropore%icp_bottom_domain=geometry%bottom_domain
  physical%macropore%volume_domain_cp=geometry%volume_domain_cp
  physical%macropore%water_domain_cp=0.0_real64
  physical%macropore%water_domain_cp(1,numnod)=0.20_real64
  if(dynamic_flag=='4' .or. dynamic_flag=='5') &
       physical%macropore%water_domain_cp=0.85_real64*geometry%volume_domain_cp
  call canonicalize_macropore_standard_storage(physical%macropore,1,z,dz,storage_view,ok)
  call require(ok,'initial macropore standard storage canonical')
  macro_before=sum(physical%macropore%water_domain_cp)

  call fmr_new_b110_committed_state(committed,column_id,physical,0.0_real64,ok)
  call require(ok,'committed state initialized')
  call fmr_capture_checkpoint(committed,checkpoint,ok)
  call require(ok,'checkpoint captured')

  call initialize_forcing(forcing)

  template%template_id=508001_int64
  template%physics_topology_id=508002_int64
  template%vertical_layout_id=508003_int64
  template%state_layout_id=508004_int64
  template%solver_interface_id=508005_int64
  template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_MACROPORE
  template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
  template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

  column%column_id=column_id
  column%template_id=template%template_id
  column%parameter_ref=1_int64
  column%state_handle=1_int64
  column%forcing_handle=1_int64
  column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

  config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
  config%transaction%temporal_tolerance=1.0_real64
  config%transaction%mass_tolerance=1.0e-9_real64
  config%transaction%retry_scale=0.5_real64
  config%transaction%max_retries=4
  config%max_committed_substeps=16
  config%progress_tolerance=0.0_real64

  policy%enabled=.true.
  policy%inner_richards_exchange_enabled=inner_route
  policy%max_correctors=80
  policy%exchange_relative_tolerance=1.0e-10_real64
  policy%exchange_floor=1.0e-12_real64
  policy%damping_previous_weight=0.5_real64
  policy%solver_mass_tolerance_cm=1.0e-9_real64
  policy%internal_exchange_tolerance_cm=1.0e-9_real64

  call backend%initialize(top)
  call backend%configure_macropore_policy(policy,ok)
  call require(ok,'macropore policy configured independently')

  call backend%run_trial(column,template,parameters,committed,forcing,config,0.0_real64,dt,checkpoint, &
       result,candidate,diagnostics)
  write(error_unit,'(*(g0))') 'PPA_WU05A9_FMR_DIAG|STATUS=',result%status,'|COMPLETED=',result%completed, &
       '|ADMISSION_REJECTIONS=',diagnostics%admission_rejections,'|TRANSACTION_CALLS=',diagnostics%transaction_calls, &
       '|ATTEMPTS=',diagnostics%attempts,'|RETRIES=',diagnostics%retries,'|HEAD_CALC=',diagnostics%headcalc_calls, &
       '|NONLINEAR=',diagnostics%nonlinear_iterations,'|TEMP_REJ=',diagnostics%temporal_rejections, &
       '|MASS_REJ=',diagnostics%mass_rejections,'|SOLVER_REJ=',diagnostics%solver_rejections, &
       '|MAX_STEP_MASS=',diagnostics%max_abs_step_mass_residual,'|CANDIDATE_READY=',candidate%ready()
  flush(error_unit)
  call require(result%status==CANONICAL_STATUS_COMPLETED .and. result%completed,'FMR macropore trial completed')
  call require(result%mass%complete,'FMR macropore mass complete')
  call require(result%mass%missing_contribution_mask==TX_MASS_MISSING_NONE,'FMR macropore mass missing mask')
  call require(abs(result%mass%residual)<=1.0e-9_real64,'FMR macropore mass residual')
  call require(candidate%ready(),'FMR macropore candidate ready')
  observation=backend%observation()
  call require(observation%macropore_top_input_active,'A9 top-input route active')
  if(dynamic_enabled)call require(observation%macropore_inner_richards_exchange_used,'MIGMAC02 inner Richards callback used')
  call require(observation%macropore_requested_top_cm>0.0_real64,'A9 requested top receipt positive')
  call require(observation%macropore_accepted_top_cm>0.0_real64,'A9 accepted top receipt positive')
  call require(observation%macropore_accepted_top_cm<=observation%macropore_requested_top_cm+1.0e-12_real64, &
       'A9 accepted top bounded by request')
  call require(abs(observation%macropore_accepted_top_cm+observation%macropore_returned_surface_cm- &
       observation%macropore_requested_top_cm)<=1.0e-9_real64,'A9 top receipt exact')
  if(dynamic_flag=='4' .or. dynamic_flag=='5')then
    call require(observation%macropore_inner_final_exchange_rate_cm_per_day>1.0e-5_real64, &
         'MIGMAC02 displaced-water matrix receipt active')
  end if
  if(dynamic_flag=='5')call require(observation%macropore_rapid_outflow_cm>0.0_real64, &
       'MIGMAC02 dynamic geometry rapid drainage active')

  ! A trial must not mutate committed authority.
  call committed%snapshot(snapshot,available)
  call require(available,'precommit snapshot available')
  select type(s=>snapshot)
  type is(fmr_b110_physical_state_t)
    call require(allocated(s%macropore),'precommit macro state present')
    call require(abs(sum(s%macropore%water_domain_cp)-macro_before)<=1.0e-14_real64, &
         'trial leaves committed macropore storage unchanged')
  class default
    error stop 'A8 precommit snapshot type'
  end select
  deallocate(snapshot)

  call backend%commit_trial_candidate(committed,candidate,diagnostics,did_commit,commit_status)
  call require(did_commit,'FMR macropore candidate committed')
  call require(committed%current_revision()==1_int64,'FMR macropore revision advanced')
  call require(.not.candidate%ready(),'committed candidate consumed')

  call committed%snapshot(snapshot,available)
  call require(available,'postcommit snapshot available')
  select type(s=>snapshot)
  type is(fmr_b110_physical_state_t)
    call require(allocated(s%macropore),'postcommit macro state present')
    call require(s%macropore%ready(),'postcommit macro state ready')
    macro_after=sum(s%macropore%water_domain_cp)
    if(constitutive_flag=='7') &
         call require(all(s%macropore%dynamic_volume_cp(3::3)==0.0_real64),'MIGMAC05 accepted rigid interfaces zero')
    if(constitutive_flag=='2' .or. constitutive_flag=='4') &
         call require(all(s%macropore%dynamic_volume_cp(2::2)==0.0_real64),'MIGMAC03 accepted rigid geometry zero')
    if(geometry_changes_expected)then
      call require(any(s%macropore%dynamic_volume_cp>1.0e-12_real64),'MIGMAC02 accepted crack geometry changed')
    else if(dynamic_flag=='4' .or. dynamic_flag=='5')then
      call require(sum(s%macropore%dynamic_volume_cp)<sum(probe_dynamic),'MIGMAC02 wetting shrinks crack capacity')
      call evaluate_macropore_geometry(parameters%macropore%geometry,s%macropore%dynamic_volume_cp,geometry)
      call evaluate_macropore_geometry_return(physical%macropore,geometry,displacement,ok)
      call require(ok,'MIGMAC02 final displacement oracle valid')
      call require(sum(displacement)>0.0_real64,'MIGMAC02 water displaced by shrinking macro capacity')
      write(*,'(*(g0))') 'PPA_WU05_MIGMAC02_WETTING|CAPACITY_LOSS=', &
           sum(probe_dynamic)-sum(s%macropore%dynamic_volume_cp),'|DISPLACEMENT=',sum(displacement)
    else
      call require(all(s%macropore%dynamic_volume_cp==0.0_real64),'MIGMAC02 no-change geometry preserved')
    end if
    call require(macro_after>=0.0_real64,'postcommit macro storage nonnegative')
    call require(abs(sum(s%macropore%water_domain_cp)-macro_after)<=1.0e-14_real64,'macro storage finite identity')
  class default
    error stop 'A9 postcommit snapshot type'
  end select

  write(*,'(*(g0))') 'PPA_WU05A9_FMR_MACRO_TRIAL|MASS=',result%mass%residual, &
       '|MACRO_BEFORE=',macro_before,'|MACRO_AFTER=',macro_after, &
       '|HEAD_CALC=',diagnostics%headcalc_calls,'|NONLINEAR=',diagnostics%nonlinear_iterations
  print '(a)', 'PPA_WU05A9_FMR_MACRO_TRIAL=PASS'
  if(geometry_changes_expected)print '(a)', 'PPA_WU05_MIGMAC02_DYNAMIC_REFERENCE_TRANSACTION=PASS'
  if(dynamic_flag=='2' .or. dynamic_flag=='3')print '(a)', 'PPA_WU05_MIGMAC02_NO_GEOMETRY_CHANGE=PASS'
  if(dynamic_flag=='4')print '(a)', 'PPA_WU05_MIGMAC02_WETTING_GEOMETRY_RETURN=PASS'
  if(dynamic_flag=='5')print '(a)', 'PPA_WU05_MIGMAC02_TWO_DOMAIN_GEOMETRY_RAPID_DRAIN=PASS'

contains

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k
    p%parameter_set_id=508001_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.02_real64; p%cofgen(2,k)=0.427494_real64; p%cofgen(3,k)=31.225016_real64
      p%cofgen(4,k)=0.021659_real64; p%cofgen(5,k)=0.98087_real64; p%cofgen(6,k)=1.734737_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64; p%cofgen(12,k)=0.99_real64*p%cofgen(3,k)
      p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=7
    p%swkimpl=0
    p%swkmean=1
    p%swsophy=0
    p%max_iterations=64
    p%max_backtracking=24
    p%min_step_duration=1.0e-12_real64
    p%compartment_balance_tolerance=1.0e-12_real64
    p%total_balance_tolerance=1.0e-12_real64
    p%head_abs_tolerance=1.0e-12_real64
    p%head_rel_tolerance=1.0e-12_real64
    p%ponding_tolerance=1.0e-12_real64
    p%root_extraction_active=.false.
    p%macropore_active=.false.
    p%snow_active=.false.
    p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.
    p%direct_retention_active=.false.
    p%elasticity_active=.false.
    p%frost_active=.false.
    p%soil_temperature_active=.false.
    p%black_evaporation_active=.false.
    p%boesten_evaporation_active=.false.
    p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_macropore_config(p,initialized)
    type(fmr_b110_physical_parameters_t),intent(inout)::p
    logical,intent(out)::initialized
    integer::k
    character(len=1)::reference_flag,partial_flag
    real(real64)::drain_level
    real(real64)::reference_kd
    real(real64)::ref_theta(numnod),ref_cond(numnod),ref_cap(numnod),ref_dk(numnod)

    allocate(static_volume(numnod),domain_fraction(nd,numnod),diameter(numnod),theta_s(numnod),theta_r(numnod), &
         wall_correction(numnod),sorp_max(numnod),sorp_alpha(numnod),conductivity(numnod),entry_head(numnod), &
         sorp_fac_parallel(numnod),ksat_horizontal(numnod),cdarcy(nd,numnod),potential_bottom(nd))
    static_volume=0.25_real64
    domain_fraction=1.0_real64
    if(nd==2)then
      domain_fraction(1,:)=0.3_real64
      domain_fraction(2,:)=0.7_real64
    end if
    diameter=4.0_real64
    theta_s=0.427494_real64
    theta_r=0.02_real64
    wall_correction=0.95_real64
    sorp_max=0.001_real64
    sorp_alpha=0.5_real64
    conductivity=0.0_real64
    entry_head=-1.0_real64
    sorp_fac_parallel=0.5_real64
    ksat_horizontal=0.0_real64
    cdarcy=0.0_real64
    potential_bottom=numnod

    shrinkage%enabled=dynamic_enabled
    shrinkage%surface_crack_area_depth_cm=-0.75_real64
    shrinkage%surface_crack_area_depth_supplied=.true.
    allocate(shrinkage%theta_s(numnod),shrinkage%theta_crack(numnod),shrinkage%geometry_factor(numnod),shrinkage%kim(numnod))
    shrinkage%theta_s=theta_s
    shrinkage%theta_crack=0.40_real64
    if(dynamic_flag=='2')shrinkage%theta_crack=0.0_real64
    shrinkage%geometry_factor=3.0_real64
    do k=1,numnod
      call prepare_clay_kim_option1(theta_s(k),0.20_real64,2.0_real64,1.20_real64,shrinkage%kim(k),ok)
      call require(ok,'MIGMAC02 clay option-1 configuration valid')
    end do
    if(constitutive_flag/='0')then
      allocate(shrinkage%law(numnod),shrinkage%peat(numnod))
      shrinkage%law=SHRINK_PEAT_DIRECT
      if(constitutive_flag=='3' .or. constitutive_flag=='4')shrinkage%law=SHRINK_PEAT_SEGMENTS
      if(constitutive_flag=='2' .or. constitutive_flag=='4')shrinkage%law(2::2)=SHRINK_RIGID
      shrinkage%peat%void_ratio_zero=0.2_real64
      shrinkage%peat%transition_moisture_ratio=0.5_real64
      shrinkage%peat%alpha=1.2_real64
      shrinkage%peat%beta=3.0_real64
      shrinkage%peat%p=0.1_real64
      shrinkage%peat%intermediate_moisture_ratio=0.2_real64
      shrinkage%peat%intermediate_void_ratio=0.4_real64
      if(constitutive_flag=='5' .or. constitutive_flag=='6' .or. constitutive_flag=='7')then
        if(constitutive_flag=='6')shrinkage%law=SHRINK_PEAT_SEGMENTS
        shrinkage%law(2::2)=SHRINK_KIM
        if(constitutive_flag=='7')shrinkage%law(3::3)=SHRINK_RIGID
      end if
    end if

    if(fit_flag=='1')then
      do k=1,numnod
        call prepare_clay_kim_option2(theta_s(k),0.2_real64,0.35_real64,shrinkage%kim(k),ok)
        call require(ok,'MIGMAC04 clay points prepare')
      end do
    else if(fit_flag=='2' .or. fit_flag=='3')then
      call require(allocated(shrinkage%peat),'MIGMAC04 peat carrier present')
      do k=1,numnod
        if(fit_flag=='2')then
          call prepare_peat_characteristic_points(theta_s(k),0.2_real64,0.5_real64,0.1_real64, &
               0.25_real64,0.1_real64,shrinkage%peat(k),ok)
        else
          call prepare_peat_characteristic_points(theta_s(k),0.2_real64,0.5_real64,0.1_real64, &
               0.25_real64,-0.3_real64,shrinkage%peat(k),ok)
        end if
        call require(ok,'MIGMAC04 peat points prepare')
      end do
    end if

    reference_kd=0.001_real64
    drain_level=-2.0_real64
    call get_environment_variable('WU05_MIGMAC07_PARTIAL',partial_flag)
    if(partial_flag=='1')drain_level=-1.9_real64
    call get_environment_variable('WU05_MIGMAC06_KD',reference_flag)
    if(reference_flag=='2')then
      call map_surface_crack_depth_to_node(shrinkage%surface_crack_area_depth_cm,z,dz,1,k,ok)
      call require(ok,'MIGMAC06 supplied reference crack-node mapping')
      shrinkage%surface_crack_area_node=k
      shrinkage%surface_crack_area_node_supplied=.true.
      call derive_dynamic_minimum_subsidence(shrinkage,dz,ok)
      call require(ok,'MIGMAC06 supplied reference geometry')
      call hyd%evaluate(drain_level-z,ref_theta,ref_cond,ref_cap,ref_dk)
      call prepare_rapid_drain_reference_kd(shrinkage,z,dz,ref_theta,static_volume,domain_fraction(1,:), &
           diameter,-sum(dz),drain_level,2,3.0_real64,reference_kd,ok)
      call require(ok,'MIGMAC06 supplied prepared reference valid')
    end if
    allocate(p%macropore)
    call initialize_fmr_macropore_standard_config(p%macropore,1,static_volume,domain_fraction,potential_bottom, &
         z,dz,diameter,theta_s,theta_r,wall_correction,sorp_max,sorp_alpha,conductivity,entry_head, &
         sorp_fac_parallel,ksat_horizontal,cdarcy,1.0_real64,1.0_real64,0,initialized,shrinkage=shrinkage, &
         rapid_enabled=dynamic_flag=='5',rapid_drain_type=2,rapid_drain_level_cm=drain_level, &
         rapid_area_exponent=3.0_real64,rapid_kd_reference=reference_kd,rapid_resistance_reference_day=20.0_real64)
    call get_environment_variable('WU05_MIGMAC06_KD',reference_flag)
    if(reference_flag=='1')then
      call hyd%evaluate(drain_level-z,ref_theta,ref_cond,ref_cap,ref_dk)
      call prepare_fmr_macropore_rapid_reference(p%macropore,z,ref_theta,-sum(dz),initialized)
      call require(initialized,'MIGMAC06 derived reference config valid')
    end if
    if(reference_flag=='1'.or.reference_flag=='2') &
         print '(a,es24.16)','PPA_WU05_MIGMAC06_REFERENCE_KD=',p%macropore%rate_template%rapid%kd_reference
  end subroutine initialize_macropore_config

  subroutine initialize_forcing(f)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    f%top_flux=0.0_real64
    f%top_head=0.0_real64
    f%bottom_flux=0.0_real64
    f%bottom_head=-100.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
    allocate(f%macropore_top_input)
    f%macropore_top_input=fmr_macropore_top_input_forcing_t()
    f%macropore_top_input%supplied=.true.
    f%macropore_top_input%net_rain_rate_cm_per_day=1.0_real64
    f%macropore_top_input%net_irrigation_rate_cm_per_day=0.25_real64
    f%macropore_top_input%melt_rate_cm_per_day=0.0_real64
    f%macropore_top_input%lateral_overland_rate_cm_per_day=0.10_real64
  end subroutine initialize_forcing

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(error_unit,'(a,1x,a)') 'PPA_WU05A9_FMR_FAIL',trim(label)
      flush(error_unit)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05a9_fmr_top_input_trial
