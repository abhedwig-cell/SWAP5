program test_fpe_elastic71_population_profile
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
  implicit none

  integer, parameter :: N=numnod
  real(real64), parameter :: DT=0.015625_real64, TOL=1.0e-10_real64
  real(real64), parameter :: HEADS(4)=[-75.0_real64,-20.0_real64,2.0_real64,10.0_real64]
  real(real64), parameter :: DELTAS(4)=[-0.05_real64,-0.035_real64,0.035_real64,0.05_real64]
  integer(int64), parameter :: ID=710071_int64

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
  real(real64) :: heads_node(N),water(N),cond(N),cap(N),dk(N),previous(N)
  real(real64) :: qeq,budget,h0,delta
  integer :: count,offset,j,origin,ih,idelta,unit,ios
  integer :: completed,retries,temporal,massrej,solverrej
  integer :: dtbins(10)
  logical :: ok

  open(newunit=unit,file='population_control.txt',status='old',action='read',iostat=ios)
  call req(ios==0,'control open')
  read(unit,*,iostat=ios)budget,count,offset
  close(unit)
  call req(ios==0.and.budget>0.0_real64.and.count>=0.and.offset>=0,'control read')

  call init_parameters(base)
  call fmr_prepare_application_parameters_with_elastic_storage('request.cfg','profile.rows',base,p,hdiag)
  call req(hdiag%status==FMR_ELAS_HOST_BINDING_OK.and.hdiag%generated_prior_applied,'generated prep')
  call req(p%elasticity_active.and.all(ieee_is_finite(p%cofgen(24,:))).and.all(p%cofgen(24,:)>0.0_real64),'Ss')
  call prepare_fmr_b110_default_mvg(p,ok); call req(ok,'prepared params')
  call init_column(column,template)
  call backend%initialize(top)

  completed=0; retries=0; temporal=0; massrej=0; solverrej=0; dtbins=0
  do j=0,count-1
    origin=mod(offset+j,16)
    ih=origin/4+1; idelta=mod(origin,4)+1
    h0=HEADS(ih); delta=DELTAS(idelta)
    call run_case(budget,h0,delta,result,diagnostics)
    if(result%completed) completed=completed+1
    retries=retries+diagnostics%retries
    temporal=temporal+diagnostics%temporal_rejections
    massrej=massrej+diagnostics%mass_rejections
    solverrej=solverrej+diagnostics%solver_rejections
    if(result%completed)then
      call bin_dt(diagnostics%min_accepted_substep_duration,dtbins)
    end if
  end do

  write(*,'(*(g0))')'ELASTIC71_PROFILE|count=',count,'|offset=',offset,'|budget=',budget, &
       '|completed=',completed,'|retries=',retries,'|temporal=',temporal, &
       '|mass=',massrej,'|solver=',solverrej, &
       '|dt1=',dtbins(1),'|dt2=',dtbins(2),'|dt3=',dtbins(3),'|dt4=',dtbins(4),'|dt5=',dtbins(5), &
       '|dt6=',dtbins(6),'|dt7=',dtbins(7),'|dt8=',dtbins(8),'|dt9=',dtbins(9),'|dt10=',dtbins(10)
  write(*,'(A)')'F_PE_ELASTIC71_PROFILE=PASS'

