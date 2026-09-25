program test_fpe_zero_waste01_h17a_adapter_vectors
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  integer :: n,reps,r
  integer(int64) :: c0,c1,rate,checksum
  real(real64), allocatable :: src_h(:),src_t(:),req_h(:),req_t(:),res_h(:),res_t(:)
  real(real64) :: fresh_seconds,reuse_seconds
  character(len=32) :: arg

  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,arg); read(arg,*) reps
  if (n<=0 .or. reps<=0) error stop 'H17A invalid request'
  allocate(src_h(n),src_t(n))
  src_h=[(-100.0_real64-real(r,real64)*1.0e-3_real64,r=1,n)]
  src_t=0.25_real64

  checksum=0_int64
  call system_clock(c0,rate)
  do r=1,reps
    if (allocated(req_h)) deallocate(req_h)
    if (allocated(req_t)) deallocate(req_t)
    if (allocated(res_h)) deallocate(res_h)
    if (allocated(res_t)) deallocate(res_t)
    allocate(req_h(n),req_t(n),res_h(n),res_t(n))
    req_h=src_h; req_t=src_t
    res_h=req_h; res_t=req_t
    checksum=checksum+int(size(req_h)+size(req_t)+size(res_h)+size(res_t),int64)
  end do
  call system_clock(c1)
  fresh_seconds=real(c1-c0,real64)/real(rate,real64)

  if (allocated(req_h)) deallocate(req_h)
  if (allocated(req_t)) deallocate(req_t)
  if (allocated(res_h)) deallocate(res_h)
  if (allocated(res_t)) deallocate(res_t)
  allocate(req_h(n),req_t(n),res_h(n),res_t(n))
  checksum=0_int64
  call system_clock(c0)
  do r=1,reps
    req_h=src_h; req_t=src_t
    res_h=req_h; res_t=req_t
    checksum=checksum+int(size(req_h)+size(req_t)+size(res_h)+size(res_t),int64)
  end do
  call system_clock(c1)
  reuse_seconds=real(c1-c0,real64)/real(rate,real64)

  write(*,'(A,I0,A,I0,A,ES24.16,A,ES24.16,A,ES24.16,A,I0)') &
    'ZW_H17A,n=',n,',reps=',reps,',fresh_ns=',1.0e9_real64*fresh_seconds/real(reps,real64), &
    ',reuse_ns=',1.0e9_real64*reuse_seconds/real(reps,real64), &
    ',ratio=',reuse_seconds/fresh_seconds,',checksum=',checksum
  write(*,'(A)') 'FPE_ZERO_WASTE01_H17A_ADAPTER_VECTORS=PASS'
end program test_fpe_zero_waste01_h17a_adapter_vectors
