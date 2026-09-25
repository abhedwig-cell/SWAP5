program test_fahl27_fmr_reference_floor_opt_in
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_reference_floor_result_t, &
       kernel_reference_floor_candidate_t, kernel_diagnostics_t, KERNEL_REFERENCE_FLOOR_STATUS_OK
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: htop=-75.0_real64, dt=0.25_real64, mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=527071_int64

  type(fmr_b110_physical_parameters_t) :: p_off,p_on
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(kernel_committed_state_t) :: committed_off,committed_on
  type(kernel_reference_floor_result_t) :: result_off,result_on
  type(kernel_reference_floor_candidate_t) :: candidate_off,candidate_on
  type(kernel_diagnostics_t) :: diagnostics_off,diagnostics_on
  type(fmr_serialized_reference_backend_t) :: backend_off,backend_on
  type(fmr_serialized_physical_observation_t) :: obs_off,obs_on
  type(fixed_flux_top_boundary_provider_t),target :: top
  class(transaction_state_t),allocatable :: state_off,state_on
  logical :: ok,av_off,av_on
  real(real64) :: hbottom,max_dh,max_dw

  call initialize_parameters(p_off,.false.)
  call initialize_parameters(p_on,.true.)
  hbottom=htop+sum(disnod(2:numnod))
  call initialize_forcing(forcing,hbottom)
  call initialize_column_template(column,template)
  call initialize_committed(committed_off,p_off,ok); call require(ok,'OFF committed')
  call initialize_committed(committed_on,p_on,ok); call require(ok,'ON committed')

  call backend_off%initialize(top)
  call backend_on%initialize(top)

  call backend_off%run_reference_floor_sample(column,template,p_off,committed_off,forcing,0.0_real64,dt,mass_gate, &
       result_off,candidate_off,diagnostics_off)
  obs_off=backend_off%observation()
  call backend_on%run_reference_floor_sample(column,template,p_on,committed_on,forcing,0.0_real64,dt,mass_gate, &
       result_on,candidate_on,diagnostics_on)
  obs_on=backend_on%observation()

  call require(result_off%status==KERNEL_REFERENCE_FLOOR_STATUS_OK .and. result_off%sample_valid,'OFF sample')
  call require(result_on%status==KERNEL_REFERENCE_FLOOR_STATUS_OK .and. result_on%sample_valid,'ON sample')
  call require(candidate_off%ready() .and. candidate_on%ready(),'candidate materialization')
  call require(result_off%mass%complete .and. result_on%mass%complete,'mass complete')
  call require(abs(result_off%mass%residual)<=mass_gate .and. abs(result_on%mass%residual)<=mass_gate,'mass gate')
  call require(obs_off%solver_executed .and. obs_on%solver_executed,'solver executed')
  call require(obs_off%solver_status==obs_on%solver_status,'same solver status')
  call require(result_off%nonlinear_iterations==result_on%nonlinear_iterations,'same nonlinear iterations')
  call require(result_off%backtracking_attempts==result_on%backtracking_attempts,'same backtracking')
  call require(abs(obs_off%top_flux-obs_on%top_flux)<=1.0e-5_real64,'top flux envelope')
  call require(abs(obs_off%bottom_flux-obs_on%bottom_flux)<=1.0e-5_real64,'bottom flux envelope')

  call candidate_off%snapshot(state_off,av_off)
  call candidate_on%snapshot(state_on,av_on)
  call require(av_off .and. av_on,'candidate snapshots')
  call compare_states(state_off,state_on,max_dh,max_dw)
  call require(max_dh<=0.05_real64,'head envelope')
  call require(max_dw<=1.0e-4_real64,'theta envelope')

  write(*,'(A,ES14.6,1X,A,ES14.6,1X,A,ES14.6)') 'FAHL27_FLOOR MAX_DH=',max_dh, &
       'MAX_DTHETA=',max_dw,'DBOTTOM=',abs(obs_off%bottom_flux-obs_on%bottom_flux)
  write(*,'(A,I0,1X,A,I0)') 'FAHL27_FLOOR ITER=',result_on%nonlinear_iterations, &
       'BACKTRACK=',result_on%backtracking_attempts
  write(*,'(A)') 'FAHL27_FMR_REFERENCE_FLOOR_OPT_IN=PASS'

contains

  subroutine initialize_parameters(p,adaptive)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    logical,intent(in)::adaptive
    integer::i
    p%parameter_set_id=527071_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do i=1,numnod
      p%cofgen(1,i)=0.032_real64;p%cofgen(2,i)=0.423_real64;p%cofgen(3,i)=4.75_real64
      p%cofgen(4,i)=0.0135_real64;p%cofgen(5,i)=0.365_real64;p%cofgen(6,i)=1.455_real64
      p%cofgen(7,i)=1.0_real64-1.0_real64/p%cofgen(6,i);p%cofgen(8,i)=p%cofgen(4,i)
      p%cofgen(9,i)=0.0_real64;p%cofgen(10,i)=p%cofgen(3,i);p%cofgen(11,i)=0.999_real64
      p%cofgen(12,i)=0.99_real64*p%cofgen(3,i);p%cofgen(22,i)=-1.0e6_real64;p%cofgen(23,i)=1.0e-12_real64
    end do
    p%bottom_mode=5;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=mass_gate;p%total_balance_tolerance=mass_gate
    p%head_abs_tolerance=mass_gate;p%head_rel_tolerance=mass_gate;p%ponding_tolerance=mass_gate
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%adaptive_hydraulics_active=adaptive
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.
    p%drainage_response_active=.false.;p%black_evaporation_active=.false.;p%boesten_evaporation_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f,bottom_head)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::bottom_head
    f%top_flux=0.0_real64;f%top_head=htop;f%bottom_flux=0.0_real64;f%bottom_head=bottom_head
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=527071_int64;t%physics_topology_id=527072_int64;t%vertical_layout_id=527073_int64
    t%state_layout_id=527074_int64;t%solver_interface_id=527075_int64
    t%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id;c%template_id=t%template_id;c%parameter_ref=1_int64;c%state_handle=1_int64
    c%forcing_handle=1_int64;c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_committed(committed,p,ok)
    type(kernel_committed_state_t),intent(out)::committed
    type(fmr_b110_physical_parameters_t),intent(in)::p
    logical,intent(out)::ok
    type(fmr_b110_physical_state_t)::state
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::hh(numnod),ww(numnod),kk(numnod),cc(numnod),dd(numnod)
    integer::i
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,dt)
    hh(1)=htop
    do i=2,numnod
      hh(i)=hh(i-1)+p%node_distance(i)
    end do
    call provider%evaluate(hh,ww,kk,cc,dd)
    state%active_nodes=numnod;allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=hh;state%water_content=ww;state%ponding_depth=0.0_real64;state%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(committed,column_id,state,0.0_real64,ok)
  end subroutine initialize_committed

  subroutine compare_states(a,b,dh,dw)
    class(transaction_state_t),intent(in)::a,b
    real(real64),intent(out)::dh,dw
    dh=huge(1.0_real64);dw=huge(1.0_real64)
    select type(x=>a)
    type is(fmr_b110_physical_state_t)
      select type(y=>b)
      type is(fmr_b110_physical_state_t)
        dh=maxval(abs(x%pressure_head-y%pressure_head))
        dw=maxval(abs(x%water_content-y%water_content))
      class default
        call require(.false.,'ON state type')
      end select
    class default
      call require(.false.,'OFF state type')
    end select
  end subroutine compare_states

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'FAHL27_FLOOR_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_fahl27_fmr_reference_floor_opt_in
