program test_ftab03_serialized_ksatexm_generated
  use, intrinsic :: iso_fortran_env, only: error_unit, int64, real64
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

  real(real64), parameter :: DURATION=0.02_real64
  real(real64), parameter :: MASS_TOL=1.0e-12_real64
  real(real64), parameter :: H0=-1.0_real64
  integer(int64), parameter :: COLUMN_ID=9730301_int64

  real(real64) :: ah(numnod),at(numnod),gh(numnod),gt(numnod),rh(numnod),rt(numnod)
  integer :: ai,ar,gi,gr,ri,rr

  call run_route(.false.,ah,at,ai,ar)
  call run_route(.true., gh,gt,gi,gr)
  call run_route(.true., rh,rt,ri,rr)

  call require(maxval(abs(gh-ah))<=5.0e-2_real64,'generated head fidelity')
  call require(maxval(abs(gt-at))<=5.0e-3_real64,'generated theta fidelity')
  call require(gi==ai,'nonlinear iteration identity')
  call require(gr==ar,'retry identity')
  call require(all(gh==rh) .and. all(gt==rt),'generated repeat state identity')
  call require(gi==ri .and. gr==rr,'generated repeat solver identity')

  write(*,'(a,es24.16)') 'F_TAB03_SERIAL_HEAD_MAX_ABS=',maxval(abs(gh-ah))
  write(*,'(a,es24.16)') 'F_TAB03_SERIAL_THETA_MAX_ABS=',maxval(abs(gt-at))
  write(*,'(a,i0)') 'F_TAB03_SERIAL_ANALYTIC_ITERS=',ai
  write(*,'(a,i0)') 'F_TAB03_SERIAL_GENERATED_ITERS=',gi
  write(*,'(a,i0)') 'F_TAB03_SERIAL_ANALYTIC_RETRIES=',ar
  write(*,'(a,i0)') 'F_TAB03_SERIAL_GENERATED_RETRIES=',gr
  write(*,'(a)') 'F_TAB03_SERIAL_HARD_MASS=PASS'
  write(*,'(a)') 'F_TAB03_SERIAL_REPEAT_IDENTITY=PASS'
  write(*,'(a)') 'F-TAB03 SERIALIZED KSATEXM COMPOSITION GATE PASS'

