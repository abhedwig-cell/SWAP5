program tabulated_hydraulics_resolution_sweep
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use iso_fortran_env, only: real64
  use swap_array_dimensions, only: macp, matab, matabentries
  implicit none

  integer, parameter :: nres = 6, nsample = 2001
  integer, parameter :: resolutions(nres) = [25, 50, 100, 200, 400, 800]
  real(real64), parameter :: theta_r=0.05_real64, theta_s=0.45_real64
  real(real64), parameter :: alpha=0.02_real64, nvg=1.60_real64
  real(real64), parameter :: mvg=1.0_real64-1.0_real64/nvg
  real(real64), parameter :: lexp=0.50_real64, ksat=50.0_real64

  real(real64) :: headtab(matab), x(matab), theta_tab(matab), logk_tab(matab)
  real(real64) :: dydx(matab), sigma(matab)
  real(real64) :: sptab(7,macp,matab)
  integer :: ientrytab(macp,0:matabentries)
  real(real64) :: h, theta_eval, k_eval, dummy, theta_ref, k_ref
  real(real64) :: frac, exponent, se, bracket
  real(real64) :: max_theta_abs, max_log10k_abs
  integer :: ir, n, i, j

  write(*,'(A)') 'resolution,max_theta_abs,max_log10K_abs'
  do ir=1,nres
    n=resolutions(ir)
    sptab=0.0_real64
    ientrytab=0

    do i=1,n-1
      frac=real(i-1,real64)/real(n-2,real64)
      exponent=7.0_real64-12.0_real64*frac
      headtab(i)=-10.0_real64**exponent
      call vg(headtab(i),theta_tab(i),k_ref)
      logk_tab(i)=log(k_ref)
    end do
    headtab(n)=0.0_real64
    theta_tab(n)=theta_s
    logk_tab(n)=log(ksat)

    do i=1,n
      x(i)=-log(-headtab(i)+1.0_real64)
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

    max_theta_abs=0.0_real64
    max_log10k_abs=0.0_real64
    do i=1,nsample
      frac=real(i-1,real64)/real(nsample-1,real64)
      exponent=7.0_real64-13.0_real64*frac
      h=-10.0_real64**exponent
      call vg(h,theta_ref,k_ref)

      dummy=0.0_real64
      call EvalTabulatedFunction(0,n,1,2,4,1,sptab,ientrytab,h,theta_eval,dummy,1)
      dummy=0.0_real64
      call EvalTabulatedFunction(0,n,1,3,5,1,sptab,ientrytab,h,k_eval,dummy,2)

      if(.not.ieee_is_finite(theta_eval) .or. .not.ieee_is_finite(k_eval)) error stop 'nonfinite interpolation'
      if(k_eval<=0.0_real64) error stop 'nonpositive K'
      max_theta_abs=max(max_theta_abs,abs(theta_eval-theta_ref))
      max_log10k_abs=max(max_log10k_abs,abs(log10(k_eval)-log10(k_ref)))
    end do

    write(*,'(I0,",",ES24.16,",",ES24.16)') n,max_theta_abs,max_log10k_abs
  end do
  write(*,'(A)') 'RESOLUTION_SWEEP_COMPLETED'

contains

  subroutine vg(head,theta,k)
    real(real64), intent(in) :: head
    real(real64), intent(out) :: theta,k
    real(real64) :: se_local, bracket_local
    if(head>=0.0_real64) then
      theta=theta_s
      k=ksat
    else
      se_local=(1.0_real64+(alpha*abs(head))**nvg)**(-mvg)
      theta=theta_r+(theta_s-theta_r)*se_local
      bracket_local=1.0_real64-(1.0_real64-se_local**(1.0_real64/mvg))**mvg
      k=ksat*se_local**lexp*bracket_local**2
    end if
  end subroutine vg
end program tabulated_hydraulics_resolution_sweep
