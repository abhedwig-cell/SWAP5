program test_a28_q4b_exact_threshold
  use,intrinsic::iso_fortran_env,only:int64,real64,error_unit
  use MOD_grid,only:numnod,z,dz,disnod
  use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts,only:canonical_numerical_config_t,CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions,only:kernel_committed_state_t,kernel_checkpoint_t,kernel_result_t, &
       kernel_candidate_state_t,kernel_diagnostics_t,kernel_reconstruct_committed_state_trusted,KERNEL_TRUSTED_RECONSTRUCTION_OK
  use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t,FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE,FMR_OPTIONAL_STATE_LAYOUT_BASE,FMR_OPTIONAL_STATE_LAYOUT_MACROPORE, &
       FMR_OPTIONAL_STATE_LAYOUT_RFM
  use mod_fmr_checkpoint_orchestrator,only:fmr_capture_checkpoint
  use mod_fmr_serialized_reference_backend,only:fmr_b110_physical_parameters_t,fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t,fmr_b110_rfm_state_t,fmr_serialized_reference_backend_t, &
       fmr_new_b110_committed_state,fmr_new_b110_rfm_committed_state
  use mod_fmr_macropore_configuration,only:initialize_fmr_macropore_standard_config
  use mod_macropore_single_column_runtime,only:macropore_runtime_policy_t
  use mod_ppa_wu05a5_multi_domain_process,only:macropore_geometry_result_t,evaluate_macropore_geometry
  use mod_rfm_runtime_configuration,only:rfm_runtime_configuration_t,RFM_SORPTIVITY_POLICY_A28_V1
  use mod_rfm_physical_state,only:rfm_physical_state_t
  use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
  use mod_process_hydraulic_view,only:process_hydraulic_view_t
  use mod_rfm_surface_sorptivity,only:evaluate_rfm_node_sorptivity
  use mod_fixed_flux_top_boundary_provider,only:fixed_flux_top_boundary_provider_t
  use mod_fmr_legacy_cauchy_bottom_boundary_provider,only:fmr_cauchy3_control_t,FMR_CAUCHY3_OK
  use mod_fmr_legacy_cauchy_bottom_boundary_provider,only:fmr_cauchy3_control_t,FMR_CAUCHY3_OK
  use mod_fmr_legacy_cauchy_bottom_boundary_provider,only:fmr_cauchy3_control_t,FMR_CAUCHY3_OK
  implicit none

  integer,parameter::ARM_A=1,ARM_B=2,ARM_C=3
  real(real64),parameter::DT=0.01_real64,TEND=24.0_real64
  type metrics_t
    logical::completed=.false.
    integer::status=-999,fail_step=0
    real(real64)::wall_seconds=0.0_real64,total_in=0.0_real64,total_out=0.0_real64
    real(real64)::bottom_out=0.0_real64,fast_external_out=0.0_real64,max_mass_resid=0.0_real64
    real(real64)::matrix_storage=0.0_real64,fast_storage=0.0_real64,ponding=0.0_real64,total_storage=0.0_real64
    real(real64)::h1=0.0_real64,h5=0.0_real64,h10=0.0_real64,t1=0.0_real64,t5=0.0_real64,t10=0.0_real64
    real(real64)::min_substep=huge(0.0_real64)
    integer::transaction_calls=0,attempts=0,retries=0,nonlinear=0,backtracks=0,headcalc=0
    integer::admission_rejections=0,solver_rejections=0,temporal_rejections=0,mass_rejections=0,trial_rollbacks=0
  end type
  type(metrics_t)::m
  integer::soil,geom,regime,arm
  logical::approximate_mode
  character(len=32)::mode_arg
  mode_arg='';call get_command_argument(1,mode_arg)
  approximate_mode=trim(mode_arg)=='approx'

  approximate_mode=.false.
  write(*,'(a)') 'Q4B,soil,geom,history,arm,completed,status,fail_step,wall_seconds,total_in_cm,total_out_cm,bottom_out_cm,fast_external_out_cm,max_mass_resid_cm,matrix_storage_cm,fast_storage_cm,ponding_cm,total_storage_cm,h1_cm,h5_cm,h10_cm,theta1,theta5,theta10,transaction_calls,attempts,retries,nonlinear,backtracks,headcalc,min_substep_day,admission_rejections,solver_rejections,temporal_rejections,mass_rejections,trial_rollbacks'
  do soil=1,2
    do geom=1,2
      regime=3
      arm=ARM_C
      call run_arm(soil,geom,regime,arm,m)
      call print_metrics('Q4BEXACT',soil,geom,regime,arm,0,m)
    end do
  end do
  print '(a)','A28_Q4B_STAGE_A_EXECUTION_COMPLETE'