contains

  subroutine run_route(generated,head_out,theta_out,iterations,retries)
    logical,intent(in)::generated
    real(real64),intent(out)::head_out(numnod),theta_out(numnod)
    integer,intent(out)::iterations,retries
    type(fmr_b110_physical_parameters_t) :: p
    type(fmr_b110_physical_forcing_t) :: f
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(canonical_numerical_config_t) :: config
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: top
    class(transaction_state_t),allocatable :: snapshot
    real(real64) :: qtop,qbottom
    logical :: ok,available

    call initialize_parameters(p,generated)
    call route_initial_boundary(p,generated,qtop,qbottom)
    call initialize_forcing(f,qtop,qbottom)
    call initialize_column_template(column,template)
    call initialize_config(config)
    call initialize_committed(committed,p,generated,ok)
    call require(ok,'committed initialization')
    call fmr_capture_checkpoint(committed,checkpoint,ok)
    call require(ok,'checkpoint capture')
    call backend%initialize(top)

    call backend%run_trial(column,template,p,committed,f,config,0.0_real64,DURATION, &
         checkpoint,result,candidate,diagnostics)

    if(result%status/=CANONICAL_STATUS_COMPLETED .or. .not.result%completed) then
      write(error_unit,'(a,l1,1x,a,i0,1x,a,es24.16)') 'F_TAB03_SERIAL_RUNTIME_FAIL generated=',generated, &
           'status=',result%status,'mass=',result%mass%residual
      write(error_unit,'(a,5(1x,i0))') 'F_TAB03_SERIAL_RUNTIME_COUNTS',diagnostics%attempts,diagnostics%retries, &
           diagnostics%solver_rejections,diagnostics%temporal_rejections,diagnostics%admission_rejections
    end if
    call require(result%status==CANONICAL_STATUS_COMPLETED .and. result%completed,'runtime completed')
    call require(result%mass%complete .and. abs(result%mass%residual)<=MASS_TOL,'hard mass')
    call require(candidate%ready(),'candidate ready')
    call candidate%snapshot(snapshot,available)
    call require(available,'candidate snapshot')
    select type(physical=>snapshot)
    type is(fmr_b110_physical_state_t)
      head_out=physical%pressure_head
      theta_out=physical%water_content
    class default
      call require(.false.,'candidate state type')
    end select
    iterations=diagnostics%nonlinear_iterations
    retries=diagnostics%internal_retries
  end subroutine run_route

  subroutine initialize_parameters(p,generated)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    logical,intent(in)::generated
    integer::k
    p%parameter_set_id=9730310_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      if(k<=2) then
        call set_node(p%cofgen(:,k),0.02_real64,0.433878_real64,0.021645_real64,1.34877_real64, &
             7.202077_real64,83.24164_real64,832.4163_real64,0.9962891879895563_real64,36.025513440889625_real64)
      else
        call set_node(p%cofgen(:,k),0.02_real64,0.387064_real64,0.016083_real64,1.524418_real64, &
             2.439662_real64,22.76176_real64,227.6176_real64,0.9981816467911503_real64,15.814441314772257_real64)
      end if
    end do
    p%bottom_mode=2
    p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=30; p%max_backtracking=3; p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=MASS_TOL; p%total_balance_tolerance=MASS_TOL
    p%head_abs_tolerance=1.0e-10_real64; p%head_rel_tolerance=1.0e-10_real64
    p%ponding_tolerance=1.0e-10_real64
    p%generated_mvg_acceleration_active=generated
    p%ksatexm_extension_active=.true.
    p%tabulated_hydraulics_active=.false.
  end subroutine initialize_parameters

  subroutine set_node(c,ores,osat,alpha,npar,lexp,ksatfit,ksatexm,relsatthr,ksatthr)
    real(real64),intent(inout)::c(:)
    real(real64),intent(in)::ores,osat,alpha,npar,lexp,ksatfit,ksatexm,relsatthr,ksatthr
    c(1)=ores; c(2)=osat; c(3)=ksatfit; c(4)=alpha; c(5)=lexp; c(6)=npar
    c(7)=1.0_real64-1.0_real64/npar; c(8)=alpha; c(9)=0.0_real64
    c(10)=ksatexm; c(11)=relsatthr; c(12)=ksatthr
    c(22)=-1.0e6_real64; c(23)=1.0e-12_real64
  end subroutine set_node

  subroutine route_initial_boundary(p,generated,qtop,qbottom)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    logical,intent(in)::generated
    real(real64),intent(out)::qtop,qbottom
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::ap
    type(b110_generated_mvg_table_state_t),target::ts
    type(b110_generated_mvg_provider_t)::gp
    real(real64)::heads(numnod),theta(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer::status
    heads=H0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen,enable_ksatexm_extension=.true.)
    if(generated) then
      call initialize_b110_generated_mvg_table_state(ts,hp,status)
      call require(status==F_TAB02_STATE_OK,'initial generated state')
      call bind_b110_generated_mvg_provider(gp,ts,DURATION,status)
      call require(status==F_TAB02_PROVIDER_OK,'initial generated provider')
      call gp%evaluate(heads,theta,conductivity,capacity,dkdh)
    else
      call bind_b110_default_mvg_provider(ap,hp,DURATION)
      call ap%evaluate(heads,theta,conductivity,capacity,dkdh)
    end if
    qtop=conductivity(1)
    qbottom=conductivity(numnod)
  end subroutine route_initial_boundary

  subroutine initialize_forcing(f,qtop,qbottom)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::qtop,qbottom
    f%top_flux=-qtop; f%bottom_flux=-qbottom
    f%top_head=H0; f%bottom_head=H0
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_committed(c,p,generated,ok)
    type(kernel_committed_state_t),intent(out)::c
    type(fmr_b110_physical_parameters_t),intent(in)::p
    logical,intent(in)::generated
    logical,intent(out)::ok
    type(fmr_b110_physical_state_t)::state
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::ap
    type(b110_generated_mvg_table_state_t),target::ts
    type(b110_generated_mvg_provider_t)::gp
    real(real64)::heads(numnod),theta(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer::status
    heads=H0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen,enable_ksatexm_extension=.true.)
    if(generated) then
      call initialize_b110_generated_mvg_table_state(ts,hp,status)
      call require(status==F_TAB02_STATE_OK,'committed generated state')
      call bind_b110_generated_mvg_provider(gp,ts,DURATION,status)
      call require(status==F_TAB02_PROVIDER_OK,'committed generated provider')
      call gp%evaluate(heads,theta,conductivity,capacity,dkdh)
    else
      call bind_b110_default_mvg_provider(ap,hp,DURATION)
      call ap%evaluate(heads,theta,conductivity,capacity,dkdh)
    end if
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=theta
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(c,COLUMN_ID,state,0.0_real64,ok)
  end subroutine initialize_committed

  subroutine initialize_column_template(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=9730321_int64; t%physics_topology_id=9730322_int64
    t%vertical_layout_id=9730323_int64; t%state_layout_id=9730324_int64
    t%solver_interface_id=9730325_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=COLUMN_ID; c%template_id=t%template_id; c%parameter_ref=1_int64
    c%state_handle=1_int64; c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    c%transaction%temporal_tolerance=1.0e-6_real64
    c%transaction%mass_tolerance=MASS_TOL
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=8
    c%max_committed_substeps=32
    c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.false.
    c%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_config

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(error_unit,'(a,1x,a)') 'F_TAB03_SERIAL_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab03_serialized_ksatexm_generated
