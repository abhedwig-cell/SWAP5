program test_fpe_zero_waste01_hdir04_copy_cost
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none

  real(real64), allocatable :: src_h(:), src_theta(:), cur_h(:), cur_theta(:)
  real(real64), allocatable :: pending_h(:), pending_theta(:), move_a(:), move_b(:), move_c(:), move_d(:)
  integer(int64) :: c0, c1, rate
  integer :: n, reps, r
  real(real64) :: checksum
  character(len=32) :: arg

  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,arg); read(arg,*) reps
  if (n <= 0 .or. reps <= 0) error stop 'HDIR04 benchmark invalid request'

  allocate(src_h(n), src_theta(n), cur_h(n), cur_theta(n))
  call initialize_vectors(src_h,src_theta)
  cur_h = -1.0_real64
  cur_theta = -2.0_real64

  checksum = 0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    cur_h = src_h
    cur_theta = src_theta
    checksum = checksum + cur_h(1) + cur_theta(n)
  end do
  call system_clock(c1)
  call emit('two_vector_reuse_copy',n,reps,c0,c1,rate,checksum)

  checksum = 0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    pending_h = src_h
    pending_theta = src_theta
    checksum = checksum + pending_h(1) + pending_theta(n)
    deallocate(pending_h,pending_theta)
  end do
  call system_clock(c1)
  call emit('pending_alloc_copy_dealloc',n,reps,c0,c1,rate,checksum)

  allocate(move_a(n),move_c(n))
  move_a = src_h
  move_c = src_theta
  checksum = 0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    call move_alloc(move_a,move_b)
    call move_alloc(move_b,move_a)
    call move_alloc(move_c,move_d)
    call move_alloc(move_d,move_c)
    checksum = checksum + move_a(1) + move_c(n)
  end do
  call system_clock(c1)
  call emit('four_move_alloc_transfers',n,reps,c0,c1,rate,checksum)

  print '(a)', 'FPE_ZERO_WASTE01_HDIR04_COPY_COST=PASS'

contains

  subroutine initialize_vectors(h,theta)
    real(real64), intent(out) :: h(:),theta(:)
    integer :: i
    do i=1,size(h)
      h(i) = -0.25_real64*real(i,real64)
      theta(i) = 0.1_real64 + 1.0e-4_real64*real(i,real64)
    end do
  end subroutine initialize_vectors

  subroutine emit(metric,nvalue,repetitions,start_clock,end_clock,clock_rate,checksum_value)
    character(len=*), intent(in) :: metric
    integer, intent(in) :: nvalue,repetitions
    integer(int64), intent(in) :: start_clock,end_clock,clock_rate
    real(real64), intent(in) :: checksum_value
    real(real64) :: seconds, ns_per_step
    seconds=real(end_clock-start_clock,real64)/real(clock_rate,real64)
    ns_per_step=1.0e9_real64*seconds/real(repetitions,real64)
    write(*,'(A,A,A,I0,A,I0,A,ES24.16,A,ES24.16,A,ES24.16)') &
      'ZW_HDIR04,metric=',trim(metric),',n=',nvalue,',reps=',repetitions,',seconds=',seconds, &
      ',ns_per_step=',ns_per_step,',checksum=',checksum_value
  end subroutine emit
end program test_fpe_zero_waste01_hdir04_copy_cost