contains

  subroutine run_arm(soil,geom,regime,arm,m)
    integer,intent(in)::soil,geom,regime,arm
    type(metrics_t),intent(out)::m
    type(fmr_serialized_reference_backend_t)::backend,replay_backend
    type(fixed_flux_top_boundary_provider_t),target::top
    type(fmr_b110_physical_parameters_t),target::parameters
    type(fmr_b110_physical_forcing_t)::forcing
    type(fmr_cauchy3_control_t)::cauchy
    type(fmr_cauchy3_control_t)::cauchy
    type(fmr_b110_physical_state_t)::physical
    type(rfm_physical_state_t)::rfm
    type(rfm_runtime_configuration_t)::rfmcfg
    type(fmr_logical_column_t)::column
    type(fmr_template_t)::template
    type(canonical_numerical_config_t)::config
    type(kernel_committed_state_t)::committed,reconstructed
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_result_t)::result
    type(kernel_candidate_state_t)::candidate,discard_candidate
    type(kernel_diagnostics_t)::diagnostics,discard_diagnostics
    type(macropore_runtime_policy_t)::policy
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::hyd
    type(macropore_geometry_result_t)::mg
    class(transaction_state_t),allocatable::snapshot,replay_snapshot,original_snapshot
    real(real64)::heads(numnod),theta(numnod),cond(numnod),cap(numnod),dkdh(numnod)
    real(real64)::wt,rain,t0,t1,macro_area,deep_fraction,endpoint_depth,sorpmax,ks
    integer::step,nsteps,commit_status,reconstruct_status,cauchy_status
    integer(int64)::saved_lineage,saved_revision
    real(real64)::saved_time
    logical::ok,did_commit,available,time_available,reconstructed_ok
    integer(int64)::c0,c1,crate

    m=metrics_t()
    call init_parameters(parameters,soil,ks)
    parameters%bottom_mode=3
    call cauchy%initialize_sine(0._real64,0._real64,[0._real64,366._real64],-55._real64,45._real64, &
         0._real64,1.2_real64,5._real64,.true.,cauchy_status)
    if(cauchy_status/=FMR_CAUCHY3_OK)then;m%status=-933;return;end if
    wt=water_table(regime)
    heads=wt-z
    call initialize_b110_default_mvg_parameters(hp,parameters%cofgen)
    call bind_b110_default_mvg_provider(hyd,hp,DT)
    call hyd%evaluate(heads,theta,cond,cap,dkdh)
    call geometry_values(geom,macro_area,deep_fraction,endpoint_depth)
    call derive_standard_sorpmax(parameters,hp,hyd,sorpmax,ok)
    if(.not.ok)then
      m%status=-901;return
    end if

    physical%active_nodes=numnod
    allocate(physical%pressure_head(numnod),physical%water_content(numnod))
    physical%pressure_head=heads
    physical%water_content=theta
    physical%ponding_depth=0.0_real64
    physical%groundwater_level=wt

    if(arm==ARM_B)then
      call init_standard_macro(parameters,physical,geom,ks,sorpmax,mg,ok)
      if(.not.ok)then;m%status=-902;return;end if
    end if

    call backend%initialize(top)
    call cauchy%initialize_sine(0._real64,0._real64,[0._real64,366._real64],-50._real64,45._real64,0._real64,1.2_real64,5._real64,.true.,cauchy_status)
    if(cauchy_status/=FMR_CAUCHY3_OK)then;m%status=-933;return;end if
    if(arm==ARM_B)then
      policy%enabled=.true.
      policy%inner_richards_exchange_enabled=.false.
      policy%source_reduction_retry_enabled=.false.
      policy%max_correctors=40
      policy%exchange_relative_tolerance=1e-8_real64
      policy%exchange_floor=1e-12_real64
      policy%damping_previous_weight=.5_real64
      policy%solver_mass_tolerance_cm=1e-8_real64
      policy%internal_exchange_tolerance_cm=1e-8_real64
      call backend%configure_macropore_policy(policy,ok)
      if(.not.ok)then;m%status=-903;return;end if
    else if(arm==ARM_C)then
      call init_rfm_config(rfmcfg,geom,macro_area,deep_fraction,endpoint_depth)
      if(.not.rfmcfg%valid())then;m%status=-904;return;end if
      call backend%configure_rfm_runtime(rfmcfg,ok)
      if(.not.ok)then;m%status=-905;return;end if
      call rfm%initialize(1,ok)
      if(.not.ok)then;m%status=-906;return;end if
    end if

    template%template_id=527000_int64+int(100*soil+10*geom+arm,int64)
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    template%physics_topology_id=527100_int64+int(geom,int64)
    template%vertical_layout_id=527200_int64
    template%state_layout_id=527300_int64+int(arm,int64)
    template%solver_interface_id=527400_int64
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    select case(arm)
    case(ARM_A);template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    case(ARM_B);template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_MACROPORE
    case(ARM_C);template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RFM
    end select

    column%column_id=527000_int64+int(1000*soil+100*geom+10*regime+arm,int64)
    column%template_id=template%template_id
    column%parameter_ref=1_int64;column%state_handle=1_int64;column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance=1.0_real64
    config%transaction%mass_tolerance=1e-7_real64
    config%transaction%retry_scale=.5_real64
    config%transaction%max_retries=4
    config%max_committed_substeps=32
    config%progress_tolerance=0.0_real64

    if(arm==ARM_C)then
      call fmr_new_b110_rfm_committed_state(committed,column%column_id,physical,rfm,0.0_real64,ok)
    else
      call fmr_new_b110_committed_state(committed,column%column_id,physical,0.0_real64,ok)
    end if
    if(.not.ok)then;m%status=-907;return;end if

    nsteps=nint(TEND/DT)
    call system_clock(c0,crate)
    do step=1,nsteps
      t0=real(step-1,real64)*DT;t1=real(step,real64)*DT
      rain=0._real64
      call init_forcing(forcing,arm,rain,macro_area)
      allocate(forcing%legacy_swbotb3_implicit_control)
      forcing%legacy_swbotb3_implicit_control=cauchy
      allocate(forcing%legacy_swbotb3_implicit_control);forcing%legacy_swbotb3_implicit_control=cauchy
      if(arm==ARM_C.and.step==nsteps/2)then
        call committed%snapshot(original_snapshot,available);if(.not.available)then;m%status=-912;m%fail_step=step;exit;end if
        saved_lineage=committed%current_lineage_id();saved_revision=committed%current_revision()
        call committed%current_time(saved_time,time_available);if(.not.time_available)then;m%status=-913;m%fail_step=step;exit;end if
        call kernel_reconstruct_committed_state_trusted(reconstructed,saved_lineage,saved_revision,original_snapshot,saved_time,.true.,reconstructed_ok,reconstruct_status)
        if(.not.reconstructed_ok.or.reconstruct_status/=KERNEL_TRUSTED_RECONSTRUCTION_OK)then;m%status=-914;m%fail_step=step;exit;end if
        call replay_backend%initialize(top)
        call replay_backend%configure_rfm_runtime(rfmcfg,ok)
        if(.not.ok)then;m%status=-928;m%fail_step=step;exit;end if
      end if
      call fmr_capture_checkpoint(committed,checkpoint,ok)
      if(.not.ok)then;m%status=-908;m%fail_step=step;exit;end if
      if(arm==ARM_C.and.step==nsteps/2)then
        call backend%run_trial(column,template,parameters,committed,forcing,config,t0,t1,checkpoint,result,discard_candidate,discard_diagnostics)
        if(.not.result%completed)then;m%status=-923;m%fail_step=step;exit;end if
        call backend%discard_trial_candidate(discard_candidate,discard_diagnostics)
        call committed%snapshot(replay_snapshot,available);if(.not.available)then;m%status=-924;m%fail_step=step;exit;end if
        select type(a=>original_snapshot)
        type is(fmr_b110_rfm_state_t)
          select type(b=>replay_snapshot)
          type is(fmr_b110_rfm_state_t)
            if(.not.a%rfm%same_values(b%rfm).or.any(a%pressure_head/=b%pressure_head).or.any(a%water_content/=b%water_content))then
              m%status=-925;m%fail_step=step;exit
            end if
          class default;m%status=-926;m%fail_step=step;exit
          end select
        class default;m%status=-927;m%fail_step=step;exit
        end select
      end if
      call backend%run_trial(column,template,parameters,committed,forcing,config,t0,t1,checkpoint, &
           result,candidate,diagnostics)
      m%status=result%status
      m%transaction_calls=m%transaction_calls+diagnostics%transaction_calls
      m%attempts=m%attempts+diagnostics%attempts
      m%retries=m%retries+diagnostics%retries
      m%nonlinear=m%nonlinear+diagnostics%nonlinear_iterations
      m%backtracks=m%backtracks+diagnostics%backtracking_attempts
      m%headcalc=m%headcalc+diagnostics%headcalc_calls
      m%admission_rejections=m%admission_rejections+diagnostics%admission_rejections
      m%solver_rejections=m%solver_rejections+diagnostics%solver_rejections
      m%temporal_rejections=m%temporal_rejections+diagnostics%temporal_rejections
      m%mass_rejections=m%mass_rejections+diagnostics%mass_rejections
      m%trial_rollbacks=m%trial_rollbacks+diagnostics%trial_rollbacks
      if(diagnostics%accepted_substeps>0) m%min_substep=min(m%min_substep,diagnostics%min_accepted_substep_duration)
      if(.not.result%completed.or.result%status/=CANONICAL_STATUS_COMPLETED.or..not.result%mass%complete)then
        m%fail_step=step;exit
      end if
      m%total_in=m%total_in+result%mass%total_in
      m%total_out=m%total_out+result%mass%total_out
      m%max_mass_resid=max(m%max_mass_resid,abs(result%mass%residual))
      if(result%bottom_interface_exchange_available) m%bottom_out=m%bottom_out+result%bottom_outward_exchange_native
      call backend%commit_trial_candidate(committed,candidate,diagnostics,did_commit,commit_status)
      if(.not.did_commit)then;m%status=-909;m%fail_step=step;exit;end if
      if(arm==ARM_C)then
        call committed%snapshot(snapshot,available);if(.not.available)then;m%status=-931;m%fail_step=step;exit;end if
        select type(ts=>snapshot)
        type is(fmr_b110_rfm_state_t)
          write(*,'(*(g0,:,","))') 'HEADTRACE',soil,geom,step,t0,ts%pressure_head(1), &
               ts%pressure_head(rfmcfg%endpoint_node_index(1)),ts%pressure_head(rfmcfg%mb_wall_node_index)
        class default;m%status=-932;m%fail_step=step;exit
        end select
      end if
      if(arm==ARM_C.and.mod(step,120)==0)then
        call committed%snapshot(snapshot,available);if(.not.available)then;m%status=-929;m%fail_step=step;exit;end if
        select type(cs=>snapshot)
        type is(fmr_b110_rfm_state_t)
          write(*,'(*(g0,:,","))') 'CYCLE',soil,geom,regime,merge(1,0,approximate_mode),step, &
               sum(cs%water_content*dz)+cs%rfm%storage_cm()+cs%ponding_depth,cs%water_content(1), &
               cs%water_content(max(1,min(size(cs%water_content),5))),cs%water_content(size(cs%water_content)), &
               sum(cs%rfm%endpoint_water_cm),maxval(cs%rfm%wall_age_day),maxval(cs%rfm%wall_sorptivity_cm_sqrt_day)
        class default;m%status=-930;m%fail_step=step;exit
        end select
      end if
      if(arm==ARM_C.and.step==nsteps/2)then
        call fmr_capture_checkpoint(reconstructed,checkpoint,ok);if(.not.ok)then;m%status=-915;m%fail_step=step;exit;end if
        call replay_backend%run_trial(column,template,parameters,reconstructed,forcing,config,t0,t1,checkpoint,result,candidate,diagnostics)
        if(.not.result%completed)then;m%status=-916;m%fail_step=step;exit;end if
        call replay_backend%commit_trial_candidate(reconstructed,candidate,diagnostics,did_commit,commit_status)
        if(.not.did_commit)then;m%status=-917;m%fail_step=step;exit;end if
        call committed%snapshot(snapshot,available);if(.not.available)then;m%status=-918;m%fail_step=step;exit;end if
        call reconstructed%snapshot(replay_snapshot,available);if(.not.available)then;m%status=-919;m%fail_step=step;exit;end if
        select type(a=>snapshot)
        type is(fmr_b110_rfm_state_t)
          select type(b=>replay_snapshot)
          type is(fmr_b110_rfm_state_t)
            if(.not.a%rfm%same_values(b%rfm).or.any(a%pressure_head/=b%pressure_head).or.any(a%water_content/=b%water_content))then
              m%status=-920;m%fail_step=step;exit
            end if
          class default;m%status=-921;m%fail_step=step;exit
          end select
        class default;m%status=-922;m%fail_step=step;exit
        end select
      end if
    end do
    call system_clock(c1)
    if(crate>0_int64)m%wall_seconds=real(c1-c0,real64)/real(crate,real64)
    m%completed=(m%fail_step==0.and.m%status==CANONICAL_STATUS_COMPLETED)
    if(.not.m%completed)return

    call committed%snapshot(snapshot,available)
    if(.not.available)then;m%completed=.false.;m%status=-910;return;end if
    select type(s=>snapshot)
    type is(fmr_b110_rfm_state_t)
      m%matrix_storage=sum(s%water_content*dz)
      m%fast_storage=s%rfm%storage_cm()
      m%ponding=s%ponding_depth
      call state_samples(s%pressure_head,s%water_content,m)
    class is(fmr_b110_physical_state_t)
      m%matrix_storage=sum(s%water_content*dz)
      m%fast_storage=0.0_real64
      if(allocated(s%macropore))m%fast_storage=sum(s%macropore%water_domain_cp)
      m%ponding=s%ponding_depth
      call state_samples(s%pressure_head,s%water_content,m)
    class default
      m%completed=.false.;m%status=-911;return
    end select
    m%total_storage=m%matrix_storage+m%fast_storage+m%ponding
    m%fast_external_out=max(0.0_real64,m%total_out-max(0.0_real64,m%bottom_out))
  end subroutine run_arm

  subroutine init_parameters(p,soil,ks)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer,intent(in)::soil
    real(real64),intent(out)::ks
    integer::i
    real(real64)::tr,ts,alpha,npar,lambda
    if(soil==1)then
      tr=.02000000_real64;ts=.42749391_real64;alpha=.02165898_real64
      npar=1.73473668_real64;lambda=.98087016_real64;ks=31.22501566_real64
    else
      tr=.01000000_real64;ts=.33670050_real64;alpha=.03030449_real64
      npar=2.88750186_real64;lambda=.07360004_real64;ks=17.41850374_real64
    end if
    p%parameter_set_id=527001_int64+int(soil,int64);p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do i=1,numnod
      p%cofgen(1,i)=tr;p%cofgen(2,i)=ts;p%cofgen(3,i)=ks;p%cofgen(4,i)=alpha;p%cofgen(5,i)=lambda
      p%cofgen(6,i)=npar;p%cofgen(7,i)=1.0_real64-1.0_real64/npar;p%cofgen(8,i)=alpha
      p%cofgen(10,i)=ks;p%cofgen(11,i)=.999_real64;p%cofgen(12,i)=.99_real64*ks
      p%cofgen(22,i)=-1e6_real64;p%cofgen(23,i)=1e-12_real64
    end do
    p%bottom_mode=3;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=64;p%max_backtracking=24;p%min_step_duration=1e-12_real64
    p%compartment_balance_tolerance=1e-8_real64;p%total_balance_tolerance=1e-8_real64
    p%head_abs_tolerance=1e-8_real64;p%head_rel_tolerance=1e-8_real64;p%ponding_tolerance=1e-8_real64
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%direct_retention_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.
    p%black_evaporation_active=.false.;p%boesten_evaporation_active=.false.;p%drainage_response_active=.false.
  end subroutine init_parameters

  subroutine derive_standard_sorpmax(p,hp,hyd,smax,ok)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(b110_default_mvg_parameters_t),target,intent(in)::hp
    type(b110_default_mvg_provider_t),intent(inout)::hyd
    real(real64),intent(out)::smax
    logical,intent(out)::ok
    type(process_hydraulic_view_t)::v
    real(real64)::hh(numnod),tt(numnod),kk(numnod),cc(numnod),dd(numnod),sref,def
    hh=-100.0_real64
    call hyd%evaluate(hh,tt,kk,cc,dd)
    v%active_nodes=numnod;allocate(v%pressure_head(numnod),v%water_content(numnod))
    v%pressure_head=hh;v%water_content=tt;v%ponding_depth=0.0_real64;v%groundwater_level=-200.0_real64
    call evaluate_rfm_node_sorptivity(v,hyd,1,64,sref,ok)
    if(.not.ok)return
    def=(p%cofgen(2,1)-tt(1))/(p%cofgen(2,1)-p%cofgen(1,1))
    if(def<=0.0_real64)then;ok=.false.;return;end if
    smax=sref/(def**0.5_real64)
    ok=smax>=0.0_real64
  end subroutine derive_standard_sorpmax

  subroutine geometry_values(geom,macro_area,deep_fraction,endpoint_depth)
    integer,intent(in)::geom
    real(real64),intent(out)::macro_area,deep_fraction,endpoint_depth
    if(geom==1)then
      macro_area=.05_real64;deep_fraction=.25_real64;endpoint_depth=60._real64
    else
      macro_area=.10_real64;deep_fraction=.65_real64;endpoint_depth=40._real64
    end if
  end subroutine geometry_values

  subroutine init_standard_macro(p,s,geom,ks,sorpmax,mg,ok)
    type(fmr_b110_physical_parameters_t),intent(inout)::p
    type(fmr_b110_physical_state_t),intent(inout)::s
    integer,intent(in)::geom
    real(real64),intent(in)::ks,sorpmax
    type(macropore_geometry_result_t),intent(out)::mg
    logical,intent(out)::ok
    real(real64)::macro_area,deep_fraction,endpoint_depth,diam
    real(real64),allocatable::static_volume(:),domain_fraction(:,:),diameter(:),theta_s(:),theta_r(:)
    real(real64),allocatable::wall_correction(:),sorp_max(:),sorp_alpha(:),conductivity(:),entry_head(:)
    real(real64),allocatable::sorp_fac_parallel(:),ksat_horizontal(:),cdarcy(:,:)
    integer,allocatable::potential_bottom(:)
    integer::i,icend
    call geometry_values(geom,macro_area,deep_fraction,endpoint_depth)
    icend=nint(endpoint_depth/10._real64)
    diam=merge(4._real64,8._real64,geom==1)
    allocate(static_volume(numnod),domain_fraction(2,numnod),diameter(numnod),theta_s(numnod),theta_r(numnod), &
         wall_correction(numnod),sorp_max(numnod),sorp_alpha(numnod),conductivity(numnod),entry_head(numnod), &
         sorp_fac_parallel(numnod),ksat_horizontal(numnod),cdarcy(2,numnod),potential_bottom(2))
    static_volume=macro_area*dz
    domain_fraction(1,:)=1.0_real64-deep_fraction;domain_fraction(2,:)=deep_fraction
    diameter=diam;theta_s=p%cofgen(2,:);theta_r=p%cofgen(1,:);wall_correction=.95_real64
    sorp_max=sorpmax;sorp_alpha=.5_real64;conductivity=ks;entry_head=-1._real64
    sorp_fac_parallel=.5_real64;ksat_horizontal=ks
    cdarcy(1,:)=ks*macro_area*(1.0_real64-deep_fraction)/20._real64
    cdarcy(2,:)=ks*macro_area*deep_fraction/20._real64
    potential_bottom=[icend,numnod]
    allocate(p%macropore)
    call initialize_fmr_macropore_standard_config(p%macropore,1,static_volume,domain_fraction,potential_bottom, &
         z,dz,diameter,theta_s,theta_r,wall_correction,sorp_max,sorp_alpha,conductivity,entry_head, &
         sorp_fac_parallel,ksat_horizontal,cdarcy,1._real64,1._real64,0,ok)
    if(.not.ok)return
    p%macropore_active=.true.
    allocate(s%macropore)
    call s%macropore%initialize(2,numnod,ok);if(.not.ok)return
    s%macropore%dynamic_volume_cp=0._real64
    call evaluate_macropore_geometry(p%macropore%geometry,s%macropore%dynamic_volume_cp,mg)
    if(.not.mg%valid)then;ok=.false.;return;end if
    s%macropore%icp_bottom_domain=mg%bottom_domain
    s%macropore%volume_domain_cp=mg%volume_domain_cp
    s%macropore%water_domain_cp=0._real64
    ok=s%macropore%ready()
  end subroutine init_standard_macro

  subroutine init_rfm_config(c,geom,macro_area,deep_fraction,endpoint_depth)
    type(rfm_runtime_configuration_t),intent(out)::c
    integer,intent(in)::geom
    real(real64),intent(in)::macro_area,deep_fraction,endpoint_depth
    integer::node
    node=nint(endpoint_depth/10._real64)
    c%enabled=.true.;c%sigma_b=.65_real64;c%f_mb=deep_fraction;c%connectivity_p=1._real64
    c%z_ah_cm=20._real64;c%z_ic_cm=endpoint_depth;c%chi_wall=1._real64
    c%exchange_length_cm=20._real64;c%mb_contact_length_cm=80._real64;c%sorptivity_panels=64
     if(approximate_mode)c%sorptivity_policy=RFM_SORPTIVITY_POLICY_A28_V1
    c%mb_wall_node_index=numnod
    c%endpoint_depth_cm=[endpoint_depth];c%endpoint_contact_thickness_cm=[20._real64]
    c%endpoint_area_fraction=[macro_area*(1._real64-deep_fraction)];c%endpoint_node_index=[node]
    if(geom<1)c%enabled=.false.
  end subroutine init_rfm_config

  subroutine init_forcing(f,arm,rain,macro_area)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    integer::cauchy_status
    integer,intent(in)::arm
    real(real64),intent(in)::rain,macro_area
    f=fmr_b110_physical_forcing_t()
    if(arm==ARM_A)then
      f%top_flux=-rain
    else if(arm==ARM_B)then
      f%top_flux=-rain*(1._real64-macro_area)
      allocate(f%macropore_top_input)
      f%macropore_top_input%supplied=.true.
      f%macropore_top_input%net_rain_rate_cm_per_day=rain
    else
      f%top_flux=0._real64
      allocate(f%rfm_surface)
      f%rfm_surface%supplied=.true.;f%rfm_surface%event_active=rain>0._real64
      f%rfm_surface%precipitation_rate_cm_per_day=rain
      f%rfm_surface%ponding_max_cm=0._real64
      f%rfm_surface%runoff_resistance_day=0._real64
      f%rfm_surface%runoff_exponent=1._real64
    end if
    f%top_head=0._real64;f%bottom_flux=0._real64;f%bottom_head=0._real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0._real64;f%subsurface_irrigation_source=0._real64;f%root_extraction_sink=0._real64
  end subroutine init_forcing

  real(real64) function water_table(regime) result(wt)
    integer,intent(in)::regime
    select case(regime)
    case(1);wt=-300._real64
    case(2);wt=-150._real64
    case(3);wt=-20._real64
    case(4);wt=-150._real64
    case(5);wt=-150._real64
    case(6);wt=-150._real64
    case(7);wt=-200._real64
    case default;wt=-100._real64
    end select
  end function water_table


  real(real64) function q4b_rain_rate(soil,geom,t) result(r)
    integer,intent(in)::soil,geom
    real(real64),intent(in)::t
    real(real64)::phase
    phase=modulo(t,1.2_real64);r=0._real64
    r=0._real64
  end function q4b_rain_rate
  real(real64) function rain_rate(regime,t) result(r)
    integer,intent(in)::regime
    real(real64),intent(in)::t
    r=0._real64
    select case(regime)
    case(1,2);if(t<.04_real64)r=8._real64
    case(3);if(t<.04_real64)r=4._real64
    case(4);r=1._real64
    case(5);if(t<.03_real64.or.(t>=.10_real64.and.t<.13_real64))r=5._real64
    case(6);r=.10_real64
    case(7);if(t<.08_real64)r=3._real64
    case(8);if(t<.08_real64)r=6._real64
    end select
  end function rain_rate

  subroutine state_samples(h,t,m)
    real(real64),intent(in)::h(:),t(:)
    type(metrics_t),intent(inout)::m
    integer::mid
    mid=max(1,min(size(h),5))
    m%h1=h(1);m%h5=h(mid);m%h10=h(size(h))
    m%t1=t(1);m%t5=t(mid);m%t10=t(size(t))
  end subroutine state_samples

  subroutine print_metrics(prefix,soil,geom,regime,arm,rep,m)
    character(len=*),intent(in)::prefix
    integer,intent(in)::soil,geom,regime,arm,rep
    type(metrics_t),intent(in)::m
    write(*,'(*(g0,:,","))') trim(prefix),soil,geom,regime,arm,merge(1,0,m%completed),m%status,m%fail_step, &
         m%wall_seconds,m%total_in,m%total_out,m%bottom_out,m%fast_external_out,m%max_mass_resid, &
         m%matrix_storage,m%fast_storage,m%ponding,m%total_storage,m%h1,m%h5,m%h10,m%t1,m%t5,m%t10, &
         m%transaction_calls,m%attempts,m%retries,m%nonlinear,m%backtracks,m%headcalc,m%min_substep, &
         m%admission_rejections,m%solver_rejections,m%temporal_rejections,m%mass_rejections,m%trial_rollbacks
  end subroutine print_metrics

end program test_a28_q4b_exact_threshold
