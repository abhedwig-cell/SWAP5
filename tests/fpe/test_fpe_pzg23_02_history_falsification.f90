program test_fpe_pzg23_02_history_falsification
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       FMR_SERIAL_DISPATCH_OK, fmr_run_serialized_physical_multiswap
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_b110_temporal_indicator_state_t, &
       fmr_new_b110_temporal_indicator_committed_state, prepare_fmr_b110_default_mvg
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_elastic_storage_application_host_binding, only: fmr_elastic_storage_application_host_diagnostics_t, &
       fmr_prepare_application_parameters_with_elastic_storage, FMR_ELAS_HOST_BINDING_OK
  implicit none

  integer, parameter :: N=numnod
  integer, parameter :: ARM_ORIGINAL=1, ARM_RECON_SAME_HISTORY=2, ARM_RECON_ZERO_HISTORY=3
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
  type(fmr_serialized_column_result_t), allocatable :: results(:)
  type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate
  type(fmr_serialized_batch_diagnostics_t) :: runtime
  type(fmr_elastic_storage_application_host_diagnostics_t) :: hdiag
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(canonical_numerical_config_t) :: numerical
  type(fmr_b110_physical_state_t) :: accepted_physical
  class(transaction_state_t), allocatable :: snapshot
  real(real64), allocatable :: accepted_history(:), zero_history(:)
  integer :: oi,arm,origin,ih,id,dispatch_status
  logical :: prepared,available,history_available,ok
  integer :: completed(2,3), committed(2,3), retries(2,3), nonlinear(2,3), backtracking(2,3)

  completed=0; committed=0; retries=0; nonlinear=0; backtracking=0

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

    do arm=1,3
      call init_origin(origin,H0(ih),DELTA(id),params(1),forcings(1),states(1),columns(1))
      call run_interval(0.0_real64,DT,'A',origin,arm)
      call req(results(1)%completed.and.results(1)%committed,'interval A complete')
      call req(results(1)%mass%complete.and.results(1)%mass%missing_contribution_mask==TX_MASS_MISSING_NONE, &
           'interval A mass')

      if(allocated(snapshot))deallocate(snapshot)
      if(allocated(accepted_history))deallocate(accepted_history)
      if(allocated(zero_history))deallocate(zero_history)

      call states(1)%snapshot(snapshot,available)
      call req(available.and.allocated(snapshot),'accepted snapshot')
      history_available=.false.
      select type(s=>snapshot)
      type is(fmr_b110_temporal_indicator_state_t)
        call copy_physical(s,accepted_physical)
        call s%temporal_history_snapshot(accepted_history,history_available)
      class default
        call req(.false.,'temporal snapshot type')
      end select
      call req(history_available.and.allocated(accepted_history),'accepted history available')
      call req(size(accepted_history)==N,'accepted history shape')
      call req(all(ieee_is_finite(accepted_history)),'accepted history finite')

      select case(arm)
      case(ARM_ORIGINAL)
        continue
      case(ARM_RECON_SAME_HISTORY)
        call fmr_new_b110_temporal_indicator_committed_state(states(1),int(620000+10*oi+arm,int64), &
             accepted_physical,DT,ok,accepted_history)
        call req(ok,'reconstruct same history')
        call verify_reconstruction(states(1),accepted_physical,accepted_history,.true.)
      case(ARM_RECON_ZERO_HISTORY)
        allocate(zero_history(N)); zero_history=0.0_real64
        call fmr_new_b110_temporal_indicator_committed_state(states(1),int(620000+10*oi+arm,int64), &
             accepted_physical,DT,ok,zero_history)
        call req(ok,'reconstruct zero history')
        call verify_reconstruction(states(1),accepted_physical,zero_history,.true.)
      case default
        call req(.false.,'unknown arm')
      end select

      call run_interval(DT,2.0_real64*DT,'B',origin,arm)
      completed(oi,arm)=merge(1,0,results(1)%completed)
      committed(oi,arm)=merge(1,0,results(1)%committed)
      retries(oi,arm)=diagnostics(1)%retries
      nonlinear(oi,arm)=results(1)%solver_nonlinear_iterations
      backtracking(oi,arm)=results(1)%solver_backtracking_attempts
    end do
  end do

  do oi=1,2
    origin=ORIGINS(oi)
    write(*,'(*(g0))')'PZG23_02_COMPARE|origin=',origin, &
         '|original_complete=',completed(oi,ARM_ORIGINAL), &
         '|same_history_complete=',completed(oi,ARM_RECON_SAME_HISTORY), &
         '|zero_history_complete=',completed(oi,ARM_RECON_ZERO_HISTORY), &
         '|original_retries=',retries(oi,ARM_ORIGINAL), &
         '|same_history_retries=',retries(oi,ARM_RECON_SAME_HISTORY), &
         '|zero_history_retries=',retries(oi,ARM_RECON_ZERO_HISTORY), &
         '|original_nonlinear=',nonlinear(oi,ARM_ORIGINAL), &
         '|same_history_nonlinear=',nonlinear(oi,ARM_RECON_SAME_HISTORY), &
         '|zero_history_nonlinear=',nonlinear(oi,ARM_RECON_ZERO_HISTORY), &
         '|original_backtracking=',backtracking(oi,ARM_ORIGINAL), &
         '|same_history_backtracking=',backtracking(oi,ARM_RECON_SAME_HISTORY), &
         '|zero_history_backtracking=',backtracking(oi,ARM_RECON_ZERO_HISTORY)
  end do

  call req(all(completed(:,ARM_ORIGINAL)==0),'original failures reproduced')
  call req(all(completed(:,ARM_RECON_SAME_HISTORY)==0),'same-history failures reproduced')

  if(all(completed(:,ARM_RECON_ZERO_HISTORY)==1))then
    write(*,'(A)')'PZG23_02_CLASS=ACCEPTED_HISTORY_CAUSAL'
  else if(all(completed(:,ARM_RECON_ZERO_HISTORY)==0))then
    write(*,'(A)')'PZG23_02_CLASS=PHYSICAL_STATE_OR_LOCAL_NONLINEAR_REGIME'
  else
    write(*,'(A)')'PZG23_02_CLASS=MIXED_HISTORY_SENSITIVITY'
  end if

  write(*,'(A)')'F_PE_PZG23_02=PASS'

