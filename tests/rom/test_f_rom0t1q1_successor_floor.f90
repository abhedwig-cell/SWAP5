program test_f_rom0t1q1_successor_floor
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_reference_floor_result_t, &
       kernel_reference_floor_candidate_t, kernel_diagnostics_t, KERNEL_REFERENCE_FLOOR_STATUS_OK, &
       KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_serialized_context_binding, only: bind_b110_serialized_legacy_context
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: base_dt=0.0016_real64
  real(real64), parameter :: refined_dt=0.0008_real64
  integer, parameter :: base_steps=32
  integer, parameter :: refined_steps=64
  real(real64), parameter :: integrated_allowance=1.6e-15_real64
  real(real64), parameter :: original_local_tol=1.0e-12_real64
  real(real64), parameter :: original_total_tol=1.0e-12_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=968101_int64
  character(len=24), parameter :: cases(4)=[character(len=24) :: &
       'B01_E1_NOMINAL_FLUX','B01_E2_DRYING_FLUX','B14_E1_NOMINAL_FLUX','B14_E2_DRYING_FLUX']
  character(len=8), parameter :: materials(4)=[character(len=8) :: 'B01','B01','B14','B14']
  real(real64), parameter :: top_factor(4)=[0.01_real64,-0.005_real64,0.01_real64,-0.005_real64]
  real(real64), parameter :: bottom_factor(4)=[-0.004_real64,-0.019_real64,-0.004_real64,-0.019_real64]
  integer, parameter :: expected_strict_pass(4)=[17,3,64,3]
  integer, parameter :: expected_strict_fail(4)=[18,4,0,4]
  integer :: icase,total_fallbacks,total_overlap,total_compares,complete_count

  call require(numnod==16,'T1Q1 geometry frozen at 16 nodes')
  call require(abs(sum(dz(1:numnod))-160.0_real64)<=1.0e-12_real64,'T1Q1 depth frozen')
  call require(maxval(abs(dz(1:numnod)-10.0_real64))<=1.0e-12_real64,'T1Q1 dz frozen')

  total_fallbacks=0;total_overlap=0;total_compares=0;complete_count=0
  do icase=1,4
    call run_case(trim(cases(icase)),trim(materials(icase)),top_factor(icase),bottom_factor(icase), &
         expected_strict_pass(icase),expected_strict_fail(icase),total_fallbacks,total_overlap,total_compares,complete_count)
  end do

  write(*,'(A,I0)') 'F_ROM0T1Q1_POLICY_COMPLETE_COUNT=',complete_count
  write(*,'(A,I0)') 'F_ROM0T1Q1_OVERLAP_NEUTRAL_COUNT=',total_overlap
  write(*,'(A,I0)') 'F_ROM0T1Q1_TOTAL_FALLBACK_COUNT=',total_fallbacks
  write(*,'(A,I0)') 'F_ROM0T1Q1_TEMPORAL_COMPARE_COUNT=',total_compares
  write(*,'(A)') 'F_ROM0T1Q1_EXECUTION_COMPLETE=PASS'

