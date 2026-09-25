program test_ref_temporal01_wu02b_mode5
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

  integer, parameter :: NMAT=2,NPROF=2,NBOUND=2,NQ=2,NDT=2,NCASE=NMAT*NPROF*NBOUND*NQ*NDT
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  real(real64), parameter :: qfac_values(NQ)=[-0.08_real64,0.08_real64]
  real(real64), parameter :: dt_values(NDT)=[5.0e-2_real64,1.0e-2_real64]
  real(real64), parameter :: oracle_head_tol=1.0e-4_real64
  real(real64), parameter :: oracle_theta_tol=1.0e-8_real64
  real(real64), parameter :: oracle_storage_tol=1.0e-10_real64

  integer :: imat,iprof,ibound,iq,idt,id
  id=0
  do imat=1,NMAT
    do iprof=1,NPROF
      do ibound=1,NBOUND
        do iq=1,NQ
          do idt=1,NDT
            id=id+1
            call run_case(id,imat,iprof,ibound,qfac_values(iq),dt_values(idt))
          end do
        end do
      end do
    end do
  end do
  call require(id==NCASE,'case count')
  write(*,'(A,I0)') 'REF_TEMPORAL01_WU02B_CASE_COUNT=',id
  write(*,'(A)') 'REF_TEMPORAL01_WU02B=PASS'

