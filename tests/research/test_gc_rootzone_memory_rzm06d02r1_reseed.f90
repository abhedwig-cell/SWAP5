program test_gc_rootzone_memory_rzm06d02r1_reseed
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
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: dt=3435974.0_real64/4294967296.0_real64
  real(real64), parameter :: mass_gate=1.0e-12_real64
  real(real64), parameter :: bottom_head_cm=-29.793709016906497_real64
  real(real64), parameter :: t_a=0.0_real64, t_b=7.0_real64
  integer(int64), parameter :: lineage_id=960620_int64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_b110_physical_state_t) :: origin
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(kernel_reference_floor_result_t) :: result_a,result_b
  type(kernel_diagnostics_t) :: diag_a,diag_b
  class(transaction_state_t),allocatable :: candidate_a,candidate_b
  character(len=1024) :: input_path

  if(numnod/=16)error stop 'D02 requires 16-node ROM geometry'
  call get_command_argument(1,input_path)
  if(len_trim(input_path)==0)error stop 'D02 audit-state path required'

  call require(same_bits((t_a+dt)-t_a,dt),'A binary duration exact')
  call require(same_bits((t_b+dt)-t_b,dt),'B binary duration exact')
  call require(same_bits((t_a+dt)-t_a,(t_b+dt)-t_b),'A/B binary durations identical')

  call initialize_parameters(parameters)
  call read_origin(trim(input_path),origin)
  call initialize_forcing(forcing)
  call initialize_identity(column,template)

  call run_probe(t_a,parameters,forcing,origin,column,template,result_a,diag_a,candidate_a)
  call run_probe(t_b,parameters,forcing,origin,column,template,result_b,diag_b,candidate_b)

  call require(result_a%status==KERNEL_REFERENCE_FLOOR_STATUS_OK .and. result_a%sample_valid,'A sample valid')
  call require(result_b%status==KERNEL_REFERENCE_FLOOR_STATUS_OK .and. result_b%sample_valid,'B sample valid')
  call require(result_a%physical_advances==1 .and. result_b%physical_advances==1,'one physical advance')
  call require(result_a%internal_retries==0 .and. result_b%internal_retries==0,'zero automatic retries')
  call require(result_a%mass%complete .and. result_b%mass%complete,'mass complete')
  call require(abs(result_a%mass%residual)<=mass_gate .and. abs(result_b%mass%residual)<=mass_gate,'mass gate')
  call emit_time_alias_diagnostic(result_a,result_b,candidate_a,candidate_b)
  call require(state_bits_equal(candidate_a,candidate_b),'candidate physical state time neutral')
  call require(same_bits(result_a%accepted_dt,result_b%accepted_dt),'accepted dt')
  call require(result_a%physical_advances==result_b%physical_advances,'advance count')
  call require(result_a%nonlinear_iterations==result_b%nonlinear_iterations,'nonlinear iterations')
  call require(result_a%internal_retries==result_b%internal_retries,'internal retries')
  call require(result_a%headcalc_calls==result_b%headcalc_calls,'headcalc calls')
  call require(result_a%jacobian_builds==result_b%jacobian_builds,'jacobian builds')
  call require(result_a%linear_solves==result_b%linear_solves,'linear solves')
  call require(result_a%backtracking_attempts==result_b%backtracking_attempts,'backtracking')
  call require(result_a%alternative_solver_calls==result_b%alternative_solver_calls,'alternative solver calls')
  call require(result_a%bottom_interface_exchange_available .eqv. result_b%bottom_interface_exchange_available,'exchange availability')
  call require(same_bits(result_a%bottom_outward_exchange_native,result_b%bottom_outward_exchange_native),'bottom exchange')
  call require(same_bits(result_a%terminal_bottom_outward_flux_native,result_b%terminal_bottom_outward_flux_native),'terminal bottom flux')
  call compare_mass(result_a,result_b)
  call compare_diagnostics(diag_a,diag_b)

  write(*,'(*(g0))') 'RZM06D02R1_RESEED|TA=',t_a,'|TB=',t_b,'|DT=',dt, &
       '|BOTTOM_EXCHANGE=',result_a%bottom_outward_exchange_native, &
       '|TERMINAL_FLUX=',result_a%terminal_bottom_outward_flux_native, &
       '|MASS_RESIDUAL=',result_a%mass%residual
  write(*,'(A)') 'GC_RZM06D02R1_COMMON_TIME_RESEED=PASS'

