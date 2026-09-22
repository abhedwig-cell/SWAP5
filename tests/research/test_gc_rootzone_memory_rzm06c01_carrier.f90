program test_gc_rootzone_memory_rzm06c01_carrier
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_canonical_contracts, only: canonical_forcing_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_reference_floor_result_t, &
       kernel_reference_floor_candidate_t, kernel_diagnostics_t, KERNEL_REFERENCE_FLOOR_STATUS_OK, &
       KERNEL_REFERENCE_FLOOR_STATUS_SOLVER_FAILED, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_groundwater_swap_forcing_adapter, only: GW_SWAP_FORCING_OK
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: dt=0.0008_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  real(real64), parameter :: bottom_elevation_m=-1.6_real64
  integer(int64), parameter :: lineage_id=960601_int64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: base_forcing,forcing
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_serialized_reference_backend_t) :: backend
  type(fixed_flux_top_boundary_provider_t),target :: top_boundary
  type(fmr_groundwater_head_forcing_materializer_t) :: materializer
  type(groundwater_head_datum_t) :: datum
  type(kernel_committed_state_t) :: committed
  type(kernel_reference_floor_result_t) :: result
  type(kernel_reference_floor_candidate_t) :: candidate
  type(kernel_diagnostics_t) :: diagnostics
  class(canonical_forcing_t),allocatable :: materialized
  class(transaction_state_t),allocatable :: before,after
  type(fmr_serialized_physical_observation_t) :: observation
  real(real64) :: h0,k0,qeq,hc_m,t
  integer :: status,commit_status,i,root_nodes
  logical :: ok,available,did_commit

  call require(numnod==16,'geometry node count')
  call require(all(abs(dz-10.0_real64)<=1.0e-14_real64),'geometry dz 10 cm')
  do i=1,numnod
    call require(abs(z(i)-(-10.0_real64*(real(i,real64)-0.5_real64)))<=1.0e-14_real64,'geometry z')
  end do
  root_nodes=count((z+0.5_real64*dz)<=0.0_real64 .and. (z-0.5_real64*dz)>=-30.0_real64)
  call require(root_nodes==3,'upper 30 cm spans exactly three full nodes')

  call initialize_parameters(parameters)
  call initialize_state(parameters,h0,k0,initial_state)
  qeq=-k0
  call initialize_forcing(base_forcing,qeq,qeq,h0)
  call initialize_identity(column,template)

  datum%available=.true.
  datum%datum_id=960602_int64
  datum%bottom_boundary_elevation_m=bottom_elevation_m
  hc_m=bottom_elevation_m+0.01_real64*h0

  call materializer%initialize(base_forcing)
  call require(materializer%profile_admitted(parameters),'mode5 profile admitted')
  call materializer%materialize(hc_m,datum,materialized,status)
  call require(status==GW_SWAP_FORCING_OK.and.allocated(materialized),'fixed head materialized')
  select type(m=>materialized)
  type is(fmr_b110_physical_forcing_t)
    forcing=m
  class default
    call require(.false.,'materialized forcing type')
  end select
  call require(abs(forcing%bottom_head-h0)<=1.0e-12_real64,'Hc maps to intended bottom pressure head')
  call require(abs(forcing%top_flux-qeq)<=1.0e-14_real64,'materializer preserves top flux')

  call fmr_new_b110_committed_state(committed,lineage_id,initial_state,0.0_real64,ok)
  call require(ok.and.committed%ready(),'committed seed')
  call backend%initialize(top_boundary)

  call committed%snapshot(before,available)
  call require(available,'before sample snapshot')
  call backend%run_reference_floor_sample(column,template,parameters,committed,forcing,0.0_real64,dt,hard_mass_gate, &
       result,candidate,diagnostics)
  observation=backend%observation()
  call require(result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK.and.result%sample_valid,'strict fixed-Hc sample valid')
  call require(candidate%ready(),'candidate ready')
  call require(result%physical_advances==1,'one physical advance')
  call require(result%internal_retries==0.and.diagnostics%retries==0,'zero retry/subdivision')
  call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'hard mass gate')
  call require(observation%solver_executed,'real solver executed')
  call require(result%bottom_interface_exchange_available,'bottom exchange available')
  call require(ieee_is_finite(result%bottom_outward_exchange_native),'finite bottom exchange')
  call committed%snapshot(after,available)
  call require(available.and.state_bits_equal(before,after),'sample leaves committed origin unchanged')
  call require(committed%current_revision()==0_int64,'sample revision unchanged')

  call backend%discard_reference_floor_candidate(candidate,diagnostics)
  call require(.not.candidate%ready(),'discard consumes candidate only')
  call committed%snapshot(after,available)
  call require(available.and.state_bits_equal(before,after),'discard leaves committed state unchanged')
  call require(committed%current_revision()==0_int64,'discard revision unchanged')

  ! Replay exactly, then commit explicitly.
  call backend%run_reference_floor_sample(column,template,parameters,committed,forcing,0.0_real64,dt,hard_mass_gate, &
       result,candidate,diagnostics)
  call require(result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK.and.candidate%ready(),'commit replay candidate')
  call backend%commit_reference_floor_candidate(committed,candidate,diagnostics,did_commit,commit_status)
  call require(did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED,'explicit commit')
  call require(committed%current_revision()==1_int64,'commit increments one revision')
  call committed%current_time(t,available)
  call require(available.and.abs(t-dt)<=1.0e-15_real64,'commit advances exact sample time')

  ! Controlled failure from a fresh origin must not mutate committed state.
  call qualify_fail_closed(parameters,base_forcing,initial_state,column,template,top_boundary,datum,h0)

  write(*,'(*(g0))') 'RZM06C01_CARRIER|N=',numnod,'|DZ_CM=',dz(1),'|ROOT_NODES=',root_nodes, &
       '|H0_CM=',h0,'|HC_M=',hc_m,'|DT_DAY=',dt,'|MASS_GATE_CM=',hard_mass_gate
  write(*,'(A)') 'GC_RZM06C01_16NODE_FIXED_HEAD_CARRIER=PASS'

