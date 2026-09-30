program test_fpe_nlglob14z37_fortran_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_linear_solver, only: reference_tridag
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       prepare_reference_workspace_for_solve
  use mod_moving_interface_manager, only: moving_interface_active_view_t, moving_interface_manager_diagnostics_t, &
       derive_moving_interface_active_view, build_moving_interface_reduced_request, &
       materialize_moving_interface_full_candidate, choose_moving_interface_result, MI_MANAGER_ROUTE_REDUCED
  implicit none

  integer, parameter :: nfull=16, ncase=4, nwarm=5000, nblock=10, nper=10000
  integer, parameter :: active_n(ncase)=[13,12,13,13]
  character(len=12), parameter :: case_id(ncase)=[character(len=12) :: 'O05_T13','O05_T12','O14_T13','B12_T13']
  real(real64), parameter :: coeff_scale(ncase)=[17.418504_real64,17.418504_real64,2.495984_real64,2.245895_real64]

  real(real64) :: full_block(nblock), reduced_block(nblock)
  real(real64) :: full_mean, reduced_mean, full_median, reduced_median, ratio
  real(real64) :: checksum_full, checksum_reduced, geom_log_sum
  real(real64) :: case_ratio(ncase), work_ratio(ncase)
  integer :: ic, ib, i
  logical :: all_ok

  all_ok=.true.
  geom_log_sum=0.0_real64

  do ic=1,ncase
     checksum_full=0.0_real64
     checksum_reduced=0.0_real64

     do i=1,nwarm
        call run_full_once(ic,checksum_full)
        call run_reduced_once(ic,checksum_reduced)
     end do

     do ib=1,nblock
        call time_full_block(ic,nper,full_block(ib),checksum_full)
        call time_reduced_block(ic,nper,reduced_block(ib),checksum_reduced)
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

     write(*,'(*(g0))') 'F_PE_NLGLOB14Z37_CASE|ID=',trim(case_id(ic)), &
          '|ACTIVE_N=',active_n(ic),'|FULL_MEDIAN_S=',full_median, &
          '|REDUCED_MEDIAN_S=',reduced_median,'|TIMING_RATIO=',ratio, &
          '|FULL_MEAN_S=',full_mean,'|REDUCED_MEAN_S=',reduced_mean, &
          '|WORK_RATIO=',work_ratio(ic),'|CHECKSUM_FULL=',checksum_full, &
          '|CHECKSUM_REDUCED=',checksum_reduced
  end do

  ratio=exp(geom_log_sum/real(ncase,real64))
  full_mean=sum(work_ratio)/real(ncase,real64)

  if (.not.all_ok) then
     write(*,'(a)') 'F_PE_NLGLOB14Z37_RESULT={"aggregate":"Z37_TIMING_EXECUTION_INVALID"}'
     error stop 'Z37 checksum invalid'
  end if

  if (count(case_ratio<0.95_real64)>=3 .and. ratio<0.95_real64 .and. &
      maxval(case_ratio)<=1.05_real64 .and. full_mean<=0.90_real64) then
     write(*,'(*(g0))') 'F_PE_NLGLOB14Z37_RESULT={"aggregate":"QUALIFIED_Z37_FORTRAN_TIMING_GAIN",', &
          '"geomean_timing_ratio":',ratio,',"mean_work_ratio":',full_mean,'}'
  else if (ratio>=0.95_real64 .and. ratio<=1.05_real64 .and. maxval(case_ratio)<=1.10_real64) then
     write(*,'(*(g0))') 'F_PE_NLGLOB14Z37_RESULT={"aggregate":"Z37_FORTRAN_TIMING_NEUTRAL",', &
          '"geomean_timing_ratio":',ratio,',"mean_work_ratio":',full_mean,'}'
  else
     write(*,'(*(g0))') 'F_PE_NLGLOB14Z37_RESULT={"aggregate":"Z37_FORTRAN_TIMING_REGRESSION",', &
          '"geomean_timing_ratio":',ratio,',"mean_work_ratio":',full_mean,'}'
  end if
  write(*,'(a)') 'F_PE_NLGLOB14Z37=PASS'

