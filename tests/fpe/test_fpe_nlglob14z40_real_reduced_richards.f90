program test_fpe_nlglob14z40_real_reduced_richards
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_fpe_timeint03_reference_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_moving_interface_manager, only: moving_interface_active_view_t, moving_interface_manager_diagnostics_t, &
       moving_interface_manager_context_t, derive_moving_interface_active_view, &
       prepare_moving_interface_reduced_request_persistent, &
       materialize_moving_interface_full_candidate_persistent, &
       finalize_moving_interface_result_persistent, MI_MANAGER_ROUTE_REDUCED
  implicit none

  integer, parameter :: nwarm=50, nblock=5, nper=200
  integer :: timeint02_mode
  real(8) :: timeint02_thetam2(1000)
  common /timeint02_history_common/ timeint02_mode, timeint02_thetam2

  type(soil_water_parameter_set_t), target :: pfull
  type(b110_default_mvg_parameters_t), target :: hpfull, hpred
  type(b110_default_mvg_provider_t), target :: constitutive_full, constitutive_red
  type(b110_source_sink_provider_t), target :: source_full, source_red
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(reference_richards_legacy_solver_t) :: solver_full, solver_red
  type(reference_richards_legacy_workspace_t) :: ws_full, ws_red
  type(soil_water_physical_state_t) :: origin
  type(soil_water_solve_request_t) :: full_req
  type(soil_water_solve_result_t) :: full_res, red_res
  type(moving_interface_active_view_t) :: view
  type(moving_interface_manager_diagnostics_t) :: manager_diag
  type(moving_interface_manager_context_t) :: manager_context

  real(real64), allocatable, target :: qdra_full(:,:), qssdi_full(:), qrot_full(:)
  real(real64), allocatable, target :: qdra_red(:,:), qssdi_red(:), qrot_red(:)
  real(real64), allocatable :: cof_full(:,:), cof_red(:,:)
  real(real64), allocatable :: theta_tmp(:), k_tmp(:), cap_tmp(:), dk_tmp(:)
  real(real64), allocatable :: tail_h(:), tail_th(:)
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,dt
  real(real64) :: hdiff,tdiff,topdiff,ledgerdiff,full_ledger,red_ledger
  real(real64) :: full_block(nblock),red_block(nblock),full_med,red_med,ratio,t0,t1
  real(real64) :: checksum_full,checksum_red
  character(len=32) :: material_id
  character(len=96) :: reason
  integer :: tail_start,n,nt,i,j,ib,full_tail,red_tail
  logical :: ok,physical_ok,origin_ok

  call get_command_argument(1,material_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda); call read_int(8,tail_start)
  n=tail_start
  nt=numnod-n
  dt=0.00125_real64

  call setup_full()
  call setup_reduced()
  call initialize_origin()
  call build_full_request()
  call prepare_reduced_request()
  allocate(tail_h(nt),tail_th(nt))

  timeint02_mode=1
  timeint02_thetam2=0.0_real64
  timeint02_thetam2(1:numnod)=origin%water_content

  call solve_full_once(full_res,ok)
  call require(ok,'full physical solve failed')
  call solve_reduced_once(red_res,ok)
  call require(ok,'reduced physical solve failed')
  call reconstruct_and_publish(red_res,ok)
  call require(ok,'reduced materialization failed')

  hdiff=maxval(abs(context_state_h()-full_res%candidate_state%pressure_head))
  tdiff=maxval(abs(context_state_theta()-full_res%candidate_state%water_content))
  topdiff=abs(manager_context%full_candidate%top_flux-full_res%top_flux)
  full_ledger=ledger(full_res)
  red_ledger=ledger(manager_context%full_candidate)
  ledgerdiff=abs(red_ledger-full_ledger)
  full_tail=tail_identity(full_res%candidate_state)
  red_tail=tail_identity(manager_context%full_candidate%candidate_state)
  origin_ok=maxval(abs(full_req%base_state%pressure_head-origin%pressure_head))<=1e-15_real64 .and. &
       maxval(abs(full_req%base_state%water_content-origin%water_content))<=1e-15_real64
  physical_ok=all(ieee_is_finite(full_res%candidate_state%pressure_head)) .and. &
       all(ieee_is_finite(manager_context%full_candidate%candidate_state%pressure_head)) .and. &
       hdiff<=5e-5_real64 .and. tdiff<=5e-8_real64 .and. topdiff<=5e-8_real64 .and. &
       ledgerdiff<=5e-7_real64 .and. full_tail==red_tail .and. &
       manager_diag%route==MI_MANAGER_ROUTE_REDUCED .and. &
       manager_context%full_candidate%candidate_state%active_nodes==numnod .and. origin_ok

  if (.not.physical_ok) then
     write(*,'(*(g0))') 'F_PE_NLGLOB14Z40_PHYSICAL|MATERIAL=',trim(material_id), &
          '|TAIL=',tail_start,'|PASS=0|HDIFF=',hdiff,'|TDIFF=',tdiff,'|TOPDIFF=',topdiff, &
          '|LEDGERDIFF=',ledgerdiff,'|FULL_TAIL=',full_tail,'|RED_TAIL=',red_tail, &
          '|ROUTE=',manager_diag%route,'|ORIGIN_OK=',merge(1,0,origin_ok)
     write(*,'(a)') 'F_PE_NLGLOB14Z40_RESULT={"classification":"Z40_REAL_REDUCED_PHYSICAL_MISMATCH"}'
     write(*,'(a)') 'F_PE_NLGLOB14Z40=PASS'
     stop
  end if

  checksum_full=0.0_real64
  checksum_red=0.0_real64
  do i=1,nwarm
     call timed_full_op(checksum_full,ok); call require(ok,'full warmup failed')
     call timed_reduced_op(checksum_red,ok); call require(ok,'reduced warmup failed')
  end do

  do ib=1,nblock
     if(mod(ib,2)==1)then
        call cpu_time(t0)
        do j=1,nper
           call timed_full_op(checksum_full,ok); call require(ok,'full timing failed')
        end do
        call cpu_time(t1); full_block(ib)=(t1-t0)/real(nper,real64)
        call cpu_time(t0)
        do j=1,nper
           call timed_reduced_op(checksum_red,ok); call require(ok,'reduced timing failed')
        end do
        call cpu_time(t1); red_block(ib)=(t1-t0)/real(nper,real64)
     else
        call cpu_time(t0)
        do j=1,nper
           call timed_reduced_op(checksum_red,ok); call require(ok,'reduced timing failed')
        end do
        call cpu_time(t1); red_block(ib)=(t1-t0)/real(nper,real64)
        call cpu_time(t0)
        do j=1,nper
           call timed_full_op(checksum_full,ok); call require(ok,'full timing failed')
        end do
        call cpu_time(t1); full_block(ib)=(t1-t0)/real(nper,real64)
     end if
  end do

  call median5(full_block,full_med)
  call median5(red_block,red_med)
  ratio=red_med/full_med
  call require(ieee_is_finite(checksum_full) .and. ieee_is_finite(checksum_red),'checksum invalid')

  write(*,'(*(g0))') 'F_PE_NLGLOB14Z40_CASE|MATERIAL=',trim(material_id), &
       '|TAIL_START=',tail_start,'|ACTIVE_N=',n,'|HDIFF=',hdiff,'|TDIFF=',tdiff, &
       '|TOPDIFF=',topdiff,'|LEDGERDIFF=',ledgerdiff,'|FULL_TAIL=',full_tail,'|RED_TAIL=',red_tail, &
       '|FULL_NL=',full_res%diagnostics%nonlinear_iterations,'|RED_NL=',red_res%diagnostics%nonlinear_iterations, &
       '|FULL_JAC=',full_res%diagnostics%jacobian_builds,'|RED_JAC=',red_res%diagnostics%jacobian_builds, &
       '|FULL_MEDIAN_S=',full_med,'|RED_MEDIAN_S=',red_med,'|TIMING_RATIO=',ratio, &
       '|CHECKSUM_FULL=',checksum_full,'|CHECKSUM_RED=',checksum_red, &
       '|REQUEST_REALLOCS=',manager_context%request_buffer_reallocations, &
       '|CANDIDATE_REALLOCS=',manager_context%full_candidate_buffer_reallocations
  write(*,'(a)') 'F_PE_NLGLOB14Z40=PASS'

