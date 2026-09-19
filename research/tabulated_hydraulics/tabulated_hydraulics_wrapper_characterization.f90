program tabulated_hydraulics_wrapper_characterization
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use iso_fortran_env, only: real64
  use swap_array_dimensions, only: matabentries
  use variables, only: swsophy, numtab, sptab, ientrytab, dt, swfrost
  use soilhydraulics_utils, only: watcon, moiscap, hconduc, dhconduc
  implicit none

  integer, parameter :: n = 241
  integer, parameter :: nh = 10
  real(real64), parameter :: theta_r=0.05_real64, theta_s=0.45_real64
  real(real64), parameter :: alpha=0.02_real64, nvg=1.60_real64
  real(real64), parameter :: mvg=1.0_real64-1.0_real64/nvg
  real(real64), parameter :: lexp=0.50_real64, ksat=50.0_real64
  real(real64) :: head_raw(n), x(n), theta_tab(n), logk_tab(n), dydx(n), sigma(n)
  real(real64) :: heads(nh), h, theta, cap, kval, dkdh
  real(real64) :: frac, exponent, dummy, se, bracket
  integer :: i,j
  character(len=32) :: mode

  swsophy=1
  swfrost=0
  dt=0.1_real64
  numtab(1)=n
  sptab=0.0_real64
  ientrytab=0

  do i=1,n-1
    frac=real(i-1,real64)/real(n-2,real64)
    exponent=7.0_real64-12.0_real64*frac
    head_raw(i)=-10.0_real64**exponent
    se=(1.0_real64+(alpha*abs(head_raw(i)))**nvg)**(-mvg)
    theta_tab(i)=theta_r+(theta_s-theta_r)*se
    bracket=1.0_real64-(1.0_real64-se**(1.0_real64/mvg))**mvg
    logk_tab(i)=log(ksat*se**lexp*bracket**2)
  end do
  head_raw(n)=0.0_real64
  theta_tab(n)=theta_s
  logk_tab(n)=log(ksat)

  do i=1,n
    x(i)=-log(-head_raw(i)+1.0_real64)
    dummy=head_raw(i)
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

  mode=''
  if(command_argument_count()>0) call get_command_argument(1,mode)
  if(trim(mode)=='dry_probe') then
    h=-1.0e8_real64
    theta=watcon(1,h)
    cap=moiscap(1,h)
    kval=hconduc(1,h,theta,1.0_real64)
    write(*,'(A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16)') &
      'DRY_PROBE h=',h,' theta=',theta,' C=',cap,' K=',kval
    dkdh=dhconduc(1,h,theta,cap,1.0_real64)
    write(*,'(A,ES24.16)') 'DRY_PROBE_UNEXPECTED_SUCCESS dKdh=',dkdh
    stop
  end if

  heads=[-1.0e7_real64,-1.0e6_real64,-1.0e4_real64,-1.0e2_real64,-1.0_real64, &
         -1.0e-2_real64,-1.0e-3_real64,-1.0e-4_real64,-1.0e-5_real64,-1.0e-6_real64]

  write(*,'(A)') 'h_cm,theta,C,K,dKdh'
  do i=1,nh
    h=heads(i)
    theta=watcon(1,h)
    cap=moiscap(1,h)
    kval=hconduc(1,h,theta,1.0_real64)
    dkdh=dhconduc(1,h,theta,cap,1.0_real64)
    if(.not.ieee_is_finite(theta) .or. .not.ieee_is_finite(cap) .or. &
       .not.ieee_is_finite(kval) .or. .not.ieee_is_finite(dkdh)) error stop 'nonfinite wrapper output'
    if(theta<theta_r-1.0e-10_real64 .or. theta>theta_s+1.0e-10_real64) error stop 'theta outside bounds'
    if(kval<=0.0_real64 .or. kval>ksat*(1.0_real64+1.0e-10_real64)) error stop 'K outside bounds'
    if(cap<0.0_real64) error stop 'negative C'

    write(*,'(ES22.14,",",ES22.14,",",ES22.14,",",ES22.14,",",ES22.14)') &
      h,theta,cap,kval,dkdh
  end do

  write(*,'(A,ES24.16)') 'WRAPPER near_sat_C=',moiscap(1,-1.0e-6_real64)
  write(*,'(A,ES24.16)') 'WRAPPER near_sat_dKdh=', &
    dhconduc(1,-1.0e-6_real64,watcon(1,-1.0e-6_real64),moiscap(1,-1.0e-6_real64),1.0_real64)
  write(*,'(A)') 'WRAPPER_CHARACTERIZATION_COMPLETED'

end program tabulated_hydraulics_wrapper_characterization
