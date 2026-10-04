program test_ppa_wu05a8_fmr_macropore_trial
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
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_fmr_macropore_configuration, only: initialize_fmr_macropore_standard_config
  use mod_macropore_single_column_runtime, only: macropore_runtime_policy_t
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_result_t, evaluate_macropore_geometry
  use mod_macropore_standard_storage, only: macropore_standard_storage_view_t, canonicalize_macropore_standard_storage
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer(int64),parameter :: column_id=508001_int64
  real(real64),parameter :: dt=1.0e-3_real64

  type(fmr_serialized_reference_backend_t) :: backend
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
  type(macropore_geometry_result_t) :: geometry
  type(macropore_standard_storage_view_t) :: storage_view
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t) :: hyd
  class(transaction_state_t),allocatable :: snapshot
  real(real64),allocatable :: static_volume(:), domain_fraction(:,:), diameter(:)
  real(real64),allocatable :: theta_s(:),theta_r(:),wall_correction(:),sorp_max(:),sorp_alpha(:)
  real(real64),allocatable :: conductivity(:),entry_head(:),sorp_fac_parallel(:),ksat_horizontal(:),cdarcy(:,:)
  integer,allocatable :: potential_bottom(:)
  real(real64) :: heads(numnod),water(numnod),cond(numnod),cap(numnod),dkdh(numnod)
  real(real64) :: macro_before, macro_after
  logical :: ok, did_commit, available
  integer :: commit_status

  call initialize_parameters(parameters)
  call initialize_macropore_config(parameters,ok)
  call require(ok,'physical macropore config initialized')
  parameters%macropore_active=.true.

  call initialize_b110_default_mvg_parameters(hp,parameters%cofgen)
  call bind_b110_default_mvg_provider(hyd,hp,dt)
  heads=-100.0_real64
  call hyd%evaluate(heads,water,cond,cap,dkdh)

  physical%active_nodes=numnod
  allocate(physical%pressure_head(numnod),physical%water_content(numnod),physical%macropore)
  physical%pressure_head=heads
  physical%water_content=water
  physical%ponding_depth=0.0_real64
  physical%groundwater_level=-1000.0_real64
  call physical%macropore%initialize(1,numnod,ok)
  call require(ok,'macropore continuation initialized')
  physical%macropore%dynamic_volume_cp=0.0_real64
  call evaluate_macropore_geometry(parameters%macropore%geometry,physical%macropore%dynamic_volume_cp,geometry)
  call require(geometry%valid,'initial macropore geometry')
  physical%macropore%icp_bottom_domain=geometry%bottom_domain
  physical%macropore%volume_domain_cp=geometry%volume_domain_cp
  physical%macropore%water_domain_cp=0.0_real64
  physical%macropore%water_domain_cp(1,numnod)=0.20_real64
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
  write(error_unit,'(*(g0))') 'PPA_WU05A8_FMR_DIAG|STATUS=',result%status,'|COMPLETED=',result%completed, &
       '|ADMISSION_REJECTIONS=',diagnostics%admission_rejections,'|TRANSACTION_CALLS=',diagnostics%transaction_calls, &
       '|ATTEMPTS=',diagnostics%attempts,'|RETRIES=',diagnostics%retries,'|HEAD_CALC=',diagnostics%headcalc_calls, &
       '|NONLINEAR=',diagnostics%nonlinear_iterations,'|CANDIDATE_READY=',candidate%ready()
  flush(error_unit)
  call require(result%status==CANONICAL_STATUS_COMPLETED .and. result%completed,'FMR macropore trial completed')
  call require(result%mass%complete,'FMR macropore mass complete')
  call require(result%mass%missing_contribution_mask==TX_MASS_MISSING_NONE,'FMR macropore mass missing mask')
  call require(abs(result%mass%residual)<=1.0e-9_real64,'FMR macropore mass residual')
  call require(candidate%ready(),'FMR macropore candidate ready')

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
    call require(macro_after<macro_before,'postcommit macro storage responds to matrix exchange')
    call require(abs(sum(s%macropore%water_domain_cp)-macro_after)<=1.0e-14_real64,'macro storage finite identity')
  class default
    error stop 'A8 postcommit snapshot type'
  end select

  write(*,'(*(g0))') 'PPA_WU05A8_FMR_MACRO_TRIAL|MASS=',result%mass%residual, &
       '|MACRO_BEFORE=',macro_before,'|MACRO_AFTER=',macro_after, &
       '|HEAD_CALC=',diagnostics%headcalc_calls,'|NONLINEAR=',diagnostics%nonlinear_iterations
  print '(a)', 'PPA_WU05A8_FMR_MACRO_TRIAL=PASS'

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

    allocate(static_volume(numnod),domain_fraction(1,numnod),diameter(numnod),theta_s(numnod),theta_r(numnod), &
         wall_correction(numnod),sorp_max(numnod),sorp_alpha(numnod),conductivity(numnod),entry_head(numnod), &
         sorp_fac_parallel(numnod),ksat_horizontal(numnod),cdarcy(1,numnod),potential_bottom(1))
    static_volume=0.50_real64
    domain_fraction=1.0_real64
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

    allocate(p%macropore)
    call initialize_fmr_macropore_standard_config(p%macropore,1,static_volume,domain_fraction,potential_bottom, &
         z,dz,diameter,theta_s,theta_r,wall_correction,sorp_max,sorp_alpha,conductivity,entry_head, &
         sorp_fac_parallel,ksat_horizontal,cdarcy,1.0_real64,1.0_real64,0,initialized)
    allocate(p%macropore%matrix_area_fraction(numnod))
    p%macropore%matrix_area_fraction=1.0_real64
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
  end subroutine initialize_forcing

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(error_unit,'(a,1x,a)') 'PPA_WU05A8_FMR_FAIL',trim(label)
      flush(error_unit)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05a8_fmr_macropore_trial