contains

  subroutine emit_time_alias_diagnostic(a,b,sa,sb)
    type(kernel_reference_floor_result_t),intent(in) :: a,b
    class(transaction_state_t),allocatable,intent(in) :: sa,sb
    real(real64) :: dh,dtheta,dpond,dgwl
    dh=huge(0.0_real64);dtheta=huge(0.0_real64);dpond=huge(0.0_real64);dgwl=huge(0.0_real64)
    select type(x=>sa)
    class is(fmr_b110_physical_state_t)
      select type(y=>sb)
      class is(fmr_b110_physical_state_t)
        dh=maxval(abs(x%pressure_head-y%pressure_head))
        dtheta=maxval(abs(x%water_content-y%water_content))
        dpond=abs(x%ponding_depth-y%ponding_depth)
        dgwl=abs(x%groundwater_level-y%groundwater_level)
      end select
    end select
    write(*,'(*(g0))') 'RZM06D02R1_ALIAS_DIAG|DT_A=',a%accepted_dt,'|DT_B=',b%accepted_dt, &
         '|DT_BITS_A=',transfer(a%accepted_dt,0_int64),'|DT_BITS_B=',transfer(b%accepted_dt,0_int64), &
         '|MAX_DH=',dh,'|MAX_DTHETA=',dtheta,'|DPOND=',dpond,'|DGWL=',dgwl, &
         '|DEX=',b%bottom_outward_exchange_native-a%bottom_outward_exchange_native, &
         '|DFLUX=',b%terminal_bottom_outward_flux_native-a%terminal_bottom_outward_flux_native
  end subroutine emit_time_alias_diagnostic

  subroutine run_probe(t0,p,f,physical,col,tmpl,result,diag,candidate_snapshot)
    real(real64),intent(in) :: t0
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(fmr_b110_physical_forcing_t),intent(in) :: f
    type(fmr_b110_physical_state_t),intent(in) :: physical
    type(fmr_logical_column_t),intent(in) :: col
    type(fmr_template_t),intent(in) :: tmpl
    type(kernel_reference_floor_result_t),intent(out) :: result
    type(kernel_diagnostics_t),intent(out) :: diag
    class(transaction_state_t),allocatable,intent(out) :: candidate_snapshot
    type(kernel_committed_state_t) :: committed
    type(kernel_reference_floor_candidate_t) :: candidate
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: top
    class(transaction_state_t),allocatable :: before,after
    logical :: ok,available
    real(real64) :: ct0,ct1
    integer :: discard_status_dummy

    call fmr_new_b110_committed_state(committed,lineage_id,physical,t0,ok)
    call require(ok.and.committed%ready(),'seed committed')
    call committed%snapshot(before,available); call require(available,'snapshot before')
    call backend%initialize(top)
    call backend%run_reference_floor_sample(col,tmpl,p,committed,f,t0,t0+dt,mass_gate,result,candidate,diag)
    call require(result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK .and. result%sample_valid,'strict sample')
    call require(candidate%ready(),'candidate ready')
    call candidate%origin_interval(ct0,ct1,available)
    call require(available.and.same_bits(ct0,t0).and.same_bits(ct1,t0+dt),'candidate interval provenance')
    call candidate%snapshot(candidate_snapshot,available); call require(available,'candidate snapshot')
    call committed%snapshot(after,available); call require(available,'snapshot after')
    call require(state_bits_equal(before,after),'read-only committed origin')
    call backend%discard_reference_floor_candidate(candidate,diag)
    call require(.not.candidate%ready(),'discard consumes candidate')
  end subroutine run_probe

  subroutine compare_mass(a,b)
    type(kernel_reference_floor_result_t),intent(in) :: a,b
    call require(a%mass%complete .eqv. b%mass%complete,'mass complete identity')
    call require(a%mass%missing_contribution_mask==b%mass%missing_contribution_mask,'mass missing mask')
    call require(same_bits(a%mass%storage_start,b%mass%storage_start),'storage start')
    call require(same_bits(a%mass%storage_end,b%mass%storage_end),'storage end')
    call require(same_bits(a%mass%storage_change,b%mass%storage_change),'storage change')
    call require(same_bits(a%mass%total_in,b%mass%total_in),'total in')
    call require(same_bits(a%mass%total_out,b%mass%total_out),'total out')
    call require(same_bits(a%mass%residual,b%mass%residual),'mass residual')
  end subroutine compare_mass

  subroutine compare_diagnostics(a,b)
    type(kernel_diagnostics_t),intent(in) :: a,b
    call require(a%transaction_calls==b%transaction_calls,'diag transaction calls')
    call require(a%accepted_substeps==b%accepted_substeps,'diag accepted substeps')
    call require(a%attempts==b%attempts,'diag attempts')
    call require(a%retries==b%retries,'diag retries')
    call require(a%solver_rejections==b%solver_rejections,'diag solver rejects')
    call require(a%mass_rejections==b%mass_rejections,'diag mass rejects')
    call require(a%nonlinear_iterations==b%nonlinear_iterations,'diag nonlinear')
    call require(a%internal_retries==b%internal_retries,'diag internal retries')
    call require(a%headcalc_calls==b%headcalc_calls,'diag headcalc')
    call require(a%jacobian_builds==b%jacobian_builds,'diag jacobian')
    call require(a%linear_solves==b%linear_solves,'diag linear')
    call require(a%backtracking_attempts==b%backtracking_attempts,'diag backtracking')
    call require(a%alternative_solver_calls==b%alternative_solver_calls,'diag alternative solver')
  end subroutine compare_diagnostics

  subroutine read_origin(path,state)
    character(len=*),intent(in) :: path
    type(fmr_b110_physical_state_t),intent(out) :: state
    integer :: unit,ios,i,node
    real(real64) :: hh,tt
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    open(newunit=unit,file=path,status='old',action='read',iostat=ios)
    call require(ios==0,'open audit state')
    do i=1,numnod
      read(unit,*,iostat=ios) node,hh,tt
      call require(ios==0.and.node==i,'read audit node')
      call require(ieee_is_finite(hh).and.ieee_is_finite(tt),'finite audit node')
      state%pressure_head(i)=hh
      state%water_content(i)=tt
    end do
    close(unit)
    state%ponding_depth=0.0_real64
    state%groundwater_level=-999.0_real64
  end subroutine read_origin

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64
    nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=960620_int64;p%active_nodes=numnod
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

  subroutine initialize_forcing(f)
    type(fmr_b110_physical_forcing_t),intent(out) :: f
    f%top_flux=0.0_real64;f%top_head=0.0_real64
    f%bottom_flux=0.0_real64;f%bottom_head=bottom_head_cm
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_identity(col,tmpl)
    type(fmr_logical_column_t),intent(out) :: col
    type(fmr_template_t),intent(out) :: tmpl
    tmpl%template_id=960620_int64;tmpl%physics_topology_id=960621_int64
    tmpl%vertical_layout_id=960622_int64;tmpl%state_layout_id=960623_int64
    tmpl%solver_interface_id=960624_int64
    tmpl%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    tmpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tmpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=lineage_id;col%template_id=tmpl%template_id;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_identity

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
      write(*,'(A,1X,A)')'GC_RZM06D02R1_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_gc_rootzone_memory_rzm06d02r1_reseed
