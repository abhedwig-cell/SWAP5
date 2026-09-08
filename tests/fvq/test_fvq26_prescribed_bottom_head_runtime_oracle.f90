program test_fvq26_prescribed_bottom_head_runtime_oracle
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use variables, only: legacy_qrot => qrot, legacy_swbotb => swbotb, legacy_hbot => hbot, legacy_qbot => qbot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, kernel_executor_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  implicit none

  real(real64), parameter :: h0 = -75.0_real64
  real(real64), parameter :: h_inflow = -55.0_real64
  real(real64), parameter :: t0 = 3600.125_real64
  real(real64), parameter :: t1 = 3600.375_real64
  real(real64), parameter :: dt = t1-t0
  real(real64), parameter :: mass_tol = 1.0e-12_real64
  real(real64), parameter :: theta_r = 0.032_real64
  real(real64), parameter :: theta_s = 0.423_real64
  real(real64), parameter :: ksat = 4.75_real64
  real(real64), parameter :: alpha = 0.0135_real64
  real(real64), parameter :: lpar = 0.365_real64
  real(real64), parameter :: npar = 1.455_real64
  real(real64), parameter :: mpar = 1.0_real64-1.0_real64/npar
  integer, parameter :: invalid_modes(4) = [1,3,8,9]

  type(fmr_b110_physical_parameters_t) :: p(1), pbad
  type(fmr_b110_physical_state_t) :: initial
  type(fmr_b110_physical_forcing_t) :: f1(1), f2(1), fhigh
  type(fmr_logical_column_t) :: col(1)
  type(fmr_template_t) :: templ(1)
  type(canonical_numerical_config_t) :: cfg
  type(fmr04_fixed_flux_top_provider_t), target :: top
  type(fmr_serialized_reference_backend_t) :: backend
  type(kernel_committed_state_t) :: trial_state, run_state1(1), run_state2(1)
  type(kernel_checkpoint_t) :: cp
  type(kernel_result_t) :: trial1, trial_high, trial_replay, rejected
  type(kernel_candidate_state_t) :: cand
  type(kernel_diagnostics_t) :: kd, discard_diag
  type(kernel_executor_t) :: discard_executor
  type(fmr_serialized_physical_observation_t) :: obs1, obs_high, obs_replay
  type(fmr_serialized_column_result_t), allocatable :: r1(:), r2(:)
  type(fmr_column_diagnostics_t), allocatable :: d1(:), d2(:)
  type(fmr_aggregate_diagnostics_t) :: a1, a2
  type(fmr_serialized_batch_diagnostics_t) :: b1, b2
  real(real64) :: theta0, k0, expected_mass
  integer :: dispatch1, dispatch2, i
  integer(int64) :: rev0
  logical :: ok

  theta0 = reference_theta(h0)
  k0 = reference_k(h0,theta0)
  expected_mass = k0*dt

  call build_parameters(p(1))
  call build_state(initial,theta0)
  call build_forcing(f1(1),-k0,1111.0_real64,h0)
  call build_forcing(f2(1),-k0,-2222.0_real64,h0)
  call build_forcing(fhigh,-k0,3333.0_real64,h_inflow)
  call build_topology(col(1),templ(1))
  call build_config(cfg)

  ! Independent direct-trial proof of qbot authority and rollback isolation.
  call fmr_new_b110_committed_state(trial_state,col(1)%column_id,initial,t0,ok)
  call check(ok,'trial state initialize')
  rev0 = trial_state%current_revision()
  call backend%initialize(top)
  call fmr_capture_checkpoint(trial_state,cp,ok)
  call check(ok,'checkpoint A')
  call poison_legacy()
  call backend%run_trial(col(1),templ(1),p(1),trial_state,f1(1),cfg,t0,t1,cp,trial1,cand,kd)
  obs1 = backend%observation()
  call check(trial1%completed .and. cand%ready(),'stationary direct trial')
  call check(obs1%solver_executed,'stationary solver execution')
  call check(trim(obs1%solver_diagnostics%route)=='legacy-reference-bound','stationary solver route')
  call check(same_bits(obs1%bottom_flux,-k0),'independent Darcy qbot expectation')
  call check(.not.same_bits(obs1%bottom_flux,f1(1)%bottom_flux),'input bottom flux seed is not authority')
  call check(trial1%mass%complete .and. trial1%mass%missing_contribution_mask==TX_MASS_MISSING_NONE,'trial mass complete')
  call check(same_bits(trial1%mass%total_in,expected_mass),'trial external top input')
  call check(same_bits(trial1%mass%total_out,expected_mass),'trial authoritative qbot exactly once')
  call check(abs(trial1%mass%residual)<=mass_tol,'trial hard mass')
  call check(trial_state%current_revision()==rev0,'trial revision immutable')
  call check(state_equals_initial(trial_state,initial),'trial physical state immutable')
  discard_diag = kd
  call fmr_discard_candidate(discard_executor,cand,discard_diag)
  call check(.not.cand%ready(),'discard candidate invalidated')
  call check(trial_state%current_revision()==rev0 .and. state_equals_initial(trial_state,initial),'discard no committed leakage')

  ! A distinct prescribed head must change qbot; fixed high-head fixture must support inflow.
  call fmr_capture_checkpoint(trial_state,cp,ok)
  call check(ok,'checkpoint high head')
  call poison_legacy()
  call backend%run_trial(col(1),templ(1),p(1),trial_state,fhigh,cfg,t0,t1,cp,trial_high,cand,kd)
  obs_high = backend%observation()
  call check(obs_high%solver_executed,'high-head solver execution')
  call check(obs_high%bottom_flux>0.0_real64,'supported positive qbot')
  call check(.not.same_bits(obs_high%bottom_flux,obs1%bottom_flux),'bottom head changes qbot')
  if (cand%ready()) then
    discard_diag=kd
    call fmr_discard_candidate(discard_executor,cand,discard_diag)
  end if
  call check(trial_state%current_revision()==rev0 .and. state_equals_initial(trial_state,initial),'high-head trial no commit')

  ! Replay the original request after the perturbation.
  call fmr_capture_checkpoint(trial_state,cp,ok)
  call check(ok,'checkpoint replay')
  call poison_legacy()
  call backend%run_trial(col(1),templ(1),p(1),trial_state,f1(1),cfg,t0,t1,cp,trial_replay,cand,kd)
  obs_replay=backend%observation()
  call check(trial_replay%completed .and. cand%ready(),'replay completed')
  call check(same_bits(obs_replay%bottom_flux,obs1%bottom_flux),'A/B/A qbot identity')
  call check(obs_replay%solver_diagnostics%nonlinear_iterations==obs1%solver_diagnostics%nonlinear_iterations,'A/B/A iteration identity')
  call check(same_bits(trial_replay%mass%total_in,trial1%mass%total_in) .and. &
       same_bits(trial_replay%mass%total_out,trial1%mass%total_out),'A/B/A mass identity')
  discard_diag=kd
  call fmr_discard_candidate(discard_executor,cand,discard_diag)

  ! Unsupported routes remain fail closed.
  do i=1,size(invalid_modes)
    pbad=p(1); pbad%bottom_mode=invalid_modes(i)
    call fmr_capture_checkpoint(trial_state,cp,ok)
    call check(ok,'unsupported checkpoint')
    call backend%run_trial(col(1),templ(1),pbad,trial_state,f1(1),cfg,t0,t1,cp,rejected,cand,kd)
    call check(.not.rejected%completed .and. kd%admission_rejections>0 .and. .not.cand%ready(),'unsupported mode fail closed')
  end do
  pbad=p(1); pbad%swkimpl=1
  call fmr_capture_checkpoint(trial_state,cp,ok)
  call backend%run_trial(col(1),templ(1),pbad,trial_state,f1(1),cfg,t0,t1,cp,rejected,cand,kd)
  call check(.not.rejected%completed .and. kd%admission_rejections>0,'swkimpl1 fail closed')
  pbad=p(1); pbad%macropore_active=.true.
  call fmr_capture_checkpoint(trial_state,cp,ok)
  call backend%run_trial(col(1),templ(1),pbad,trial_state,f1(1),cfg,t0,t1,cp,rejected,cand,kd)
  call check(.not.rejected%completed .and. kd%admission_rejections>0,'macropore fail closed')

  ! Independent composed runtime admission with two irrelevant bottom-flux seeds.
  call fmr_new_b110_committed_state(run_state1(1),col(1)%column_id,initial,t0,ok); call check(ok,'runtime state1 init')
  call fmr_new_b110_committed_state(run_state2(1),col(1)%column_id,initial,t0,ok); call check(ok,'runtime state2 init')
  call poison_legacy()
  call fmr_run_serialized_physical_multiswap(col,templ,p,f1,run_state1,cfg,top,t0,t1,1,r1,d1,a1,dispatch1,b1)
  call poison_legacy()
  call fmr_run_serialized_physical_multiswap(col,templ,p,f2,run_state2,cfg,top,t0,t1,1,r2,d2,a2,dispatch2,b2)

  call check(dispatch1==FMR_SERIAL_DISPATCH_OK .and. dispatch2==FMR_SERIAL_DISPATCH_OK,'serialized dispatch')
  call check(r1(1)%admitted .and. r2(1)%admitted,'mode5 runtime admitted')
  call check(r1(1)%completed .and. r1(1)%committed .and. r2(1)%completed .and. r2(1)%committed,'mode5 runtime committed')
  call check(trim(r1(1)%solver_route)=='legacy-reference-bound','runtime solver route')
  call check(r1(1)%mass%complete .and. r2(1)%mass%complete,'runtime mass complete')
  call check(same_bits(r1(1)%mass%total_in,expected_mass) .and. same_bits(r1(1)%mass%total_out,expected_mass),'runtime independent mass oracle')
  call check(same_bits(r1(1)%mass%total_in,r2(1)%mass%total_in) .and. same_bits(r1(1)%mass%total_out,r2(1)%mass%total_out),'runtime seed mass identity')
  call check(states_equal(run_state1(1),run_state2(1)),'runtime seed state identity')
  call check(state_equals_initial(run_state1(1),initial),'stationary committed state')
  call check(run_state1(1)%current_revision()==1_int64 .and. run_state2(1)%current_revision()==1_int64,'one commit revision')
  call check(d1(1)%retries==0 .and. d2(1)%retries==0,'zero-tolerance exact temporal acceptance')
  call check(b1%max_simultaneous_real_physical_solves==1 .and. b2%max_simultaneous_real_physical_solves==1,'serialized-only execution')
  call check(b1%authoritative_aggregate_mass%complete,'aggregate mass complete')
  call check(same_bits(b1%authoritative_aggregate_mass%total_in,r1(1)%mass%total_in) .and. &
       same_bits(b1%authoritative_aggregate_mass%total_out,r1(1)%mass%total_out),'aggregate mass exactly once')

  write(*,'(A,Z16.16)') 'FVQ26_REFERENCE_K_BITS=',transfer(k0,0_int64)
  write(*,'(A,Z16.16)') 'FVQ26_RUNTIME_QBOT_BITS=',transfer(obs1%bottom_flux,0_int64)
  write(*,'(A,Z16.16)') 'FVQ26_POSITIVE_QBOT_BITS=',transfer(obs_high%bottom_flux,0_int64)
  write(*,'(A,Z16.16)') 'FVQ26_MASS_BITS=',transfer(expected_mass,0_int64)
  write(*,'(A)') 'FVQ26_INDEPENDENT_BOTTOM_HEAD_AUTHORITY PASS'
  write(*,'(A)') 'FVQ26_INDEPENDENT_QBOT_MASS_EXACTLY_ONCE PASS'
  write(*,'(A)') 'FVQ26_INDEPENDENT_TRIAL_DISCARD_REPLAY PASS'
  write(*,'(A)') 'FVQ26_INDEPENDENT_FAIL_CLOSED PASS'
  write(*,'(A)') 'FVQ26_INDEPENDENT_ZERO_TOLERANCE_TEMPORAL PASS'
  write(*,'(A)') 'FVQ26_INDEPENDENT_SERIALIZED_RUNTIME PASS'
  write(*,'(A)') 'FVQ26_PRESCRIBED_BOTTOM_HEAD_RUNTIME_ORACLE PASS'

