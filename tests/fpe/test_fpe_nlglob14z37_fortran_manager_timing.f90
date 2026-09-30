program test_fpe_nlglob14z37_fortran_manager_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace, &
       prepare_reference_workspace_for_solve
  use mod_reference_linear_solver, only: reference_tridag
  use mod_moving_interface_manager, only: moving_interface_active_view_t, moving_interface_manager_diagnostics_t, &
       derive_moving_interface_active_view, build_moving_interface_reduced_request, &
       materialize_moving_interface_full_candidate, choose_moving_interface_result
  implicit none

  integer, parameter :: nf=16, ncase=4, nblock=10, nrep=10000, nwarm=5000
  integer, parameter :: active_n(ncase)=[13,12,13,13]
  character(len=16), parameter :: case_id(ncase)=[character(len=16) :: 'O05_T13','O05_T12','O14_T13','B12_T13']
  real(real64) :: ratios(ncase), med_full(ncase), med_red(ncase), mean_full(ncase), mean_red(ncase)
  real(real64) :: checksum, geom
  integer :: ic
  logical :: all_ok

  all_ok=.true.
  checksum=0.0_real64
  do ic=1,ncase
     call benchmark_case(case_id(ic),active_n(ic),ratios(ic),med_full(ic),med_red(ic), &
          mean_full(ic),mean_red(ic),checksum,all_ok)
  end do
  geom=exp(sum(log(ratios))/real(ncase,real64))

  write(*,'(*(g0))') 'F_PE_NLGLOB14Z37_SUMMARY|GEOMEAN_RATIO=',geom,'|CHECKSUM=',checksum
  if (.not.all_ok) then
     write(*,'(a)') 'F_PE_NLGLOB14Z37_RESULT={"classification":"Z37_TIMING_EXECUTION_INVALID"}'
     error stop 'Z37 correctness failed'
  else if (geom>1.05_real64 .or. any(ratios>1.10_real64)) then
     write(*,'(a)') 'F_PE_NLGLOB14Z37_RESULT={"classification":"Z37_FORTRAN_TIMING_REGRESSION"}'
  else if (geom>=0.95_real64 .or. count(ratios<0.95_real64)<3) then
     write(*,'(a)') 'F_PE_NLGLOB14Z37_RESULT={"classification":"Z37_FORTRAN_TIMING_NEUTRAL"}'
  else
     write(*,'(a)') 'F_PE_NLGLOB14Z37_RESULT={"classification":"QUALIFIED_Z37_FORTRAN_TIMING_GAIN"}'
  end if
  write(*,'(a)') 'F_PE_NLGLOB14Z37=PASS'

