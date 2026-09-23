program test_ftab02e_serialized_runtime_performance
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF, transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_checkpoint_t, kernel_committed_state_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, F_TAB02_STATE_OK
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, &
       bind_b110_generated_mvg_provider, F_TAB02_PROVIDER_OK
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: NROUND=8, NREPEAT=300
  real(real64), parameter :: DURATION=0.25_real64
  real(real64), parameter :: MASS_TOLERANCE=1.0e-12_real64

  call benchmark_profile('coarse',0.01_real64,0.42_real64,0.0163_real64,1.559_real64,54.80_real64,0.177_real64,-180.0_real64,9601001_int64)
  call benchmark_profile('loam',0.00_real64,0.43_real64,0.0065_real64,1.325_real64,1.54_real64,-2.161_real64,-75.0_real64,9601002_int64)
  call benchmark_profile('clay',0.00_real64,0.55_real64,0.0532_real64,1.081_real64,15.46_real64,-8.823_real64,-40.0_real64,9601003_int64)
  write(*,'(a)') 'F-TAB02-E SERIALIZED RUNTIME PERFORMANCE CHARACTERIZATION PASS'

contains

  subroutine benchmark_profile(label,ores,osat,alpha,npar,ksat,lexp,h0,column_id)
    character(len=*),intent(in)::label
    real(real64),intent(in)::ores,osat,alpha,npar,ksat,lexp,h0
    integer(int64),intent(in)::column_id
    type(fmr_b110_physical_parameters_t) :: pa,pg
    type(fmr_b110_physical_forcing_t) :: fa,fg
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(canonical_numerical_config_t) :: config
    type(kernel_committed_state_t) :: ca,cg
    type(kernel_checkpoint_t) :: cpa,cpg
    type(kernel_result_t) :: ra,rg
    type(kernel_candidate_state_t) :: canda,candg
    type(kernel_diagnostics_t) :: da,dg
    type(fmr_serialized_reference_backend_t) :: ba,bg
    type(fixed_flux_top_boundary_provider_t),target :: topa,topg
    real(real64) :: theta_a(numnod),theta_g(numnod),q_a,q_g
    real(real64) :: head_a(numnod),head_g(numnod),out_theta_a(numnod),out_theta_g(numnod)
    real(real64) :: at(NROUND),gt(NROUND),ma,mg,checksum_a,checksum_g,t0,t1
    logical :: ok
    integer :: r

    call initialize_parameters(pa,.false.,ores,osat,alpha,npar,ksat,lexp,column_id+100_int64)
    call initialize_parameters(pg,.true., ores,osat,alpha,npar,ksat,lexp,column_id+200_int64)
    call route_initial_constitutive(pa,.false.,h0,theta_a,q_a)
    call route_initial_constitutive(pg,.true., h0,theta_g,q_g)
    call initialize_forcing(fa,q_a,h0)
    call initialize_forcing(fg,q_g,h0)
    call initialize_column_template(column,template,column_id)
    call initialize_config(config)
    call initialize_committed(ca,column_id,h0,theta_a,ok); call require(ok,'analytic committed')
    call initialize_committed(cg,column_id,h0,theta_g,ok); call require(ok,'generated committed')
    call fmr_capture_checkpoint(ca,cpa,ok); call require(ok,'analytic checkpoint')
    call fmr_capture_checkpoint(cg,cpg,ok); call require(ok,'generated checkpoint')
    call ba%initialize(topa)
    call bg%initialize(topg)

    call ba%run_trial(column,template,pa,ca,fa,config,0.0_real64,DURATION,cpa,ra,canda,da)
    call bg%run_trial(column,template,pg,cg,fg,config,0.0_real64,DURATION,cpg,rg,candg,dg)
    call validate_trial(ra,canda,'analytic warm')
    call validate_trial(rg,candg,'generated warm')
    call extract_state(canda,head_a,out_theta_a)
    call extract_state(candg,head_g,out_theta_g)

    call require(maxval(abs(head_g-head_a))<=5.0e-2_real64,'serialized head fidelity')
    call require(maxval(abs(out_theta_g-out_theta_a))<=5.0e-3_real64,'serialized theta fidelity')
    call require(da%nonlinear_iterations==dg%nonlinear_iterations,'serialized nonlinear count')
    call require(da%linear_solves==dg%linear_solves,'serialized linear count')
    call require(da%retries==dg%retries,'serialized retry count')

    checksum_a=0.0_real64; checksum_g=0.0_real64
    do r=1,NROUND
      if(mod(r,2)==1) then
        call time_route(.false.,at(r),checksum_a)
        call time_route(.true.,gt(r),checksum_g)
      else
        call time_route(.true.,gt(r),checksum_g)
        call time_route(.false.,at(r),checksum_a)
      end if
    end do
    ma=median_small(at); mg=median_small(gt)
    call require(ma>0.0_real64 .and. mg>0.0_real64,'positive serialized timings')
    call require(ieee_is_finite(checksum_a) .and. ieee_is_finite(checksum_g),'finite serialized checksums')

    write(*,'(a,a)') 'F_TAB02_E_SERIALIZED_PROFILE=',trim(label)
    write(*,'(a,es24.16)') 'F_TAB02_E_SERIALIZED_HEAD_MAX_ABS=',maxval(abs(head_g-head_a))
    write(*,'(a,es24.16)') 'F_TAB02_E_SERIALIZED_THETA_MAX_ABS=',maxval(abs(out_theta_g-out_theta_a))
    write(*,'(a,i0)') 'F_TAB02_E_SERIALIZED_ANALYTIC_ITERS=',da%nonlinear_iterations
    write(*,'(a,i0)') 'F_TAB02_E_SERIALIZED_GENERATED_ITERS=',dg%nonlinear_iterations
    write(*,'(a,i0)') 'F_TAB02_E_SERIALIZED_ANALYTIC_RETRIES=',da%retries
    write(*,'(a,i0)') 'F_TAB02_E_SERIALIZED_GENERATED_RETRIES=',dg%retries
    write(*,'(a,es24.16)') 'F_TAB02_E_SERIALIZED_ANALYTIC_MEDIAN_S=',ma
    write(*,'(a,es24.16)') 'F_TAB02_E_SERIALIZED_GENERATED_MEDIAN_S=',mg
    write(*,'(a,f14.8)') 'F_TAB02_E_SERIALIZED_DELTA_PCT=',100.0_real64*(mg/ma-1.0_real64)
    write(*,'(a)') 'F_TAB02_E_SERIALIZED_TIMING_CAPTURED=PASS'

  contains
    subroutine time_route(use_generated,seconds,checksum)
      logical,intent(in)::use_generated
      real(real64),intent(out)::seconds
      real(real64),intent(inout)::checksum
      integer::q
      call cpu_time(t0)
      do q=1,NREPEAT
        if(use_generated) then
          call bg%run_trial(column,template,pg,cg,fg,config,0.0_real64,DURATION,cpg,rg,candg,dg)
          if(rg%status/=CANONICAL_STATUS_COMPLETED .or. .not.rg%completed) error stop 'timed generated runtime failed'
          checksum=checksum+rg%mass%residual+real(dg%nonlinear_iterations,real64)
        else
          call ba%run_trial(column,template,pa,ca,fa,config,0.0_real64,DURATION,cpa,ra,canda,da)
          if(ra%status/=CANONICAL_STATUS_COMPLETED .or. .not.ra%completed) error stop 'timed analytic runtime failed'
          checksum=checksum+ra%mass%residual+real(da%nonlinear_iterations,real64)
        end if
      end do
      call cpu_time(t1)
      seconds=t1-t0
    end subroutine time_route
  end subroutine benchmark_profile

  subroutine initialize_parameters(p,generated,ores,osat,alpha,npar,ksat,lexp,parameter_id)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    logical,intent(in)::generated
    real(real64),intent(in)::ores,osat,alpha,npar,ksat,lexp
    integer(int64),intent(in)::parameter_id
    integer::k
    p%parameter_set_id=parameter_id
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=ores; p%cofgen(2,k)=osat; p%cofgen(3,k)=ksat
      p%cofgen(4,k)=alpha; p%cofgen(5,k)=lexp; p%cofgen(6,k)=npar
      p%cofgen(7,k)=1.0_real64-1.0_real64/npar; p%cofgen(8,k)=alpha
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=ksat
      p%cofgen(11,k)=0.999_real64; p%cofgen(12,k)=0.99_real64*ksat
      p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=2; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=MASS_TOLERANCE; p%total_balance_tolerance=MASS_TOLERANCE
    p%head_abs_tolerance=1.0e-10_real64; p%head_rel_tolerance=1.0e-10_real64
    p%ponding_tolerance=1.0e-10_real64
    p%generated_mvg_acceleration_active=generated
    p%tabulated_hydraulics_active=.false.
  end subroutine initialize_parameters

  subroutine route_initial_constitutive(p,generated,h0,theta0,qref)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    logical,intent(in)::generated
    real(real64),intent(in)::h0
    real(real64),intent(out)::theta0(numnod),qref
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::ap
    type(b110_generated_mvg_table_state_t),target::ts
    type(b110_generated_mvg_provider_t)::gp
    real(real64)::heads(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer::status
    heads=h0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    if(generated) then
      call initialize_b110_generated_mvg_table_state(ts,hp,status)
      call require(status==F_TAB02_STATE_OK,'serialized initial generated state')
      call bind_b110_generated_mvg_provider(gp,ts,DURATION,status)
      call require(status==F_TAB02_PROVIDER_OK,'serialized initial generated provider')
      call gp%evaluate(heads,theta0,conductivity,capacity,dkdh)
    else
      call bind_b110_default_mvg_provider(ap,hp,DURATION)
      call ap%evaluate(heads,theta0,conductivity,capacity,dkdh)
    end if
    qref=conductivity(1)
    call require(qref>0.0_real64 .and. ieee_is_finite(qref),'serialized positive qref')
  end subroutine route_initial_constitutive

  subroutine initialize_forcing(f,qref,h0)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::qref,h0
    f%top_flux=-qref; f%bottom_flux=-qref
    f%top_head=h0; f%bottom_head=h0
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t,column_id)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    integer(int64),intent(in)::column_id
    t%template_id=column_id+10_int64; t%physics_topology_id=column_id+11_int64
    t%vertical_layout_id=column_id+12_int64; t%state_layout_id=column_id+13_int64
    t%solver_interface_id=column_id+14_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id; c%template_id=t%template_id; c%parameter_ref=1_int64
    c%state_handle=1_int64; c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    c%transaction%temporal_tolerance=1.0e-6_real64
    c%transaction%mass_tolerance=MASS_TOLERANCE
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=8
    c%max_committed_substeps=32
    c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.false.
    c%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_config

  subroutine initialize_committed(c,column_id,h0,theta0,ok)
    type(kernel_committed_state_t),intent(out)::c
    integer(int64),intent(in)::column_id
    real(real64),intent(in)::h0,theta0(numnod)
    logical,intent(out)::ok
    type(fmr_b110_physical_state_t)::state
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=h0; state%water_content=theta0
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(c,column_id,state,0.0_real64,ok)
  end subroutine initialize_committed

  subroutine validate_trial(r,c,label)
    type(kernel_result_t),intent(in)::r
    type(kernel_candidate_state_t),intent(in)::c
    character(len=*),intent(in)::label
    call require(r%status==CANONICAL_STATUS_COMPLETED .and. r%completed,trim(label)//' runtime completed')
    call require(c%ready(),trim(label)//' candidate ready')
    call require(r%mass%complete .and. abs(r%mass%residual)<=MASS_TOLERANCE,trim(label)//' hard mass')
  end subroutine validate_trial

  subroutine extract_state(c,heads,theta)
    type(kernel_candidate_state_t),intent(in)::c
    real(real64),intent(out)::heads(numnod),theta(numnod)
    class(transaction_state_t),allocatable::snapshot
    logical::available
    call c%snapshot(snapshot,available)
    call require(available,'serialized snapshot')
    select type(physical=>snapshot)
    type is(fmr_b110_physical_state_t)
      heads=physical%pressure_head; theta=physical%water_content
    class default
      call require(.false.,'serialized snapshot type')
    end select
  end subroutine extract_state

  real(real64) function median_small(v) result(m)
    real(real64),intent(in)::v(:)
    real(real64)::x(size(v)),tmp
    integer::a,b
    x=v
    do a=1,size(x)-1
      do b=a+1,size(x)
        if(x(b)<x(a)) then
          tmp=x(a);x(a)=x(b);x(b)=tmp
        end if
      end do
    end do
    if(mod(size(x),2)==0) then
      m=0.5_real64*(x(size(x)/2)+x(size(x)/2+1))
    else
      m=x((size(x)+1)/2)
    end if
  end function median_small

  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok) then
      write(*,'(a,1x,a)') 'F_TAB02_E_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab02e_serialized_runtime_performance
