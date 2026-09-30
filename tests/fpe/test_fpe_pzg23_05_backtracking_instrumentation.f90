program test_fpe_pzg23_05_backtracking_instrumentation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       FMR_SERIAL_DISPATCH_OK, fmr_run_serialized_physical_multiswap
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_new_b110_temporal_indicator_committed_state, prepare_fmr_b110_default_mvg, &
       fmr_serialized_reference_backend_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_elastic_storage_application_host_binding, only: fmr_elastic_storage_application_host_diagnostics_t, &
       fmr_prepare_application_parameters_with_elastic_storage, FMR_ELAS_HOST_BINDING_OK
  implicit none

  integer, parameter :: N=numnod
  integer, parameter :: ORIGINS(2)=[10,11]
  real(real64), parameter :: DT=0.015625_real64, TOL=1.0e-10_real64, BUDGET=0.20_real64
  real(real64), parameter :: H0(4)=[-75.0_real64,-20.0_real64,2.0_real64,10.0_real64]
  real(real64), parameter :: DELTA(4)=[-0.05_real64,-0.035_real64,0.035_real64,0.05_real64]

  type(fmr_b110_physical_parameters_t), allocatable :: params(:)
  type(fmr_b110_physical_parameters_t) :: base
  type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
  type(kernel_committed_state_t), allocatable :: states(:)
  type(fmr_logical_column_t), allocatable :: columns(:)
  type(fmr_template_t), allocatable :: templates(:)
  type(fmr_serialized_column_result_t), allocatable :: a_results(:)
  type(fmr_column_diagnostics_t), allocatable :: a_diagnostics(:)
  type(fmr_aggregate_diagnostics_t) :: a_aggregate
  type(fmr_serialized_batch_diagnostics_t) :: a_runtime
  type(fmr_elastic_storage_application_host_diagnostics_t) :: hdiag
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(canonical_numerical_config_t) :: numerical
  type(fmr_serialized_reference_backend_t) :: backend
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_result_t) :: b_result
  type(kernel_candidate_state_t) :: b_candidate
  type(kernel_diagnostics_t) :: b_diag

  integer :: oi,origin,ih,id,dispatch_status
  logical :: prepared,ok

  call init_base(base)
  allocate(params(1))
  call fmr_prepare_application_parameters_with_elastic_storage('request.cfg','profile.rows',base,params(1),hdiag)
  call req(hdiag%status==FMR_ELAS_HOST_BINDING_OK.and.hdiag%generated_prior_applied,'generated prep')
  call req(params(1)%elasticity_active,'elasticity active')
  call prepare_fmr_b110_default_mvg(params(1),prepared)
  call req(prepared.and.params(1)%prepared_default_mvg_available,'prepared generated hydraulics')

  allocate(forcings(1),states(1),columns(1),templates(1))
  call init_template(templates(1))
  call init_numerical(numerical)

  do oi=1,2
    origin=ORIGINS(oi)
    ih=origin/4+1
    id=mod(origin,4)+1

    call init_origin(origin,H0(ih),DELTA(id),params(1),forcings(1),states(1),columns(1))

    if(allocated(a_results))deallocate(a_results)
    if(allocated(a_diagnostics))deallocate(a_diagnostics)
    call fmr_run_serialized_physical_multiswap(columns,templates,params,forcings,states,numerical,top,0.0_real64,DT,1, &
         a_results,a_diagnostics,a_aggregate,dispatch_status,a_runtime)

    call req(dispatch_status==FMR_SERIAL_DISPATCH_OK,'interval A dispatch')
    call req(size(a_results)==1.and.size(a_diagnostics)==1,'interval A result size')
    call req(a_results(1)%completed.and.a_results(1)%committed,'interval A complete')
    call req(a_results(1)%mass%complete.and.a_results(1)%mass%missing_contribution_mask==TX_MASS_MISSING_NONE, &
         'interval A mass')

    call states(1)%capture_checkpoint(checkpoint,ok)
    call req(ok.and.checkpoint%ready(),'interval A checkpoint')

    call backend%initialize(top)
    call backend%run_trial(columns(1),templates(1),params(1),states(1),forcings(1),numerical,DT,2.0_real64*DT, &
         checkpoint,b_result,b_candidate,b_diag,trusted_prepared_parameters=.true.)

    write(*,'(*(g0))')'PZG23_05|origin=',origin,'|h0=',H0(ih),'|delta=',DELTA(id), &
         '|completed=',b_result%completed,'|status=',b_result%status, &
         '|attempts=',b_diag%attempts,'|retries=',b_diag%retries, &
         '|solver_rejections=',b_diag%solver_rejections, &
         '|temporal_rejections=',b_diag%temporal_rejections, &
         '|temporal_unavailable=',b_diag%temporal_certificate_unavailable_rejections, &
         '|mass_rejections=',b_diag%mass_rejections, &
         '|admission_rejections=',b_diag%admission_rejections, &
         '|checkpoint_rejections=',b_diag%checkpoint_rejections, &
         '|accepted_substeps=',b_diag%accepted_substeps, &
         '|nonlinear=',b_diag%nonlinear_iterations, &
         '|internal_retries=',b_diag%internal_retries, &
         '|headcalc=',b_diag%headcalc_calls,'|jacobian=',b_diag%jacobian_builds, &
         '|linear=',b_diag%linear_solves,'|backtracking=',b_diag%backtracking_attempts, &
         '|min_accepted_dt=',b_diag%min_accepted_substep_duration, &
         '|max_accepted_dt=',b_diag%max_accepted_substep_duration, &
         '|max_temporal_indicator=',b_diag%max_temporal_indicator, &
         '|max_abs_mass_residual=',b_diag%max_abs_step_mass_residual, &
         '|mass_complete=',b_result%mass%complete,'|mass_residual=',b_result%mass%residual

    call req(.not.b_result%completed,'B failure reproduced')
    call req(b_diag%admission_rejections==0.and.b_diag%checkpoint_rejections==0,'valid B origin')
  end do

  write(*,'(A)')'F_PE_PZG23_05=PASS'