contains

  subroutine setup_full_request(ic,parameters,request)
    integer,intent(in)::ic
    type(soil_water_parameter_set_t),target,intent(out)::parameters
    type(soil_water_solve_request_t),intent(out)::request
    integer::j
    parameters=soil_water_parameter_set_t()
    parameters%parameter_set_id=int(3700+ic,int64)
    parameters%active_nodes=nfull
    allocate(parameters%z(nfull),parameters%dz(nfull),parameters%node_distance(nfull))
    do j=1,nfull
       parameters%z(j)=-10.0_real64*real(j,real64)
       parameters%dz(j)=10.0_real64
       parameters%node_distance(j)=10.0_real64
    end do
    request=soil_water_solve_request_t()
    request%parameters=>parameters
    request%step_duration=6.25e-5_real64
    request%base_state%active_nodes=nfull
    allocate(request%base_state%pressure_head(nfull),request%base_state%water_content(nfull))
    do j=1,nfull
       request%base_state%pressure_head(j)=10.0_real64*real(j-active_n(ic),real64)
       request%base_state%water_content(j)=0.20_real64+1.0e-3_real64*real(j,real64)
    end do
  end subroutine setup_full_request

  subroutine coefficients(n,scale,a,d,c,rhs,truth)
    integer,intent(in)::n
    real(real64),intent(in)::scale
    real(real64),intent(out)::a(n),d(n),c(n),rhs(n),truth(n)
    integer::j
    a=0.0_real64
    c=0.0_real64
    d=4.0_real64+1.0e-3_real64*scale
    do j=2,n
       a(j)=-1.0_real64
    end do
    do j=1,n-1
       c(j)=-1.0_real64
    end do
    do j=1,n
       truth(j)=real(j,real64)/real(n,real64)
    end do
    rhs=d*truth
    do j=1,n
       if (j>1) rhs(j)=rhs(j)+a(j)*truth(j-1)
       if (j<n) rhs(j)=rhs(j)+c(j)*truth(j+1)
    end do
  end subroutine coefficients

  subroutine run_full_once(ic,checksum)
    integer,intent(in)::ic
    real(real64),intent(inout)::checksum
    type(reference_richards_workspace_t) :: ws
    type(soil_water_parameter_set_t),target :: p
    type(soil_water_solve_request_t) :: req
    type(soil_water_solve_result_t) :: candidate
    real(real64) :: a(nfull),d(nfull),c(nfull),rhs(nfull),truth(nfull),x(nfull),gamma(nfull)
    integer::ierror

    call setup_full_request(ic,p,req)
    call initialize_reference_workspace(ws,nfull)
    call prepare_reference_workspace_for_solve(ws,nfull)
    call coefficients(nfull,coeff_scale(ic),a,d,c,rhs,truth)
    call reference_tridag(nfull,a,d,c,rhs,x,gamma,ierror)
    if (ierror/=0) error stop 'Z37 full tridag failed'

    candidate%status=SW_SOLVE_CONVERGED
    candidate%candidate_state%active_nodes=nfull
    allocate(candidate%candidate_state%pressure_head(nfull),candidate%candidate_state%water_content(nfull))
    candidate%candidate_state%pressure_head=req%base_state%pressure_head
    candidate%candidate_state%pressure_head=candidate%candidate_state%pressure_head+1.0e-6_real64*x
    candidate%candidate_state%water_content=req%base_state%water_content
    checksum=checksum+x(1)+x(nfull)+candidate%candidate_state%pressure_head(1)
  end subroutine run_full_once

  subroutine run_reduced_once(ic,checksum)
    integer,intent(in)::ic
    real(real64),intent(inout)::checksum
    integer::n,ierror,nt
    type(reference_richards_workspace_t) :: ws
    type(soil_water_parameter_set_t),target :: pfull,pred
    type(soil_water_solve_request_t) :: full_req,red_req
    type(soil_water_solve_result_t) :: red_result,materialized,full_stub,selected
    type(moving_interface_active_view_t) :: view
    type(moving_interface_manager_diagnostics_t) :: diag
    logical::ok
    character(len=64)::reason
    real(real64),allocatable :: a(:),d(:),c(:),rhs(:),truth(:),x(:),gamma(:),tail_h(:),tail_th(:)

    n=active_n(ic)
    nt=nfull-n
    call setup_full_request(ic,pfull,full_req)
    call derive_moving_interface_active_view(full_req%base_state,n,view,ok,reason)
    if (.not.ok) error stop 'Z37 active view failed'
    call build_moving_interface_reduced_request(full_req,view,pred,red_req,ok,reason)
    if (.not.ok) error stop 'Z37 reduced request failed'
    call initialize_reference_workspace(ws,n)
    call prepare_reference_workspace_for_solve(ws,n)

    allocate(a(n),d(n),c(n),rhs(n),truth(n),x(n),gamma(n))
    call coefficients(n,coeff_scale(ic),a,d,c,rhs,truth)
    call reference_tridag(n,a,d,c,rhs,x,gamma,ierror)
    if (ierror/=0) error stop 'Z37 reduced tridag failed'

    red_result%status=SW_SOLVE_CONVERGED
    red_result%candidate_state%active_nodes=n
    allocate(red_result%candidate_state%pressure_head(n),red_result%candidate_state%water_content(n))
    red_result%candidate_state%pressure_head=red_req%base_state%pressure_head+1.0e-6_real64*x
    red_result%candidate_state%water_content=red_req%base_state%water_content

    allocate(tail_h(nt),tail_th(nt))
    tail_h=full_req%base_state%pressure_head(n+1:nfull)
    tail_th=full_req%base_state%water_content(n+1:nfull)
    call materialize_moving_interface_full_candidate(full_req%base_state,red_result,tail_h,tail_th,materialized,ok,reason)
    if (.not.ok) error stop 'Z37 materialization failed'

    full_stub=materialized
    call choose_moving_interface_result(full_stub,materialized,.true.,view,ws%generation,'none',selected,diag)
    if (diag%route/=1) error stop 'Z37 reduced manager route failed'
    checksum=checksum+x(1)+x(n)+selected%candidate_state%pressure_head(1)
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

  subroutine time_reduced_block(ic,niter,seconds_per_op,checksum)
    integer,intent(in)::ic,niter
    real(real64),intent(out)::seconds_per_op
    real(real64),intent(inout)::checksum
    real(real64)::t0,t1
    integer::j
    call cpu_time(t0)
    do j=1,niter
       call run_reduced_once(ic,checksum)
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

end program test_fpe_nlglob14z37_fortran_timing
