program test_fpe_elastic70_production_transaction_performance
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, &
       kernel_result_t, kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_OPTIONAL_STATE_LAYOUT_BASE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, &
       fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state, &
       prepare_fmr_b110_default_mvg
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_elastic_storage_application_host_binding, only: &
       fmr_elastic_storage_application_host_diagnostics_t, &
       fmr_prepare_application_parameters_with_elastic_storage, FMR_ELAS_HOST_BINDING_OK
  use mod_fmr_elastic_storage_row_interchange_file_adapter, only: &
       FMR_ELAS_ROWS_MAGIC, FMR_ELAS_ROWS_SOURCE_HASH, FMR_ELAS_ROWS_COLUMNS
  implicit none

  integer, parameter :: N=numnod, NCASE=4, NREP=100
  real(real64), parameter :: H0=-20.0_real64, DT=0.015625_real64
  real(real64), parameter :: TOL=1.0e-10_real64
  real(real64), parameter :: BUDGET_STRICT=0.01_real64, BUDGET_POLICY=0.20_real64
  real(real64), parameter :: DELTA(NCASE)=[-0.05_real64,-0.035_real64,0.035_real64,0.05_real64]
  integer(int64), parameter :: ID=700070_int64

  type(fmr_b110_physical_parameters_t) :: base,p
  type(fmr_elastic_storage_application_host_diagnostics_t) :: hdiag
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_b110_physical_state_t) :: state
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_result_t) :: result
  type(kernel_candidate_state_t) :: candidate
  type(kernel_diagnostics_t) :: diagnostics
  type(fmr_serialized_reference_backend_t) :: backend
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(b110_default_mvg_provider_t) :: provider
  type(canonical_numerical_config_t) :: config
  real(real64) :: heads(N),water(N),cond(N),cap(N),dk(N),previous(N)
  real(real64) :: qeq,t0,t1,strict_seconds,policy_seconds
  integer :: i,rep
  integer :: strict_completed,policy_completed,strict_retries,policy_retries
  integer :: strict_temporal,policy_temporal,strict_mass,policy_mass
  integer :: strict_solver,policy_solver
  integer :: strict_case_retry(NCASE),policy_case_retry(NCASE)
  integer :: strict_case_complete(NCASE),policy_case_complete(NCASE)
  real(real64) :: strict_case_dt(NCASE),policy_case_dt(NCASE)
  logical :: ok

  call write_config('elastic70-request.cfg')
  call write_rows('elastic70-valid.rows')
  call init_parameters(base)
  call fmr_prepare_application_parameters_with_elastic_storage('elastic70-request.cfg','elastic70-valid.rows', &
       base,p,hdiag)
  call req(hdiag%status==FMR_ELAS_HOST_BINDING_OK,'generated host preparation')
  call req(hdiag%generated_prior_requested.and.hdiag%generated_prior_applied,'generated prior applied')
  call req(p%elasticity_active,'generated elasticity active')
  call req(all(ieee_is_finite(p%cofgen(24,:))).and.all(p%cofgen(24,:)>0.0_real64),'generated Ss finite positive')
  write(*,'(*(g0))')'ELASTIC70_GENERATED|ss_min=',minval(p%cofgen(24,:)),'|ss_max=',maxval(p%cofgen(24,:))
  write(*,'(A)')'F_PE_ELASTIC70_A1_GENERATED=PASS'

  call prepare_fmr_b110_default_mvg(p,ok)
  call req(ok,'prepared generated parameters')
  call init_column(column,template)
  call backend%initialize(top)

  strict_completed=0;policy_completed=0
  strict_retries=0;policy_retries=0
  strict_temporal=0;policy_temporal=0
  strict_mass=0;policy_mass=0
  strict_solver=0;policy_solver=0
  strict_case_retry=0;policy_case_retry=0
  strict_case_complete=0;policy_case_complete=0
  strict_case_dt=0.0_real64;policy_case_dt=0.0_real64

  do i=1,NCASE
    call run_case(BUDGET_STRICT,DELTA(i),result,diagnostics)
    strict_case_complete(i)=merge(1,0,result%completed)
    strict_case_retry(i)=diagnostics%retries
    strict_case_dt(i)=diagnostics%min_accepted_substep_duration
    strict_completed=strict_completed+strict_case_complete(i)
    strict_retries=strict_retries+diagnostics%retries
    strict_temporal=strict_temporal+diagnostics%temporal_rejections
    strict_mass=strict_mass+diagnostics%mass_rejections
    strict_solver=strict_solver+diagnostics%solver_rejections

    call run_case(BUDGET_POLICY,DELTA(i),result,diagnostics)
    policy_case_complete(i)=merge(1,0,result%completed)
    policy_case_retry(i)=diagnostics%retries
    policy_case_dt(i)=diagnostics%min_accepted_substep_duration
    policy_completed=policy_completed+policy_case_complete(i)
    policy_retries=policy_retries+diagnostics%retries
    policy_temporal=policy_temporal+diagnostics%temporal_rejections
    policy_mass=policy_mass+diagnostics%mass_rejections
    policy_solver=policy_solver+diagnostics%solver_rejections

    write(*,'(*(g0))')'ELASTIC70_CASE|delta=',DELTA(i), &
         '|strict_complete=',strict_case_complete(i),'|strict_retries=',strict_case_retry(i), &
         '|strict_dt=',strict_case_dt(i),'|policy_complete=',policy_case_complete(i), &
         '|policy_retries=',policy_case_retry(i),'|policy_dt=',policy_case_dt(i)

    call req(policy_case_complete(i)>=strict_case_complete(i),'policy completion dominance')
    if(strict_case_complete(i)==1.and.policy_case_complete(i)==1)then
      call req(policy_case_retry(i)<=strict_case_retry(i),'policy retry dominance')
    end if
  end do

  call req(policy_completed>=strict_completed,'aggregate completion dominance')
  call req(policy_retries<=strict_retries,'aggregate retry dominance')
  call req(policy_completed>strict_completed.or.policy_retries<strict_retries,'material deterministic work benefit')
  write(*,'(A)')'F_PE_ELASTIC70_A2_TRANSACTION_WORK=PASS'

  call cpu_time(t0)
  do rep=1,NREP
    do i=1,NCASE
      call run_case(BUDGET_STRICT,DELTA(i),result,diagnostics)
    end do
  end do
  call cpu_time(t1)
  strict_seconds=t1-t0

  call cpu_time(t0)
  do rep=1,NREP
    do i=1,NCASE
      call run_case(BUDGET_POLICY,DELTA(i),result,diagnostics)
    end do
  end do
  call cpu_time(t1)
  policy_seconds=t1-t0

  write(*,'(*(g0))')'ELASTIC70_TOTAL|strict_completed=',strict_completed,'|policy_completed=',policy_completed, &
       '|strict_retries=',strict_retries,'|policy_retries=',policy_retries, &
       '|strict_temporal=',strict_temporal,'|policy_temporal=',policy_temporal, &
       '|strict_mass=',strict_mass,'|policy_mass=',policy_mass, &
       '|strict_solver=',strict_solver,'|policy_solver=',policy_solver
  write(*,'(*(g0))')'ELASTIC70_RUNTIME|repetitions=',NREP,'|strict_seconds=',strict_seconds, &
       '|policy_seconds=',policy_seconds,'|ratio=',policy_seconds/max(strict_seconds,tiny(1.0_real64))
  write(*,'(A)')'F_PE_ELASTIC70=PASS'

  call execute_command_line('rm -f elastic70-request.cfg elastic70-valid.rows')

