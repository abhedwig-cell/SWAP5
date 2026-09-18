program test_pub_gc_native_time
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_temporal_indicator_state_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_pub_gc_macro_window_response, only: pub_gc_macro_window_response_t, pub_gc_run_macro_window_response, &
       PUB_GC_MACRO_OK
  implicit none

  integer, parameter :: ncase=5, nlevel=4
  real(real64), parameter :: initial_time_day=4200.125_real64
  real(real64), parameter :: initial_head_cm=-80.0_real64
  real(real64), parameter :: macro_duration_day=0.04_real64
  real(real64), parameter :: hard_mass_gate=1.0e-10_real64
  real(real64), parameter :: temporal_budget=100.0_real64
  real(real64), parameter :: tol_q=1.0e-4_real64
  real(real64), parameter :: tol_head=1.0e-2_real64
  real(real64), parameter :: tol_water=1.0e-5_real64
  real(real64), parameter :: tol_storage=1.0e-4_real64
  integer(int64), parameter :: origin_lineage=951001_int64
  integer, parameter :: interval_count(nlevel)=[4,8,16,32]
  real(real64), parameter :: native_dt(nlevel)=[0.01_real64,0.005_real64,0.0025_real64,0.00125_real64]

  type level_result_t
    logical :: completed=.false.
    integer :: status=-999
    real(real64) :: q_whole_cm=0.0_real64
    real(real64), allocatable :: pressure_head(:)
    real(real64), allocatable :: water_content(:)
    real(real64) :: storage_cm=0.0_real64
    integer :: retries=0
    integer :: substeps=0
  end type level_result_t

  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_b110_physical_forcing_t) :: base_forcing
  type(fmr_serialized_reference_backend_t) :: backend
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: origin
  type(level_result_t) :: r(ncase,nlevel)
  real(real64) :: predecessor(numnod), conductivity_reference
  real(real64) :: factors(4), bottom_head
  character(len=12) :: case_id
  character(len=48) :: selection
  logical :: ok, all_valid, fine_guard, level_ok
  integer :: ic, il

  call configure_column(column,template)
  call configure_transaction(config)
  call configure_case(parameters,initial_state,base_forcing,initial_head_cm,0.005_real64,conductivity_reference)
  call backend%initialize(top_provider)
  predecessor=0.0_real64
  call fmr_new_b110_temporal_indicator_committed_state(origin,origin_lineage,initial_state,initial_time_day,ok,predecessor)
  call require(ok .and. origin%ready(),'initial committed state')

  all_valid=.true.
  do ic=1,ncase
    call case_definition(ic,case_id,bottom_head,factors)
    do il=1,nlevel
      call execute_level(ic,il,case_id,bottom_head,factors,r(ic,il))
      if(.not.r(ic,il)%completed) all_valid=.false.
      call print_level(case_id,il,r(ic,il))
    end do
  end do

  fine_guard=all_valid
  if(fine_guard) then
    do ic=1,ncase
      call compare_levels(r(ic,3),r(ic,4),level_ok,'FINE',ic)
      fine_guard=fine_guard .and. level_ok
    end do
  end if

  if(.not.all_valid) then
    selection='NO_POLICY_SELECTED'
  else if(.not.fine_guard) then
    selection='NO_POLICY_SELECTED_FINE_LEVEL_UNSTABLE'
  else
    selection='NO_POLICY_SELECTED'
    do il=1,3
      level_ok=.true.
      do ic=1,ncase
        call compare_levels(r(ic,il),r(ic,4),ok,'SELECT',ic)
        level_ok=level_ok .and. ok
      end do
      if(level_ok) then
        select case(il)
        case(1); selection='SELECT_N0_0P01000_DAY'
        case(2); selection='SELECT_N1_0P00500_DAY'
        case(3); selection='SELECT_N2_0P00250_DAY'
        end select
        exit
      end if
    end do
  end if

  write(*,'(a,l1)') 'PUB_GC_NATIVE_ALL_TRAJECTORIES_VALID=',all_valid
  write(*,'(a,l1)') 'PUB_GC_NATIVE_FINE_LEVEL_GUARD=',fine_guard
  write(*,'(a,a)') 'PUB_GC_NATIVE_POLICY_SELECTION=',trim(selection)
  write(*,'(a)') 'PUB_GC_NATIVE_TERMINAL_MISMATCH_USED_FOR_SELECTION=false'
  write(*,'(a)') 'PUB_GC_NATIVE_PRIMARY_H2_H3_ELIGIBLE=false'
  write(*,'(a)') 'PUB_GC_NATIVE_TIME_EXECUTION_COMPLETE=PASS'

