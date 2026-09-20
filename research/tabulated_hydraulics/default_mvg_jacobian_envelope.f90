program default_mvg_jacobian_envelope
  use iso_fortran_env, only: real64
  use variables, only: cofgen, swsophy, iHWCKmodel, layer, fluseksatexm, swfrost, dt
  use soilhydraulics_utils, only: watcon, moiscap, hconduc, dhconduc
  implicit none

  integer, parameter :: nsoil=6, nh=14
  character(len=4), parameter :: names(nsoil)=[character(len=4) :: 'b4','o5','b9','o9','b12','o13']
  real(real64), parameter :: ores(nsoil)=[0.01d0,0.01d0,0.0d0,0.0d0,0.0d0,0.0d0]
  real(real64), parameter :: osat(nsoil)=[0.42d0,0.32d0,0.43d0,0.46d0,0.55d0,0.57d0]
  real(real64), parameter :: alpha(nsoil)=[0.0163d0,0.0597d0,0.0065d0,0.0094d0,0.0532d0,0.0171d0]
  real(real64), parameter :: npar(nsoil)=[1.559d0,2.059d0,1.325d0,1.400d0,1.081d0,1.110d0]
  real(real64), parameter :: ksat(nsoil)=[54.80d0,43.55d0,1.54d0,2.23d0,15.46d0,3.32d0]
  real(real64), parameter :: lexp(nsoil)=[0.177d0,0.343d0,-2.161d0,-1.382d0,-8.823d0,-4.645d0]
  real(real64), parameter :: hvals(nh)=[ &
       -1.0d3,-1.0d2,-1.0d1,-1.0d0,-1.0d-1,-2.0d-2,-1.1d-2, &
       -9.0d-3,-5.0d-3,-2.0d-3,-1.0d-3,-5.0d-4,-1.0d-4,-1.0d-5 ]

  real(real64) :: h, eps, theta, cap, k0, kp, km, dcode, dfd, relerr, mpar
  integer :: i, s

  swsophy=0
  swfrost=0
  dt=0.04_real64
  iHWCKmodel=1
  layer=1
  fluseksatexm=.false.

  write(*,'(A)') 'soil,h_cm,theta,K,dKdh_code,dKdh_residual_fd,relative_error'
  do s=1,nsoil
    cofgen=0.0_real64
    mpar=1.0_real64-1.0_real64/npar(s)
    cofgen(1,1)=ores(s)
    cofgen(2,1)=osat(s)
    cofgen(3,1)=ksat(s)
    cofgen(4,1)=alpha(s)
    cofgen(5,1)=lexp(s)
    cofgen(6,1)=npar(s)
    cofgen(7,1)=mpar
    cofgen(9,1)=0.0_real64
    cofgen(10,1)=-999.0_real64

    do i=1,nh
      h=hvals(i)
      theta=watcon(1,h)
      cap=moiscap(1,h)
      k0=hconduc(1,h,theta,1.0_real64)
      dcode=dhconduc(1,h,theta,cap,1.0_real64)
      eps=max(1.0e-9_real64,abs(h)*1.0e-6_real64)
      kp=hconduc(1,h+eps,watcon(1,h+eps),1.0_real64)
      km=hconduc(1,h-eps,watcon(1,h-eps),1.0_real64)
      dfd=(kp-km)/(2.0_real64*eps)
      relerr=abs(dcode-dfd)/max(1.0e-12_real64,abs(dcode),abs(dfd))
      write(*,'(A,",",ES22.14,",",ES22.14,",",ES22.14,",",ES22.14,",",ES22.14,",",ES22.14)') &
        trim(names(s)),h,theta,k0,dcode,dfd,relerr
    end do
  end do
  write(*,'(A)') 'DEFAULT_MVG_JACOBIAN_ENVELOPE_COMPLETED'
end program default_mvg_jacobian_envelope
