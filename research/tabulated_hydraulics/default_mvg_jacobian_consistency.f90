program default_mvg_jacobian_consistency
  use iso_fortran_env, only: real64
  use variables, only: cofgen, swsophy, iHWCKmodel, layer, fluseksatexm, swfrost, dt
  use soilhydraulics_utils, only: watcon, moiscap, hconduc, dhconduc
  implicit none

  real(real64), parameter :: ores=0.01_real64, osat=0.42_real64
  real(real64), parameter :: alpha=0.0276_real64, npar=1.491_real64
  real(real64), parameter :: ksat=12.52_real64, lexp=-1.060_real64
  real(real64), parameter :: mpar=1.0_real64-1.0_real64/npar
  real(real64), parameter :: hvals(5) = [ &
       -1.0e-2_real64, -8.0e-3_real64, -7.0e-3_real64, -5.0e-3_real64, -1.0e-3_real64 ]
  real(real64) :: h, eps, theta, cap, k0, kp, km, dcode, dfd
  integer :: i

  cofgen=0.0_real64
  swsophy=0
  swfrost=0
  dt=0.04_real64
  iHWCKmodel=1
  layer=1
  fluseksatexm=.false.

  cofgen(1,1)=ores
  cofgen(2,1)=osat
  cofgen(3,1)=ksat
  cofgen(4,1)=alpha
  cofgen(5,1)=lexp
  cofgen(6,1)=npar
  cofgen(7,1)=mpar
  cofgen(9,1)=0.0_real64
  cofgen(10,1)=-999.0_real64

  write(*,'(A)') 'h_cm,theta,K,dKdh_code,dKdh_residual_fd'
  do i=1,size(hvals)
    h=hvals(i)
    theta=watcon(1,h)
    cap=moiscap(1,h)
    k0=hconduc(1,h,theta,1.0_real64)
    dcode=dhconduc(1,h,theta,cap,1.0_real64)
    eps=max(1.0e-8_real64,abs(h)*1.0e-5_real64)
    kp=hconduc(1,h+eps,watcon(1,h+eps),1.0_real64)
    km=hconduc(1,h-eps,watcon(1,h-eps),1.0_real64)
    dfd=(kp-km)/(2.0_real64*eps)
    write(*,'(ES22.14,",",ES22.14,",",ES22.14,",",ES22.14,",",ES22.14)') &
       h,theta,k0,dcode,dfd
  end do
  write(*,'(A)') 'DEFAULT_MVG_JACOBIAN_CHARACTERIZATION_COMPLETED'
end program default_mvg_jacobian_consistency
