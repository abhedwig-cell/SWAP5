program test_rm11_management_boundary_scheduler
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_ribasim_management_scheduler
  implicit none

  real(real64), parameter :: tol = 1.0e-9_real64
  real(real64), parameter :: a5_targets(4) = [21600.0_real64,43200.0_real64,64800.0_real64,86400.0_real64]
  real(real64), parameter :: a5_expected_advances(8) = [18000.0_real64,21600.0_real64,36000.0_real64, &
       43200.0_real64,54000.0_real64,64800.0_real64,72000.0_real64,86400.0_real64]
  real(real64), parameter :: a5_expected_solves(5) = [0.0_real64,18000.0_real64,36000.0_real64, &
       54000.0_real64,72000.0_real64]
  real(real64), parameter :: a6_targets(4) = [21600.0_real64,43200.0_real64,64800.0_real64,86400.0_real64]
  real(real64), parameter :: a6_expected_advances(4) = [21600.0_real64,43200.0_real64,64800.0_real64,86400.0_real64]
  real(real64), parameter :: a6_expected_solves(4) = [0.0_real64,21600.0_real64,43200.0_real64,64800.0_real64]

  type(fmr_ribasim_management_clock_t) :: a5, a6, replay_a, replay_b, pending_clock, solved_clock
  type(fmr_ribasim_management_clock_t) :: restored_pending, restored_solved
  type(fmr_ribasim_management_clock_persistence_t) :: persistence
  real(real64), allocatable :: advances(:), solves(:)
  real(real64) :: planned_a, planned_b, boundary
  logical :: reaches_a, reaches_b, available, exported, reconstructed
  integer :: status

  call initialize_fmr_ribasim_management_clock(0.0_real64,18000.0_real64,a5,status)
  call require(status==FMR_RMS_OK,'A5 initialize')
  call execute_sequence(a5,a5_targets,advances,solves)
  call require(same_array(advances,a5_expected_advances),'A5 accepted target sequence')
  call require(same_array(solves,a5_expected_solves),'A5 allocation solve sequence')
  call require(.not.a5%boundary_is_pending(),'A5 final 24 h lies between management boundaries')
  call a5%next_boundary_time(boundary,available)
  call require(available .and. same_time(boundary,90000.0_real64),'A5 next allocation boundary 25 h')
  deallocate(advances,solves)

  call initialize_fmr_ribasim_management_clock(0.0_real64,21600.0_real64,a6,status)
  call require(status==FMR_RMS_OK,'A6 initialize')
  call execute_sequence(a6,a6_targets,advances,solves)
  call require(same_array(advances,a6_expected_advances),'A6 accepted target sequence')
  call require(same_array(solves,a6_expected_solves),'A6 allocation solve sequence')
  call require(a6%boundary_is_pending(),'A6 final 24 h boundary pending')
  deallocate(advances,solves)

  ! Same accepted scheduler origin plus the same requested target produces the same plan.
  call initialize_fmr_ribasim_management_clock(0.0_real64,18000.0_real64,replay_a,status)
  call require(status==FMR_RMS_OK,'replay initialize')
  call replay_a%mark_boundary_solved(status)
  call require(status==FMR_RMS_OK,'replay initial solve')
  call export_fmr_ribasim_management_clock(replay_a,persistence,exported,status)
  call require(exported .and. status==FMR_RMS_OK,'replay export')
  call reconstruct_fmr_ribasim_management_clock(persistence,replay_b,reconstructed,status)
  call require(reconstructed .and. status==FMR_RMS_OK,'replay reconstruct')
  call replay_a%plan_advance(21600.0_real64,planned_a,reaches_a,status)
  call require(status==FMR_RMS_OK,'replay plan A')
  call replay_b%plan_advance(21600.0_real64,planned_b,reaches_b,status)
  call require(status==FMR_RMS_OK,'replay plan B')
  call require(same_time(planned_a,planned_b) .and. (reaches_a .eqv. reaches_b),'same-origin plan identity')
  call require(same_time(planned_a,18000.0_real64) .and. reaches_a,'same-origin split at 5 h')

  ! Wrong acceptance fails closed and preserves the outstanding plan.
  call replay_a%accept_planned_advance(17000.0_real64,status)
  call require(status==FMR_RMS_PLAN_MISMATCH,'wrong accepted target rejected')
  call require(replay_a%has_outstanding_plan(),'wrong target preserves plan')
  call replay_a%accept_planned_advance(18000.0_real64,status)
  call require(status==FMR_RMS_OK,'correct accepted target succeeds')
  call require(replay_a%boundary_is_pending(),'accepted boundary becomes pending')

  ! Persistence is only legal at accepted state boundaries, never with an outstanding plan.
  call export_fmr_ribasim_management_clock(replay_b,persistence,exported,status)
  call require(.not.exported .and. status==FMR_RMS_PLAN_OUTSTANDING,'outstanding plan not restartable')
  call replay_b%accept_planned_advance(18000.0_real64,status)
  call require(status==FMR_RMS_OK,'replay B accepted boundary')

  ! Restart on a pending boundary cannot skip the solve.
  pending_clock = replay_b
  call export_fmr_ribasim_management_clock(pending_clock,persistence,exported,status)
  call require(exported .and. status==FMR_RMS_OK,'pending restart export')
  call reconstruct_fmr_ribasim_management_clock(persistence,restored_pending,reconstructed,status)
  call require(reconstructed .and. restored_pending%boundary_is_pending(),'pending restart reconstruct')
  call restored_pending%plan_advance(21600.0_real64,planned_a,reaches_a,status)
  call require(status==FMR_RMS_BOUNDARY_PENDING,'pending restart blocks physical advance')
  call restored_pending%mark_boundary_solved(status)
  call require(status==FMR_RMS_OK,'pending restart boundary solved')
  call restored_pending%next_boundary_time(boundary,available)
  call require(available .and. same_time(boundary,36000.0_real64),'pending restart advances next boundary')
  call restored_pending%plan_advance(21600.0_real64,planned_a,reaches_a,status)
  call require(status==FMR_RMS_OK .and. same_time(planned_a,21600.0_real64) .and. .not.reaches_a, &
       'pending restart continues to product target')

  ! Restart after a solved boundary cannot repeat the previous allocation solve.
  call reconstruct_fmr_ribasim_management_clock(persistence,solved_clock,reconstructed,status)
  call require(reconstructed,'solved seed reconstruct')
  call solved_clock%mark_boundary_solved(status)
  call require(status==FMR_RMS_OK,'solved seed mark once')
  call export_fmr_ribasim_management_clock(solved_clock,persistence,exported,status)
  call require(exported,'solved restart export')
  call reconstruct_fmr_ribasim_management_clock(persistence,restored_solved,reconstructed,status)
  call require(reconstructed .and. .not.restored_solved%boundary_is_pending(),'solved restart reconstruct')
  call restored_solved%mark_boundary_solved(status)
  call require(status==FMR_RMS_NO_BOUNDARY_PENDING,'solved restart cannot repeat solve')
  call restored_solved%next_boundary_time(boundary,available)
  call require(available .and. same_time(boundary,36000.0_real64),'solved restart next boundary retained')

  print '(a)','RM11_A5_EXPLICIT_NONCOMMENSURATE_SPLIT=PASS'
  print '(a)','RM11_A6_ALIGNED_NO_EXTRA_SPLIT=PASS'
  print '(a)','RM11_SAME_ORIGIN_PLAN_IDENTITY=PASS'
  print '(a)','RM11_WRONG_ACCEPT_FAIL_CLOSED=PASS'
  print '(a)','RM11_PENDING_RESTART_REQUIRES_SOLVE=PASS'
  print '(a)','RM11_SOLVED_RESTART_NO_REPEAT=PASS'
  print '(a)','RM11 MANAGEMENT BOUNDARY SCHEDULER GATE PASS'

