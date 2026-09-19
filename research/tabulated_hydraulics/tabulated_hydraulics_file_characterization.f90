program tabulated_hydraulics_file_characterization
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use iso_fortran_env, only: real64
  use swap_array_dimensions, only: macp, matab, matabentries
  implicit none

  real(real64) :: headtab(matab), x(matab), theta_tab(matab), logk_tab(matab), kraw(matab)
  real(real64) :: dydx(matab), sigma(matab), sptab(7,macp,matab)
  integer :: ientrytab(macp,0:matabentries)
  real(real64) :: h, theta_eval, k_eval, c_eval, dk_eval, dummy, xmid
  real(real64) :: theta_lo, theta_hi, k_lo, k_hi, min_c, min_dk
  integer :: n, i, j, ios, iu, theta_overshoot, k_overshoot
  character(len=512) :: path

  if(command_argument_count()<1) error stop 'usage: file-characterization <numeric-table>'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'cannot open numeric table'
  read(iu,*,iostat=ios) n
  if(ios/=0 .or. n<3 .or. n>matab) error stop 'invalid point count'
  do i=1,n
    read(iu,*,iostat=ios) headtab(i),theta_tab(i),kraw(i)
    if(ios/=0) error stop 'invalid table row'
    if(kraw(i)<=0.0_real64) error stop 'nonpositive input K'
  end do
  close(iu)

  do i=2,n
    if(headtab(i)<=headtab(i-1)) error stop 'head not strictly increasing'
    if(theta_tab(i)<=theta_tab(i-1)) error stop 'theta not strictly increasing'
    if(kraw(i)<=kraw(i-1)) error stop 'K not strictly increasing'
  end do
  if(abs(headtab(n))>1.0e-12_real64) error stop 'table does not terminate at h=0'

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
    if(j<0 .or. j>matabentries) error stop 'lookup index out of range'
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

  theta_overshoot=0
  k_overshoot=0
  min_c=huge(1.0_real64)
  min_dk=huge(1.0_real64)

  do i=1,n-1
    xmid=0.5_real64*(x(i)+x(i+1))
    h=-(exp(-xmid)-1.0_real64)
    if(h>=-1.0e-9_real64) cycle

    dummy=0.0_real64
    call EvalTabulatedFunction(0,n,1,2,4,1,sptab,ientrytab,h,theta_eval,dummy,1)
    dummy=0.0_real64
    call EvalTabulatedFunction(0,n,1,3,5,1,sptab,ientrytab,h,k_eval,dummy,2)
    c_eval=0.0_real64
    dummy=0.0_real64
    call EvalTabulatedFunction(0,n,1,2,4,1,sptab,ientrytab,h,dummy,c_eval,3)
    dk_eval=0.0_real64
    dummy=0.0_real64
    call EvalTabulatedFunction(0,n,1,3,5,1,sptab,ientrytab,h,dummy,dk_eval,4)

    if(.not.ieee_is_finite(theta_eval) .or. .not.ieee_is_finite(k_eval) .or. &
       .not.ieee_is_finite(c_eval) .or. .not.ieee_is_finite(dk_eval)) error stop 'nonfinite interpolation'

    theta_lo=min(theta_tab(i),theta_tab(i+1))
    theta_hi=max(theta_tab(i),theta_tab(i+1))
    k_lo=min(kraw(i),kraw(i+1))
    k_hi=max(kraw(i),kraw(i+1))
    if(theta_eval<theta_lo-1.0e-12_real64 .or. theta_eval>theta_hi+1.0e-12_real64) theta_overshoot=theta_overshoot+1
    if(k_eval<k_lo*(1.0_real64-1.0e-10_real64) .or. k_eval>k_hi*(1.0_real64+1.0e-10_real64)) k_overshoot=k_overshoot+1
    min_c=min(min_c,c_eval)
    min_dk=min(min_dk,dk_eval)
  end do

  write(*,'(A,A)') 'TABLE ',trim(path)
  write(*,'(A,I0)') 'SUMMARY n=',n
  write(*,'(A,I0)') 'SUMMARY theta_overshoot=',theta_overshoot
  write(*,'(A,I0)') 'SUMMARY k_overshoot=',k_overshoot
  write(*,'(A,ES24.16)') 'SUMMARY min_C=',min_c
  write(*,'(A,ES24.16)') 'SUMMARY min_dKdh=',min_dk
  write(*,'(A)') 'FILE_CHARACTERIZATION_COMPLETED'
end program tabulated_hydraulics_file_characterization
