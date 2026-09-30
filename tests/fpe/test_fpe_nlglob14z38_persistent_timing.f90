program test_fpe_nlglob14z38_persistent_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_linear_solver, only: reference_tridag
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       prepare_reference_workspace_for_solve
  use mod_moving_interface_manager, only: moving_interface_active_view_t, moving_interface_manager_diagnostics_t, &
       derive_moving_interface_active_view, prepare_moving_interface_reduced_request_inplace, &
       materialize_moving_interface_full_candidate_inplace, select_moving_interface_route, MI_MANAGER_ROUTE_REDUCED
  implicit none

  integer, parameter :: nfull=16, ncase=4, nwarm=5000, nblock=10, nper=10000
  integer, parameter :: active_n(ncase)=[13,12,13,13]
  character(len=12), parameter :: case_id(ncase)=[character(len=12) :: 'O05_T13','O05_T12','O14_T13','B12_T13']
  real(real64), parameter :: coeff_scale(ncase)=[17.418504_real64,17.418504_real64,2.495984_real64,2.245895_real64]

  type(soil_water_parameter_set_t), target :: pfull_ctx(ncase), pred_ctx(ncase)
  type(soil_water_solve_request_t) :: full_req_ctx(ncase), red_req_ctx(ncase)
  type(reference_richards_workspace_t) :: red_ws_ctx(ncase)
  type(moving_interface_active_view_t) :: view_ctx(ncase)
  type(soil_water_solve_result_t) :: red_result_ctx(ncase), materialized_ctx(ncase)
  real(real64), allocatable :: tail_h_ctx(:,:), tail_th_ctx(:,:)
  real(real64) :: a_ctx(nfull,ncase), d_ctx(nfull,ncase), c_ctx(nfull,ncase)
  real(real64) :: rhs_ctx(nfull,ncase), truth_ctx(nfull,ncase)
  logical :: initialized(ncase)

  real(real64) :: full_block(nblock), reduced_block(nblock)
  real(real64) :: full_mean, reduced_mean, full_median, reduced_median, ratio
  real(real64) :: checksum_full, checksum_reduced, geom_log_sum
  real(real64) :: case_ratio(ncase), work_ratio(ncase)
  integer :: ic, ib, i, request_reallocs, candidate_reallocs
  logical :: all_ok

  initialized=.false.
  allocate(tail_h_ctx(4,ncase),tail_th_ctx(4,ncase))
  tail_h_ctx=0.0_real64
  tail_th_ctx=0.0_real64
  all_ok=.true.
  geom_log_sum=0.0_real64

  do ic=1,ncase
     checksum_full=0.0_real64
     checksum_reduced=0.0_real64
     call init_reduced_context(ic)

     do i=1,nwarm
        call run_full_once(ic,checksum_full)
        call run_reduced_once(ic,checksum_reduced,request_reallocs,candidate_reallocs)
     end do

     request_reallocs=0
     candidate_reallocs=0
     do ib=1,nblock
        call time_full_block(ic,nper,full_block(ib),checksum_full)
        call time_reduced_block(ic,nper,reduced_block(ib),checksum_reduced,request_reallocs,candidate_reallocs)
     end do

     full_mean=sum(full_block)/real(nblock,real64)
     reduced_mean=sum(reduced_block)/real(nblock,real64)
     call median10(full_block,full_median)
     call median10(reduced_block,reduced_median)
     ratio=reduced_median/full_median
     case_ratio(ic)=ratio
     work_ratio(ic)=real(active_n(ic),real64)/real(nfull,real64)
     geom_log_sum=geom_log_sum+log(ratio)

     if (.not.ieee_is_finite(checksum_full) .or. .not.ieee_is_finite(checksum_reduced)) all_ok=.false.
     if (request_reallocs/=0 .or. candidate_reallocs/=0) all_ok=.false.

     write(*,'(*(g0))') 'F_PE_NLGLOB14Z38_CASE|ID=',trim(case_id(ic)), &
          '|ACTIVE_N=',active_n(ic),'|FULL_MEDIAN_S=',full_median, &
          '|REDUCED_MEDIAN_S=',reduced_median,'|TIMING_RATIO=',ratio, &
          '|FULL_MEAN_S=',full_mean,'|REDUCED_MEAN_S=',reduced_mean, &
          '|WORK_RATIO=',work_ratio(ic),'|REQUEST_REALLOCS=',request_reallocs, &
          '|CANDIDATE_REALLOCS=',candidate_reallocs, &
          '|CHECKSUM_FULL=',checksum_full,'|CHECKSUM_REDUCED=',checksum_reduced
  end do

  ratio=exp(geom_log_sum/real(ncase,real64))
  full_mean=sum(work_ratio)/real(ncase,real64)

  if (.not.all_ok) then
     write(*,'(a)') 'F_PE_NLGLOB14Z38_RESULT={"aggregate":"Z38_PERSISTENT_MANAGER_EXECUTION_INVALID"}'
     error stop 'Z38 persistent benchmark invalid'
  end if

  if (count(case_ratio<0.95_real64)>=3 .and. ratio<0.95_real64 .and. &
      maxval(case_ratio)<=1.05_real64 .and. full_mean<=0.90_real64) then
     write(*,'(*(g0))') 'F_PE_NLGLOB14Z38_RESULT={"aggregate":"QUALIFIED_Z38_PERSISTENT_MANAGER_TIMING_GAIN",', &
          '"geomean_timing_ratio":',ratio,',"mean_work_ratio":',full_mean,'}'
  else if (ratio>=0.95_real64 .and. ratio<=1.05_real64 .and. maxval(case_ratio)<=1.10_real64) then
     write(*,'(*(g0))') 'F_PE_NLGLOB14Z38_RESULT={"aggregate":"Z38_PERSISTENT_MANAGER_TIMING_NEUTRAL",', &
          '"geomean_timing_ratio":',ratio,',"mean_work_ratio":',full_mean,'}'
  else
     write(*,'(*(g0))') 'F_PE_NLGLOB14Z38_RESULT={"aggregate":"Z38_PERSISTENT_MANAGER_TIMING_REGRESSION",', &
          '"geomean_timing_ratio":',ratio,',"mean_work_ratio":',full_mean,'}'
  end if
  write(*,'(a)') 'F_PE_NLGLOB14Z38=PASS'

