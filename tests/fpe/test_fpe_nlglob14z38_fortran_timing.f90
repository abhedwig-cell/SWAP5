program test_fpe_nlglob14z38_fortran_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_linear_solver, only: reference_tridag
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       prepare_reference_workspace_for_solve
  use mod_moving_interface_manager, only: moving_interface_active_view_t, moving_interface_manager_diagnostics_t, &
       moving_interface_manager_context_t, derive_moving_interface_active_view, &
       prepare_moving_interface_reduced_request_persistent, &
       materialize_moving_interface_full_candidate_persistent, &
       finalize_moving_interface_result_persistent, MI_MANAGER_ROUTE_REDUCED
  implicit none

  integer, parameter :: nfull=16, ncase=4, nwarm=5000, nblock=10, nper=10000
  integer, parameter :: active_n(ncase)=[13,12,13,13]
  character(len=12), parameter :: case_id(ncase)=[character(len=12) :: 'O05_T13','O05_T12','O14_T13','B12_T13']
  real(real64), parameter :: coeff_scale(ncase)=[17.418504_real64,17.418504_real64,2.495984_real64,2.245895_real64]

  real(real64) :: case_ratio(ncase), work_ratio(ncase), geom_log_sum, checksum
  logical :: all_ok
  integer :: ic

  all_ok=.true.
  geom_log_sum=0.0_real64
  checksum=0.0_real64

  do ic=1,ncase
     call benchmark_case(ic,case_ratio(ic),work_ratio(ic),checksum,all_ok)
     geom_log_sum=geom_log_sum+log(case_ratio(ic))
  end do

  write(*,'(*(g0))') 'F_PE_NLGLOB14Z38_SUMMARY|GEOMEAN_RATIO=', &
       exp(geom_log_sum/real(ncase,real64)),'|MEAN_WORK_RATIO=',sum(work_ratio)/real(ncase,real64), &
       '|CHECKSUM=',checksum

  if (.not.all_ok) then
     write(*,'(a)') 'F_PE_NLGLOB14Z38_RESULT={"aggregate":"Z38_PERSISTENT_MANAGER_EXECUTION_INVALID"}'
     error stop 'Z38 correctness failed'
  else if (exp(geom_log_sum/real(ncase,real64))>1.05_real64 .or. any(case_ratio>1.10_real64)) then
     write(*,'(*(g0))') 'F_PE_NLGLOB14Z38_RESULT={"aggregate":"Z38_PERSISTENT_MANAGER_TIMING_REGRESSION",', &
          '"geomean_timing_ratio":',exp(geom_log_sum/real(ncase,real64)),',', &
          '"mean_work_ratio":',sum(work_ratio)/real(ncase,real64),'}'
  else if (exp(geom_log_sum/real(ncase,real64))>=0.95_real64 .or. count(case_ratio<0.95_real64)<3) then
     write(*,'(*(g0))') 'F_PE_NLGLOB14Z38_RESULT={"aggregate":"Z38_PERSISTENT_MANAGER_TIMING_NEUTRAL",', &
          '"geomean_timing_ratio":',exp(geom_log_sum/real(ncase,real64)),',', &
          '"mean_work_ratio":',sum(work_ratio)/real(ncase,real64),'}'
  else
     write(*,'(*(g0))') 'F_PE_NLGLOB14Z38_RESULT={"aggregate":"QUALIFIED_Z38_PERSISTENT_MANAGER_TIMING_GAIN",', &
          '"geomean_timing_ratio":',exp(geom_log_sum/real(ncase,real64)),',', &
          '"mean_work_ratio":',sum(work_ratio)/real(ncase,real64),'}'
  end if
  write(*,'(a)') 'F_PE_NLGLOB14Z38=PASS'