contains

  subroutine execute_level(case_index,level_index,id,bottom,four_factors,out)
    integer,intent(in)::case_index,level_index
    character(len=*),intent(in)::id
    real(real64),intent(in)::bottom,four_factors(4)
    type(level_result_t),intent(out)::out
    type(pub_gc_macro_window_response_t)::response
    type(fmr_b110_physical_forcing_t),allocatable::forcings(:)
    real(real64),allocatable::dt(:),f(:)
    integer::i,per_segment,status
    integer(int64)::lineage

    out=level_result_t()
    allocate(dt(interval_count(level_index)),f(interval_count(level_index)))
    dt=native_dt(level_index)
    per_segment=interval_count(level_index)/4
    do i=1,size(f)
      f(i)=four_factors(1+(i-1)/per_segment)
    end do
    call build_forcings(f,conductivity_reference,forcings)
    lineage=960000_int64+int(case_index*100+level_index,int64)
    call pub_gc_run_macro_window_response(column,template,parameters,backend,config,origin,forcings,dt, &
         initial_time_day,initial_time_day+macro_duration_day,bottom,lineage,response,status)
    out%status=status
    if(status/=PUB_GC_MACRO_OK .or. .not.response%completed) return
    if(.not.allocated(response%endpoint_state)) return
    out%completed=.true.
    out%q_whole_cm=response%q_whole_cm
    out%retries=sum(response%transaction_retries)
    out%substeps=sum(response%accepted_substeps)
    call extract_endpoint(response%endpoint_state,out%pressure_head,out%water_content,out%storage_cm,ok)
    if(.not.ok) out%completed=.false.
    if(.not.ieee_is_finite(out%q_whole_cm) .or. .not.ieee_is_finite(out%storage_cm)) out%completed=.false.
  end subroutine execute_level

  subroutine extract_endpoint(state,head,water,storage,available)
    class(transaction_state_t),allocatable,intent(in)::state
    real(real64),allocatable,intent(out)::head(:),water(:)
    real(real64),intent(out)::storage
    logical,intent(out)::available
    available=.false.; storage=0.0_real64
    if(.not.allocated(state)) return
    select type(s=>state)
    type is(fmr_b110_temporal_indicator_state_t)
      allocate(head(size(s%pressure_head)),water(size(s%water_content)))
      head=s%pressure_head; water=s%water_content
    type is(fmr_b110_physical_state_t)
      allocate(head(size(s%pressure_head)),water(size(s%water_content)))
      head=s%pressure_head; water=s%water_content
    class default
      return
    end select
    if(size(water)>numnod) return
    storage=sum(water*dz(1:size(water)))
    available=all(ieee_is_finite(head)) .and. all(ieee_is_finite(water)) .and. ieee_is_finite(storage)
  end subroutine extract_endpoint

  subroutine compare_levels(a,b,pass,label,case_index)
    type(level_result_t),intent(in)::a,b
    logical,intent(out)::pass
    character(len=*),intent(in)::label
    integer,intent(in)::case_index
    real(real64)::dq,dh,dw,ds
    pass=.false.
    if(.not.a%completed .or. .not.b%completed) then
      write(*,'(a,a,a,i0,a)') 'PUB_GC_NATIVE_COMPARE_',trim(label),'_CASE=',case_index,'=INVALID'
      return
    end if
    if(.not.allocated(a%pressure_head) .or. .not.allocated(b%pressure_head)) return
    if(size(a%pressure_head)/=size(b%pressure_head) .or. size(a%water_content)/=size(b%water_content)) return
    dq=abs(a%q_whole_cm-b%q_whole_cm)
    dh=maxval(abs(a%pressure_head-b%pressure_head))
    dw=maxval(abs(a%water_content-b%water_content))
    ds=abs(a%storage_cm-b%storage_cm)
    pass=dq<=tol_q .and. dh<=tol_head .and. dw<=tol_water .and. ds<=tol_storage
    write(*,'(a,a,a,i0,a,4(es26.17e3,1x),a,l1)') 'PUB_GC_NATIVE_COMPARE_',trim(label),'_CASE=',case_index, &
         ' METRICS=',dq,dh,dw,ds,' PASS=',pass
  end subroutine compare_levels

  subroutine print_level(id,level_index,out)
    character(len=*),intent(in)::id
    integer,intent(in)::level_index
    type(level_result_t),intent(in)::out
    if(out%completed) then
      write(*,'(a,a,a,i0,a,es26.17e3,a,es26.17e3,a,es26.17e3,a,i0,a,i0)') &
           'PUB_GC_NATIVE_LEVEL CASE=',trim(id),' LEVEL=',level_index-1,' DT=',native_dt(level_index), &
           ' Q=',out%q_whole_cm,' STORAGE=',out%storage_cm,' RETRIES=',out%retries,' SUBSTEPS=',out%substeps
    else
      write(*,'(a,a,a,i0,a,i0)') 'PUB_GC_NATIVE_LEVEL CASE=',trim(id),' LEVEL=',level_index-1,' STATUS=',out%status
    end if
  end subroutine print_level

  subroutine case_definition(index,id,bottom,four_factors)
    integer,intent(in)::index
    character(len=*),intent(out)::id
    real(real64),intent(out)::bottom,four_factors(4)
    select case(index)
    case(1)
      id='NT-C0'; bottom=-80.0_real64; four_factors=[-1.0_real64,-1.0_real64,-1.0_real64,-1.0_real64]
    case(2)
      id='NT-W3'; bottom=-80.0_real64; four_factors=[-3.0_real64,-1.0_real64,-1.0_real64,-1.0_real64]
    case(3)
      id='NT-D05'; bottom=-80.0_real64; four_factors=[0.5_real64,-1.0_real64,-1.0_real64,-1.0_real64]
    case(4)
      id='NT-R3'; bottom=-80.0_real64; four_factors=[-3.0_real64,0.5_real64,-1.0_real64,-1.0_real64]
    case(5)
      id='NT-H60'; bottom=-60.0_real64; four_factors=[-1.0_real64,-1.0_real64,-1.0_real64,-1.0_real64]
    case default
      call require(.false.,'unknown case')
    end select
  end subroutine case_definition

  subroutine build_forcings(factors,k0,forcings)
    real(real64),intent(in)::factors(:),k0
    type(fmr_b110_physical_forcing_t),allocatable,intent(out)::forcings(:)
    integer::i
    allocate(forcings(size(factors)))
    do i=1,size(factors)
      forcings(i)=base_forcing
      forcings(i)%top_flux=factors(i)*k0
    end do
  end subroutine build_forcings

  subroutine configure_column(c,tpl)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::tpl
    tpl%template_id=9101_int64
    tpl%physics_topology_id=910101_int64
    tpl%vertical_layout_id=910102_int64
    tpl%state_layout_id=910103_int64
    tpl%solver_interface_id=910104_int64
    tpl%optional_state_layout_id=0_int64
    tpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    tpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=origin_lineage
    c%template_id=tpl%template_id
    c%parameter_ref=1_int64
    c%state_handle=1_int64
    c%forcing_handle=1_int64
    c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t),intent(out)::cfg
    cfg%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    cfg%transaction%temporal_tolerance=0.0_real64
    cfg%transaction%mass_tolerance=hard_mass_gate
    cfg%transaction%retry_scale=0.5_real64
    cfg%transaction%max_retries=4
    cfg%max_committed_substeps=64
    cfg%progress_tolerance=0.0_real64
    cfg%model_temporal_indicator_budget_available=.true.
    cfg%model_temporal_indicator_budget=temporal_budget
  end subroutine configure_transaction

  subroutine configure_case(p,state,forcing,head,dt,kref)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    type(fmr_b110_physical_state_t),intent(out)::state
    type(fmr_b110_physical_forcing_t),intent(out)::forcing
    real(real64),intent(in)::head,dt
    real(real64),intent(out)::kref
    real(real64)::heads(numnod),conductivity(numnod)
    integer::k
    call configure_base_parameters(p)
    heads=head
    call evaluate_state(p,heads,state,conductivity,dt)
    kref=conductivity(1)
    do k=2,numnod
      call require(same_bits(conductivity(k),kref),'uniform conductivity fixture')
    end do
    forcing%top_flux=-kref
    forcing%top_head=head
    forcing%bottom_flux=12345.0_real64
    forcing%bottom_head=head
    call allocate_zero_forcing(forcing)
  end subroutine configure_case

  subroutine configure_base_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k
    p%parameter_set_id=910101_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=5; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
    p%max_iterations=12; p%max_backtracking=8; p%min_step_duration=1.0e-7_real64
    p%compartment_balance_tolerance=hard_mass_gate; p%total_balance_tolerance=hard_mass_gate
    p%head_abs_tolerance=1.0e-10_real64; p%head_rel_tolerance=1.0e-10_real64; p%ponding_tolerance=1.0e-10_real64
  end subroutine configure_base_parameters

  subroutine evaluate_state(p,heads,state,conductivity,dt)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(in)::heads(:),dt
    type(fmr_b110_physical_state_t),intent(out)::state
    real(real64),intent(out)::conductivity(:)
    type(b110_default_mvg_parameters_t),target::hydraulic_parameters
    type(b110_default_mvg_provider_t)::constitutive
    real(real64)::water(numnod),capacity(numnod),dkdh(numnod)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
  end subroutine evaluate_state

  subroutine allocate_zero_forcing(f)
    type(fmr_b110_physical_forcing_t),intent(inout)::f
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine allocate_zero_forcing

  pure logical function same_bits(a,b) result(equal)
    real(real64),intent(in)::a,b
    equal=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(a)') 'PUB_GC_NATIVE_INFRA_FAIL='//trim(label)
      error stop 7
    end if
  end subroutine require
end program test_pub_gc_native_time