contains

  subroutine run_case(case_id,material_id,qtop_factor,qbot_factor,expected_pass,expected_fail, &
                      total_fallbacks,total_overlap,total_compares,complete_count)
    character(len=*),intent(in) :: case_id,material_id
    real(real64),intent(in) :: qtop_factor,qbot_factor
    integer,intent(in) :: expected_pass,expected_fail
    integer,intent(inout) :: total_fallbacks,total_overlap,total_compares,complete_count

    type(fmr_b110_physical_parameters_t) :: strict_parameters,policy_parameters,fallback_parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(kernel_committed_state_t) :: base_state,control_state,policy_state
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template

    real(real64) :: h0,k0,qtop,qbot,t0,t1,rep_bound,total_bound,comp_tol,total_tol
    real(real64) :: sh(numnod,refined_steps),stheta(numnod,refined_steps)
    real(real64) :: spond(refined_steps),sgwl(refined_steps),smass(refined_steps)
    real(real64) :: sbex(refined_steps),sbflux(refined_steps)
    integer :: snl(refined_steps),sback(refined_steps)
    logical :: svalid(refined_steps)

    real(real64) :: base_h(numnod,base_steps),base_theta(numnod,base_steps)
    real(real64) :: base_cum_top(base_steps),base_cum_bottom(base_steps),base_bottom_flux(base_steps)
    real(real64) :: ph(numnod),ptheta(numnod),pond,gwl
    real(real64) :: mass,bex,bflux,cum_top,cum_bottom,max_mass
    real(real64) :: rsum,rmax,local_integrated,total_integrated
    real(real64) :: dh(numnod),dtheta(numnod),dht_inf,dht_rms,dth_inf,dth_rms
    real(real64) :: base_total,base_upper,base_lower,pol_total,pol_upper,pol_lower
    integer :: i,j,control_pass,control_fail,status,nl,ir,back,bal_flags,head_flags,imax
    integer :: failed_nl,failed_back,nfallback
    character(len=96) :: route
    character(len=24) :: failure_class
    logical :: ok,neutral,unchanged,time_ok,got
    integer(int64) :: rev_before,lineage_before
    real(real64) :: time_before,time_after
    class(transaction_state_t),allocatable :: snap_before,snap_after

    call initialize_parameters(material_id,strict_parameters)
    policy_parameters=strict_parameters
    call initialize_state(strict_parameters,h0,k0,initial_state)
    qtop=qtop_factor*k0;qbot=qbot_factor*k0
    call initialize_identity(column,template)
    call initialize_forcing(forcing,qtop,qbot,h0)
    strict_parameters%bottom_mode=2
    strict_parameters%compartment_balance_tolerance=original_local_tol
    strict_parameters%total_balance_tolerance=original_total_tol
    policy_parameters=strict_parameters

    ! Untouched 0.0016-day strict baseline used for the original temporal-floor comparison.
    call fmr_new_b110_committed_state(base_state,column%column_id,initial_state,0.0_real64,ok)
    call require(ok,'T1Q1 base initial state')
    t0=0.0_real64;cum_top=0.0_real64;cum_bottom=0.0_real64;max_mass=0.0_real64
    do i=1,base_steps
      t1=real(i,real64)*base_dt
      call sample_fresh(column,template,strict_parameters,base_state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
      call require(ok,'T1Q1 strict base trajectory')
      cum_top=cum_top+qtop*(t1-t0);cum_bottom=cum_bottom+bex;max_mass=max(max_mass,abs(mass))
      call capture_state(base_state,base_h(:,i),base_theta(:,i),pond,gwl,ok);call require(ok,'T1Q1 base capture')
      base_cum_top(i)=cum_top;base_cum_bottom(i)=cum_bottom;base_bottom_flux(i)=bflux
      t0=t1
    end do
    write(*,'(*(g0))') 'F_ROM0T1Q1_BASE_PASS|CASE=',trim(case_id),'|STEPS=',base_steps,'|MAX_ABS_MASS=',max_mass

    ! Immutable strict refined provenance reproduction.
    svalid=.false.;sh=0.0_real64;stheta=0.0_real64;spond=0.0_real64;sgwl=0.0_real64
    smass=0.0_real64;sbex=0.0_real64;sbflux=0.0_real64;snl=0;sback=0
    call fmr_new_b110_committed_state(control_state,column%column_id,initial_state,0.0_real64,ok)
    call require(ok,'T1Q1 control initial state')
    t0=0.0_real64;control_pass=0;control_fail=0
    do i=1,refined_steps
      t1=real(i,real64)*refined_dt
      call sample_fresh(column,template,strict_parameters,control_state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
      if(.not.ok) then
        control_fail=i
        exit
      end if
      control_pass=i;svalid(i)=.true.;smass(i)=mass;sbex(i)=bex;sbflux(i)=bflux;snl(i)=nl;sback(i)=back
      call capture_state(control_state,sh(:,i),stheta(:,i),spond(i),sgwl(i),ok);call require(ok,'T1Q1 control capture')
      t0=t1
    end do
    call require(control_pass==expected_pass.and.control_fail==expected_fail,'T1Q1 immutable strict provenance')
    write(*,'(*(g0))') 'F_ROM0T1Q1_CONTROL|CASE=',trim(case_id),'|PASS_STEPS=',control_pass,'|FAIL_STEP=',control_fail

    ! Strict-first fail-closed successor.
    call fmr_new_b110_committed_state(policy_state,column%column_id,initial_state,0.0_real64,ok)
    call require(ok,'T1Q1 policy initial state')
    t0=0.0_real64;cum_top=0.0_real64;cum_bottom=0.0_real64;max_mass=0.0_real64;nfallback=0

    do i=1,refined_steps
      t1=real(i,real64)*refined_dt
      call prospective_bound(policy_state,policy_parameters,rep_bound,ok)
      call require(ok.and.rep_bound>0.0_real64,'T1Q1 pre-solve representation bound')
      total_bound=max(integrated_allowance,rep_bound)

      rev_before=policy_state%current_revision();lineage_before=policy_state%current_lineage_id()
      call policy_state%current_time(time_before,time_ok);call require(time_ok.and.same_bits(time_before,t0),'T1Q1 pre-attempt time')
      call policy_state%snapshot(snap_before,got);call require(got,'T1Q1 pre-attempt snapshot')

      policy_parameters%compartment_balance_tolerance=original_local_tol
      policy_parameters%total_balance_tolerance=original_total_tol
      call sample_fresh(column,template,policy_parameters,policy_state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)

      neutral=.true.
      if(ok) then
        if(svalid(i)) then
          call compare_with_baseline(policy_state,sh(:,i),stheta(:,i),spond(i),sgwl(i),smass(i),sbex(i),sbflux(i), &
               snl(i),sback(i),mass,bex,bflux,nl,back,neutral)
          call require(neutral,'T1Q1 strict overlap bit neutrality')
          total_overlap=total_overlap+1
        end if
        write(*,'(*(g0))') 'F_ROM0T1Q1_STEP|CASE=',trim(case_id),'|STEP=',i,'|ROUTE=STRICT|OVERLAP=',svalid(i), &
             '|NEUTRAL=',neutral,'|MASS=',mass,'|BOTTOM_EXCHANGE=',bex,'|BOTTOM_FLUX=',bflux,'|NL=',nl,'|BACKTRACK=',back
      else
        call require(.not.svalid(i),'T1Q1 fallback on original strict accepted overlap')
        call policy_state%current_time(time_after,time_ok);call require(time_ok.and.same_bits(time_after,time_before),'T1Q1 failed time immutable')
        call require(policy_state%current_revision()==rev_before,'T1Q1 failed revision immutable')
        call require(policy_state%current_lineage_id()==lineage_before,'T1Q1 failed lineage immutable')
        call policy_state%snapshot(snap_after,got);call require(got,'T1Q1 failed snapshot')
        unchanged=state_bits_equal(snap_before,snap_after);call require(unchanged,'T1Q1 failed state immutable')
        failed_nl=nl;failed_back=back

        call diagnose_failed_interval(policy_parameters,forcing,policy_state,t0,t1,status,failed_nl,failed_back, &
             failure_class,bal_flags,head_flags,rmax,rsum,imax)
        call require(trim(failure_class)=='RETRY_TOTAL_ONLY'.or.trim(failure_class)=='RETRY_LOCAL_BALANCE', &
             'T1Q1 fallback class allowed')
        call require(head_flags==0,'T1Q1 fallback has no head failure')
        local_integrated=rmax*(t1-t0);total_integrated=abs(rsum)*(t1-t0)
        if(bal_flags>0) call require(local_integrated<=integrated_allowance,'T1Q1 local defect inside integrated allowance')
        call require(total_integrated<=total_bound,'T1Q1 total defect inside prospective bound')

        comp_tol=integrated_allowance/(t1-t0)
        total_tol=total_bound/(t1-t0)
        fallback_parameters=policy_parameters
        fallback_parameters%compartment_balance_tolerance=comp_tol
        fallback_parameters%total_balance_tolerance=total_tol
        call sample_fresh(column,template,fallback_parameters,policy_state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
        call require(ok,'T1Q1 qualified fallback reattempt')
        nfallback=nfallback+1;total_fallbacks=total_fallbacks+1
        write(*,'(*(g0))') 'F_ROM0T1Q1_FALLBACK|CASE=',trim(case_id),'|STEP=',i,'|CLASS=',trim(failure_class), &
             '|BAL_FLAGS=',bal_flags,'|HEAD_FLAGS=',head_flags,'|RMAX=',rmax,'|RSUM=',rsum,'|IMAX=',imax, &
             '|LOCAL_INTEGRATED_CM=',local_integrated,'|LOCAL_ALLOWANCE_CM=',integrated_allowance, &
             '|REP_BOUND_CM=',rep_bound,'|TOTAL_BOUND_CM=',total_bound,'|ABS_TOTAL_RESIDUAL_CM=',total_integrated, &
             '|COMP_TOL=',comp_tol,'|TOTAL_TOL=',total_tol,'|FAILED_NL=',failed_nl,'|FAILED_BACKTRACK=',failed_back, &
             '|ACCEPT_NL=',nl,'|ACCEPT_BACKTRACK=',back,'|MASS=',mass
      end if

      cum_top=cum_top+qtop*(t1-t0);cum_bottom=cum_bottom+bex;max_mass=max(max_mass,abs(mass))
      call capture_state(policy_state,ph,ptheta,pond,gwl,ok);call require(ok,'T1Q1 policy capture')

      if(mod(i,2)==0) then
        j=i/2
        dh=base_h(:,j)-ph;dtheta=base_theta(:,j)-ptheta
        dht_inf=maxval(abs(dh));dht_rms=sqrt(sum(dh*dh)/real(numnod,real64))
        dth_inf=maxval(abs(dtheta));dth_rms=sqrt(sum(dtheta*dtheta)/real(numnod,real64))
        base_total=sum(base_theta(:,j)*dz(1:numnod));pol_total=sum(ptheta*dz(1:numnod))
        base_upper=sum(base_theta(1:4,j)*dz(1:4));pol_upper=sum(ptheta(1:4)*dz(1:4))
        base_lower=sum(base_theta(5:numnod,j)*dz(5:numnod));pol_lower=sum(ptheta(5:numnod)*dz(5:numnod))
        call require(all(ieee_is_finite([dht_inf,dht_rms,dth_inf,dth_rms,base_total,pol_total,base_upper,pol_upper,base_lower,pol_lower])), &
             'T1Q1 finite temporal comparison')
        total_compares=total_compares+1
        write(*,'(*(g0))') 'F_ROM0T1Q1_COMPARE|CASE=',trim(case_id),'|BASE_STEP=',j,'|REFINED_STEP=',i,'|T=',t1, &
             '|D_H_INF=',dht_inf,'|D_H_RMS=',dht_rms,'|D_THETA_INF=',dth_inf,'|D_THETA_RMS=',dth_rms, &
             '|D_TOTAL_STORAGE=',abs(base_total-pol_total),'|D_UPPER_STORAGE=',abs(base_upper-pol_upper), &
             '|D_LOWER_STORAGE=',abs(base_lower-pol_lower),'|D_CUM_TOP=',abs(base_cum_top(j)-cum_top), &
             '|D_CUM_BOTTOM=',abs(base_cum_bottom(j)-cum_bottom),'|D_BOTTOM_FLUX=',abs(base_bottom_flux(j)-bflux)
      end if
      t0=t1
      if(allocated(snap_before))deallocate(snap_before)
      if(allocated(snap_after))deallocate(snap_after)
    end do

    call require(policy_state%current_revision()==int(refined_steps,int64),'T1Q1 refined final revision')
    call require(abs(t0-real(refined_steps,real64)*refined_dt)<=1e-15_real64,'T1Q1 refined final time')
    if(expected_fail==0) call require(nfallback==0,'T1Q1 complete strict case has zero fallback')
    if(expected_fail>0) call require(nfallback>0,'T1Q1 failed strict case exercises fallback')
    complete_count=complete_count+1
    write(*,'(*(g0))') 'F_ROM0T1Q1_CASE_PASS|CASE=',trim(case_id),'|FALLBACKS=',nfallback, &
         '|MAX_ABS_MASS=',max_mass,'|FINAL_REV=',policy_state%current_revision(),'|FINAL_T=',t0
  end subroutine run_case



  subroutine sample_fresh(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(kernel_committed_state_t),intent(inout) :: state
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1
    logical,intent(out) :: ok
    real(real64),intent(out) :: mass,bex,bflux
    integer,intent(out) :: status,nl,ir,back
    character(len=*),intent(out) :: route
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: top
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    logical :: did_commit
    integer :: commit_status

    mass=huge(0.0_real64);bex=0.0_real64;bflux=0.0_real64
    call backend%initialize(top)
    call backend%run_reference_floor_sample(column,template,p,state,forcing,t0,t1,hard_mass_gate,result,candidate,diagnostics)
    observation=backend%observation()
    status=observation%solver_status;route=trim(observation%solver_diagnostics%route)
    nl=result%nonlinear_iterations;ir=result%internal_retries;back=result%backtracking_attempts
    ok=result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK.and.result%sample_valid.and.candidate%ready().and. &
       result%physical_advances==1.and.result%internal_retries==0.and.diagnostics%retries==0.and. &
       result%mass%complete.and.ieee_is_finite(result%mass%residual).and.abs(result%mass%residual)<=hard_mass_gate.and. &
       observation%solver_executed.and.observation%solver_status==SW_SOLVE_CONVERGED.and. &
       result%bottom_interface_exchange_available.and.ieee_is_finite(result%bottom_outward_exchange_native).and. &
       ieee_is_finite(result%terminal_bottom_outward_flux_native)
    if(.not.ok) then
      if(candidate%ready()) call backend%discard_reference_floor_candidate(candidate,diagnostics)
      return
    end if
    mass=result%mass%residual;bex=result%bottom_outward_exchange_native;bflux=result%terminal_bottom_outward_flux_native
    call backend%commit_reference_floor_candidate(state,candidate,diagnostics,did_commit,commit_status)
    ok=did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED.and..not.candidate%ready()
  end subroutine sample_fresh

  subroutine diagnose_failed_interval(p,forcing,state,t0,t1,fmr_status,fmr_nl,fmr_back,class_name,bal,head,rmax,rsum,imax)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    type(kernel_committed_state_t),intent(in) :: state
    real(real64),intent(in) :: t0,t1
    integer,intent(in) :: fmr_status,fmr_nl,fmr_back
    character(len=*),intent(out) :: class_name
    integer,intent(out) :: bal,head,imax
    real(real64),intent(out) :: rmax,rsum

    type(soil_water_parameter_set_t),target :: pset
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top
    real(real64),target :: drainage(1,numnod),irrigation(numnod),root_sink(numnod)
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    class(transaction_state_t),allocatable :: snap
    logical :: got,context_ok

    call require(fmr_status==SW_SOLVE_RETRY_ADVISED,'FMR failed status retry-advised')
    pset%parameter_set_id=p%parameter_set_id;pset%active_nodes=numnod
    allocate(pset%z(numnod),pset%dz(numnod),pset%node_distance(numnod))
    pset%z=p%z;pset%dz=p%dz;pset%node_distance=p%node_distance
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,t1-t0)
    drainage=0.0_real64;irrigation=0.0_real64;root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    request%parameters=>pset;request%step_duration=t1-t0
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;request%boundary%bottom_mode=2
    request%boundary%top_flux=forcing%top_flux;request%boundary%top_head=forcing%top_head
    request%boundary%bottom_flux=forcing%bottom_flux;request%boundary%bottom_head=forcing%bottom_head
    request%numerical%max_iterations=p%max_iterations;request%numerical%max_backtracking=p%max_backtracking
    request%numerical%conductivity_implicit_mode=p%swkimpl;request%numerical%conductivity_mean_method=p%swkmean
    request%numerical%min_step_duration=p%min_step_duration
    request%numerical%compartment_balance_tolerance=original_local_tol
    request%numerical%total_balance_tolerance=original_total_tol
    request%numerical%head_abs_tolerance=p%head_abs_tolerance;request%numerical%head_rel_tolerance=p%head_rel_tolerance
    request%numerical%ponding_tolerance=p%ponding_tolerance;request%physical%macropore_active=.false.
    request%evaluation%constitutive=>constitutive;request%evaluation%source_sink=>source_sink;request%evaluation%top_boundary=>top

    call state%snapshot(snap,got);call require(got,'diagnostic state snapshot')
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      request%base_state%active_nodes=physical%active_nodes
      allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
      request%base_state%pressure_head=physical%pressure_head;request%base_state%water_content=physical%water_content
      request%base_state%ponding_depth=physical%ponding_depth;request%base_state%groundwater_level=physical%groundwater_level
    class default
      call require(.false.,'diagnostic B110 state')
    end select

    call bind_b110_serialized_legacy_context(request,context_ok);call require(context_ok,'diagnostic serialized context')
    call solver%solve(request,workspace,result)
    call require(result%status==SW_SOLVE_RETRY_ADVISED,'direct retry-advised')
    call require(trim(result%diagnostics%route)=='legacy-reference-retry','direct retry route')
    call require(result%diagnostics%nonlinear_iterations==fmr_nl,'FMR/direct nonlinear identity')
    call require(result%diagnostics%backtracking_attempts==fmr_back,'FMR/direct backtracking identity')

    bal=count(workspace%richards%nonconverged_balance)
    head=count(workspace%richards%nonconverged_head)
    rsum=sum(workspace%richards%residual)
    rmax=maxval(abs(workspace%richards%residual))
    imax=maxloc(abs(workspace%richards%residual),dim=1)
    if(bal>0.and.head>0) then
      class_name='RETRY_MIXED'
    else if(bal>0) then
      class_name='RETRY_LOCAL_BALANCE'
    else if(head>0) then
      class_name='RETRY_HEAD'
    else if(ieee_is_finite(rsum).and.ieee_is_finite(rmax).and.rmax<=p%compartment_balance_tolerance.and. &
            abs(rsum)>original_total_tol) then
      class_name='RETRY_TOTAL_ONLY'
    else
      class_name='RETRY_OTHER'
    end if
    if(allocated(snap))deallocate(snap)
  end subroutine diagnose_failed_interval

  subroutine prospective_bound(state,p,bound,ok)
    type(kernel_committed_state_t),intent(in) :: state
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    real(real64),intent(out) :: bound
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snap
    logical :: got
    integer :: i
    real(real64) :: theta_s
    bound=0.0_real64;ok=.false.;theta_s=p%cofgen(2,1)
    call state%snapshot(snap,got);if(.not.got)return
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      if(physical%active_nodes/=numnod)return
      do i=1,numnod
        if(.not.ieee_is_finite(physical%water_content(i)))return
        if(physical%water_content(i)<=0.0_real64.or.physical%water_content(i)>=theta_s)return
        if(spacing(physical%water_content(i))>spacing(theta_s))return
        bound=bound+0.5_real64*(spacing(theta_s)+spacing(physical%water_content(i)))*p%dz(i)
      end do
      ok=ieee_is_finite(bound).and.bound>0.0_real64
    class default
      ok=.false.
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine prospective_bound

  subroutine compare_with_baseline(state,h,theta,pond,gwl,bmass,bbex,bbflux,bnl,bback,mass,bex,bflux,nl,back,neutral)
    type(kernel_committed_state_t),intent(in) :: state
    real(real64),intent(in) :: h(:),theta(:),pond,gwl,bmass,bbex,bbflux,mass,bex,bflux
    integer,intent(in) :: bnl,bback,nl,back
    logical,intent(out) :: neutral
    class(transaction_state_t),allocatable :: snap
    logical :: got
    neutral=.false.
    if(.not.same_bits(bmass,mass).or..not.same_bits(bbex,bex).or..not.same_bits(bbflux,bflux))return
    if(bnl/=nl.or.bback/=back)return
    call state%snapshot(snap,got);if(.not.got)return
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      neutral=array_bits_equal(physical%pressure_head,h).and.array_bits_equal(physical%water_content,theta).and. &
           same_bits(physical%ponding_depth,pond).and.same_bits(physical%groundwater_level,gwl)
    class default
      neutral=.false.
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine compare_with_baseline

  subroutine capture_state(state,h,theta,pond,gwl,ok)
    type(kernel_committed_state_t),intent(in) :: state
    real(real64),intent(out) :: h(:),theta(:),pond,gwl
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snap
    logical :: got
    ok=.false.;call state%snapshot(snap,got);if(.not.got)return
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      h=physical%pressure_head;theta=physical%water_content;pond=physical%ponding_depth;gwl=physical%groundwater_level
      ok=.true.
    class default
      ok=.false.
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine capture_state

  logical function state_bits_equal(left,right) result(equal)
    class(transaction_state_t),allocatable,intent(in) :: left,right
    equal=.false.
    select type(a=>left)
    type is(fmr_b110_physical_state_t)
      select type(b=>right)
      type is(fmr_b110_physical_state_t)
        equal=a%active_nodes==b%active_nodes.and.array_bits_equal(a%pressure_head,b%pressure_head).and. &
             array_bits_equal(a%water_content,b%water_content).and.same_bits(a%ponding_depth,b%ponding_depth).and. &
             same_bits(a%groundwater_level,b%groundwater_level)
      end select
    end select
  end function state_bits_equal

  subroutine state_metrics(state,total,upper,lower,ok)
    type(kernel_committed_state_t),intent(in) :: state
    real(real64),intent(out) :: total,upper,lower
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snap
    logical :: got
    total=0.0_real64;upper=0.0_real64;lower=0.0_real64;ok=.false.
    call state%snapshot(snap,got);if(.not.got)return
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      total=sum(physical%water_content*dz(1:numnod))
      upper=sum(physical%water_content(1:4)*dz(1:4))
      lower=sum(physical%water_content(5:numnod)*dz(5:numnod))
      ok=ieee_is_finite(total).and.ieee_is_finite(upper).and.ieee_is_finite(lower)
    class default
      ok=.false.
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine state_metrics

  pure logical function array_bits_equal(a,b)
    real(real64),intent(in) :: a(:),b(:)
    integer :: i
    array_bits_equal=size(a)==size(b);if(.not.array_bits_equal)return
    do i=1,size(a)
      if(.not.same_bits(a(i),b(i)))then;array_bits_equal=.false.;return;end if
    end do
  end function array_bits_equal

  pure logical function same_bits(a,b)
    real(real64),intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia);ib=transfer(b,ib);same_bits=ia==ib
  end function same_bits

  subroutine initialize_parameters(material_id,p)
    character(len=*),intent(in) :: material_id
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    select case(trim(material_id))
    case('B01')
      tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64;nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64
    case('B14')
      tr=0.01_real64;ts=0.416774_real64;alpha=0.00541_real64;nn=1.301528_real64;ks=0.895023_real64;lam=-0.334926_real64
    case default
      call require(.false.,'known T1Q1 material');tr=0.0_real64;ts=0.0_real64;alpha=0.0_real64;nn=2.0_real64;ks=0.0_real64;lam=0.0_real64
    end select
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=968101_int64;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=tr;p%cofgen(2,k)=ts;p%cofgen(3,k)=ks;p%cofgen(4,k)=alpha;p%cofgen(5,k)=lam;p%cofgen(6,k)=nn
      p%cofgen(7,k)=mm;p%cofgen(8,k)=alpha;p%cofgen(9,k)=0.0_real64;p%cofgen(10,k)=ks
      p%cofgen(11,k)=0.999_real64;p%cofgen(12,k)=0.99_real64*ks;p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=2;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=original_local_tol;p%total_balance_tolerance=original_total_tol
    p%head_abs_tolerance=1.0e-12_real64;p%head_rel_tolerance=1.0e-12_real64;p%ponding_tolerance=1.0e-12_real64
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%ksatexm_extension_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.
    p%drainage_response_active=.false.;p%drainage_qbot_smooth_freatic_projection=.false.
  end subroutine initialize_parameters

  subroutine initialize_state(p,h0,k0,state)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    real(real64),intent(out) :: h0,k0
    type(fmr_b110_physical_state_t),intent(out) :: state
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: m,heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    m=1.0_real64-1.0_real64/p%cofgen(6,1)
    h0=-(se0**(-1.0_real64/m)-1.0_real64)**(1.0_real64/p%cofgen(6,1))/p%cofgen(4,1)
    heads=h0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,base_dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    call require(k0>0.0_real64.and.all(ieee_is_finite(water)),'finite T1Q1 seed')
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads;state%water_content=water
    state%ponding_depth=0.0_real64;state%groundwater_level=-999.0_real64
  end subroutine initialize_state

  subroutine initialize_forcing(f,qt,qb,hb)
    type(fmr_b110_physical_forcing_t),intent(out) :: f
    real(real64),intent(in) :: qt,qb,hb
    f%top_flux=qt;f%top_head=0.0_real64;f%bottom_flux=qb;f%bottom_head=hb
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_identity(col,tmpl)
    type(fmr_logical_column_t),intent(out) :: col
    type(fmr_template_t),intent(out) :: tmpl
    tmpl%template_id=968101_int64;tmpl%physics_topology_id=968102_int64
    tmpl%vertical_layout_id=968103_int64;tmpl%state_layout_id=968104_int64;tmpl%solver_interface_id=968105_int64
    tmpl%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    tmpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tmpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=column_id;col%template_id=tmpl%template_id;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_identity

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition)then
      write(*,'(A,1X,A)') 'F_ROM0T1Q1_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_f_rom0t1q1_successor_floor
