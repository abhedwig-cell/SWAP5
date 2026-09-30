program test_fpe_pzg23_01_second_interval_attribution
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       FMR_SERIAL_DISPATCH_OK
  use mod_fmr_parallel_worker_pool, only: fmr_run_parallel_physical_multiswap, FMR_PARALLEL_POOL_OK
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_new_b110_temporal_indicator_committed_state, prepare_fmr_b110_default_mvg
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_elastic_storage_application_host_binding, only: fmr_elastic_storage_application_host_diagnostics_t, &
       fmr_prepare_application_parameters_with_elastic_storage, FMR_ELAS_HOST_BINDING_OK
  implicit none

  integer, parameter :: N=numnod, NCOL=16, PROFILE_ID=90210030
  real(real64), parameter :: DT=0.015625_real64, TOL=1.0e-10_real64, BUDGET=0.20_real64
  real(real64), parameter :: H0(4)=[-75.0_real64,-20.0_real64,2.0_real64,10.0_real64]
  real(real64), parameter :: DELTA(4)=[-0.05_real64,-0.035_real64,0.035_real64,0.05_real64]

  type(fmr_b110_physical_parameters_t), allocatable :: params(:)
  type(fmr_b110_physical_parameters_t) :: base
  type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
  type(kernel_committed_state_t), allocatable :: states(:)
  type(fmr_logical_column_t), allocatable :: columns(:)
  type(fmr_template_t), allocatable :: templates(:)
  type(fmr_serialized_column_result_t), allocatable :: results_a(:),results_b(:)
  type(fmr_column_diagnostics_t), allocatable :: diagnostics_a(:),diagnostics_b(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate_a,aggregate_b
  type(fmr_serialized_batch_diagnostics_t) :: runtime_a,runtime_b
  type(fmr_elastic_storage_application_host_diagnostics_t) :: hdiag
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(canonical_numerical_config_t) :: numerical
  integer :: dispatch_status,pool_status,i,origin,ih,id
  integer :: completed_a,completed_b,committed_a,committed_b,retries_a,retries_b,mass_fail_b,rejected_b
  integer(int64) :: lagged_work,clock0,clock1,clock_rate
  logical :: prepared

  call init_base(base)
  allocate(params(1))
  call fmr_prepare_application_parameters_with_elastic_storage('request.cfg','profile.rows',base,params(1),hdiag)
  call req(hdiag%status==FMR_ELAS_HOST_BINDING_OK.and.hdiag%generated_prior_applied,'generated prep')
  call req(params(1)%elasticity_active,'elasticity active')
  call prepare_fmr_b110_default_mvg(params(1),prepared)
  call req(prepared.and.params(1)%prepared_default_mvg_available,'prepared generated hydraulics')

  allocate(forcings(NCOL),states(NCOL),columns(NCOL),templates(1))
  call init_template(templates(1))
  call init_numerical(numerical)

  do i=1,NCOL
    origin=mod(i-1,16)
    ih=origin/4+1
    id=mod(origin,4)+1
    call init_column_state(i,H0(ih),DELTA(id),params(1),forcings(i),states(i),columns(i))
  end do

  call fmr_run_parallel_physical_multiswap(columns,templates,params,forcings,states,numerical,top,0.0_real64,DT, &
       32,1,results_a,diagnostics_a,aggregate_a,dispatch_status,pool_status,runtime_a)
  call req(dispatch_status==FMR_SERIAL_DISPATCH_OK.and.pool_status==FMR_PARALLEL_POOL_OK,'interval A dispatch')
  call req(size(results_a)==NCOL.and.size(diagnostics_a)==NCOL,'interval A size')

  completed_a=count(results_a%completed)
  committed_a=count(results_a%committed)
  retries_a=sum(diagnostics_a%retries)
  lagged_work=0_int64
  do i=1,NCOL
    call req(results_a(i)%completed.and.results_a(i)%committed,'interval A column')
    call req(results_a(i)%mass%complete.and.results_a(i)%mass%missing_contribution_mask==TX_MASS_MISSING_NONE,'interval A mass')
    lagged_work=lagged_work+int(results_a(i)%solver_headcalc_calls,int64)
    write(*,'(*(g0))')'PZG23_A|origin=',mod(i-1,16),'|h0=',H0(mod(i-1,16)/4+1), &
         '|delta=',DELTA(mod(mod(i-1,16),4)+1),'|status=',results_a(i)%kernel_status, &
         '|completed=',results_a(i)%completed,'|committed=',results_a(i)%committed, &
         '|attempts=',diagnostics_a(i)%attempts,'|retries=',diagnostics_a(i)%retries, &
         '|accepted_substeps=',results_a(i)%accepted_substeps, &
         '|nonlinear=',results_a(i)%solver_nonlinear_iterations,'|internal_retries=',results_a(i)%solver_internal_retries, &
         '|headcalc=',results_a(i)%solver_headcalc_calls,'|jacobian=',results_a(i)%solver_jacobian_builds, &
         '|linear=',results_a(i)%solver_linear_solves,'|backtracking=',results_a(i)%solver_backtracking_attempts, &
         '|final_revision=',results_a(i)%final_revision,'|final_time=',results_a(i)%final_committed_time, &
         '|mass_complete=',results_a(i)%mass%complete,'|mass_residual=',results_a(i)%mass%residual
  end do
  call req(completed_a==NCOL.and.committed_a==NCOL,'interval A aggregate')
  call req(runtime_a%authoritative_aggregate_mass%complete,'interval A aggregate mass')

  call system_clock(clock0,count_rate=clock_rate)
  call fmr_run_parallel_physical_multiswap(columns,templates,params,forcings,states,numerical,top,DT,2.0_real64*DT, &
       32,1,results_b,diagnostics_b,aggregate_b,dispatch_status,pool_status,runtime_b)
  call system_clock(clock1)

  call req(dispatch_status==FMR_SERIAL_DISPATCH_OK.and.pool_status==FMR_PARALLEL_POOL_OK,'interval B dispatch')
  call req(size(results_b)==NCOL.and.size(diagnostics_b)==NCOL,'interval B size')

  completed_b=count(results_b%completed)
  committed_b=count(results_b%committed)
  retries_b=sum(diagnostics_b%retries)
  mass_fail_b=0
  rejected_b=0
  do i=1,NCOL
    if(.not.results_b(i)%mass%complete .or. results_b(i)%mass%missing_contribution_mask/=TX_MASS_MISSING_NONE) mass_fail_b=mass_fail_b+1
    if(diagnostics_b(i)%rejected/=0) rejected_b=rejected_b+1
    call req(results_b(i)%column_id==int(100000+i,int64),'interval B order')
    write(*,'(*(g0))')'PZG23_B|origin=',mod(i-1,16),'|h0=',H0(mod(i-1,16)/4+1), &
         '|delta=',DELTA(mod(mod(i-1,16),4)+1),'|status=',results_b(i)%kernel_status, &
         '|completed=',results_b(i)%completed,'|committed=',results_b(i)%committed, &
         '|attempts=',diagnostics_b(i)%attempts,'|retries=',diagnostics_b(i)%retries, &
         '|accepted_substeps=',results_b(i)%accepted_substeps, &
         '|nonlinear=',results_b(i)%solver_nonlinear_iterations,'|internal_retries=',results_b(i)%solver_internal_retries, &
         '|headcalc=',results_b(i)%solver_headcalc_calls,'|jacobian=',results_b(i)%solver_jacobian_builds, &
         '|linear=',results_b(i)%solver_linear_solves,'|backtracking=',results_b(i)%solver_backtracking_attempts, &
         '|final_revision=',results_b(i)%final_revision,'|final_time=',results_b(i)%final_committed_time, &
         '|mass_complete=',results_b(i)%mass%complete,'|mass_residual=',results_b(i)%mass%residual
    if(.not.results_b(i)%completed .or. .not.results_b(i)%committed)then
      write(*,'(*(g0))')'PZG23_B_FAIL|profile=',PROFILE_ID,'|column=',i,'|origin=',mod(i-1,16), &
           '|status=',results_b(i)%kernel_status,'|completed=',results_b(i)%completed,'|committed=',results_b(i)%committed, &
           '|retries=',diagnostics_b(i)%retries,'|diagnostic_rejected=',diagnostics_b(i)%rejected, &
           '|attempts=',diagnostics_b(i)%attempts,'|final_time=',results_b(i)%final_committed_time
    else
      call req(results_b(i)%final_revision==results_b(i)%initial_revision+1_int64,'interval B revision')
      call req(results_b(i)%final_committed_time_bound,'interval B time bound')
      call req(abs(results_b(i)%final_committed_time-2.0_real64*DT)<=64.0_real64*epsilon(1.0_real64),'interval B time')
    end if
  end do


  write(*,'(*(g0))')'PZG23_SUMMARY|profile=',PROFILE_ID,'|n=',NCOL,'|1=',1, &
       '|lagged_work=',lagged_work,'|a_completed=',completed_a,'|a_committed=',committed_a,'|a_retries=',retries_a, &
       '|b_completed=',completed_b,'|b_committed=',committed_b,'|b_retries=',retries_b, &
       '|b_mass_fail=',mass_fail_b,'|b_rejected=',rejected_b, &
       '|b_mass_complete=',runtime_b%authoritative_aggregate_mass%complete, &
       '|max_simultaneous=',runtime_b%max_simultaneous_real_physical_solves, &
       '|seconds=',real(clock1-clock0,real64)/real(clock_rate,real64)
  write(*,'(A)')'F_PE_PZG23_01=PASS'

contains

  subroutine init_base(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k,u,ios
    real(real64)::wcr,wcs,alpha,npar
    p%parameter_set_id=770001_int64; p%active_nodes=N
    allocate(p%z(N),p%dz(N),p%node_distance(N),p%cofgen(24,N))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:N)
    open(newunit=u,file='retention.txt',status='old',action='read',iostat=ios); call req(ios==0,'retention open')
    do k=1,N
      read(u,*,iostat=ios)wcr,wcs,alpha,npar; call req(ios==0,'retention read')
      p%cofgen(:,k)=0.0_real64
      p%cofgen(1,k)=wcr;p%cofgen(2,k)=wcs;p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=alpha;p%cofgen(5,k)=0.365_real64;p%cofgen(6,k)=npar
      p%cofgen(7,k)=1.0_real64-1.0_real64/npar;p%cofgen(8,k)=alpha
      p%cofgen(9,k)=0.0_real64;p%cofgen(10,k)=p%cofgen(3,k);p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k);p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
    end do
    close(u)
    p%bottom_mode=7;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=32;p%max_backtracking=12;p%min_step_duration=1.0e-10_real64
    p%compartment_balance_tolerance=TOL;p%total_balance_tolerance=TOL
    p%head_abs_tolerance=TOL;p%head_rel_tolerance=TOL;p%ponding_tolerance=TOL
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%direct_retention_active=.false.
    p%ksatexm_extension_active=.false.;p%elasticity_active=.false.;p%frost_active=.false.
    p%soil_temperature_active=.false.;p%drainage_response_active=.false.
    p%drainage_qbot_smooth_freatic_projection=.false.
  end subroutine init_base

  subroutine init_template(t)
    type(fmr_template_t),intent(out)::t
    t%template_id=770101_int64;t%physics_topology_id=770102_int64;t%vertical_layout_id=770103_int64
    t%state_layout_id=770104_int64;t%solver_interface_id=770105_int64
    t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine init_template

  subroutine init_numerical(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    c%transaction%temporal_tolerance=0.0_real64;c%transaction%mass_tolerance=TOL
    c%transaction%retry_scale=0.5_real64;c%transaction%max_retries=8
    c%max_committed_substeps=32;c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.true.;c%model_temporal_indicator_budget=BUDGET
  end subroutine init_numerical

  subroutine init_column_state(idx,h,delta,p,f,c,col)
    integer,intent(in)::idx
    real(real64),intent(in)::h,delta
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_forcing_t),intent(out)::f
    type(kernel_committed_state_t),intent(out)::c
    type(fmr_logical_column_t),intent(out)::col
    type(fmr_b110_physical_state_t)::s
    type(b110_default_mvg_provider_t)::provider
    real(real64)::hv(N),theta(N),k(N),cap(N),dk(N),history(N),qeq
    logical::ok
    hv=h
    call bind_b110_default_mvg_provider(provider,p%prepared_default_mvg,DT)
    call provider%evaluate(hv,theta,k,cap,dk)
    call req(all(ieee_is_finite(theta)).and.all(ieee_is_finite(k)),'constitutive')
    qeq=-k(1)
    s%active_nodes=N;allocate(s%pressure_head(N),s%water_content(N))
    s%pressure_head=hv;s%water_content=theta;s%ponding_depth=0.0_real64;s%groundwater_level=-2.0_real64
    history=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(c,int(300000+idx,int64),s,0.0_real64,ok,history)
    call req(ok,'committed init')
    f%top_flux=qeq+delta;f%top_head=h;f%bottom_flux=777777.0_real64;f%bottom_head=-999999.0_real64
    allocate(f%drainage_flux_by_level(1,N),f%subsurface_irrigation_source(N),f%root_extraction_sink(N))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
    col%column_id=int(100000+idx,int64);col%template_id=770101_int64;col%parameter_ref=1_int64
    col%state_handle=int(idx,int64);col%forcing_handle=int(idx,int64);col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine init_column_state

  subroutine req(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_PZG23_01_FAIL',trim(label)
      error stop 1
    end if
  end subroutine req
end program test_fpe_pzg23_01_second_interval_attribution