contains

  subroutine run_case(b,h,d,result_out,diag_out)
    real(real64),intent(in)::b,h,d
    type(kernel_result_t),intent(out)::result_out
    type(kernel_diagnostics_t),intent(out)::diag_out
    heads_node=h
    call bind_b110_default_mvg_provider(provider,p%prepared_default_mvg,DT)
    call provider%evaluate(heads_node,water,cond,cap,dk)
    call req(all(ieee_is_finite(water)).and.all(ieee_is_finite(cond)),'initial constitutive')
    qeq=-cond(1)
    state%active_nodes=N
    if(allocated(state%pressure_head))deallocate(state%pressure_head)
    if(allocated(state%water_content))deallocate(state%water_content)
    allocate(state%pressure_head(N),state%water_content(N))
    state%pressure_head=heads_node; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
    previous=0.0_real64
    committed=kernel_committed_state_t(); checkpoint=kernel_checkpoint_t()
    call fmr_new_b110_temporal_indicator_committed_state(committed,ID,state,0.0_real64,ok,previous)
    call req(ok,'committed')
    call fmr_capture_checkpoint(committed,checkpoint,ok); call req(ok,'checkpoint')
    call init_forcing(forcing,qeq+d,h)
    call init_config(config,b,8)
    call backend%run_trial(column,template,p,committed,forcing,config,0.0_real64,DT,checkpoint, &
         result_out,candidate,diag_out,trusted_prepared_parameters=.true.)
  end subroutine run_case

  subroutine init_parameters(q)
    type(fmr_b110_physical_parameters_t),intent(out)::q
    integer::k,ru,ri
    real(real64)::rwcr,rwcs,ralpha,rnpar
    q%parameter_set_id=ID; q%active_nodes=N
    allocate(q%z(N),q%dz(N),q%node_distance(N),q%cofgen(24,N))
    q%z=z; q%dz=dz; q%node_distance=disnod(1:N)
    open(newunit=ru,file='retention.txt',status='old',action='read',iostat=ri); call req(ri==0,'retention open')
    do k=1,N
      read(ru,*,iostat=ri)rwcr,rwcs,ralpha,rnpar; call req(ri==0,'retention read')
      q%cofgen(:,k)=0.0_real64
      q%cofgen(1,k)=rwcr;q%cofgen(2,k)=rwcs;q%cofgen(3,k)=4.75_real64
      q%cofgen(4,k)=ralpha;q%cofgen(5,k)=0.365_real64;q%cofgen(6,k)=rnpar
      q%cofgen(7,k)=1.0_real64-1.0_real64/q%cofgen(6,k);q%cofgen(8,k)=q%cofgen(4,k)
      q%cofgen(9,k)=0.0_real64;q%cofgen(10,k)=q%cofgen(3,k);q%cofgen(11,k)=0.999_real64
      q%cofgen(12,k)=0.99_real64*q%cofgen(3,k);q%cofgen(22,k)=-1.0e6_real64;q%cofgen(23,k)=1.0e-12_real64
    end do
    close(ru)
    q%bottom_mode=7;q%swkimpl=0;q%swkmean=1;q%swsophy=0
    q%max_iterations=32;q%max_backtracking=12;q%min_step_duration=1.0e-10_real64
    q%compartment_balance_tolerance=TOL;q%total_balance_tolerance=TOL
    q%head_abs_tolerance=TOL;q%head_rel_tolerance=TOL;q%ponding_tolerance=TOL
    q%root_extraction_active=.false.;q%macropore_active=.false.;q%snow_active=.false.
    q%hysteresis_active=.false.;q%tabulated_hydraulics_active=.false.;q%direct_retention_active=.false.
    q%elasticity_active=.false.;q%frost_active=.false.;q%soil_temperature_active=.false.
    q%drainage_response_active=.false.;q%drainage_qbot_smooth_freatic_projection=.false.
  end subroutine init_parameters

  subroutine init_forcing(f,qtop,h)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::qtop,h
    f%top_flux=qtop;f%top_head=h;f%bottom_flux=777777.0_real64;f%bottom_head=-999999.0_real64
    if(allocated(f%drainage_flux_by_level))deallocate(f%drainage_flux_by_level)
    if(allocated(f%subsurface_irrigation_source))deallocate(f%subsurface_irrigation_source)
    if(allocated(f%root_extraction_sink))deallocate(f%root_extraction_sink)
    allocate(f%drainage_flux_by_level(1,N),f%subsurface_irrigation_source(N),f%root_extraction_sink(N))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine init_forcing

  subroutine init_column(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=710001_int64;t%physics_topology_id=710002_int64;t%vertical_layout_id=710003_int64
    t%state_layout_id=710004_int64;t%solver_interface_id=710005_int64
    t%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=ID;c%template_id=t%template_id;c%parameter_ref=1_int64;c%state_handle=1_int64
    c%forcing_handle=1_int64;c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine init_column

  subroutine init_config(c,b,max_retries)
    type(canonical_numerical_config_t),intent(out)::c
    real(real64),intent(in)::b
    integer,intent(in)::max_retries
    c%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE;c%transaction%temporal_tolerance=0.0_real64
    c%transaction%mass_tolerance=TOL;c%transaction%retry_scale=0.5_real64;c%transaction%max_retries=max_retries
    c%max_committed_substeps=32;c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.true.;c%model_temporal_indicator_budget=b
  end subroutine init_config

  subroutine bin_dt(v,bins)
    real(real64),intent(in)::v
    integer,intent(inout)::bins(10)
    integer::k
    real(real64)::d
    d=DT
    do k=1,9
      if(abs(v-d)<=64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(d)))then
        bins(k)=bins(k)+1;return
      end if
      d=0.5_real64*d
    end do
    bins(10)=bins(10)+1
  end subroutine bin_dt

  subroutine req(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC71_FAIL',trim(label)
      error stop 1
    end if
  end subroutine req
end program test_fpe_elastic71_population_profile