contains

  subroutine benchmark_case(id,n,ratio,full_median,red_median,full_mean,red_mean,checksum,ok_all)
    character(len=*), intent(in) :: id
    integer, intent(in) :: n
    real(real64), intent(out) :: ratio,full_median,red_median,full_mean,red_mean
    real(real64), intent(inout) :: checksum
    logical, intent(inout) :: ok_all

    type(soil_water_parameter_set_t), target :: full_parameters, reduced_parameters
    type(soil_water_solve_request_t) :: full_request, reduced_request
    type(soil_water_solve_result_t) :: full_result, reduced_result, materialized, selected
    type(reference_richards_workspace_t) :: full_ws, red_ws
    type(moving_interface_active_view_t) :: view
    type(moving_interface_manager_diagnostics_t) :: diag
    real(real64) :: a(nf),bb(nf),c(nf),rhs(nf),u(nf),gamma(nf)
    real(real64) :: tail_h(nf),tail_th(nf)
    real(real64) :: tf(nblock),tr(nblock),t0,t1,tmp
    real(real64) :: residual_max
    character(len=96) :: reason
    logical :: vok
    integer :: i,j,ib,ierr,tail_count

    full_parameters%parameter_set_id=3700_int64+n
    full_parameters%active_nodes=nf
    allocate(full_parameters%z(nf),full_parameters%dz(nf),full_parameters%node_distance(nf))
    do i=1,nf
       full_parameters%z(i)=-10.0_real64*real(i,real64)
       full_parameters%dz(i)=10.0_real64
       full_parameters%node_distance(i)=10.0_real64
    end do
    full_request%parameters=>full_parameters
    full_request%step_duration=6.25e-5_real64
    full_request%base_state%active_nodes=nf
    allocate(full_request%base_state%pressure_head(nf),full_request%base_state%water_content(nf))
    do i=1,nf
       full_request%base_state%pressure_head(i)=10.0_real64*real(i-n,real64)
       full_request%base_state%water_content(i)=merge(0.4_real64,0.2_real64,i>=n)
    end do

    call derive_moving_interface_active_view(full_request%base_state,n,view,vok,reason)
    if (.not.vok .or. .not.view%eligible .or. view%active_nodes/=n) ok_all=.false.
    call build_moving_interface_reduced_request(full_request,view,reduced_parameters,reduced_request,vok,reason)
    if (.not.vok) ok_all=.false.

    call initialize_reference_workspace(full_ws,nf)
    call initialize_reference_workspace(red_ws,n)

    full_result%status=SW_SOLVE_CONVERGED
    full_result%candidate_state%active_nodes=nf
    allocate(full_result%candidate_state%pressure_head(nf),full_result%candidate_state%water_content(nf))
    full_result%candidate_state%water_content=full_request%base_state%water_content

    reduced_result%status=SW_SOLVE_CONVERGED
    reduced_result%candidate_state%active_nodes=n
    allocate(reduced_result%candidate_state%pressure_head(n),reduced_result%candidate_state%water_content(n))
    reduced_result%candidate_state%water_content=full_request%base_state%water_content(1:n)

    tail_count=nf-n
    do i=1,tail_count
       tail_h(i)=10.0_real64*real(i,real64)
       tail_th(i)=0.4_real64
    end do

    a=0.0_real64;bb=4.0_real64;c=0.0_real64
    do i=2,nf
       a(i)=-1.0_real64
    end do
    do i=1,nf-1
       c(i)=-1.0_real64
    end do
    do i=1,nf
       rhs(i)=2.0_real64+0.01_real64*real(i+n,real64)
    end do

    call reference_tridag(nf,a,bb,c,rhs,u,gamma,ierr)
    if (ierr/=0) ok_all=.false.
    residual_max=linear_residual(nf,a,bb,c,rhs,u)
    if (residual_max>1e-12_real64) ok_all=.false.
    call reference_tridag(n,a,bb,c,rhs,u,gamma,ierr)
    if (ierr/=0) ok_all=.false.
    residual_max=max(residual_max,linear_residual(n,a,bb,c,rhs,u))
    if (residual_max>1e-12_real64) ok_all=.false.

    do j=1,nwarm
       call full_op(n,a,bb,c,rhs,full_ws,full_result,checksum)
       call reduced_op(n,a,bb,c,rhs,red_ws,full_request,reduced_parameters,reduced_request, &
            reduced_result,tail_h(1:tail_count),tail_th(1:tail_count),view,materialized,selected,diag,checksum)
    end do

    do ib=1,nblock
       if (mod(ib,2)==1) then
          call cpu_time(t0)
          do j=1,nrep
             call full_op(n,a,bb,c,rhs,full_ws,full_result,checksum)
          end do
          call cpu_time(t1); tf(ib)=(t1-t0)/real(nrep,real64)
          call cpu_time(t0)
          do j=1,nrep
             call reduced_op(n,a,bb,c,rhs,red_ws,full_request,reduced_parameters,reduced_request, &
                  reduced_result,tail_h(1:tail_count),tail_th(1:tail_count),view,materialized,selected,diag,checksum)
          end do
          call cpu_time(t1); tr(ib)=(t1-t0)/real(nrep,real64)
       else
          call cpu_time(t0)
          do j=1,nrep
             call reduced_op(n,a,bb,c,rhs,red_ws,full_request,reduced_parameters,reduced_request, &
                  reduced_result,tail_h(1:tail_count),tail_th(1:tail_count),view,materialized,selected,diag,checksum)
          end do
          call cpu_time(t1); tr(ib)=(t1-t0)/real(nrep,real64)
          call cpu_time(t0)
          do j=1,nrep
             call full_op(n,a,bb,c,rhs,full_ws,full_result,checksum)
          end do
          call cpu_time(t1); tf(ib)=(t1-t0)/real(nrep,real64)
       end if
    end do

    full_mean=sum(tf)/real(nblock,real64)
    red_mean=sum(tr)/real(nblock,real64)
    call sort_small(tf)
    call sort_small(tr)
    full_median=0.5_real64*(tf(5)+tf(6))
    red_median=0.5_real64*(tr(5)+tr(6))
    ratio=red_median/full_median

    write(*,'(*(g0))') 'F_PE_NLGLOB14Z37_CASE|ID=',trim(id),'|N=',n, &
         '|FULL_MEDIAN=',full_median,'|RED_MEDIAN=',red_median,'|RATIO=',ratio, &
         '|FULL_MEAN=',full_mean,'|RED_MEAN=',red_mean,'|WORK_RATIO=',real(n,real64)/16.0_real64, &
         '|RESIDUAL=',residual_max
  end subroutine benchmark_case

  subroutine full_op(n,a,bb,c,rhs,ws,result,checksum)
    integer, intent(in) :: n
    real(real64), intent(in) :: a(:),bb(:),c(:),rhs(:)
    type(reference_richards_workspace_t), intent(inout) :: ws
    type(soil_water_solve_result_t), intent(inout) :: result
    real(real64), intent(inout) :: checksum
    integer :: ierr
    call prepare_reference_workspace_for_solve(ws,nf)
    call reference_tridag(nf,a,bb,c,rhs,ws%delta_head,ws%tridag_gamma,ierr)
    result%candidate_state%pressure_head=ws%delta_head(1:nf)
    checksum=checksum+result%candidate_state%pressure_head(mod(n,16)+1)*1e-12_real64+real(ierr,real64)
  end subroutine full_op

  subroutine reduced_op(n,a,bb,c,rhs,ws,full_request,reduced_parameters,reduced_request,reduced_result, &
                        tail_h,tail_th,view,materialized,selected,diag,checksum)
    integer, intent(in) :: n
    real(real64), intent(in) :: a(:),bb(:),c(:),rhs(:),tail_h(:),tail_th(:)
    type(reference_richards_workspace_t), intent(inout) :: ws
    type(soil_water_solve_request_t), intent(in) :: full_request
    type(soil_water_parameter_set_t), target, intent(inout) :: reduced_parameters
    type(soil_water_solve_request_t), intent(inout) :: reduced_request
    type(soil_water_solve_result_t), intent(inout) :: reduced_result,materialized,selected
    type(moving_interface_active_view_t), intent(in) :: view
    type(moving_interface_manager_diagnostics_t), intent(inout) :: diag
    real(real64), intent(inout) :: checksum
    integer :: ierr
    logical :: ok
    character(len=96) :: reason

    call build_moving_interface_reduced_request(full_request,view,reduced_parameters,reduced_request,ok,reason)
    if (.not.ok) error stop 'Z37 reduced request build failed'
    call prepare_reference_workspace_for_solve(ws,n)
    call reference_tridag(n,a,bb,c,rhs,ws%delta_head,ws%tridag_gamma,ierr)
    if (ierr/=0) error stop 'Z37 reduced tridag failed'
    reduced_result%candidate_state%pressure_head=ws%delta_head(1:n)
    call materialize_moving_interface_full_candidate(full_request%base_state,reduced_result,tail_h,tail_th, &
         materialized,ok,reason)
    if (.not.ok) error stop 'Z37 materialization failed'
    call choose_moving_interface_result(materialized,materialized,.true.,view,ws%generation,'none',selected,diag)
    checksum=checksum+selected%candidate_state%pressure_head(mod(n,16)+1)*1e-12_real64
  end subroutine reduced_op

  real(real64) function linear_residual(n,a,bb,c,rhs,u) result(mx)
    integer, intent(in) :: n
    real(real64), intent(in) :: a(:),bb(:),c(:),rhs(:),u(:)
    real(real64) :: r
    integer :: i
    mx=0.0_real64
    do i=1,n
       r=bb(i)*u(i)-rhs(i)
       if (i>1) r=r+a(i)*u(i-1)
       if (i<n) r=r+c(i)*u(i+1)
       mx=max(mx,abs(r))
    end do
  end function linear_residual

  subroutine sort_small(x)
    real(real64), intent(inout) :: x(:)
    real(real64) :: key
    integer :: i,j
    do i=2,size(x)
       key=x(i);j=i-1
       do while(j>=1 .and. x(j)>key)
          x(j+1)=x(j);j=j-1
       end do
       x(j+1)=key
    end do
  end subroutine sort_small

end program test_fpe_nlglob14z37_fortran_manager_timing