contains

  subroutine read_real(iarg,x)
    integer,intent(in)::iarg
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(iarg,s); read(s,*)x
  end subroutine read_real

  subroutine read_int(iarg,x)
    integer,intent(in)::iarg
    integer,intent(out)::x
    character(len=64)::s
    call get_command_argument(iarg,s); read(s,*)x
  end subroutine read_int

  subroutine fill_cof(cof,nn)
    real(real64),intent(out)::cof(:,:)
    integer,intent(in)::nn
    integer::k
    real(real64)::mm
    cof=0.0_real64
    mm=1.0_real64-1.0_real64/nvg
    do k=1,nn
       cof(1,k)=tr; cof(2,k)=ts; cof(3,k)=ksat; cof(4,k)=alpha; cof(5,k)=lambda
       cof(6,k)=nvg; cof(7,k)=mm; cof(8,k)=alpha; cof(9,k)=0.0_real64
       cof(10,k)=ksat; cof(11,k)=0.999_real64; cof(12,k)=0.99_real64*ksat
       cof(22,k)=-1.0e6_real64; cof(23,k)=1.0e-12_real64
    end do
  end subroutine fill_cof

  subroutine setup_full()
    integer::k
    pfull%parameter_set_id=4001_int64
    pfull%active_nodes=numnod
    allocate(pfull%z(numnod),pfull%dz(numnod),pfull%node_distance(numnod))
    pfull%z=z; pfull%dz=dz; pfull%node_distance=disnod(1:numnod)
    allocate(cof_full(24,numnod))
    call fill_cof(cof_full,numnod)
    call initialize_b110_default_mvg_parameters(hpfull,cof_full)
    call bind_b110_default_mvg_provider(constitutive_full,hpfull,dt)
    allocate(qdra_full(1,numnod),qssdi_full(numnod),qrot_full(numnod))
    qdra_full=0.0_real64; qssdi_full=0.0_real64; qrot_full=0.0_real64
    call bind_b110_source_sink_provider(source_full,qdra_full,qssdi_full,qrot_full)
  end subroutine setup_full

  subroutine setup_reduced()
    allocate(cof_red(24,n))
    call fill_cof(cof_red,n)
    call initialize_b110_default_mvg_parameters(hpred,cof_red)
    call bind_b110_default_mvg_provider(constitutive_red,hpred,dt)
    allocate(qdra_red(1,n),qssdi_red(n),qrot_red(n))
    qdra_red=0.0_real64; qssdi_red=0.0_real64; qrot_red=0.0_real64
    call bind_b110_source_sink_provider(source_red,qdra_red,qssdi_red,qrot_red)
  end subroutine setup_reduced

  subroutine initialize_origin()
    real(real64)::heads(numnod)
    integer::k
    allocate(theta_tmp(numnod),k_tmp(numnod),cap_tmp(numnod),dk_tmp(numnod))
    do k=1,numnod
       heads(k)=10.0_real64*real(k-tail_start,real64)
    end do
    call constitutive_full%evaluate(heads,theta_tmp,k_tmp,cap_tmp,dk_tmp)
    origin%active_nodes=numnod
    allocate(origin%pressure_head(numnod),origin%water_content(numnod))
    origin%pressure_head=heads
    origin%water_content=theta_tmp
    origin%ponding_depth=0.0_real64
    origin%groundwater_level=-10.0_real64*real(tail_start-1,real64)
  end subroutine initialize_origin

  subroutine configure_request(req)
    type(soil_water_solve_request_t),intent(inout)::req
    req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%top_flux=-0.01_real64
    req%boundary%bottom_mode=2
    req%boundary%bottom_flux=0.0_real64
    req%numerical%max_iterations=8
    req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    req%numerical%compartment_balance_tolerance=1.0e-12_real64
    req%numerical%total_balance_tolerance=1.0e-12_real64
    req%numerical%head_abs_tolerance=1.0e-9_real64
    req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
  end subroutine configure_request

  subroutine build_full_request()
    full_req%parameters=>pfull
    full_req%base_state=origin
    call configure_request(full_req)
    full_req%evaluation%constitutive=>constitutive_full
    full_req%evaluation%source_sink=>source_full
    full_req%evaluation%top_boundary=>top
  end subroutine build_full_request

  subroutine prepare_reduced_request()
    call derive_moving_interface_active_view(origin,tail_start,view,ok,reason)
    call require(ok,'active view failed')
    call prepare_moving_interface_reduced_request_persistent(full_req,view,manager_context,ok,reason)
    call require(ok,'persistent reduced request failed')
    manager_context%reduced_request%evaluation%constitutive=>constitutive_red
    manager_context%reduced_request%evaluation%source_sink=>source_red
    manager_context%reduced_request%evaluation%top_boundary=>top
  end subroutine prepare_reduced_request

  subroutine solve_full_once(result,solve_ok)
    type(soil_water_solve_result_t),intent(out)::result
    logical,intent(out)::solve_ok
    timeint02_mode=1
    timeint02_thetam2=0.0_real64
    timeint02_thetam2(1:numnod)=origin%water_content
    call solver_full%solve(full_req,ws_full,result)
    solve_ok=result%status==SW_SOLVE_CONVERGED
  end subroutine solve_full_once

  subroutine solve_reduced_once(result,solve_ok)
    type(soil_water_solve_result_t),intent(out)::result
    logical,intent(out)::solve_ok
    call prepare_moving_interface_reduced_request_persistent(full_req,view,manager_context,ok,reason)
    if(.not.ok)then
       solve_ok=.false.; return
    end if
    manager_context%reduced_request%evaluation%constitutive=>constitutive_red
    manager_context%reduced_request%evaluation%source_sink=>source_red
    manager_context%reduced_request%evaluation%top_boundary=>top
    timeint02_mode=1
    timeint02_thetam2=0.0_real64
    timeint02_thetam2(1:n)=origin%water_content(1:n)
    call solver_red%solve(manager_context%reduced_request,ws_red,result)
    solve_ok=result%status==SW_SOLVE_CONVERGED
  end subroutine solve_reduced_once

  subroutine reconstruct_and_publish(result,publish_ok)
    type(soil_water_solve_result_t),intent(in)::result
    logical,intent(out)::publish_ok
    integer::k
    if(nt>0)then
       tail_h(1)=result%candidate_state%pressure_head(n)+pfull%node_distance(n+1)
       do k=2,nt
          tail_h(k)=tail_h(k-1)+pfull%node_distance(n+k)
       end do
       tail_th=ts
    end if
    call materialize_moving_interface_full_candidate_persistent(origin,result,tail_h,tail_th, &
         manager_context,ok,reason)
    if(.not.ok)then
       publish_ok=.false.; return
    end if
    call finalize_moving_interface_result_persistent(full_res,.true.,view,ws_red%richards%generation, &
         'none',manager_context,manager_diag)
    publish_ok=manager_diag%route==MI_MANAGER_ROUTE_REDUCED
  end subroutine reconstruct_and_publish

  subroutine timed_full_op(sumcheck,solve_ok)
    real(real64),intent(inout)::sumcheck
    logical,intent(out)::solve_ok
    type(soil_water_solve_result_t)::r
    call solve_full_once(r,solve_ok)
    if(solve_ok) sumcheck=sumcheck+r%candidate_state%pressure_head(1)*1e-12_real64
  end subroutine timed_full_op

  subroutine timed_reduced_op(sumcheck,solve_ok)
    real(real64),intent(inout)::sumcheck
    logical,intent(out)::solve_ok
    type(soil_water_solve_result_t)::r
    call solve_reduced_once(r,solve_ok)
    if(.not.solve_ok)return
    call reconstruct_and_publish(r,solve_ok)
    if(solve_ok) sumcheck=sumcheck+manager_context%full_candidate%candidate_state%pressure_head(1)*1e-12_real64
  end subroutine timed_reduced_op

  function context_state_h() result(v)
    real(real64)::v(numnod)
    v=manager_context%full_candidate%candidate_state%pressure_head
  end function context_state_h

  function context_state_theta() result(v)
    real(real64)::v(numnod)
    v=manager_context%full_candidate%candidate_state%water_content
  end function context_state_theta

  real(real64) function ledger(r) result(v)
    type(soil_water_solve_result_t),intent(in)::r
    v=sum((r%candidate_state%water_content-origin%water_content)*pfull%dz) + &
         dt*(r%top_flux-r%bottom_flux)
  end function ledger

  integer function tail_identity(s) result(first)
    type(soil_water_physical_state_t),intent(in)::s
    integer::k
    logical::sat(numnod)
    sat=.false.
    do k=1,numnod
       sat(k)=s%pressure_head(k)>=0.0_real64 .and. abs(s%water_content(k)-ts)<=1e-10_real64
    end do
    first=numnod+1
    do k=numnod,1,-1
       if(sat(k))then
          first=k
       else
          exit
       end if
    end do
    if(first<=numnod)then
       if(any(sat(1:first-1))) first=-1
    end if
  end function tail_identity

  subroutine median5(v,medout)
    real(real64),intent(in)::v(nblock)
    real(real64),intent(out)::medout
    real(real64)::x(nblock),key
    integer::ii,jj
    x=v
    do ii=2,nblock
       key=x(ii);jj=ii-1
       do while(jj>=1)
          if(x(jj)<=key)exit
          x(jj+1)=x(jj);jj=jj-1
       end do
       x(jj+1)=key
    end do
    medout=x(3)
  end subroutine median5

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
       write(*,'(A,1X,A)')'F_PE_NLGLOB14Z40_FAIL',trim(msg)
       error stop 1
    end if
  end subroutine require

end program test_fpe_nlglob14z40_real_reduced_richards