contains

  subroutine qualify_fail_closed(base_parameters,base,origin,col,tmpl,top_ref,head_datum,h0_value)
    type(fmr_b110_physical_parameters_t),intent(in) :: base_parameters
    type(fmr_b110_physical_forcing_t),intent(in) :: base
    type(fmr_b110_physical_state_t),intent(in) :: origin
    type(fmr_logical_column_t),intent(in) :: col
    type(fmr_template_t),intent(in) :: tmpl
    type(fixed_flux_top_boundary_provider_t),target,intent(inout) :: top_ref
    type(groundwater_head_datum_t),intent(in) :: head_datum
    real(real64),intent(in) :: h0_value
    type(fmr_b110_physical_parameters_t) :: p
    type(fmr_b110_physical_forcing_t) :: f
    type(fmr_serialized_reference_backend_t) :: b
    type(fmr_groundwater_head_forcing_materializer_t) :: mat
    type(kernel_committed_state_t) :: c
    type(kernel_reference_floor_result_t) :: r
    type(kernel_reference_floor_candidate_t) :: cand
    type(kernel_diagnostics_t) :: diag
    class(canonical_forcing_t),allocatable :: mf
    class(transaction_state_t),allocatable :: s0,s1
    real(real64) :: fail_hc,t0,t1
    integer :: st
    integer(int64) :: rev0
    logical :: good,a0,a1,tok

    p=base_parameters
    p%max_iterations=1
    call mat%initialize(base)
    fail_hc=head_datum%bottom_boundary_elevation_m+0.01_real64*(0.75_real64*h0_value)
    call mat%materialize(fail_hc,head_datum,mf,st)
    call require(st==GW_SWAP_FORCING_OK,'failure forcing materialized')
    select type(x=>mf)
    type is(fmr_b110_physical_forcing_t)
      f=x
    class default
      call require(.false.,'failure forcing type')
    end select

    call fmr_new_b110_committed_state(c,lineage_id+1_int64,origin,0.0_real64,good)
    call require(good.and.c%ready(),'failure committed seed')
    call b%initialize(top_ref)
    rev0=c%current_revision()
    call c%current_time(t0,tok); call require(tok,'failure t0')
    call c%snapshot(s0,a0); call require(a0,'failure snapshot before')

    call b%run_reference_floor_sample(col,tmpl,p,c,f,0.0_real64,dt,hard_mass_gate,r,cand,diag)
    call require(r%status==KERNEL_REFERENCE_FLOOR_STATUS_SOLVER_FAILED,'controlled solver failure')
    call require(.not.r%sample_valid.and..not.cand%ready(),'failure has no candidate')
    call require(c%current_revision()==rev0,'failure revision immutable')
    call c%current_time(t1,tok); call require(tok.and.same_bits(t0,t1),'failure time immutable')
    call c%snapshot(s1,a1); call require(a1.and.state_bits_equal(s0,s1),'failure state immutable')
  end subroutine qualify_fail_closed

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64
    nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=960601_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=tr;p%cofgen(2,k)=ts;p%cofgen(3,k)=ks;p%cofgen(4,k)=alpha
      p%cofgen(5,k)=lam;p%cofgen(6,k)=nn;p%cofgen(7,k)=mm;p%cofgen(8,k)=alpha
      p%cofgen(9,k)=0.0_real64;p%cofgen(10,k)=ks;p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*ks;p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=5;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=hard_mass_gate;p%total_balance_tolerance=hard_mass_gate
    p%head_abs_tolerance=hard_mass_gate;p%head_rel_tolerance=hard_mass_gate;p%ponding_tolerance=hard_mass_gate
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%ksatexm_extension_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.
    p%drainage_response_active=.false.;p%drainage_qbot_smooth_freatic_projection=.false.
  end subroutine initialize_parameters

  subroutine initialize_state(p,h0_value,k0_value,state)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    real(real64),intent(out) :: h0_value,k0_value
    type(fmr_b110_physical_state_t),intent(out) :: state
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: m,heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    m=1.0_real64-1.0_real64/p%cofgen(6,1)
    h0_value=-(se0**(-1.0_real64/m)-1.0_real64)**(1.0_real64/p%cofgen(6,1))/p%cofgen(4,1)
    heads=h0_value
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0_value=conductivity(1)
    call require(k0_value>0.0_real64.and.all(ieee_is_finite(water)),'finite B01 seed')
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
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_identity(col,tmpl)
    type(fmr_logical_column_t),intent(out) :: col
    type(fmr_template_t),intent(out) :: tmpl
    tmpl%template_id=960601_int64;tmpl%physics_topology_id=960602_int64
    tmpl%vertical_layout_id=960603_int64;tmpl%state_layout_id=960604_int64
    tmpl%solver_interface_id=960605_int64
    tmpl%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    tmpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tmpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=lineage_id;col%template_id=tmpl%template_id;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_identity

  logical function state_bits_equal(left,right) result(equal)
    class(transaction_state_t),allocatable,intent(in) :: left,right
    integer :: j
    equal=.false.
    select type(a=>left)
    type is(fmr_b110_physical_state_t)
      select type(b=>right)
      type is(fmr_b110_physical_state_t)
        if(a%active_nodes/=b%active_nodes) return
        if(size(a%pressure_head)/=size(b%pressure_head).or.size(a%water_content)/=size(b%water_content)) return
        do j=1,size(a%pressure_head)
          if(.not.same_bits(a%pressure_head(j),b%pressure_head(j))) return
        end do
        do j=1,size(a%water_content)
          if(.not.same_bits(a%water_content(j),b%water_content(j))) return
        end do
        if(.not.same_bits(a%ponding_depth,b%ponding_depth)) return
        if(.not.same_bits(a%groundwater_level,b%groundwater_level)) return
        equal=.true.
      end select
    end select
  end function state_bits_equal

  pure logical function same_bits(a,b) result(equal)
    real(real64),intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia);ib=transfer(b,ib)
    equal=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'GC_RZM06C01_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_gc_rootzone_memory_rzm06c01_carrier
