program test_gc_rootzone_memory_rzm06e08_probe
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_canonical_contracts, only: canonical_forcing_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_reference_floor_result_t, &
       kernel_reference_floor_candidate_t, kernel_diagnostics_t, KERNEL_REFERENCE_FLOOR_STATUS_OK
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_groundwater_swap_forcing_adapter, only: GW_SWAP_FORCING_OK
  implicit none

  real(real64), parameter :: probe_dt=3435974.0_real64/4294967296.0_real64
  real(real64), parameter :: mass_gate=1.0e-12_real64
  real(real64), parameter :: hc_m=-1.8979370901690651_real64
  real(real64), parameter :: bottom_z_m=-1.6_real64
  real(real64), parameter :: expected_bottom_head_cm=-29.793709016906497_real64
  real(real64), parameter :: w_tol_cm=1.0e-9_real64
  real(real64), parameter :: root30_tol_cm=1.0e-9_real64
  real(real64), parameter :: h16_min_cm=1.0e-2_real64
  real(real64), parameter :: response_threshold_cm=1.0e-18_real64
  integer(int64), parameter :: lineage_id=960708_int64

  type :: probe_observation_t
    logical :: admitted=.false.
    integer :: result_status=-999
    logical :: sample_valid=.false.
    logical :: candidate_ready=.false.
    logical :: mass_complete=.false.
    logical :: exchange_available=.false.
    real(real64) :: mass_residual=0.0_real64
    real(real64) :: exchange=0.0_real64
    real(real64) :: terminal_flux=0.0_real64
    real(real64) :: accepted_dt=0.0_real64
    integer :: physical_advances=0
    integer :: internal_retries=0
    integer :: transaction_retries=0
    integer :: solver_rejections=0
    integer :: nonlinear_iterations=0
    integer :: backtracking_attempts=0
  end type probe_observation_t

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: base_forcing,forcing
  type(fmr_b110_physical_state_t) :: origin_a,origin_b
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_groundwater_head_forcing_materializer_t) :: materializer
  type(groundwater_head_datum_t) :: datum
  class(canonical_forcing_t),allocatable :: forcing_poly
  type(probe_observation_t) :: a1,b1,b2,a2
  character(len=1024) :: path_a,path_b
  real(real64) :: wa,wb,ua,ub,h16a,h16b,delta_exchange
  integer :: forcing_status
  logical :: support

  call require(numnod==16,'E08 geometry node count')
  call require(all(abs(dz-10.0_real64)<=1.0e-14_real64),'E08 geometry dz')
  call require(same_bits(probe_dt,3435974.0_real64/4294967296.0_real64),'E08 dyadic dt')

  call get_command_argument(1,path_a)
  call get_command_argument(2,path_b)
  call require(len_trim(path_a)>0.and.len_trim(path_b)>0,'E08 origin paths')

  call initialize_parameters(parameters)
  call read_origin(trim(path_a),origin_a)
  call read_origin(trim(path_b),origin_b)
  call state_observables(origin_a,wa,ua,h16a)
  call state_observables(origin_b,wb,ub,h16b)
  call require(abs(wb-wa)<=w_tol_cm,'E08 frozen profile-water gate')
  call require(abs(ub-ua)<=root30_tol_cm,'E08 frozen root30-water gate')
  call require(abs(h16b-h16a)>=h16_min_cm,'E08 frozen H16 gate')
  write(*,'(*(g0))') 'RZM06E08_RECON|WA=',wa,'|WB=',wb,'|ABS_DW=',abs(wb-wa), &
       '|UPPERA=',ua,'|UPPERB=',ub,'|ABS_DROOT=',abs(ub-ua), &
       '|H16A=',h16a,'|H16B=',h16b,'|ABS_DH16=',abs(h16b-h16a)

  call initialize_identity(column,template)
  call initialize_base_forcing(base_forcing)
  datum%available=.true.
  datum%datum_id=960708_int64
  datum%bottom_boundary_elevation_m=bottom_z_m
  call materializer%initialize(base_forcing)
  call require(materializer%profile_admitted(parameters),'E08 mode5 profile admitted')
  call materializer%materialize(hc_m,datum,forcing_poly,forcing_status)
  call require(forcing_status==GW_SWAP_FORCING_OK.and.allocated(forcing_poly),'E08 fixed Hc materialized')
  select type(f=>forcing_poly)
  type is(fmr_b110_physical_forcing_t)
    forcing=f
  class default
    call require(.false.,'E08 materialized forcing type')
  end select
  call require(same_bits(forcing%top_flux,0.0_real64),'E08 zero top flux')
  call require(abs(forcing%bottom_head-expected_bottom_head_cm)<=1.0e-12_real64,'E08 Hc pressure mapping')
  write(*,'(*(g0))') 'RZM06E08_FORCING|HC_M=',hc_m,'|BOTTOM_Z_M=',bottom_z_m, &
       '|BOTTOM_HEAD_CM=',forcing%bottom_head,'|TOP_FLUX=',forcing%top_flux,'|DT_DAY=',probe_dt

  ! Execute in both orders. Every call constructs a fresh committed origin and backend.
  call run_probe(origin_a,parameters,forcing,column,template,a1)
  call run_probe(origin_b,parameters,forcing,column,template,b1)
  call run_probe(origin_b,parameters,forcing,column,template,b2)
  call run_probe(origin_a,parameters,forcing,column,template,a2)

  call require(probe_same(a1,a2),'E08 A order independence')
  call require(probe_same(b1,b2),'E08 B order independence')
  write(*,'(A)') 'GC_RZM06E08_ORDER_INDEPENDENCE=PASS'

  if(a1%admitted.and.b1%admitted)then
    delta_exchange=b1%exchange-a1%exchange
    support=abs(delta_exchange)>response_threshold_cm
    write(*,'(*(g0))') 'RZM06E08_PROBE|ADMITTED_A=T|ADMITTED_B=T|A_STATUS=',a1%result_status, &
         '|B_STATUS=',b1%result_status,'|A_EXCHANGE=',a1%exchange,'|B_EXCHANGE=',b1%exchange, &
         '|DELTA_EXCHANGE=',delta_exchange,'|ABS_DELTA_EXCHANGE=',abs(delta_exchange), &
         '|THRESHOLD=',response_threshold_cm,'|A_TERMINAL_FLUX=',a1%terminal_flux, &
         '|B_TERMINAL_FLUX=',b1%terminal_flux,'|A_MASS=',a1%mass_residual,'|B_MASS=',b1%mass_residual, &
         '|SUPPORT=',support
  else
    write(*,'(*(g0))') 'RZM06E08_PROBE|ADMITTED_A=',a1%admitted,'|ADMITTED_B=',b1%admitted, &
         '|A_STATUS=',a1%result_status,'|B_STATUS=',b1%result_status, &
         '|A_SOLVER_REJECTIONS=',a1%solver_rejections,'|B_SOLVER_REJECTIONS=',b1%solver_rejections, &
         '|A_MASS_COMPLETE=',a1%mass_complete,'|B_MASS_COMPLETE=',b1%mass_complete
  end if

  write(*,'(A)') 'GC_RZM06E08_FIXED_HC_PROBE_EXECUTION=PASS'

