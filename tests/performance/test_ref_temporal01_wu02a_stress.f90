program test_ref_temporal01_wu02a_stress
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: NMAT=2,NPROF=2,NQ=2,NDT=3,NCASE=NMAT*NPROF*NQ*NDT
  integer, parameter :: REFINE=32
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  real(real64), parameter :: qfac_values(NQ)=[-0.05_real64,0.05_real64]
  real(real64), parameter :: dt_values(NDT)=[5.0e-2_real64,1.0e-2_real64,1.0e-4_real64]
  integer :: imat,iprof,iq,idt,id
  id=0
  do imat=1,NMAT
    do iprof=1,NPROF
      do iq=1,NQ
        do idt=1,NDT
          id=id+1
          call run_case(id,imat,iprof,qfac_values(iq),dt_values(idt))
        end do
      end do
    end do
  end do
  call require(id==NCASE,'case count')
  write(*,'(A,I0)') 'REF_TEMPORAL01_WU02A_CASE_COUNT=',id
  write(*,'(A)') 'REF_TEMPORAL01_WU02A=PASS'

contains

  subroutine run_case(id,imat,iprof,qfac,dt)
    integer,intent(in)::id,imat,iprof
    real(real64),intent(in)::qfac,dt
    type(soil_water_parameter_set_t),target :: p
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t),target :: cp
    type(b110_source_sink_provider_t),target :: sp
    type(fixed_flux_top_boundary_provider_t),target :: tp
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: ws_warm,ws_main,ws_ref
    type(soil_water_solve_request_t) :: warmreq,req,subreq
    type(soil_water_solve_result_t) :: warm,principal,subres
    type(soil_water_temporal_indicator_request_t) :: ireq
    type(soil_water_temporal_indicator_result_t) :: ind
    real(real64),target :: qdra(1,numnod),qssdi(numnod),qrot(numnod)
    real(real64) :: cof(24,numnod),heads(numnod),theta(numnod),k(numnod),cap(numnod),dkdh(numnod)
    real(real64),allocatable :: prev_derivative(:)
    real(real64) :: qtop,qbot,subdt,head_err,theta_err,storage_err,ratio
    real(real64) :: storage_p,storage_r
    integer :: s

    call configure_material(imat,p,cof)
    call initialize_b110_default_mvg_parameters(hp,cof)
    call build_profile(iprof,heads)
    call bind_b110_default_mvg_provider(cp,hp,dt)
    call cp%evaluate(heads,theta,k,cap,dkdh)
    call require(all(ieee_is_finite(k)).and.all(k>0.0_real64),'initial K')

    qtop=qfac*k(1)
    qbot=-0.5_real64*qtop
    qdra=0.0_real64;qssdi=0.0_real64;qrot=0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)

    call build_request(warmreq,p,cp,sp,tp,heads,theta,qtop,qbot,dt)
    call solver%solve(warmreq,ws_warm,warm)
    call require(warm%status==SW_SOLVE_CONVERGED,'warmup solve')
    allocate(prev_derivative(numnod))
    prev_derivative=(warm%candidate_state%pressure_head-heads)/dt

    req=warmreq
    req%base_state=warm%candidate_state
    call solver%solve(req,ws_main,principal)
    call require(principal%status==SW_SOLVE_CONVERGED,'principal solve')

    ireq%previous_right_derivative_available=.true.
    allocate(ireq%previous_right_derivative(numnod))
    ireq%previous_right_derivative=prev_derivative
    call solver%evaluate_temporal_indicator(req,principal,ireq,ws_main,ind)
    call require(ind%status==SW_TEMPORAL_INDICATOR_AVAILABLE.and.ind%available,'indicator')

    subdt=dt/real(REFINE,real64)
    subreq=req
    subreq%step_duration=subdt
    call bind_b110_default_mvg_provider(cp,hp,subdt)
    subreq%evaluation%constitutive=>cp
    do s=1,REFINE
      call solver%solve(subreq,ws_ref,subres)
      call require(subres%status==SW_SOLVE_CONVERGED,'refined solve')
      subreq%base_state=subres%candidate_state
    end do

    head_err=maxval(abs(principal%candidate_state%pressure_head-subres%candidate_state%pressure_head))
    theta_err=maxval(abs(principal%candidate_state%water_content-subres%candidate_state%water_content))
    storage_p=sum(p%dz*principal%candidate_state%water_content)+principal%candidate_state%ponding_depth
    storage_r=sum(p%dz*subres%candidate_state%water_content)+subres%candidate_state%ponding_depth
    storage_err=abs(storage_p-storage_r)
    if(head_err>0.0_real64) then
      ratio=ind%head_inf_bound/head_err
    else
      ratio=huge(1.0_real64)
    end if

    write(*,'(A,I0,A,I0,A,I0,A,ES16.8E3,A,ES16.8E3,A,ES16.8E3,A,ES16.8E3,A,ES16.8E3,A,A)') &
      'REF_TEMPORAL01_WU02A_ROW,case=',id,',mat=',imat,',profile=',iprof,',qfac=',qfac,',dt=',dt, &
      ',bound=',ind%head_inf_bound,',head_err=',head_err,',ratio=',ratio,',route=',trim(ind%route)
    write(*,'(A,I0,A,ES16.8E3,A,ES16.8E3)') 'REF_TEMPORAL01_WU02A_AUX,case=',id, &
      ',theta_err=',theta_err,',storage_err=',storage_err
  end subroutine run_case

  subroutine configure_material(imat,p,c)
    integer,intent(in)::imat
    type(soil_water_parameter_set_t),target,intent(out)::p
    real(real64),intent(out)::c(24,numnod)
    real(real64)::tr,ts,ks,alpha,lambda,n,m,ksx,relsat,kthr
    integer::i
    select case(imat)
    case(1)
      tr=0.032_real64;ts=0.423_real64;ks=4.75_real64;alpha=0.0135_real64
      lambda=0.365_real64;n=1.455_real64;m=1.0_real64-1.0_real64/n
      ksx=ks;relsat=0.999_real64;kthr=0.99_real64*ks
    case(2)
      ! Exact Hupsel lower-layer rows from F-SI39 authority.
      tr=0.02_real64;ts=0.3870640000000001_real64;ks=22.76176_real64;alpha=0.016083_real64
      lambda=2.4396619999999993_real64;n=1.524418_real64;m=0.3440119442305195_real64
      ksx=227.61759999999998_real64;relsat=0.9981816467911503_real64;kthr=15.814441314772257_real64
    case default
      error stop 'unknown material'
    end select
    p%parameter_set_id=992000_int64+imat
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod)
    c=0.0_real64
    do i=1,numnod
      c(1,i)=tr;c(2,i)=ts;c(3,i)=ks;c(4,i)=alpha;c(5,i)=lambda;c(6,i)=n;c(7,i)=m
      c(8,i)=alpha;c(9,i)=0.0_real64;c(10,i)=ksx;c(11,i)=relsat;c(12,i)=kthr
      c(22,i)=-1.0e6_real64;c(23,i)=1.0e-12_real64
    end do
  end subroutine configure_material

  subroutine build_profile(iprof,h)
    integer,intent(in)::iprof
    real(real64),intent(out)::h(numnod)
    integer::i
    select case(iprof)
    case(1)
      h=-20.0_real64
    case(2)
      do i=1,numnod
        h(i)=-60.0_real64 + (-300.0_real64+60.0_real64)*real(i-1,real64)/real(max(1,numnod-1),real64)
      end do
    end select
  end subroutine build_profile

  subroutine build_request(req,p,cp,sp,tp,heads,theta,qtop,qbot,dt)
    type(soil_water_solve_request_t),intent(out)::req
    type(soil_water_parameter_set_t),target,intent(in)::p
    type(b110_default_mvg_provider_t),target,intent(in)::cp
    type(b110_source_sink_provider_t),target,intent(in)::sp
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::tp
    real(real64),intent(in)::heads(:),theta(:),qtop,qbot,dt
    req%parameters=>p
    req%base_state%active_nodes=numnod
    allocate(req%base_state%pressure_head(numnod),req%base_state%water_content(numnod))
    req%base_state%pressure_head=heads;req%base_state%water_content=theta
    req%base_state%ponding_depth=0.0_real64;req%base_state%groundwater_level=-2.0_real64
    req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop;req%boundary%bottom_flux=qbot
    req%boundary%top_head=heads(1);req%boundary%bottom_head=777777.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16;req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0;req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-12_real64
    req%numerical%compartment_balance_tolerance=hard_mass_gate;req%numerical%total_balance_tolerance=hard_mass_gate
    req%numerical%head_abs_tolerance=hard_mass_gate;req%numerical%head_rel_tolerance=hard_mass_gate
    req%numerical%ponding_tolerance=hard_mass_gate
    req%evaluation%constitutive=>cp;req%evaluation%source_sink=>sp;req%evaluation%top_boundary=>tp
  end subroutine build_request

  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok) then
      write(*,'(A,1X,A)') 'REF_TEMPORAL01_WU02A_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ref_temporal01_wu02a_stress
