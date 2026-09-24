program test_fpe_profile01_state_clone_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t
  implicit none

  type(fmr_b110_physical_state_t) :: state
  class(transaction_state_t), allocatable :: copy
  character(len=64) :: arg
  integer :: n, calls, i, j, warmups
  integer(int64) :: c0, c1, rate
  real(real64) :: seconds, ns_per_clone, checksum

  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,arg); read(arg,*) calls
  if (n <= 0 .or. calls <= 0) error stop 'PROFILE01 clone invalid arguments'

  state%active_nodes=n
  allocate(state%pressure_head(n), state%water_content(n))
  do i=1,n
    state%pressure_head(i)=-20.0_real64-real(i,real64)
    state%water_content(i)=0.2_real64+1.0e-5_real64*real(i,real64)
  end do
  state%ponding_depth=0.1_real64
  state%groundwater_level=-250.0_real64

  warmups=min(2000,max(100,calls/100))
  do j=1,warmups
    call state%clone(copy)
    if (allocated(copy)) deallocate(copy)
  end do

  checksum=0.0_real64
  call system_clock(c0,rate)
  do j=1,calls
    call state%clone(copy)
    select type (typed => copy)
    type is (fmr_b110_physical_state_t)
      checksum=checksum+typed%pressure_head(1)+typed%water_content(n)
    class default
      error stop 'PROFILE01 clone wrong type'
    end select
    deallocate(copy)
  end do
  call system_clock(c1)

  seconds=real(c1-c0,real64)/real(rate,real64)
  ns_per_clone=1.0e9_real64*seconds/real(calls,real64)
  write(*,'(A,I0,A,I0,A,ES24.16,A,ES24.16,A,ES24.16)') &
       'PROFILE01_CLONE_TIMING,nodes=',n,',calls=',calls,',seconds=',seconds, &
       ',ns_per_clone=',ns_per_clone,',checksum=',checksum
end program test_fpe_profile01_state_clone_timing