contains

  subroutine run_probe(origin,p,f,col,tmpl,obs)
    type(fmr_b110_physical_state_t),intent(in) :: origin
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(fmr_b110_physical_forcing_t),intent(in) :: f
    type(fmr_logical_column_t),intent(in) :: col
    type(fmr_template_t),intent(in) :: tmpl
    type(probe_observation_t),intent(out) :: obs
    type(kernel_committed_state_t) :: committed
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: top
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diag
    class(transaction_state_t),allocatable :: before,after
    logical :: ok,available

    obs=probe_observation_t()
    call fmr_new_b110_committed_state(committed,lineage_id,origin,0.0_real64,ok)
    call require(ok.and.committed%ready(),'E08 fresh committed origin')
    call committed%snapshot(before,available)
    call require(available.and.snapshot_matches_state(before,origin),'E08 reconstructed committed state bit identity')

    call backend%initialize(top)
    call backend%run_reference_floor_sample(col,tmpl,p,committed,f,0.0_real64,probe_dt,mass_gate,result,candidate,diag)

    obs%result_status=result%status
    obs%sample_valid=result%sample_valid
    obs%candidate_ready=candidate%ready()
    obs%mass_complete=result%mass%complete
    obs%mass_residual=result%mass%residual
    obs%exchange_available=result%bottom_interface_exchange_available
    obs%exchange=result%bottom_outward_exchange_native
    obs%terminal_flux=result%terminal_bottom_outward_flux_native
    obs%accepted_dt=result%accepted_dt
    obs%physical_advances=result%physical_advances
    obs%internal_retries=result%internal_retries
    obs%transaction_retries=diag%retries
    obs%solver_rejections=diag%solver_rejections
    obs%nonlinear_iterations=result%nonlinear_iterations
    obs%backtracking_attempts=result%backtracking_attempts
    obs%admitted=result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK .and. result%sample_valid .and. candidate%ready() .and. &
         result%mass%complete .and. abs(result%mass%residual)<=mass_gate .and. result%physical_advances==1 .and. &
         result%internal_retries==0 .and. diag%retries==0 .and. result%bottom_interface_exchange_available .and. &
         ieee_is_finite(result%bottom_outward_exchange_native) .and. ieee_is_finite(result%terminal_bottom_outward_flux_native)

    call committed%snapshot(after,available)
    call require(available.and.state_bits_equal(before,after),'E08 read-only origin after probe')
    call require(committed%current_revision()==0_int64,'E08 probe does not commit')
    if(candidate%ready())then
      call backend%discard_reference_floor_candidate(candidate,diag)
      call require(.not.candidate%ready(),'E08 discard candidate')
    end if
  end subroutine run_probe

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64
    nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=960708_int64;p%active_nodes=numnod
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
    p%compartment_balance_tolerance=mass_gate;p%total_balance_tolerance=mass_gate
    p%head_abs_tolerance=mass_gate;p%head_rel_tolerance=mass_gate;p%ponding_tolerance=mass_gate
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%ksatexm_extension_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.
    p%black_evaporation_active=.false.;p%boesten_evaporation_active=.false.
    p%drainage_response_active=.false.;p%drainage_qbot_smooth_freatic_projection=.false.
  end subroutine initialize_parameters

  subroutine initialize_base_forcing(f)
    type(fmr_b110_physical_forcing_t),intent(out) :: f
    f%top_flux=0.0_real64;f%top_head=0.0_real64
    f%bottom_flux=0.0_real64;f%bottom_head=0.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_base_forcing

  subroutine initialize_identity(col,tmpl)
    type(fmr_logical_column_t),intent(out) :: col
    type(fmr_template_t),intent(out) :: tmpl
    tmpl%template_id=960708_int64;tmpl%physics_topology_id=960703_int64
    tmpl%vertical_layout_id=960708_int64;tmpl%state_layout_id=960705_int64
    tmpl%solver_interface_id=960708_int64
    tmpl%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    tmpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tmpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=lineage_id;col%template_id=tmpl%template_id;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_identity

  subroutine read_origin(path,state)
    character(len=*),intent(in) :: path
    type(fmr_b110_physical_state_t),intent(out) :: state
    integer :: unit,ios,i,node
    real(real64) :: hh,tt
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    open(newunit=unit,file=path,status='old',action='read',iostat=ios)
    call require(ios==0,'E08 open origin')
    do i=1,numnod
      read(unit,*,iostat=ios) node,hh,tt
      call require(ios==0.and.node==i,'E08 read origin node')
      call require(ieee_is_finite(hh).and.ieee_is_finite(tt),'E08 finite origin')
      state%pressure_head(i)=hh
      state%water_content(i)=tt
    end do
    close(unit)
    state%ponding_depth=0.0_real64
    state%groundwater_level=-999.0_real64
  end subroutine read_origin

  subroutine state_observables(state,w,upper,h16)
    type(fmr_b110_physical_state_t),intent(in) :: state
    real(real64),intent(out) :: w,upper,h16
    integer :: i
    w=0.0_real64;upper=0.0_real64
    do i=1,numnod
      w=w+state%water_content(i)*dz(i)
      if(i<=3)upper=upper+state%water_content(i)*dz(i)
    end do
    call require(w>0.0_real64,'E08 positive storage')
    h16=state%pressure_head(numnod)
  end subroutine state_observables

  logical function snapshot_matches_state(snapshot,state) result(equal)
    class(transaction_state_t),allocatable,intent(in) :: snapshot
    type(fmr_b110_physical_state_t),intent(in) :: state
    integer :: i
    equal=.false.
    if(.not.allocated(snapshot))return
    select type(s=>snapshot)
    class is(fmr_b110_physical_state_t)
      if(s%active_nodes/=state%active_nodes)return
      do i=1,state%active_nodes
        if(.not.same_bits(s%pressure_head(i),state%pressure_head(i)))return
        if(.not.same_bits(s%water_content(i),state%water_content(i)))return
      end do
      if(.not.same_bits(s%ponding_depth,state%ponding_depth))return
      if(.not.same_bits(s%groundwater_level,state%groundwater_level))return
      equal=.true.
    end select
  end function snapshot_matches_state

  logical function state_bits_equal(left,right) result(equal)
    class(transaction_state_t),allocatable,intent(in) :: left,right
    integer :: i
    equal=.false.
    if(.not.allocated(left).or..not.allocated(right))return
    select type(a=>left)
    class is(fmr_b110_physical_state_t)
      select type(b=>right)
      class is(fmr_b110_physical_state_t)
        if(a%active_nodes/=b%active_nodes)return
        do i=1,a%active_nodes
          if(.not.same_bits(a%pressure_head(i),b%pressure_head(i)))return
          if(.not.same_bits(a%water_content(i),b%water_content(i)))return
        end do
        if(.not.same_bits(a%ponding_depth,b%ponding_depth))return
        if(.not.same_bits(a%groundwater_level,b%groundwater_level))return
        equal=.true.
      end select
    end select
  end function state_bits_equal

  logical function probe_same(a,b) result(equal)
    type(probe_observation_t),intent(in) :: a,b
    equal=a%admitted.eqv.b%admitted
    equal=equal.and.a%result_status==b%result_status
    equal=equal.and.(a%sample_valid.eqv.b%sample_valid)
    equal=equal.and.(a%candidate_ready.eqv.b%candidate_ready)
    equal=equal.and.(a%mass_complete.eqv.b%mass_complete)
    equal=equal.and.(a%exchange_available.eqv.b%exchange_available)
    equal=equal.and.same_bits(a%mass_residual,b%mass_residual)
    equal=equal.and.same_bits(a%exchange,b%exchange)
    equal=equal.and.same_bits(a%terminal_flux,b%terminal_flux)
    equal=equal.and.same_bits(a%accepted_dt,b%accepted_dt)
    equal=equal.and.a%physical_advances==b%physical_advances
    equal=equal.and.a%internal_retries==b%internal_retries
    equal=equal.and.a%transaction_retries==b%transaction_retries
    equal=equal.and.a%solver_rejections==b%solver_rejections
    equal=equal.and.a%nonlinear_iterations==b%nonlinear_iterations
    equal=equal.and.a%backtracking_attempts==b%backtracking_attempts
  end function probe_same

  pure logical function same_bits(a,b) result(equal)
    real(real64),intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia);ib=transfer(b,ib)
    equal=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition)then
      write(*,'(A,1X,A)') 'GC_RZM06E08_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_gc_rootzone_memory_rzm06e08_probe