contains

  subroutine init_base(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k,u,ios
    real(real64)::wcr,wcs,alpha,npar
    p%parameter_set_id=800001_int64; p%active_nodes=N
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
    t%template_id=800101_int64;t%physics_topology_id=800102_int64;t%vertical_layout_id=800103_int64
    t%state_layout_id=800104_int64;t%solver_interface_id=800105_int64
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

  subroutine init_origin(origin,h,delta,p,f,c,col)
    integer,intent(in)::origin
    real(real64),intent(in)::h,delta
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_forcing_t),intent(out)::f
    type(kernel_committed_state_t),intent(out)::c
    type(fmr_logical_column_t),intent(out)::col
    type(fmr_b110_physical_state_t)::s
    type(b110_default_mvg_provider_t)::provider
    real(real64)::hv(N),theta(N),k(N),cap(N),dk(N),history(N),qeq
    logical::oklocal
    hv=h
    call bind_b110_default_mvg_provider(provider,p%prepared_default_mvg,DT)
    call provider%evaluate(hv,theta,k,cap,dk)
    call req(all(ieee_is_finite(theta)).and.all(ieee_is_finite(k)),'constitutive')
    qeq=-k(1)
    s%active_nodes=N
    allocate(s%pressure_head(N),s%water_content(N))
    s%pressure_head=hv;s%water_content=theta;s%ponding_depth=0.0_real64;s%groundwater_level=-2.0_real64
    history=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(c,int(900000+origin,int64),s,0.0_real64,oklocal,history)
    call req(oklocal,'committed init')
    f%top_flux=qeq+delta;f%top_head=h;f%bottom_flux=777777.0_real64;f%bottom_head=-999999.0_real64
    if(allocated(f%drainage_flux_by_level))deallocate(f%drainage_flux_by_level)
    if(allocated(f%subsurface_irrigation_source))deallocate(f%subsurface_irrigation_source)
    if(allocated(f%root_extraction_sink))deallocate(f%root_extraction_sink)
    allocate(f%drainage_flux_by_level(1,N),f%subsurface_irrigation_source(N),f%root_extraction_sink(N))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
    col%column_id=int(910000+origin,int64);col%template_id=800101_int64;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine init_origin

  subroutine req(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_PZG23_05_FAIL',trim(label)
      error stop 1
    end if
  end subroutine req
end program test_fpe_pzg23_05_backtracking_instrumentation
