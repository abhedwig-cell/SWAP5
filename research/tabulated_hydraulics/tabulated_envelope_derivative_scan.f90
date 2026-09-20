program tabulated_envelope_derivative_scan
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use swap_array_dimensions, only: macp, matab, matabentries
  implicit none

  integer, parameter :: nsamp_interval = 21
  real(real64) :: headtab(matab), x(matab), theta_tab(matab), logk_tab(matab), kraw(matab)
  real(real64) :: dydx(matab), sigma(matab), sptab(7,macp,matab)
  integer :: ientrytab(macp,0:matabentries)
  real(real64) :: h, xe, frac, dummy, kval, dkdh
  real(real64) :: max_abs_dk, h_at_max, k_at_max
  real(real64) :: min_dk, max_k
  integer :: n, i, j, isamp, ios, iu
  character(len=512) :: path

  if(command_argument_count()<1) error stop 'usage: tabulated-envelope-derivative-scan <numeric-table>'
  call get_command_argument(1,path)

  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'cannot open numeric table'
  read(iu,*,iostat=ios) n
  if(ios/=0 .or. n<3 .or. n>matab) error stop 'invalid point count'
  do i=1,n
    read(iu,*,iostat=ios) headtab(i),theta_tab(i),kraw(i)
    if(ios/=0) error stop 'invalid row'
    if(kraw(i)<=0.0_real64) error stop 'nonpositive K'
  end do
  close(iu)

  do i=2,n
    if(headtab(i)<=headtab(i-1)) error stop 'head not strictly increasing'
    if(theta_tab(i)<=theta_tab(i-1)) error stop 'theta not strictly increasing'
    if(kraw(i)<=kraw(i-1)) error stop 'K not strictly increasing'
  end do

  sptab=0.0_real64
  ientrytab=0
  do i=1,n
    x(i)=-log(-headtab(i)+1.0_real64)
    logk_tab(i)=log(kraw(i))
    dummy=headtab(i)
    if(dummy > -1.0e-5_real64) then
      j=0
    else
      j=int(1000.0_real64*(log10(-dummy)+1.0_real64))+4001
    end if
    if(j<0 .or. j>matabentries) error stop 'lookup index outside range'
    ientrytab(1,j)=i
    sptab(1,1,i)=x(i)
    sptab(2,1,i)=theta_tab(i)
    sptab(3,1,i)=logk_tab(i)
  end do
  ientrytab(1,1)=0
  do j=matabentries-1,1,-1
    if(ientrytab(1,j)==0) ientrytab(1,j)=ientrytab(1,j+1)
  end do

  call PreProcTabulatedFunction(1,n,x,theta_tab,dydx,sigma)
  do i=1,n
    sptab(4,1,i)=dydx(i)
    sptab(6,1,i)=sigma(i)
  end do
  call PreProcTabulatedFunction(2,n,x,logk_tab,dydx,sigma)
  do i=1,n
    sptab(5,1,i)=dydx(i)
    sptab(7,1,i)=sigma(i)
  end do

  max_abs_dk=-1.0_real64
  h_at_max=0.0_real64
  k_at_max=0.0_real64
  min_dk=huge(1.0_real64)
  max_k=0.0_real64

  do i=1,n-1
    do isamp=1,nsamp_interval
      frac=real(isamp,real64)/real(nsamp_interval+1,real64)
      xe=x(i)+frac*(x(i+1)-x(i))
      h=1.0_real64-exp(-xe)
      if(h>=-1.0e-9_real64) cycle

      dummy=0.0_real64
      call EvalTabulatedFunction(0,n,1,3,5,1,sptab,ientrytab,h,kval,dummy,2)
      dummy=0.0_real64
      call EvalTabulatedFunction(0,n,1,3,5,1,sptab,ientrytab,h,kval,dkdh,4)

      if(.not.ieee_is_finite(kval) .or. .not.ieee_is_finite(dkdh)) error stop 'nonfinite output'
      min_dk=min(min_dk,dkdh)
      max_k=max(max_k,kval)
      if(abs(dkdh)>max_abs_dk) then
        max_abs_dk=abs(dkdh)
        h_at_max=h
        k_at_max=kval
      end if
    end do
  end do

  write(*,'(A,A)') 'TABLE ',trim(path)
  write(*,'(A,I0)') 'SUMMARY n=',n
  write(*,'(A,ES24.16)') 'SUMMARY max_abs_dKdh=',max_abs_dk
  write(*,'(A,ES24.16)') 'SUMMARY h_at_max=',h_at_max
  write(*,'(A,ES24.16)') 'SUMMARY K_at_max=',k_at_max
  write(*,'(A,ES24.16)') 'SUMMARY min_dKdh=',min_dk
  write(*,'(A,ES24.16)') 'SUMMARY max_K_sampled=',max_k
  write(*,'(A)') 'TABULATED_ENVELOPE_DERIVATIVE_SCAN_COMPLETED'
end program tabulated_envelope_derivative_scan