contains

  subroutine execute_sequence(clock,product_targets,accepted_targets,solved_boundaries)
    type(fmr_ribasim_management_clock_t), intent(inout) :: clock
    real(real64), intent(in) :: product_targets(:)
    real(real64), allocatable, intent(out) :: accepted_targets(:),solved_boundaries(:)
    real(real64), allocatable :: accepted_work(:),solved_work(:)
    real(real64) :: target,planned
    logical :: reaches
    integer :: i,status_local,n_accept,n_solve

    allocate(accepted_work(64),solved_work(64))
    n_accept=0; n_solve=0

    do i=1,size(product_targets)
      target=product_targets(i)
      do while (clock%current_time() < target .and. .not.same_time(clock%current_time(),target))
        if (clock%boundary_is_pending()) then
          n_solve=n_solve+1
          solved_work(n_solve)=clock%current_time()
          call clock%mark_boundary_solved(status_local)
          call require(status_local==FMR_RMS_OK,'sequence boundary solve')
        end if
        call clock%plan_advance(target,planned,reaches,status_local)
        call require(status_local==FMR_RMS_OK,'sequence plan')
        call require(reaches .eqv. same_time(planned,next_boundary(clock)),'sequence boundary flag')
        n_accept=n_accept+1
        accepted_work(n_accept)=planned
        call clock%accept_planned_advance(planned,status_local)
        call require(status_local==FMR_RMS_OK,'sequence accept')
      end do
    end do

    allocate(accepted_targets(n_accept),solved_boundaries(n_solve))
    if(n_accept>0) accepted_targets=accepted_work(1:n_accept)
    if(n_solve>0) solved_boundaries=solved_work(1:n_solve)
    deallocate(accepted_work,solved_work)
  end subroutine execute_sequence

  real(real64) function next_boundary(clock) result(value)
    type(fmr_ribasim_management_clock_t), intent(in) :: clock
    logical :: got
    call clock%next_boundary_time(value,got)
    call require(got,'next boundary available')
  end function next_boundary

  logical function same_array(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    same_array=size(a)==size(b)
    if(.not.same_array)return
    do i=1,size(a)
      if(.not.same_time(a(i),b(i)))then
        same_array=.false.
        return
      end if
    end do
  end function same_array

  logical function same_time(a,b)
    real(real64), intent(in) :: a,b
    same_time=abs(a-b)<=tol
  end function same_time

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(a,1x,a)')'RM11_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require

end program test_rm11_management_boundary_scheduler