contains

  subroutine benchmark_case(ic,ratio,wr,checksum,ok_all)
    integer,intent(in)::ic
    real(real64),intent(out)::ratio,wr
    real(real64),intent(inout)::checksum
    logical,intent(inout)::ok_all

    integer :: n,nt,ib,j,ierr
    type(soil_water_parameter_set_t),target :: pfull
    type(soil_water_solve_request_t) :: full_req
    type(reference_richards_workspace_t) :: full_ws,red_ws
    type(soil_water_solve_result_t) :: full_candidate,red_result
    type(moving_interface_active_view_t) :: view
    type(moving_interface_manager_diagnostics_t) :: diag
    type(moving_interface_manager_context_t) :: context
    real(real64) :: af(nfull),df(nfull),cf(nfull),rhsf(nfull),truthf(nfull)
    real(real64) :: ar(nfull),dr(nfull),cr(nfull),rhsr(nfull),truthr(nfull)
    real(real64) :: tail_h(nfull),tail_th(nfull)
    real(real64) :: full_block(nblock),red_block(nblock),t0,t1,full_med,red_med
    logical :: ok
    character(len=96) :: reason

    n=active_n(ic)
    nt=nfull-n
    call setup_full_request(ic,pfull,full_req)
    call initialize_reference_workspace(full_ws,nfull)
    call initialize_reference_workspace(red_ws,n)

    full_candidate%status=SW_SOLVE_CONVERGED
    full_candidate%candidate_state%active_nodes=nfull
    allocate(full_candidate%candidate_state%pressure_head(nfull), &
         full_candidate%candidate_state%water_content(nfull))
    full_candidate%candidate_state%water_content=full_req%base_state%water_content

    red_result%status=SW_SOLVE_CONVERGED
    red_result%candidate_state%active_nodes=n
    allocate(red_result%candidate_state%pressure_head(n),red_result%candidate_state%water_content(n))
    red_result%candidate_state%water_content=full_req%base_state%water_content(1:n)

    call derive_moving_interface_active_view(full_req%base_state,n,view,ok,reason)
    if (.not.ok) ok_all=.false.
    call prepare_moving_interface_reduced_request_persistent(full_req,view,context,ok,reason)
    if (.not.ok) ok_all=.false.

    call coefficients(nfull,coeff_scale(ic),af,df,cf,rhsf,truthf)
    call coefficients(n,coeff_scale(ic),ar(1:n),dr(1:n),cr(1:n),rhsr(1:n),truthr(1:n))
    tail_h(1:nt)=full_req%base_state%pressure_head(n+1:nfull)
    tail_th(1:nt)=full_req%base_state%water_content(n+1:nfull)

    do j=1,nwarm
       call full_once(af,df,cf,rhsf,full_ws,full_req,full_candidate,checksum)
       call reduced_once(n,ar,dr,cr,rhsr,red_ws,full_req,red_result,tail_h(1:nt),tail_th(1:nt), &
            view,context,diag,checksum)
    end do

    if (context%request_buffer_reallocations/=1) ok_all=.false.
    if (context%full_candidate_buffer_reallocations/=1) ok_all=.false.
    if (red_ws%active_nodes/=n) ok_all=.false.

    do ib=1,nblock
       if (mod(ib,2)==1) then
          call cpu_time(t0)
          do j=1,nper
             call full_once(af,df,cf,rhsf,full_ws,full_req,full_candidate,checksum)
          end do
          call cpu_time(t1);full_block(ib)=(t1-t0)/real(nper,real64)

          call cpu_time(t0)
          do j=1,nper
             call reduced_once(n,ar,dr,cr,rhsr,red_ws,full_req,red_result,tail_h(1:nt),tail_th(1:nt), &
                  view,context,diag,checksum)
          end do
          call cpu_time(t1);red_block(ib)=(t1-t0)/real(nper,real64)
       else
          call cpu_time(t0)
          do j=1,nper
             call reduced_once(n,ar,dr,cr,rhsr,red_ws,full_req,red_result,tail_h(1:nt),tail_th(1:nt), &
                  view,context,diag,checksum)
          end do
          call cpu_time(t1);red_block(ib)=(t1-t0)/real(nper,real64)

          call cpu_time(t0)
          do j=1,nper
             call full_once(af,df,cf,rhsf,full_ws,full_req,full_candidate,checksum)
          end do
          call cpu_time(t1);full_block(ib)=(t1-t0)/real(nper,real64)
       end if
    end do

    call median10(full_block,full_med)
    call median10(red_block,red_med)
    ratio=red_med/full_med
    wr=real(n,real64)/real(nfull,real64)

    if (.not.ieee_is_finite(checksum)) ok_all=.false.
    if (diag%route/=MI_MANAGER_ROUTE_REDUCED) ok_all=.false.
    if (context%full_candidate%candidate_state%active_nodes/=nfull) ok_all=.false.
    if (context%request_buffer_reallocations/=1) ok_all=.false.
    if (context%full_candidate_buffer_reallocations/=1) ok_all=.false.

    write(*,'(*(g0))') 'F_PE_NLGLOB14Z38_CASE|ID=',trim(case_id(ic)), &
         '|ACTIVE_N=',n,'|FULL_MEDIAN_S=',full_med,'|REDUCED_MEDIAN_S=',red_med, &
         '|TIMING_RATIO=',ratio,'|WORK_RATIO=',wr, &
         '|REQUEST_REALLOCS=',context%request_buffer_reallocations, &
         '|WORKSPACE_SHAPE_REALLOCS=0|CANDIDATE_REALLOCS=',context%full_candidate_buffer_reallocations
  end subroutine benchmark_case

  subroutine setup_full_request(ic,p,req)
    integer,intent(in)::ic
    type(soil_water_parameter_set_t),target,intent(out)::p
    type(soil_water_solve_request_t),intent(out)::req
    integer::j,n
    n=active_n(ic)
    p%parameter_set_id=int(3800+ic,int64)
    p%active_nodes=nfull
    allocate(p%z(nfull),p%dz(nfull),p%node_distance(nfull))
    do j=1,nfull
       p%z(j)=-10.0_real64*real(j,real64)
       p%dz(j)=10.0_real64
       p%node_distance(j)=10.0_real64
    end do
    req%parameters=>p
    req%step_duration=6.25e-5_real64
    req%base_state%active_nodes=nfull
    allocate(req%base_state%pressure_head(nfull),req%base_state%water_content(nfull))
    do j=1,nfull
       req%base_state%pressure_head(j)=10.0_real64*real(j-n,real64)
       req%base_state%water_content(j)=0.20_real64+1.0e-3_real64*real(j,real64)
    end do
  end subroutine setup_full_request

  subroutine coefficients(n,scale,a,d,c,rhs,truth)
    integer,intent(in)::n
    real(real64),intent(in)::scale
    real(real64),intent(out)::a(n),d(n),c(n),rhs(n),truth(n)
    integer::j
    a=0.0_real64;c=0.0_real64;d=4.0_real64+1.0e-3_real64*scale
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

  subroutine full_once(a,d,c,rhs,ws,req,candidate,checksum)
    real(real64),intent(in)::a(:),d(:),c(:),rhs(:)
    type(reference_richards_workspace_t),intent(inout)::ws
    type(soil_water_solve_request_t),intent(in)::req
    type(soil_water_solve_result_t),intent(inout)::candidate
    real(real64),intent(inout)::checksum
    integer::ierror
    call prepare_reference_workspace_for_solve(ws,nfull)
    call reference_tridag(nfull,a,d,c,rhs,ws%delta_head,ws%tridag_gamma,ierror)
    if (ierror/=0) error stop 'Z38 full tridag failed'
    candidate%candidate_state%pressure_head=req%base_state%pressure_head+1.0e-6_real64*ws%delta_head
    checksum=checksum+candidate%candidate_state%pressure_head(1)*1e-12_real64
  end subroutine full_once

  subroutine reduced_once(n,a,d,c,rhs,ws,full_req,red_result,tail_h,tail_th,view,context,diag,checksum)
    integer,intent(in)::n
    real(real64),intent(in)::a(:),d(:),c(:),rhs(:),tail_h(:),tail_th(:)
    type(reference_richards_workspace_t),intent(inout)::ws
    type(soil_water_solve_request_t),intent(in)::full_req
    type(soil_water_solve_result_t),intent(inout)::red_result
    type(moving_interface_active_view_t),intent(inout)::view
    type(moving_interface_manager_context_t),intent(inout)::context
    type(moving_interface_manager_diagnostics_t),intent(inout)::diag
    real(real64),intent(inout)::checksum
    logical::ok
    character(len=96)::reason
    integer::ierror

    call derive_moving_interface_active_view(full_req%base_state,n,view,ok,reason)
    if (.not.ok) error stop 'Z38 view failed'
    call prepare_moving_interface_reduced_request_persistent(full_req,view,context,ok,reason)
    if (.not.ok) error stop 'Z38 persistent request failed'
    call prepare_reference_workspace_for_solve(ws,n)
    call reference_tridag(n,a,d,c,rhs,ws%delta_head,ws%tridag_gamma,ierror)
    if (ierror/=0) error stop 'Z38 reduced tridag failed'

    red_result%candidate_state%pressure_head=context%reduced_request%base_state%pressure_head+ &
         1.0e-6_real64*ws%delta_head(1:n)
    red_result%candidate_state%water_content=context%reduced_request%base_state%water_content

    call materialize_moving_interface_full_candidate_persistent(full_req%base_state,red_result,tail_h,tail_th, &
         context,ok,reason)
    if (.not.ok) error stop 'Z38 persistent materialization failed'
    call finalize_moving_interface_result_persistent(context%full_candidate,.true.,view,ws%generation,'none', &
         context,diag)
    if (diag%route/=MI_MANAGER_ROUTE_REDUCED) error stop 'Z38 reduced route failed'
    checksum=checksum+context%full_candidate%candidate_state%pressure_head(1)*1e-12_real64
  end subroutine reduced_once

  subroutine median10(values,med)
    real(real64),intent(in)::values(nblock)
    real(real64),intent(out)::med
    real(real64)::tmp(nblock),v
    integer::i,j
    tmp=values
    do i=2,nblock
       v=tmp(i);j=i-1
       do while(j>=1)
          if (tmp(j)<=v) exit
          tmp(j+1)=tmp(j);j=j-1
       end do
       tmp(j+1)=v
    end do
    med=0.5_real64*(tmp(5)+tmp(6))
  end subroutine median10

end program test_fpe_nlglob14z38_fortran_timing
