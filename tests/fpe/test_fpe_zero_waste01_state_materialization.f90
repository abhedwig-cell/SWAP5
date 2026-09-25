program test_fpe_zero_waste01_state_materialization
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none

  real(real64), allocatable :: pressure(:), water(:), target_pressure(:), target_water(:)
  integer(int64) :: c0, c1, rate
  integer :: n, reps, r, k
  character(len=32) :: arg
  real(real64) :: checksum

  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,arg); read(arg,*) reps
  if (n <= 0 .or. reps <= 0) error stop 'state materialization benchmark invalid request'

  allocate(pressure(n),water(n))
  do k=1,n
    pressure(k)=-real(k,real64)
    water(k)=0.2_real64+1.0e-4_real64*real(k,real64)
  end do

  checksum=0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    if (allocated(target_pressure)) deallocate(target_pressure)
    if (allocated(target_water)) deallocate(target_water)
    allocate(target_pressure(n),target_water(n))
    target_pressure=pressure
    target_water=water
    checksum=checksum+target_pressure(n)+target_water(1)
  end do
  call system_clock(c1)
  call emit('base_state_fresh_alloc_copy',n,reps,c0,c1,rate,checksum)

  if (allocated(target_pressure)) deallocate(target_pressure)
  if (allocated(target_water)) deallocate(target_water)
  allocate(target_pressure(n),target_water(n))
  checksum=0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    target_pressure=pressure
    target_water=water
    checksum=checksum+target_pressure(n)+target_water(1)
  end do
  call system_clock(c1)
  call emit('base_state_reuse_copy',n,reps,c0,c1,rate,checksum)

  checksum=0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    do k=1,3
      if (allocated(target_pressure)) deallocate(target_pressure)
      if (allocated(target_water)) deallocate(target_water)
      allocate(target_pressure(n),target_water(n))
      target_pressure=pressure
      target_water=water
      checksum=checksum+target_pressure(n)+target_water(1)
    end do
  end do
  call system_clock(c1)
  call emit('full_half_three_materializations',n,reps,c0,c1,rate,checksum)

contains

  subroutine emit(metric,nvalue,repetitions,start_clock,end_clock,clock_rate,value)
    character(len=*), intent(in) :: metric
    integer, intent(in) :: nvalue,repetitions
    integer(int64), intent(in) :: start_clock,end_clock,clock_rate
    real(real64), intent(in) :: value
    real(real64) :: seconds, ns_per_transaction
    seconds=real(end_clock-start_clock,real64)/real(clock_rate,real64)
    ns_per_transaction=1.0e9_real64*seconds/real(repetitions,real64)
    write(*,'(A,A,A,I0,A,I0,A,ES24.16,A,ES24.16,A,ES24.16)') &
      'ZW_STATE,metric=',trim(metric),',n=',nvalue,',reps=',repetitions,',seconds=',seconds, &
      ',ns_per_transaction=',ns_per_transaction,',checksum=',value
  end subroutine emit

end program test_fpe_zero_waste01_state_materialization