contains

  subroutine run_case(budget,delta,result_out,diag_out)
    real(real64),intent(in)::budget,delta
    type(kernel_result_t),intent(out)::result_out
    type(kernel_diagnostics_t),intent(out)::diag_out

    heads=H0
    call bind_b110_default_mvg_provider(provider,p%prepared_default_mvg,DT)
    call provider%evaluate(heads,water,cond,cap,dk)
    call req(all(ieee_is_finite(water)).and.all(ieee_is_finite(cond)),'initial constitutive')
    qeq=-cond(1)

    state%active_nodes=N
    if(allocated(state%pressure_head))deallocate(state%pressure_head)
    if(allocated(state%water_content))deallocate(state%water_content)
    allocate(state%pressure_head(N),state%water_content(N))
    state%pressure_head=heads
    state%water_content=water
    state%ponding_depth=0.0_real64
    state%groundwater_level=-2.0_real64
    previous=0.0_real64

    committed=kernel_committed_state_t()
    checkpoint=kernel_checkpoint_t()
    call fmr_new_b110_temporal_indicator_committed_state(committed,ID,state,0.0_real64,ok,previous)
    call req(ok,'temporal committed state')
    call fmr_capture_checkpoint(committed,checkpoint,ok)
    call req(ok,'checkpoint')

    call init_forcing(forcing,qeq+delta)
    call init_config(config,budget,8)
    call backend%run_trial(column,template,p,committed,forcing,config,0.0_real64,DT,checkpoint, &
         result_out,candidate,diag_out,trusted_prepared_parameters=.true.)
  end subroutine run_case

  subroutine init_parameters(q)
    type(fmr_b110_physical_parameters_t),intent(out)::q
    integer::k
    q%parameter_set_id=ID
    q%active_nodes=N
    allocate(q%z(N),q%dz(N),q%node_distance(N),q%cofgen(24,N))
    q%z=z
    q%dz=dz
    q%node_distance=disnod(1:N)
    do k=1,N
      q%cofgen(:,k)=0.0_real64
      q%cofgen(1,k)=0.032_real64;q%cofgen(2,k)=0.423_real64;q%cofgen(3,k)=4.75_real64
      q%cofgen(4,k)=0.0135_real64;q%cofgen(5,k)=0.365_real64;q%cofgen(6,k)=1.455_real64
      q%cofgen(7,k)=1.0_real64-1.0_real64/q%cofgen(6,k);q%cofgen(8,k)=q%cofgen(4,k)
      q%cofgen(9,k)=0.0_real64;q%cofgen(10,k)=q%cofgen(3,k);q%cofgen(11,k)=0.999_real64
      q%cofgen(12,k)=0.99_real64*q%cofgen(3,k);q%cofgen(22,k)=-1.0e6_real64;q%cofgen(23,k)=1.0e-12_real64
    end do
    q%bottom_mode=7;q%swkimpl=0;q%swkmean=1;q%swsophy=0
    q%max_iterations=32;q%max_backtracking=12;q%min_step_duration=1.0e-10_real64
    q%compartment_balance_tolerance=TOL;q%total_balance_tolerance=TOL
    q%head_abs_tolerance=TOL;q%head_rel_tolerance=TOL;q%ponding_tolerance=TOL
    q%root_extraction_active=.false.;q%macropore_active=.false.;q%snow_active=.false.
    q%hysteresis_active=.false.;q%tabulated_hydraulics_active=.false.;q%direct_retention_active=.false.
    q%elasticity_active=.false.;q%frost_active=.false.;q%soil_temperature_active=.false.
    q%drainage_response_active=.false.;q%drainage_qbot_smooth_freatic_projection=.false.
  end subroutine init_parameters

  subroutine init_forcing(f,qtop)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::qtop
    f%top_flux=qtop;f%top_head=H0
    f%bottom_flux=777777.0_real64;f%bottom_head=-999999.0_real64
    if(allocated(f%drainage_flux_by_level))deallocate(f%drainage_flux_by_level)
    if(allocated(f%subsurface_irrigation_source))deallocate(f%subsurface_irrigation_source)
    if(allocated(f%root_extraction_sink))deallocate(f%root_extraction_sink)
    allocate(f%drainage_flux_by_level(1,N),f%subsurface_irrigation_source(N),f%root_extraction_sink(N))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine init_forcing

  subroutine init_column(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=700071_int64;t%physics_topology_id=700072_int64;t%vertical_layout_id=700073_int64
    t%state_layout_id=700074_int64;t%solver_interface_id=700075_int64
    t%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=ID;c%template_id=t%template_id;c%parameter_ref=1_int64;c%state_handle=1_int64
    c%forcing_handle=1_int64;c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine init_column

  subroutine init_config(c,budget,max_retries)
    type(canonical_numerical_config_t),intent(out)::c
    real(real64),intent(in)::budget
    integer,intent(in)::max_retries
    c%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    c%transaction%temporal_tolerance=0.0_real64
    c%transaction%mass_tolerance=TOL
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=max_retries
    c%max_committed_substeps=32
    c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.true.
    c%model_temporal_indicator_budget=budget
  end subroutine init_config

  subroutine write_config(path)
    character(len=*),intent(in)::path
    integer::unit
    open(newunit=unit,file=path,status='replace',action='write',form='formatted')
    write(unit,'(A)')'ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR'
    close(unit)
  end subroutine write_config

  subroutine write_rows(path)
    character(len=*),intent(in)::path
    integer::unit
    open(newunit=unit,file=path,status='replace',action='write',form='formatted')
    write(unit,'(A)')FMR_ELAS_ROWS_MAGIC
    write(unit,'(A)')'source_artifact_sha256='//FMR_ELAS_ROWS_SOURCE_HASH
    write(unit,'(A)')'normalsoilprofile_id=101'
    write(unit,'(A)')'row_count=2'
    write(unit,'(A)')'columns='//FMR_ELAS_ROWS_COLUMNS
    write(unit,'(A)')'101|1|0|0.8|101|1.45|1|2|0'
    write(unit,'(A)')'101|2|0.8|1.6|201|1.3|1|3|0'
    close(unit)
  end subroutine write_rows

  subroutine req(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC70_FAIL',trim(label)
      error stop 1
    end if
  end subroutine req
end program test_fpe_elastic70_production_transaction_performance
