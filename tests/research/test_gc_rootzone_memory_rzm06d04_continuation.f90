program test_gc_rootzone_memory_rzm06d04_continuation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_reference_floor_result_t, &
       kernel_reference_floor_candidate_t, kernel_diagnostics_t, KERNEL_REFERENCE_FLOOR_STATUS_OK
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: NCTRL=7, NDUR=5
  real(real64), parameter :: base_dt=3435974.0_real64/4294967296.0_real64
  real(real64), parameter :: duration_factor(NDUR)=[0.125_real64,0.25_real64,0.5_real64,1.0_real64,2.0_real64]
  real(real64), parameter :: mass_gate=1.0e-12_real64
  real(real64), parameter :: se0=0.85_real64
  integer(int64), parameter :: lineage_id=960640_int64

  type(fmr_b110_physical_state_t) :: origin_a,origin_b
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  real(real64) :: h0,k0,qeq
  character(len=1024) :: path_a,path_b
  integer :: ic,id

  if(numnod/=16) error stop 'D04 requires 16-node ROM geometry'
  call get_command_argument(1,path_a)
  call get_command_argument(2,path_b)
  if(len_trim(path_a)==0 .or. len_trim(path_b)==0) error stop 'D04 origin paths required'
  call require(all(abs(dz-10.0_real64)<=1.0e-14_real64),'D04 10-cm geometry')

  call read_origin(trim(path_a),origin_a)
  call read_origin(trim(path_b),origin_b)
  call material_constants(h0,k0,qeq)
  call initialize_identity(column,template)

  call emit_identity('A',origin_a)
  call emit_identity('B',origin_b)

  do ic=1,NCTRL
    do id=1,NDUR
      call sample_endpoint('A',origin_a,ic,id,base_dt*duration_factor(id),h0,k0,qeq,column,template)
      call sample_endpoint('B',origin_b,ic,id,base_dt*duration_factor(id),h0,k0,qeq,column,template)
    end do
  end do

  write(*,'(A)') 'GC_RZM06D04_LOCAL_CONTINUATION_MAP=PASS'