contains

  subroutine setup_full_request(ic,parameters,request)
    integer,intent(in)::ic
    type(soil_water_parameter_set_t),target,intent(inout)::parameters
    type(soil_water_solve_request_t),intent(inout)::request
    integer::j
    if (.not.allocated(parameters%z)) then
       parameters%parameter_set_id=int(3800+ic,int64)
       parameters%active_nodes=nfull
       allocate(parameters%z(nfull),parameters%dz(nfull),parameters%node_distance(nfull))
       allocate(request%base_state%pressure_head(nfull),request%base_state%water_content(nfull))
    end if
    do j=1,nfull
       parameters%z(j)=-10.0_real64*real(j,real64)
       parameters%dz(j)=10.0_real64
       parameters%node_distance(j)=10.0_real64
       request%base_state%pressure_head(j)=10.0_real64*real(j-active_n(ic),real64)
       request%base_state%water_content(j)=0.20_real64+1.0e-3_real64*real(j,real64)
    end do
    request%parameters=>parameters
    request%step_duration=6.25e-5_real64
    request%base_state%active_nodes=nfull
  end subroutine setup_full_request

  subroutine coefficients(n,scale,a,d,c,rhs,truth)
    integer,intent(in)::n
    real(real64),intent(in)::scale
    real(real64),intent(out)::a(:),d(:),c(:),rhs(:),truth(:)
    integer::j
    a(1:n)=0.0_real64
    c(1:n)=0.0_real64
    d(1:n)=4.0_real64+1.0e-3_real64*scale
    do j=2,n
       a(j)=-1.0_real64
    end do
    do j=1,n-1
       c(j)=-1.0_real64
    end do
    do j=1,n
       truth(j)=real(j,real64)/real(n,real64)
       rhs(j)=d(j)*truth(j)
       if (j>1) rhs(j)=rhs(j)+a(j)*truth(j-1)
       if (j<n) rhs(j)=rhs(j)+c(j)*truth(j+1)
    end do
  end subroutine coefficients

  subroutine init_reduced_context(ic)
    integer,intent(in)::ic
    integer::n,nt
    logical::ok,reallocated
    character(len=64)::reason

    if (initialized(ic)) return
    n=active_n(ic)
    nt=nfull-n
    call setup_full_request(ic,pfull_ctx(ic),full_req_ctx(ic))
    call derive_moving_interface_active_view(full_req_ctx(ic)%base_state,n,view_ctx(ic),ok,reason)
    if (.not.ok) error stop 'Z38 active view init failed'
    call prepare_moving_interface_reduced_request_inplace(full_req_ctx(ic),view_ctx(ic),pred_ctx(ic), &
         red_req_ctx(ic),ok,reason,reallocated)
    if (.not.ok) error stop 'Z38 reduced request init failed'
    call initialize_reference_workspace(red_ws_ctx(ic),n)
    call coefficients(n,coeff_scale(ic),a_ctx(:,ic),d_ctx(:,ic),c_ctx(:,ic),rhs_ctx(:,ic),truth_ctx(:,ic))

    red_result_ctx(ic)%status=SW_SOLVE_CONVERGED
    red_result_ctx(ic)%candidate_state%active_nodes=n
    allocate(red_result_ctx(ic)%candidate_state%pressure_head(n),red_result_ctx(ic)%candidate_state%water_content(n))
    red_result_ctx(ic)%candidate_state%water_content=red_req_ctx(ic)%base_state%water_content
    tail_h_ctx(1:nt,ic)=full_req_ctx(ic)%base_state%pressure_head(n+1:nfull)
    tail_th_ctx(1:nt,ic)=full_req_ctx(ic)%base_state%water_content(n+1:nfull)

    ! Prime full-candidate storage so measured blocks should never allocate it.
    red_result_ctx(ic)%candidate_state%pressure_head=red_req_ctx(ic)%base_state%pressure_head
    call materialize_moving_interface_full_candidate_inplace(full_req_ctx(ic)%base_state,red_result_ctx(ic), &
         tail_h_ctx(1:nt,ic),tail_th_ctx(1:nt,ic),materialized_ctx(ic),ok,reason,reallocated)
    if (.not.ok) error stop 'Z38 candidate prime failed'
    initialized(ic)=.true.
  end subroutine init_reduced_context

  subroutine run_full_once(ic,checksum)
    integer,intent(in)::ic
    real(real64),intent(inout)::checksum
    type(reference_richards_workspace_t) :: ws
    type(soil_water_parameter_set_t),target :: p
    type(soil_water_solve_request_t) :: req
    type(soil_water_solve_result_t) :: candidate
    real(real64) :: a(nfull),d(nfull),c(nfull),rhs(nfull),truth(nfull),x(nfull),gamma(nfull)
    integer::ierror,j

    ! Keep the exact Z37 full path, including request/workspace/candidate setup.
    p%parameter_set_id=int(3700+ic,int64)
    p%active_nodes=nfull
    allocate(p%z(nfull),p%dz(nfull),p%node_distance(nfull))
    req%parameters=>p
    req%step_duration=6.25e-5_real64
    req%base_state%active_nodes=nfull
    allocate(req%base_state%pressure_head(nfull),req%base_state%water_content(nfull))
    do j=1,nfull
       p%z(j)=-10.0_real64*real(j,real64)
       p%dz(j)=10.0_real64
       p%node_distance(j)=10.0_real64
       req%base_state%pressure_head(j)=10.0_real64*real(j-active_n(ic),real64)
       req%base_state%water_content(j)=0.20_real64+1.0e-3_real64*real(j,real64)
    end do
    call initialize_reference_workspace(ws,nfull)
    call prepare_reference_workspace_for_solve(ws,nfull)
    call coefficients(nfull,coeff_scale(ic),a,d,c,rhs,truth)
    call reference_tridag(nfull,a,d,c,rhs,x,gamma,ierror)
    if (ierror/=0) error stop 'Z38 full tridag failed'
    candidate%status=SW_SOLVE_CONVERGED
    candidate%candidate_state%active_nodes=nfull
    allocate(candidate%candidate_state%pressure_head(nfull),candidate%candidate_state%water_content(nfull))
    candidate%candidate_state%pressure_head=req%base_state%pressure_head+1.0e-6_real64*x
    candidate%candidate_state%water_content=req%base_state%water_content
    checksum=checksum+x(1)+x(nfull)+candidate%candidate_state%pressure_head(1)
  end subroutine run_full_once

  subroutine run_reduced_once(ic,checksum,request_reallocs,candidate_reallocs)
    integer,intent(in)::ic
    real(real64),intent(inout)::checksum
    integer,intent(inout)::request_reallocs,candidate_reallocs
    integer::n,nt,ierror
    real(real64)::x(nfull),gamma(nfull)
    logical::ok,reallocated,use_reduced
    character(len=64)::reason
    type(moving_interface_manager_diagnostics_t)::diag

    n=active_n(ic)
    nt=nfull-n
    call derive_moving_interface_active_view(full_req_ctx(ic)%base_state,n,view_ctx(ic),ok,reason)
    if (.not.ok) error stop 'Z38 active view failed'
    call prepare_moving_interface_reduced_request_inplace(full_req_ctx(ic),view_ctx(ic),pred_ctx(ic), &
         red_req_ctx(ic),ok,reason,reallocated)
    if (.not.ok) error stop 'Z38 reduced request failed'
    if (reallocated) request_reallocs=request_reallocs+1
    call prepare_reference_workspace_for_solve(red_ws_ctx(ic),n)

    call reference_tridag(n,a_ctx(:,ic),d_ctx(:,ic),c_ctx(:,ic),rhs_ctx(:,ic),x,gamma,ierror)
    if (ierror/=0) error stop 'Z38 reduced tridag failed'
    red_result_ctx(ic)%candidate_state%pressure_head=red_req_ctx(ic)%base_state%pressure_head+1.0e-6_real64*x(1:n)
    red_result_ctx(ic)%candidate_state%water_content=red_req_ctx(ic)%base_state%water_content

    call materialize_moving_interface_full_candidate_inplace(full_req_ctx(ic)%base_state,red_result_ctx(ic), &
         tail_h_ctx(1:nt,ic),tail_th_ctx(1:nt,ic),materialized_ctx(ic),ok,reason,reallocated)
    if (.not.ok) error stop 'Z38 materialization failed'
    if (reallocated) candidate_reallocs=candidate_reallocs+1

    call select_moving_interface_route(red_result_ctx(ic)%status,.true.,view_ctx(ic),red_ws_ctx(ic)%generation, &
         'none',use_reduced,diag)
    if (.not.use_reduced .or. diag%route/=MI_MANAGER_ROUTE_REDUCED) error stop 'Z38 reduced route failed'
    checksum=checksum+x(1)+x(n)+materialized_ctx(ic)%candidate_state%pressure_head(1)
  end subroutine run_reduced_once

  subroutine time_full_block(ic,niter,seconds_per_op,checksum)
    integer,intent(in)::ic,niter
    real(real64),intent(out)::seconds_per_op
    real(real64),intent(inout)::checksum
    real(real64)::t0,t1
    integer::j
    call cpu_time(t0)
    do j=1,niter
       call run_full_once(ic,checksum)
    end do
    call cpu_time(t1)
    seconds_per_op=(t1-t0)/real(niter,real64)
  end subroutine time_full_block

  subroutine time_reduced_block(ic,niter,seconds_per_op,checksum,request_reallocs,candidate_reallocs)
    integer,intent(in)::ic,niter
    real(real64),intent(out)::seconds_per_op
    real(real64),intent(inout)::checksum
    integer,intent(inout)::request_reallocs,candidate_reallocs
    real(real64)::t0,t1
    integer::j
    call cpu_time(t0)
    do j=1,niter
       call run_reduced_once(ic,checksum,request_reallocs,candidate_reallocs)
    end do
    call cpu_time(t1)
    seconds_per_op=(t1-t0)/real(niter,real64)
  end subroutine time_reduced_block

  subroutine median10(values,med)
    real(real64),intent(in)::values(nblock)
    real(real64),intent(out)::med
    real(real64)::tmp(nblock),v
    integer::i,j
    tmp=values
    do i=2,nblock
       v=tmp(i)
       j=i-1
       do while(j>=1)
          if (tmp(j)<=v) exit
          tmp(j+1)=tmp(j)
          j=j-1
       end do
       tmp(j+1)=v
    end do
    med=0.5_real64*(tmp(nblock/2)+tmp(nblock/2+1))
  end subroutine median10

end program test_fpe_nlglob14z38_persistent_timing
