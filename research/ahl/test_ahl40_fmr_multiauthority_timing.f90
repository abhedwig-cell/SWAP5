program test_ahl40_fmr_multiauthority_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_reference_floor_result_t, &
       kernel_reference_floor_candidate_t, kernel_diagnostics_t, KERNEL_REFERENCE_FLOOR_STATUS_OK
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t, fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: NKEY=16, NREPLAY=65536, NPAIR=9
  real(real64), parameter :: h0=-75.0_real64, hbot=-50.0_real64, duration=0.25_real64
  real(real64), parameter :: mass_tol=1.0e-12_real64

  type(fmr_b110_physical_parameters_t) :: p_off(NKEY),p_on(NKEY)
  type(fmr_b110_physical_forcing_t) :: forcing(NKEY)
  type(fmr_logical_column_t) :: column(NKEY)
  type(fmr_template_t) :: template
  type(kernel_committed_state_t) :: committed_off(NKEY),committed_on(NKEY)
  type(kernel_reference_floor_result_t) :: result_off,result_on
  type(kernel_reference_floor_candidate_t) :: cand_off,cand_on
  type(kernel_diagnostics_t) :: diag_off,diag_on
  type(fmr_serialized_reference_backend_t) :: backend_off,backend_on
  type(fmr_serialized_physical_observation_t) :: obs_off,obs_on
  type(fixed_flux_top_boundary_provider_t),target :: top
  class(transaction_state_t),allocatable :: state_off,state_on
  real(real64) :: k0,max_dh,max_dw,dbot,dtop
  real(real64) :: times_off(NPAIR),times_on(NPAIR),ratios(NPAIR)
  logical :: ok,av_off,av_on
  integer :: i,r

  call init_template(template)
  do i=1,NKEY
    call init_parameters(p_off(i),i)
    p_on(i)=p_off(i)
    p_on(i)%adaptive_hydraulics_active=.true.
    call initial_k(p_off(i),k0)
    call init_forcing(forcing(i),-k0)
    call init_column(column(i),template,i)
    call init_committed(committed_off(i),p_off(i),column(i)%column_id,ok)
    call require(ok,'off committed')
    call init_committed(committed_on(i),p_on(i),column(i)%column_id,ok)
    call require(ok,'on committed')
  end do

  call backend_off%initialize(top)
  call backend_on%initialize(top)

  ! Untimed full fidelity pass also warms all adaptive authorities.
  do i=1,NKEY
    call backend_off%run_reference_floor_sample(column(i),template,p_off(i),committed_off(i),forcing(i), &
         0.0_real64,duration,mass_tol,result_off,cand_off,diag_off)
    call backend_on%run_reference_floor_sample(column(i),template,p_on(i),committed_on(i),forcing(i), &
         0.0_real64,duration,mass_tol,result_on,cand_on,diag_on)

    call require(result_off%status==KERNEL_REFERENCE_FLOOR_STATUS_OK .and. result_off%sample_valid,'off sample')
    call require(result_on%status==KERNEL_REFERENCE_FLOOR_STATUS_OK .and. result_on%sample_valid,'on sample')
    call require(result_off%mass%complete .and. result_on%mass%complete,'mass complete')
    call require(abs(result_off%mass%residual)<=mass_tol .and. abs(result_on%mass%residual)<=mass_tol,'mass')

    if(allocated(state_off))deallocate(state_off)
    if(allocated(state_on))deallocate(state_on)
    call cand_off%snapshot(state_off,av_off)
    call cand_on%snapshot(state_on,av_on)
    call require(av_off .and. av_on,'snapshots')
    call compare_states(state_off,state_on,max_dh,max_dw)

    obs_off=backend_off%observation()
    obs_on=backend_on%observation()
    dbot=abs(obs_on%bottom_flux-obs_off%bottom_flux)
    dtop=abs(obs_on%top_flux-obs_off%top_flux)

    call require(obs_off%solver_executed .and. obs_on%solver_executed,'solver executed')
    call require(obs_off%solver_status==obs_on%solver_status,'solver status')
    call require(obs_off%solver_diagnostics%nonlinear_iterations==obs_on%solver_diagnostics%nonlinear_iterations, &
         'nonlinear iterations')
    call require(obs_off%solver_diagnostics%backtracking_attempts==obs_on%solver_diagnostics%backtracking_attempts, &
         'backtracking')
    call require(max_dh<=0.05_real64,'head')
    call require(max_dw<=1.0e-4_real64,'theta')
    call require(dtop<=1.0e-5_real64,'top flux')
    call require(dbot<=1.0e-5_real64,'bottom flux')

    write(*,'(A,1X,I0,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6)') &
         'AHL40_FIDELITY',i,'MAX_DH=',max_dh,'MAX_DTHETA=',max_dw,'DBOTTOM=',dbot
  end do
  write(*,'(A)') 'AHL40_FIDELITY_16_OF_16=PASS'

  do r=1,NPAIR
    if(mod(r,2)==1)then
      call time_batch(.false.,times_off(r))
      call time_batch(.true.,times_on(r))
    else
      call time_batch(.true.,times_on(r))
      call time_batch(.false.,times_off(r))
    end if
    ratios(r)=times_on(r)/times_off(r)
    write(*,'(A,1X,I0,2(1X,ES18.10),1X,F10.6)') &
         'AHL40_PAIR',r,times_off(r),times_on(r),ratios(r)
  end do
  call sort9(ratios)
  write(*,'(A,1X,F10.6)') 'AHL40_MEDIAN_RATIO',ratios(5)
  write(*,'(A,1X,F10.6)') 'AHL40_MEDIAN_REDUCTION',1.0_real64-ratios(5)
  call require(ratios(5)<0.98_real64,'application speed gate')
  write(*,'(A)') 'AHL40_APPLICATION_TIMING=PASS'

