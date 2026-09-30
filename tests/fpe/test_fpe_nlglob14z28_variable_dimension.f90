program test_fpe_nlglob14z28_variable_dimension
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_reference_linear_solver, only: reference_tridag
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, ensure_reference_workspace_shape, &
       reference_workspace_payload_bytes, poison_reference_workspace
  implicit none

  type(reference_richards_workspace_t) :: ws
  integer, parameter :: nseq(5) = [12,11,12,13,12]
  integer, parameter :: controls(4) = [11,12,13,16]
  integer :: i, n, ierr
  real(real64), allocatable :: a(:),b(:),c(:),rhs(:),x(:),truth(:),gamma(:)
  real(real64) :: maxerr, maxres
  integer(int64) :: bytes
  integer :: structural_work
  logical :: ok

  ok=.true.
  do i=1,size(nseq)
     n=nseq(i)
     if (i>1) call poison_reference_workspace(ws)
     call ensure_reference_workspace_shape(ws,n)
     if (ws%active_nodes /= n) ok=.false.
     if (.not. allocated(ws%residual)) ok=.false.
     if (size(ws%residual) /= n) ok=.false.
     if (size(ws%vertical_flux) /= n+1) ok=.false.
     if (size(ws%band_matrix,1) /= n) ok=.false.
     bytes=reference_workspace_payload_bytes(ws)
     call solve_case(n,maxerr,maxres,ierr,structural_work)
     write(*,'(*(g0))') 'F_PE_NLGLOB14Z28_CASE|SEQ=',i,'|N=',n,'|ACTIVE=',ws%active_nodes, &
          '|BYTES=',bytes,'|WORK=',structural_work,'|WORK_RATIO=',real(structural_work,real64)/31.0_real64, &
          '|MAXERR=',maxerr,'|MAXRES=',maxres,'|IERR=',ierr
     if (ierr /= 0 .or. maxerr > 1.0e-12_real64 .or. maxres > 1.0e-11_real64) ok=.false.
  end do

  do i=1,size(controls)
     n=controls(i)
     call ensure_reference_workspace_shape(ws,n)
     bytes=reference_workspace_payload_bytes(ws)
     call solve_case(n,maxerr,maxres,ierr,structural_work)
     write(*,'(*(g0))') 'F_PE_NLGLOB14Z28_CONTROL|N=',n,'|ACTIVE=',ws%active_nodes, &
          '|BYTES=',bytes,'|WORK=',structural_work,'|WORK_RATIO=',real(structural_work,real64)/31.0_real64, &
          '|MAXERR=',maxerr,'|MAXRES=',maxres,'|IERR=',ierr
     if (ws%active_nodes /= n .or. ierr /= 0 .or. maxerr > 1.0e-12_real64 .or. maxres > 1.0e-11_real64) ok=.false.
  end do

  if (.not. ok) error stop 'NLGLOB14Z28 qualification failed'
  write(*,'(a)') 'F_PE_NLGLOB14Z28_RESULT={"classification":"VARIABLE_DIMENSION_PRIMITIVES_QUALIFIED","aggregate":"QUALIFIED_Z28_VARIABLE_DIMENSION_MANAGER_BOOTSTRAP"}'
  write(*,'(a)') 'F_PE_NLGLOB14Z28=PASS'

contains

  subroutine solve_case(n,maxerr,maxres,ierr,work)
    integer,intent(in)::n
    real(real64),intent(out)::maxerr,maxres
    integer,intent(out)::ierr,work
    integer::j
    allocate(a(n),b(n),c(n),rhs(n),x(n),truth(n),gamma(n))
    a=0.0_real64; b=4.0_real64; c=0.0_real64
    do j=2,n
       a(j)=-1.0_real64
    end do
    do j=1,n-1
       c(j)=-1.0_real64
    end do
    do j=1,n
       truth(j)=real(j,real64)/real(n,real64)
    end do
    rhs=0.0_real64
    do j=1,n
       rhs(j)=b(j)*truth(j)
       if (j>1) rhs(j)=rhs(j)+a(j)*truth(j-1)
       if (j<n) rhs(j)=rhs(j)+c(j)*truth(j+1)
    end do
    call reference_tridag(n,a,b,c,rhs,x,gamma,ierr)
    maxerr=maxval(abs(x-truth))
    maxres=0.0_real64
    do j=1,n
       maxres=max(maxres,abs(b(j)*x(j) + merge(a(j)*x(j-1),0.0_real64,j>1) + &
            merge(c(j)*x(j+1),0.0_real64,j<n) - rhs(j)))
    end do
    work=n+(n-1)
    deallocate(a,b,c,rhs,x,truth,gamma)
  end subroutine solve_case
end program test_fpe_nlglob14z28_variable_dimension