contains

  subroutine run_interval(t0,t1,label,origin,arm)
    real(real64),intent(in)::t0,t1
    character(len=*),intent(in)::label
    integer,intent(in)::origin,arm

    if(allocated(results))deallocate(results)
    if(allocated(diagnostics))deallocate(diagnostics)

    call fmr_run_serialized_physical_multiswap(columns,templates,params,forcings,states,numerical,top,t0,t1,1, &
         results,diagnostics,aggregate,dispatch_status,runtime)

    call req(dispatch_status==FMR_SERIAL_DISPATCH_OK,'serialized dispatch')
    call req(size(results)==1.and.size(diagnostics)==1,'result size')

    write(*,'(*(g0))')'PZG23_02_CASE|interval=',trim(label),'|origin=',origin,'|arm=',arm, &
         '|kernel_status=',results(1)%kernel_status,'|admitted=',results(1)%admitted, &
         '|admission_status=',trim(results(1)%admission_status), &
         '|completed=',results(1)%completed,'|committed=',results(1)%committed, &
         '|attempts=',diagnostics(1)%attempts,'|retries=',diagnostics(1)%retries, &
         '|accepted=',diagnostics(1)%accepted,'|rejected=',diagnostics(1)%rejected, &
         '|failure=',trim(diagnostics(1)%failure_classification), &
         '|accepted_substeps=',results(1)%accepted_substeps, &
         '|nonlinear=',results(1)%solver_nonlinear_iterations, &
         '|internal_retries=',results(1)%solver_internal_retries, &
         '|headcalc=',results(1)%solver_headcalc_calls,'|jacobian=',results(1)%solver_jacobian_builds, &
         '|linear=',results(1)%solver_linear_solves,'|backtracking=',results(1)%solver_backtracking_attempts, &
         '|final_revision=',results(1)%final_revision,'|final_time=',results(1)%final_committed_time, &
         '|mass_complete=',results(1)%mass%complete,'|mass_residual=',results(1)%mass%residual
  end subroutine run_interval

  subroutine verify_reconstruction(committed_state,physical,history,expect_history)
    type(kernel_committed_state_t),intent(in)::committed_state
    type(fmr_b110_physical_state_t),intent(in)::physical
    real(real64),intent(in)::history(:)
    logical,intent(in)::expect_history
    class(transaction_state_t),allocatable::snap
    real(real64),allocatable::hist(:)
    logical::av,hav

    call committed_state%snapshot(snap,av)
    call req(av.and.allocated(snap),'reconstruction snapshot')
    select type(s=>snap)
    type is(fmr_b110_temporal_indicator_state_t)
      call req(s%active_nodes==physical%active_nodes,'reconstruction nodes')
      call req(all(s%pressure_head==physical%pressure_head),'reconstruction head')
      call req(all(s%water_content==physical%water_content),'reconstruction theta')
      call req(s%ponding_depth==physical%ponding_depth,'reconstruction ponding')
      call req(s%groundwater_level==physical%groundwater_level,'reconstruction gwl')
      call s%temporal_history_snapshot(hist,hav)
      call req(hav.eqv.expect_history,'reconstruction history availability')
      if(expect_history)then
        call req(size(hist)==size(history),'reconstruction history shape')
        call req(all(hist==history),'reconstruction history values')
      end if
    class default
      call req(.false.,'reconstruction type')
    end select
  end subroutine verify_reconstruction

  subroutine copy_physical(source,target)
    class(fmr_b110_physical_state_t),intent(in)::source
    type(fmr_b110_physical_state_t),intent(out)::target
    target%active_nodes=source%active_nodes
    if(allocated(target%pressure_head))deallocate(target%pressure_head)
    if(allocated(target%water_content))deallocate(target%water_content)
    allocate(target%pressure_head(size(source%pressure_head)),target%water_content(size(source%water_content)))
    target%pressure_head=source%pressure_head
    target%water_content=source%water_content
    target%ponding_depth=source%ponding_depth
    target%groundwater_level=source%groundwater_level
  end subroutine copy_physical

  subroutine init_base(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k,u,ios
    real(real64)::wcr,wcs,alpha,npar
    p%parameter_set_id=790001_int64; p%active_nodes=N
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
    t%template_id=790101_int64;t%physics_topology_id=790102_int64;t%vertical_layout_id=790103_int64
    t%state_layout_id=790104_int64;t%solver_interface_id=790105_int64
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
    s%active_nodes=N;allocate(s%pressure_head(N),s%water_content(N))
    s%pressure_head=hv;s%water_content=theta;s%ponding_depth=0.0_real64;s%groundwater_level=-2.0_real64
    history=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(c,int(700000+origin,int64),s,0.0_real64,oklocal,history)
    call req(oklocal,'committed init')
    f%top_flux=qeq+delta;f%top_head=h;f%bottom_flux=777777.0_real64;f%bottom_head=-999999.0_real64
    if(allocated(f%drainage_flux_by_level))deallocate(f%drainage_flux_by_level)
    if(allocated(f%subsurface_irrigation_source))deallocate(f%subsurface_irrigation_source)
    if(allocated(f%root_extraction_sink))deallocate(f%root_extraction_sink)
    allocate(f%drainage_flux_by_level(1,N),f%subsurface_irrigation_source(N),f%root_extraction_sink(N))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
    col%column_id=int(800000+origin,int64);col%template_id=790101_int64;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine init_origin

  subroutine req(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_PZG23_02_FAIL',trim(label)
      error stop 1
    end if
  end subroutine req
end program test_fpe_pzg23_02_history_falsification