contains
  pure real(real64) function reference_theta(head) result(theta)
    real(real64),intent(in)::head
    real(real64)::se
    se=(1.0_real64+(abs(alpha*head))**npar)**(-mpar)
    theta=theta_r+(theta_s-theta_r)*se
  end function reference_theta

  pure real(real64) function reference_k(head,theta) result(k)
    real(real64),intent(in)::head,theta
    real(real64)::se,term
    if (head>=0.0_real64) then
      k=ksat
    else
      se=(theta-theta_r)/(theta_s-theta_r)
      term=(1.0_real64-se**(1.0_real64/mpar))**mpar
      k=ksat*(se**lpar)*(1.0_real64-term)**2
    end if
  end function reference_k

  subroutine build_parameters(x)
    type(fmr_b110_physical_parameters_t),intent(out)::x
    integer::j
    x%parameter_set_id=26001_int64; x%active_nodes=numnod
    allocate(x%z(numnod),x%dz(numnod),x%node_distance(numnod),x%cofgen(24,numnod))
    x%z=z; x%dz=dz; x%node_distance=disnod(1:numnod); x%cofgen=0.0_real64
    do j=1,numnod
      x%cofgen(1,j)=theta_r; x%cofgen(2,j)=theta_s; x%cofgen(3,j)=ksat; x%cofgen(4,j)=alpha
      x%cofgen(5,j)=lpar; x%cofgen(6,j)=npar; x%cofgen(7,j)=mpar; x%cofgen(8,j)=alpha
      x%cofgen(9,j)=0.0_real64; x%cofgen(10,j)=ksat; x%cofgen(11,j)=0.999_real64
      x%cofgen(12,j)=0.99_real64*ksat; x%cofgen(22,j)=-1.0e6_real64; x%cofgen(23,j)=1.0e-12_real64
    end do
    x%bottom_mode=5; x%swkimpl=0; x%swkmean=1; x%swsophy=0
    x%max_iterations=8; x%max_backtracking=4; x%min_step_duration=1.0e-6_real64
    x%compartment_balance_tolerance=mass_tol; x%total_balance_tolerance=mass_tol
    x%head_abs_tolerance=mass_tol; x%head_rel_tolerance=mass_tol; x%ponding_tolerance=mass_tol
    x%root_extraction_active=.false.; x%macropore_active=.false.; x%snow_active=.false.
    x%hysteresis_active=.false.; x%tabulated_hydraulics_active=.false.; x%elasticity_active=.false.; x%frost_active=.false.
  end subroutine build_parameters

  subroutine build_state(s,theta)
    type(fmr_b110_physical_state_t),intent(out)::s
    real(real64),intent(in)::theta
    s%active_nodes=numnod; allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=h0; s%water_content=theta; s%ponding_depth=0.0_real64; s%groundwater_level=-2.0_real64
  end subroutine build_state

  subroutine build_forcing(f,top_flux,bottom_seed,bottom_head)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::top_flux,bottom_seed,bottom_head
    f%top_flux=top_flux; f%top_head=h0; f%bottom_flux=bottom_seed; f%bottom_head=bottom_head
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine build_forcing

  subroutine build_topology(c,t)
    type(fmr_logical_column_t),intent(out)::c; type(fmr_template_t),intent(out)::t
    t%template_id=2601_int64; t%physics_topology_id=2602_int64; t%vertical_layout_id=2603_int64
    t%state_layout_id=2604_int64; t%solver_interface_id=2605_int64; t%optional_state_layout_id=2606_int64
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=26001_int64; c%template_id=t%template_id; c%parameter_ref=1_int64; c%state_handle=1_int64
    c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine build_topology

  subroutine build_config(x)
    type(canonical_numerical_config_t),intent(out)::x
    x%transaction%temporal_tolerance=0.0_real64; x%transaction%mass_tolerance=mass_tol
    x%transaction%retry_scale=0.5_real64; x%transaction%max_retries=2
    x%max_committed_substeps=8; x%progress_tolerance=0.0_real64
  end subroutine build_config

  subroutine poison_legacy()
    swmacro=0; legacy_melt=0.0_real64; legacy_qrot=0.0_real64
    legacy_swbotb=3; legacy_hbot=99999.0_real64; legacy_qbot=-99999.0_real64
  end subroutine poison_legacy

  logical function state_equals_initial(c,s)
    type(kernel_committed_state_t),intent(in)::c; type(fmr_b110_physical_state_t),intent(in)::s
    class(transaction_state_t),allocatable::snap; logical::available; integer::j
    state_equals_initial=.false.; call c%snapshot(snap,available); if(.not.available)return
    select type(x=>snap); type is(fmr_b110_physical_state_t)
      if(x%active_nodes/=s%active_nodes)return
      do j=1,x%active_nodes
        if(.not.same_bits(x%pressure_head(j),s%pressure_head(j)))return
        if(.not.same_bits(x%water_content(j),s%water_content(j)))return
      end do
      if(.not.same_bits(x%ponding_depth,s%ponding_depth))return
      if(.not.same_bits(x%groundwater_level,s%groundwater_level))return
      state_equals_initial=.true.
    end select
  end function state_equals_initial

  logical function states_equal(a,b)
    type(kernel_committed_state_t),intent(in)::a,b
    class(transaction_state_t),allocatable::sa,sb; logical::oka,okb; integer::j
    states_equal=.false.; call a%snapshot(sa,oka); call b%snapshot(sb,okb); if(.not.oka.or..not.okb)return
    select type(x=>sa); type is(fmr_b110_physical_state_t)
      select type(y=>sb); type is(fmr_b110_physical_state_t)
        if(x%active_nodes/=y%active_nodes)return
        do j=1,x%active_nodes
          if(.not.same_bits(x%pressure_head(j),y%pressure_head(j)))return
          if(.not.same_bits(x%water_content(j),y%water_content(j)))return
        end do
        if(.not.same_bits(x%ponding_depth,y%ponding_depth))return
        if(.not.same_bits(x%groundwater_level,y%groundwater_level))return
        states_equal=.true.
      end select
    end select
  end function states_equal

  logical function same_bits(a,b)
    real(real64),intent(in)::a,b
    same_bits=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits

  subroutine check(cond,label)
    logical,intent(in)::cond; character(len=*),intent(in)::label
    if(.not.cond)then
      write(*,'(A,1X,A)')'FVQ26_FAIL',trim(label); error stop 1
    end if
  end subroutine check
end program test_fvq26_prescribed_bottom_head_runtime_oracle