contains

  subroutine sample_endpoint(origin_label,origin,control_id,duration_id,duration,h0v,k0v,qeqv,col,tmpl)
    character(len=*),intent(in) :: origin_label
    type(fmr_b110_physical_state_t),intent(in) :: origin
    integer,intent(in) :: control_id,duration_id
    real(real64),intent(in) :: duration,h0v,k0v,qeqv
    type(fmr_logical_column_t),intent(in) :: col
    type(fmr_template_t),intent(in) :: tmpl
    type(fmr_b110_physical_parameters_t) :: p
    type(fmr_b110_physical_forcing_t) :: forcing
    type(kernel_committed_state_t) :: committed
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diag
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: top
    class(transaction_state_t),allocatable :: before,after,candidate_snap
    logical :: ok,available,accepted
    real(real64) :: ct0,ct1
    integer :: i

    call initialize_parameters(p)
    call configure_control(control_id,h0v,k0v,qeqv,p,forcing)
    call fmr_new_b110_committed_state(committed,lineage_id,origin,0.0_real64,ok)
    call require(ok.and.committed%ready(),'D04 committed origin')
    call committed%snapshot(before,available);call require(available,'D04 before snapshot')
    call backend%initialize(top)
    call backend%run_reference_floor_sample(col,tmpl,p,committed,forcing,0.0_real64,duration,mass_gate, &
         result,candidate,diag)
    call committed%snapshot(after,available);call require(available,'D04 after snapshot')
    call require(state_bits_equal(before,after),'D04 read-only committed origin')
    call require(committed%current_revision()==0_int64,'D04 revision immutable')
    accepted=result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK .and. result%sample_valid .and. candidate%ready() .and. &
         result%physical_advances==1 .and. result%internal_retries==0 .and. diag%retries==0 .and. &
         result%mass%complete .and. ieee_is_finite(result%mass%residual) .and. abs(result%mass%residual)<=mass_gate

    if(accepted)then
      call candidate%origin_interval(ct0,ct1,available)
      call require(available.and.same_bits(ct0,0.0_real64).and.same_bits(ct1,duration),'D04 candidate interval')
      call candidate%snapshot(candidate_snap,available);call require(available,'D04 candidate snapshot')
      select type(s=>candidate_snap)
      class is(fmr_b110_physical_state_t)
        call emit_endpoint(origin_label,control_id,duration_id,duration,s,result,diag)
      class default
        call require(.false.,'D04 B110 candidate type')
      end select
    else
      write(*,'(*(g0))') 'RZM06D04_REJECT|ORIGIN=',trim(origin_label),'|CONTROL=',trim(control_label(control_id)), &
           '|CRANK=',control_id,'|DIDX=',duration_id,'|DT=',duration,'|RESULT_STATUS=',result%status, &
           '|SAMPLE_VALID=',result%sample_valid,'|PHYSICAL_ADVANCES=',result%physical_advances, &
           '|TX_RETRIES=',diag%retries,'|SOLVER_REJECTIONS=',diag%solver_rejections, &
           '|MASS_REJECTIONS=',diag%mass_rejections,'|MASS_COMPLETE=',result%mass%complete, &
           '|MASS_RESIDUAL=',result%mass%residual,'|NL=',result%nonlinear_iterations, &
           '|BACKTRACK=',result%backtracking_attempts
    end if

    if(candidate%ready()) call backend%discard_reference_floor_candidate(candidate,diag)
    call committed%snapshot(after,available);call require(available,'D04 final snapshot')
    call require(state_bits_equal(before,after),'D04 discard origin immutable')
    if(allocated(before))deallocate(before)
    if(allocated(after))deallocate(after)
    if(allocated(candidate_snap))deallocate(candidate_snap)
  end subroutine sample_endpoint

  subroutine emit_identity(origin_label,state)
    character(len=*),intent(in) :: origin_label
    type(fmr_b110_physical_state_t),intent(in) :: state
    real(real64) :: w,m1,r30
    integer :: i
    call state_metrics(state,w,m1,r30)
    write(*,'(*(g0))') 'RZM06D04_ENDPOINT|ORIGIN=',trim(origin_label),'|CONTROL=IDENTITY|CRANK=0|DIDX=0|DT=0.0', &
         '|MASS=0.0|NL=0|BACKTRACK=0|W=',w,'|M1=',m1,'|ROOT30=',r30
    do i=1,numnod
      write(*,'(*(g0))') 'RZM06D04_NODE|ORIGIN=',trim(origin_label),'|CONTROL=IDENTITY|CRANK=0|DIDX=0|NODE=',i, &
           '|H=',state%pressure_head(i),'|THETA=',state%water_content(i)
    end do
  end subroutine emit_identity

  subroutine emit_endpoint(origin_label,control_id,duration_id,duration,state,result,diag)
    character(len=*),intent(in) :: origin_label
    integer,intent(in) :: control_id,duration_id
    real(real64),intent(in) :: duration
    type(fmr_b110_physical_state_t),intent(in) :: state
    type(kernel_reference_floor_result_t),intent(in) :: result
    type(kernel_diagnostics_t),intent(in) :: diag
    real(real64) :: w,m1,r30
    integer :: i
    call state_metrics(state,w,m1,r30)
    write(*,'(*(g0))') 'RZM06D04_ENDPOINT|ORIGIN=',trim(origin_label),'|CONTROL=',trim(control_label(control_id)), &
         '|CRANK=',control_id,'|DIDX=',duration_id,'|DT=',duration,'|MASS=',result%mass%residual, &
         '|NL=',result%nonlinear_iterations,'|BACKTRACK=',result%backtracking_attempts,'|TX_RETRIES=',diag%retries, &
         '|W=',w,'|M1=',m1,'|ROOT30=',r30
    do i=1,numnod
      write(*,'(*(g0))') 'RZM06D04_NODE|ORIGIN=',trim(origin_label),'|CONTROL=',trim(control_label(control_id)), &
           '|CRANK=',control_id,'|DIDX=',duration_id,'|NODE=',i,'|H=',state%pressure_head(i), &
           '|THETA=',state%water_content(i)
    end do
  end subroutine emit_endpoint

  subroutine state_metrics(state,w,m1,r30)
    type(fmr_b110_physical_state_t),intent(in) :: state
    real(real64),intent(out) :: w,m1,r30
    integer :: i
    real(real64) :: weighted
    w=0.0_real64;weighted=0.0_real64;r30=0.0_real64
    do i=1,numnod
      w=w+state%water_content(i)*dz(i)
      weighted=weighted+state%water_content(i)*dz(i)*z(i)
      if(i<=3)r30=r30+state%water_content(i)*dz(i)
    end do
    call require(w>0.0_real64.and.ieee_is_finite(w).and.ieee_is_finite(weighted),'D04 finite metrics')
    m1=weighted/w
  end subroutine state_metrics

  subroutine material_constants(h0v,k0v,qeqv)
    real(real64),intent(out) :: h0v,k0v,qeqv
    type(fmr_b110_physical_parameters_t) :: p
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: m,heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    call initialize_parameters(p)
    m=1.0_real64-1.0_real64/p%cofgen(6,1)
    h0v=-(se0**(-1.0_real64/m)-1.0_real64)**(1.0_real64/p%cofgen(6,1))/p%cofgen(4,1)
    heads=h0v
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,base_dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0v=conductivity(1)
    call require(k0v>0.0_real64.and.ieee_is_finite(k0v),'D04 finite K0')
    qeqv=-k0v
  end subroutine material_constants

  subroutine configure_control(control_id,h0v,k0v,qeqv,p,f)
    integer,intent(in) :: control_id
    real(real64),intent(in) :: h0v,k0v,qeqv
    type(fmr_b110_physical_parameters_t),intent(inout) :: p
    type(fmr_b110_physical_forcing_t),intent(out) :: f
    real(real64) :: qt
    qt=qeqv
    p%bottom_mode=2
    select case(control_id)
    case(1)
      qt=qeqv
    case(2)
      qt=qeqv+0.01_real64*k0v
    case(3)
      qt=qeqv-0.01_real64*k0v
    case(4)
      p%bottom_mode=5;qt=qeqv
    case(5)
      p%bottom_mode=5;qt=qeqv
    case(6)
      p%bottom_mode=5;qt=qeqv+0.01_real64*k0v
    case(7)
      p%bottom_mode=5;qt=qeqv-0.01_real64*k0v
    case default
      call require(.false.,'D04 control id')
    end select
    f%top_flux=qt;f%top_head=0.0_real64;f%bottom_flux=qeqv;f%bottom_head=h0v
    if(control_id==4.or.control_id==6)f%bottom_head=0.75_real64*h0v
    if(control_id==5.or.control_id==7)f%bottom_head=1.25_real64*h0v
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine configure_control

  pure function control_label(control_id) result(label)
    integer,intent(in) :: control_id
    character(len=24) :: label
    select case(control_id)
    case(1);label='HOLD'
    case(2);label='TOP_PLUS'
    case(3);label='TOP_MINUS'
    case(4);label='BOTTOM_HEAD_RISE'
    case(5);label='BOTTOM_HEAD_FALL'
    case(6);label='COMBINED_RISE_PLUS'
    case(7);label='COMBINED_FALL_MINUS'
    case default;label='UNKNOWN'
    end select
  end function control_label

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64
    nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=960640_int64;p%active_nodes=numnod
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
    p%compartment_balance_tolerance=mass_gate;p%total_balance_tolerance=mass_gate
    p%head_abs_tolerance=mass_gate;p%head_rel_tolerance=mass_gate;p%ponding_tolerance=mass_gate
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%ksatexm_extension_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.
    p%black_evaporation_active=.false.;p%boesten_evaporation_active=.false.
    p%drainage_response_active=.false.;p%drainage_qbot_smooth_freatic_projection=.false.
  end subroutine initialize_parameters

  subroutine initialize_identity(col,tmpl)
    type(fmr_logical_column_t),intent(out) :: col
    type(fmr_template_t),intent(out) :: tmpl
    tmpl%template_id=960640_int64;tmpl%physics_topology_id=960641_int64
    tmpl%vertical_layout_id=960642_int64;tmpl%state_layout_id=960643_int64
    tmpl%solver_interface_id=960644_int64
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
    call require(ios==0,'D04 open origin')
    do i=1,numnod
      read(unit,*,iostat=ios)node,hh,tt
      call require(ios==0.and.node==i,'D04 read origin node')
      call require(ieee_is_finite(hh).and.ieee_is_finite(tt),'D04 finite origin node')
      state%pressure_head(i)=hh;state%water_content(i)=tt
    end do
    close(unit)
    state%ponding_depth=0.0_real64
    state%groundwater_level=-999.0_real64
  end subroutine read_origin

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

  pure logical function same_bits(a,b) result(equal)
    real(real64),intent(in)::a,b
    integer(int64)::ia,ib
    ia=transfer(a,ia);ib=transfer(b,ib);equal=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'GC_RZM06D04_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_gc_rootzone_memory_rzm06d04_continuation