contains

  subroutine time_batch(adaptive,elapsed)
    logical,intent(in)::adaptive
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q,idx
    call cpu_time(a)
    if(adaptive)then
      do q=1,NREPLAY
        idx=1+mod(q-1,NKEY)
        call backend_on%run_reference_floor_sample(column(idx),template,p_on(idx),committed_on(idx),forcing(idx), &
             0.0_real64,duration,mass_tol,result_on,cand_on,diag_on)
        if(result_on%status/=KERNEL_REFERENCE_FLOOR_STATUS_OK)error stop 'timed adaptive failed'
      end do
    else
      do q=1,NREPLAY
        idx=1+mod(q-1,NKEY)
        call backend_off%run_reference_floor_sample(column(idx),template,p_off(idx),committed_off(idx),forcing(idx), &
             0.0_real64,duration,mass_tol,result_off,cand_off,diag_off)
        if(result_off%status/=KERNEL_REFERENCE_FLOOR_STATUS_OK)error stop 'timed analytical failed'
      end do
    end if
    call cpu_time(b)
    elapsed=(b-a)/real(NREPLAY,real64)
  end subroutine time_batch

  subroutine init_parameters(p,idx)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer,intent(in)::idx
    integer::j
    real(real64)::sf,nv
    sf=1.0_real64+0.002_real64*real(idx-1,real64)
    nv=1.455_real64+0.0005_real64*real(mod(idx-1,7),real64)
    p%parameter_set_id=539000_int64+int(idx,int64)
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do j=1,numnod
      p%cofgen(1,j)=0.032_real64;p%cofgen(2,j)=0.423_real64;p%cofgen(3,j)=4.75_real64*sf
      p%cofgen(4,j)=0.0135_real64;p%cofgen(5,j)=0.365_real64;p%cofgen(6,j)=nv
      p%cofgen(7,j)=1.0_real64-1.0_real64/nv;p%cofgen(8,j)=p%cofgen(4,j)
      p%cofgen(9,j)=0.0_real64;p%cofgen(10,j)=p%cofgen(3,j);p%cofgen(11,j)=0.999_real64
      p%cofgen(12,j)=0.99_real64*p%cofgen(3,j);p%cofgen(22,j)=-1.0e6_real64;p%cofgen(23,j)=1.0e-12_real64
    end do
    p%bottom_mode=5;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=mass_tol;p%total_balance_tolerance=mass_tol
    p%head_abs_tolerance=mass_tol;p%head_rel_tolerance=mass_tol;p%ponding_tolerance=mass_tol
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%adaptive_hydraulics_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.;p%drainage_response_active=.false.
  end subroutine init_parameters

  subroutine initial_k(p,k)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(out)::k
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::prov
    real(real64)::hh(numnod),ww(numnod),kk(numnod),cc(numnod),dd(numnod)
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(prov,hp,duration)
    hh=h0;call prov%evaluate(hh,ww,kk,cc,dd);k=kk(1)
  end subroutine initial_k

  subroutine init_forcing(f,qtop)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::qtop
    f%top_flux=qtop;f%top_head=h0;f%bottom_flux=0.0_real64;f%bottom_head=hbot
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine init_forcing

  subroutine init_template(t)
    type(fmr_template_t),intent(out)::t
    t%template_id=539011_int64;t%physics_topology_id=539012_int64;t%vertical_layout_id=539013_int64
    t%state_layout_id=539014_int64;t%solver_interface_id=539015_int64;t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine init_template

  subroutine init_column(c,t,idx)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(in)::t
    integer,intent(in)::idx
    c%column_id=539100_int64+int(idx,int64)
    c%template_id=t%template_id;c%parameter_ref=int(idx,int64);c%state_handle=int(idx,int64)
    c%forcing_handle=int(idx,int64);c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine init_column

  subroutine init_committed(committed,p,column_id,ok)
    type(kernel_committed_state_t),intent(out)::committed
    type(fmr_b110_physical_parameters_t),intent(in)::p
    integer(int64),intent(in)::column_id
    logical,intent(out)::ok
    type(fmr_b110_physical_state_t)::st
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::prov
    real(real64)::hh(numnod),ww(numnod),kk(numnod),cc(numnod),dd(numnod)
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(prov,hp,duration)
    hh=h0;call prov%evaluate(hh,ww,kk,cc,dd)
    st%active_nodes=numnod;allocate(st%pressure_head(numnod),st%water_content(numnod))
    st%pressure_head=hh;st%water_content=ww;st%ponding_depth=0.0_real64;st%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(committed,column_id,st,0.0_real64,ok)
  end subroutine init_committed

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
        call require(.false.,'on state type')
      end select
    class default
      call require(.false.,'off state type')
    end select
  end subroutine compare_states

  subroutine sort9(v)
    real(real64),intent(inout)::v(9)
    real(real64)::tmp
    integer::a,b
    do a=1,8
      do b=a+1,9
        if(v(b)<v(a))then;tmp=v(a);v(a)=v(b);v(b)=tmp;end if
      end do
    end do
  end subroutine sort9

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'AHL40_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require

end program test_ahl40_fmr_multiauthority_timing