contains

  subroutine run_case(id,imat,iprof,ibound,qfac,dt)
    integer,intent(in)::id,imat,iprof,ibound
    real(real64),intent(in)::qfac,dt
    type(soil_water_parameter_set_t),target :: p
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t),target :: cp
    type(b110_source_sink_provider_t),target :: sp
    type(fixed_flux_top_boundary_provider_t),target :: tp
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: ws_warm,ws_main
    type(soil_water_solve_request_t) :: warmreq,req
    type(soil_water_solve_result_t) :: warm,principal
    type(soil_water_temporal_indicator_request_t) :: ireq
    type(soil_water_temporal_indicator_result_t) :: ind
    real(real64),target :: qdra(1,numnod),qssdi(numnod),qrot(numnod)
    real(real64) :: cof(24,numnod),heads(numnod),theta(numnod),k(numnod),cap(numnod),dkdh(numnod)
    real(real64),allocatable :: prev_derivative(:)
    real(real64) :: qtop,qbot,hbot
    type(soil_water_solve_result_t) :: r8,r16,r32
    logical :: ok8,ok16,ok32,stable
    real(real64) :: hdiff,thediff,sdiff,head_err,theta_err,storage_err,ratio

    call configure_material(imat,p,cof)
    call initialize_b110_default_mvg_parameters(hp,cof)
    call build_profile(iprof,heads)
    call bind_b110_default_mvg_provider(cp,hp,dt)
    call cp%evaluate(heads,theta,k,cap,dkdh)
    call require(all(ieee_is_finite(k)).and.all(k>0.0_real64),'initial K')

    qtop=qfac*k(1)
    qbot=-0.4_real64*qtop
    hbot=heads(numnod)-25.0_real64
    qdra=0.0_real64;qssdi=0.0_real64;qrot=0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)

    call build_request(warmreq,p,cp,sp,tp,heads,theta,qtop,qbot,hbot,ibound,dt)
    call solver%solve(warmreq,ws_warm,warm)
    if(warm%status/=SW_SOLVE_CONVERGED) then
      call emit_invalid(id,imat,iprof,ibound,qfac,dt,'PRINCIPAL_REFERENCE_INVALID')
      return
    end if
    allocate(prev_derivative(numnod))
    prev_derivative=(warm%candidate_state%pressure_head-heads)/dt

    req=warmreq
    req%base_state=warm%candidate_state
    call solver%solve(req,ws_main,principal)
    if(principal%status/=SW_SOLVE_CONVERGED) then
      call emit_invalid(id,imat,iprof,ibound,qfac,dt,'PRINCIPAL_REFERENCE_INVALID')
      return
    end if

    ireq%previous_right_derivative_available=.true.
    allocate(ireq%previous_right_derivative(numnod))
    ireq%previous_right_derivative=prev_derivative
    call solver%evaluate_temporal_indicator(req,principal,ireq,ws_main,ind)
    if(ind%status/=SW_TEMPORAL_INDICATOR_AVAILABLE .or. .not.ind%available) then
      call emit_invalid(id,imat,iprof,ibound,qfac,dt,'INDICATOR_UNAVAILABLE')
      return
    end if

    call refined_endpoint(req,hp,8,r8,ok8)
    call refined_endpoint(req,hp,16,r16,ok16)
    call refined_endpoint(req,hp,32,r32,ok32)
    stable=.false.
    if(ok16 .and. ok32) then
      hdiff=maxval(abs(r16%candidate_state%pressure_head-r32%candidate_state%pressure_head))
      thediff=maxval(abs(r16%candidate_state%water_content-r32%candidate_state%water_content))
      sdiff=abs(storage_of(p,r16)-storage_of(p,r32))
      stable=hdiff<=oracle_head_tol .and. thediff<=oracle_theta_tol .and. sdiff<=oracle_storage_tol
    else if(ok8 .and. ok16) then
      hdiff=maxval(abs(r8%candidate_state%pressure_head-r16%candidate_state%pressure_head))
      thediff=maxval(abs(r8%candidate_state%water_content-r16%candidate_state%water_content))
      sdiff=abs(storage_of(p,r8)-storage_of(p,r16))
      stable=hdiff<=oracle_head_tol .and. thediff<=oracle_theta_tol .and. sdiff<=oracle_storage_tol
      if(stable) r32=r16
    end if
    if(.not.stable) then
      call emit_invalid(id,imat,iprof,ibound,qfac,dt,'REFINED_REFERENCE_INVALID')
      return
    end if

    head_err=maxval(abs(principal%candidate_state%pressure_head-r32%candidate_state%pressure_head))
    theta_err=maxval(abs(principal%candidate_state%water_content-r32%candidate_state%water_content))
    storage_err=abs(storage_of(p,principal)-storage_of(p,r32))
    if(head_err>0.0_real64) then
      ratio=ind%head_inf_bound/head_err
    else
      ratio=huge(1.0_real64)
    end if

    write(*,'(A,I0,A,I0,A,I0,A,I0,A,ES16.8E3,A,ES16.8E3,A,ES16.8E3,A,ES16.8E3,A,ES16.8E3,A,A,A,A)') &
      'REF_TEMPORAL01_WU02B_ROW,case=',id,',mat=',imat,',profile=',iprof,',boundary=',ibound,',qfac=',qfac,',dt=',dt, &
      ',bound=',ind%head_inf_bound,',head_err=',head_err,',ratio=',ratio,',route=',trim(ind%route), &
      ',classification=',merge('BOUND_VALID_CONSERVATIVE   ','BOUND_VALID_NONCONSERVATIVE',ind%head_inf_bound>=head_err)
    write(*,'(A,I0,A,ES16.8E3,A,ES16.8E3)') 'REF_TEMPORAL01_WU02B_AUX,case=',id, &
      ',theta_err=',theta_err,',storage_err=',storage_err
  end subroutine run_case

  subroutine refined_endpoint(base_req,hp,nsub,result,ok)
    type(soil_water_solve_request_t),intent(in)::base_req
    type(b110_default_mvg_parameters_t),target,intent(inout)::hp
    integer,intent(in)::nsub
    type(soil_water_solve_result_t),intent(out)::result
    logical,intent(out)::ok
    type(soil_water_solve_request_t)::req
    type(reference_richards_legacy_solver_t)::solver
    type(reference_richards_legacy_workspace_t)::ws
    type(b110_default_mvg_provider_t),target::cp
    real(real64)::subdt
    integer::s
    req=base_req
    subdt=base_req%step_duration/real(nsub,real64)
    req%step_duration=subdt
    call bind_b110_default_mvg_provider(cp,hp,subdt)
    req%evaluation%constitutive=>cp
    ok=.false.
    do s=1,nsub
      call solver%solve(req,ws,result)
      if(result%status/=SW_SOLVE_CONVERGED) return
      req%base_state=result%candidate_state
    end do
    ok=.true.
  end subroutine refined_endpoint

  pure real(real64) function storage_of(p,r) result(v)
    type(soil_water_parameter_set_t),intent(in)::p
    type(soil_water_solve_result_t),intent(in)::r
    v=sum(p%dz*r%candidate_state%water_content)+r%candidate_state%ponding_depth
  end function storage_of

  subroutine emit_invalid(id,imat,iprof,ibound,qfac,dt,classification)
    integer,intent(in)::id,imat,iprof,ibound
    real(real64),intent(in)::qfac,dt
    character(len=*),intent(in)::classification
    write(*,'(A,I0,A,I0,A,I0,A,I0,A,ES16.8E3,A,ES16.8E3,A,A)') &
      'REF_TEMPORAL01_WU02B_INVALID,case=',id,',mat=',imat,',profile=',iprof,',boundary=',ibound, &
      ',qfac=',qfac,',dt=',dt,',classification=',trim(classification)
  end subroutine emit_invalid

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
      tr=0.02_real64;ts=0.3870640000000001_real64;ks=22.76176_real64;alpha=0.016083_real64
      lambda=2.4396619999999993_real64;n=1.524418_real64;m=0.3440119442305195_real64
      ksx=227.61759999999998_real64;relsat=0.9981816467911503_real64;kthr=15.814441314772257_real64
    end select
    p%parameter_set_id=993000_int64+imat
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
      do i=1,numnod
        h(i)=-20.0_real64 + (-120.0_real64+20.0_real64)*real(i-1,real64)/real(max(1,numnod-1),real64)
      end do
    case(2)
      do i=1,numnod
        h(i)=-80.0_real64 + (-320.0_real64+80.0_real64)*real(i-1,real64)/real(max(1,numnod-1),real64)
      end do
    end select
  end subroutine build_profile

  subroutine build_request(req,p,cp,sp,tp,heads,theta,qtop,qbot,hbot,ibound,dt)
    type(soil_water_solve_request_t),intent(out)::req
    type(soil_water_parameter_set_t),target,intent(in)::p
    type(b110_default_mvg_provider_t),target,intent(in)::cp
    type(b110_source_sink_provider_t),target,intent(in)::sp
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::tp
    real(real64),intent(in)::heads(:),theta(:),qtop,qbot,hbot,dt
    integer,intent(in)::ibound
    req%parameters=>p
    req%base_state%active_nodes=numnod
    allocate(req%base_state%pressure_head(numnod),req%base_state%water_content(numnod))
    req%base_state%pressure_head=heads;req%base_state%water_content=theta
    req%base_state%ponding_depth=0.0_real64;req%base_state%groundwater_level=-2.0_real64
    req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%top_flux=qtop;req%boundary%top_head=heads(1)
    if(ibound==1) then
      req%boundary%bottom_mode=2
      req%boundary%bottom_flux=qbot
      req%boundary%bottom_head=777777.0_real64
    else
      req%boundary%bottom_mode=5
      req%boundary%bottom_flux=12345.678_real64
      req%boundary%bottom_head=hbot
    end if
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
      write(*,'(A,1X,A)') 'REF_TEMPORAL01_WU02B_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ref_temporal01_wu02b_mode5
