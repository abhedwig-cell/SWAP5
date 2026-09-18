program test_f_rom0r_r3r1_representation_policy
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
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_solver_contract, only: SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: seed_dt=0.0016_real64
  integer, parameter :: seed_intervals=2
  real(real64), parameter :: perturb_dt=0.0008_real64
  integer, parameter :: perturb_intervals=16
  real(real64), parameter :: original_total_rate_tol=1.0e-12_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=963201_int64
  character(len=8), parameter :: materials(2)=[character(len=8) :: 'B01','B14']
  character(len=20), parameter :: cases(2)=[character(len=20) :: 'BOTTOM_HEAD_RISE','BOTTOM_HEAD_FALL']

  integer :: imat,icase

  call require(numnod==16,'R3R1 geometry frozen at 16 nodes')
  call require(abs(sum(dz(1:numnod))-160.0_real64)<=1.0e-12_real64,'R3R1 depth frozen at 160 cm')

  do imat=1,size(materials)
    do icase=1,size(cases)
      call run_case(trim(materials(imat)),trim(cases(icase)))
    end do
  end do
  write(*,'(A)') 'F_ROM0R_R3R1_EXECUTION_COMPLETE=PASS'

contains

  subroutine run_case(material_id,case_id)
    character(len=*),intent(in) :: material_id,case_id
    type(fmr_b110_physical_parameters_t) :: original_parameters,candidate_parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr_serialized_reference_backend_t) :: original_backend,candidate_backend
    type(fixed_flux_top_boundary_provider_t),target :: original_top,candidate_top
    type(kernel_committed_state_t) :: original_committed,candidate_committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    real(real64) :: h0,k0,qeq,hbot,t0,t1
    real(real64) :: omass,obex,obflux,cmass,cbex,cbflux
    real(real64) :: cumulative_candidate_bottom,max_candidate_mass
    real(real64) :: rep_bound,policy_tol
    real(real64) :: total_storage,upper_storage,lower_storage,pond,gwl,bottom_head_state
    integer :: i,expected_original_fail,original_passes
    integer :: osolver_status,onl,oretries,oback
    integer :: csolver_status,cnl,cretries,cback
    character(len=96) :: oroute,croute
    logical :: ook,cok,original_failed,identical,policy_ok

    call initialize_parameters(material_id,original_parameters)
    candidate_parameters=original_parameters
    call initialize_state(original_parameters,h0,k0,initial_state)
    qeq=-k0
    select case(trim(case_id))
    case('BOTTOM_HEAD_RISE')
      hbot=0.75_real64*h0
      if(trim(material_id)=='B01') then
        expected_original_fail=11
      else
        expected_original_fail=0
      end if
    case('BOTTOM_HEAD_FALL')
      hbot=1.25_real64*h0
      if(trim(material_id)=='B01') then
        expected_original_fail=10
      else
        expected_original_fail=0
      end if
    case default
      call require(.false.,'R3R1 known case')
      hbot=h0; expected_original_fail=-1
    end select

    call initialize_identity(column,template)
    call initialize_forcing(forcing,qeq,qeq,h0)
    call fmr_new_b110_committed_state(original_committed,column_id,initial_state,0.0_real64,ook)
    call require(ook.and.original_committed%ready(),'R3R1 original committed initialized')
    call fmr_new_b110_committed_state(candidate_committed,column_id,initial_state,0.0_real64,cok)
    call require(cok.and.candidate_committed%ready(),'R3R1 candidate committed initialized')
    call original_backend%initialize(original_top)
    call candidate_backend%initialize(candidate_top)

    original_parameters%bottom_mode=2
    candidate_parameters%bottom_mode=2
    original_parameters%total_balance_tolerance=original_total_rate_tol
    candidate_parameters%total_balance_tolerance=original_total_rate_tol
    t0=0.0_real64
    do i=1,seed_intervals
      t1=real(i,real64)*seed_dt
      forcing%top_flux=qeq; forcing%bottom_flux=qeq; forcing%bottom_head=h0
      call execute_sample(original_backend,column,template,original_parameters,original_committed,forcing,t0,t1, &
           ook,omass,obex,obflux,osolver_status,oroute,onl,oretries,oback)
      call execute_sample(candidate_backend,column,template,candidate_parameters,candidate_committed,forcing,t0,t1, &
           cok,cmass,cbex,cbflux,csolver_status,croute,cnl,cretries,cback)
      call require(ook.and.cok,'R3R1 both seed samples pass')
      call states_bit_equal(original_committed,candidate_committed,identical)
      call require(identical,'R3R1 seed endpoint bit identity')
      t0=t1
    end do

    original_parameters%bottom_mode=5
    candidate_parameters%bottom_mode=5
    forcing%top_flux=qeq; forcing%bottom_flux=qeq; forcing%bottom_head=hbot
    cumulative_candidate_bottom=0.0_real64
    max_candidate_mass=0.0_real64
    original_failed=.false.
    original_passes=0

    do i=1,perturb_intervals
      t1=real(seed_intervals,real64)*seed_dt+real(i,real64)*perturb_dt

      if(.not.original_failed) then
        original_parameters%total_balance_tolerance=original_total_rate_tol
        call execute_sample(original_backend,column,template,original_parameters,original_committed,forcing,t0,t1, &
             ook,omass,obex,obflux,osolver_status,oroute,onl,oretries,oback)
      else
        ook=.false.; osolver_status=-999; oroute='not-run'; onl=0; oretries=0; oback=0
      end if

      call representation_policy(candidate_parameters,candidate_committed,t1-t0,rep_bound,policy_tol,policy_ok)
      call require(policy_ok,'R3R1 prospective candidate policy available')
      candidate_parameters%total_balance_tolerance=policy_tol
      call execute_sample(candidate_backend,column,template,candidate_parameters,candidate_committed,forcing,t0,t1, &
           cok,cmass,cbex,cbflux,csolver_status,croute,cnl,cretries,cback)
      call require(cok,'R3R1 candidate policy completes every perturbation interval')
      call require(csolver_status==SW_SOLVE_CONVERGED,'R3R1 candidate solver converged')
      call require(cretries==0,'R3R1 candidate internal retry zero')
      call require(abs(cmass)<=hard_mass_gate,'R3R1 candidate hard mass gate')
      cumulative_candidate_bottom=cumulative_candidate_bottom+cbex
      max_candidate_mass=max(max_candidate_mass,abs(cmass))

      if(.not.original_failed) then
        if(ook) then
          original_passes=original_passes+1
          call states_bit_equal(original_committed,candidate_committed,identical)
          call require(identical,'R3R1 candidate endpoint neutrality')
          write(*,'(*(g0))') 'F_ROM0R_R3R1_NEUTRAL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
               '|STEP=',i,'|POLICY_TOL=',policy_tol,'|REP_BOUND=',rep_bound,'|IDENTICAL=T'
        else
          original_failed=.true.
          call require(expected_original_fail>0,'R3R1 unexpected original failure material')
          call require(i==expected_original_fail,'R3R1 original failure step reproduced')
          call require(osolver_status==SW_SOLVE_RETRY_ADVISED,'R3R1 original retry status reproduced')
          call require(trim(oroute)=='legacy-reference-retry','R3R1 original retry route reproduced')
          write(*,'(*(g0))') 'F_ROM0R_R3R1_ORIGINAL_FAIL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
               '|STEP=',i,'|NL=',onl,'|BACKTRACK=',oback,'|CAND_POLICY_TOL=',policy_tol,'|REP_BOUND=',rep_bound
        end if
      end if

      write(*,'(*(g0))') 'F_ROM0R_R3R1_CAND_STEP|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
           '|STEP=',i,'|T=',t1,'|POLICY_TOL=',policy_tol,'|REP_BOUND=',rep_bound,'|MASS=',cmass, &
           '|BOTTOM_EXCHANGE=',cbex,'|BOTTOM_FLUX=',cbflux,'|NL=',cnl
      t0=t1
    end do

    if(trim(material_id)=='B01') then
      call require(original_failed,'R3R1 B01 original failure reproduced')
      call require(original_passes==expected_original_fail-1,'R3R1 B01 accepted prefix count')
    else
      call require(.not.original_failed,'R3R1 B14 original full horizon remains accepted')
      call require(original_passes==perturb_intervals,'R3R1 B14 full neutrality count')
    end if

    call state_metrics(candidate_committed,total_storage,upper_storage,lower_storage,pond,gwl,bottom_head_state,policy_ok)
    call require(policy_ok,'R3R1 candidate final state metrics')
    write(*,'(*(g0))') 'F_ROM0R_R3R1_CASE_PASS|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|FINAL_STORAGE=',total_storage,'|UPPER_STORAGE=',upper_storage,'|LOWER_STORAGE=',lower_storage, &
         '|CUM_BOTTOM_OUTWARD_EXCHANGE=',cumulative_candidate_bottom,'|TERMINAL_BOTTOM_FLUX=',cbflux, &
         '|FINAL_BOTTOM_NODE_HEAD=',bottom_head_state,'|POND=',pond,'|GWL=',gwl, &
         '|MAX_ABS_MASS=',max_candidate_mass,'|FINAL_REV=',candidate_committed%current_revision(),'|FINAL_T=',t0, &
         '|ORIGINAL_PREFIX_PASSES=',original_passes
  end subroutine run_case

  subroutine representation_policy(parameters,committed,dt_day,rep_bound,policy_tol,ok)
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(kernel_committed_state_t),intent(in) :: committed
    real(real64),intent(in) :: dt_day
    real(real64),intent(out) :: rep_bound,policy_tol
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snapshot
    logical :: got
    rep_bound=0.0_real64; policy_tol=0.0_real64; ok=.false.
    if(dt_day<=0.0_real64)return
    call committed%snapshot(snapshot,got)
    if(.not.got)return
    select type(physical=>snapshot)
    type is(fmr_b110_physical_state_t)
      if(physical%active_nodes/=numnod)return
      if(.not.allocated(physical%water_content))return
      rep_bound=0.5_real64*sum((spacing(parameters%cofgen(2,1:numnod)) + &
           spacing(physical%water_content))*parameters%dz(1:numnod))
      policy_tol=max(original_total_rate_tol,rep_bound/dt_day)
      ok=ieee_is_finite(rep_bound).and.rep_bound>0.0_real64.and.ieee_is_finite(policy_tol).and. &
           policy_tol>=original_total_rate_tol
    class default
      ok=.false.
    end select
    if(allocated(snapshot))deallocate(snapshot)
  end subroutine representation_policy

  subroutine execute_sample(backend,column,template,parameters,committed,forcing,t0,t1,ok,mass_residual,bottom_exchange, &
                            terminal_bottom_flux,solver_status,solver_route,nonlinear_iterations,internal_retries,backtracking)
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(kernel_committed_state_t),intent(inout) :: committed
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1
    logical,intent(out) :: ok
    real(real64),intent(out) :: mass_residual,bottom_exchange,terminal_bottom_flux
    integer,intent(out) :: solver_status,nonlinear_iterations,internal_retries,backtracking
    character(len=*),intent(out) :: solver_route
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    logical :: did_commit
    integer :: commit_status

    mass_residual=huge(0.0_real64); bottom_exchange=0.0_real64; terminal_bottom_flux=0.0_real64
    solver_status=-999; nonlinear_iterations=0; internal_retries=0; backtracking=0; solver_route='not-run'
    call backend%run_reference_floor_sample(column,template,parameters,committed,forcing,t0,t1,hard_mass_gate, &
         result,candidate,diagnostics)
    observation=backend%observation()
    solver_status=observation%solver_status
    solver_route=trim(observation%solver_diagnostics%route)
    nonlinear_iterations=result%nonlinear_iterations
    internal_retries=result%internal_retries
    backtracking=result%backtracking_attempts
    ok=result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK.and.result%sample_valid.and.candidate%ready().and. &
       result%physical_advances==1.and.result%internal_retries==0.and.diagnostics%retries==0.and. &
       result%mass%complete.and.ieee_is_finite(result%mass%residual).and.abs(result%mass%residual)<=hard_mass_gate.and. &
       observation%solver_executed.and.observation%solver_status==SW_SOLVE_CONVERGED.and. &
       result%bottom_interface_exchange_available.and.ieee_is_finite(result%bottom_outward_exchange_native).and. &
       ieee_is_finite(result%terminal_bottom_outward_flux_native)
    if(.not.ok) then
      if(candidate%ready())call backend%discard_reference_floor_candidate(candidate,diagnostics)
      return
    end if
    mass_residual=result%mass%residual
    bottom_exchange=result%bottom_outward_exchange_native
    terminal_bottom_flux=result%terminal_bottom_outward_flux_native
    call backend%commit_reference_floor_candidate(committed,candidate,diagnostics,did_commit,commit_status)
    ok=did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED.and..not.candidate%ready()
  end subroutine execute_sample

  subroutine states_bit_equal(left,right,equal)
    type(kernel_committed_state_t),intent(in) :: left,right
    logical,intent(out) :: equal
    class(transaction_state_t),allocatable :: astate,bstate
    logical :: ga,gb
    equal=.false.
    call left%snapshot(astate,ga); call right%snapshot(bstate,gb)
    if(.not.ga.or..not.gb)return
    select type(a=>astate)
    type is(fmr_b110_physical_state_t)
      select type(b=>bstate)
      type is(fmr_b110_physical_state_t)
        equal=a%active_nodes==b%active_nodes.and.array_bits_equal(a%pressure_head,b%pressure_head).and. &
             array_bits_equal(a%water_content,b%water_content).and.same_bits(a%ponding_depth,b%ponding_depth).and. &
             same_bits(a%groundwater_level,b%groundwater_level)
      end select
    end select
    if(allocated(astate))deallocate(astate)
    if(allocated(bstate))deallocate(bstate)
  end subroutine states_bit_equal

  pure logical function array_bits_equal(a,b)
    real(real64),intent(in) :: a(:),b(:)
    integer :: i
    array_bits_equal=size(a)==size(b)
    if(.not.array_bits_equal)return
    do i=1,size(a)
      if(.not.same_bits(a(i),b(i)))then
        array_bits_equal=.false.; return
      end if
    end do
  end function array_bits_equal

  pure logical function same_bits(a,b)
    real(real64),intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib)
    same_bits=ia==ib
  end function same_bits

  subroutine state_metrics(committed,total_storage,upper_storage,lower_storage,pond,gwl,bottom_head_state,ok)
    type(kernel_committed_state_t),intent(in) :: committed
    real(real64),intent(out) :: total_storage,upper_storage,lower_storage,pond,gwl,bottom_head_state
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snapshot
    logical :: got
    integer :: upper_nodes
    ok=.false.; total_storage=0.0_real64; upper_storage=0.0_real64; lower_storage=0.0_real64
    pond=0.0_real64; gwl=0.0_real64; bottom_head_state=0.0_real64
    call committed%snapshot(snapshot,got)
    if(.not.got)return
    select type(physical=>snapshot)
    type is(fmr_b110_physical_state_t)
      if(physical%active_nodes/=numnod)return
      upper_nodes=4
      total_storage=sum(physical%water_content(1:numnod)*dz(1:numnod))
      upper_storage=sum(physical%water_content(1:upper_nodes)*dz(1:upper_nodes))
      lower_storage=sum(physical%water_content(upper_nodes+1:numnod)*dz(upper_nodes+1:numnod))
      pond=physical%ponding_depth; gwl=physical%groundwater_level
      bottom_head_state=physical%pressure_head(numnod)
      ok=ieee_is_finite(total_storage).and.ieee_is_finite(upper_storage).and.ieee_is_finite(lower_storage).and. &
         ieee_is_finite(pond).and.ieee_is_finite(gwl).and.ieee_is_finite(bottom_head_state)
    class default
      ok=.false.
    end select
    if(allocated(snapshot))deallocate(snapshot)
  end subroutine state_metrics

  subroutine initialize_parameters(material_id,p)
    character(len=*),intent(in) :: material_id
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    select case(trim(material_id))
    case('B01')
      tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64
      nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64
    case('B14')
      tr=0.01_real64;ts=0.416774_real64;alpha=0.00541_real64
      nn=1.301528_real64;ks=0.895023_real64;lam=-0.334926_real64
    case default
      call require(.false.,'R3R1 known material')
      tr=0.0_real64;ts=0.0_real64;alpha=0.0_real64;nn=2.0_real64;ks=0.0_real64;lam=0.0_real64
    end select
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=963201_int64;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=tr;p%cofgen(2,k)=ts;p%cofgen(3,k)=ks;p%cofgen(4,k)=alpha
      p%cofgen(5,k)=lam;p%cofgen(6,k)=nn;p%cofgen(7,k)=mm;p%cofgen(8,k)=alpha
      p%cofgen(9,k)=0.0_real64;p%cofgen(10,k)=ks;p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*ks;p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=2;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=1.0e-12_real64;p%total_balance_tolerance=original_total_rate_tol
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
    call bind_b110_default_mvg_provider(provider,hp,seed_dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    call require(k0>0.0_real64.and.all(ieee_is_finite(water)),'R3R1 finite seed')
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
    tmpl%template_id=963201_int64;tmpl%physics_topology_id=963202_int64
    tmpl%vertical_layout_id=963203_int64;tmpl%state_layout_id=963204_int64
    tmpl%solver_interface_id=963205_int64
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
      write(*,'(A,1X,A)') 'F_ROM0R_R3R1_STRUCTURAL_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_f_rom0r_r3r1_representation_policy
