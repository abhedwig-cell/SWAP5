program mvg_envelope_derivative_scan
  use iso_fortran_env, only: real64
  use variables, only: cofgen, swsophy, iHWCKmodel, layer, fluseksatexm, swfrost, dt
  use soilhydraulics_utils, only: watcon, moiscap, hconduc, dhconduc
  implicit none

  integer, parameter :: nsoil=7, nscan=5000
  character(len=24), parameter :: names(nsoil) = [character(len=24) :: &
       'Hupsel_top','B4_top_sand','O5_sub_sand','B9_top_loam', &
       'O9_sub_loam','B12_top_clay','O13_sub_clay']
  real(real64), parameter :: p(nsoil,6) = reshape([ &
       0.01_real64,0.42_real64,0.0276_real64,1.491_real64,12.52_real64,-1.060_real64, &
       0.01_real64,0.42_real64,0.0163_real64,1.559_real64,54.80_real64, 0.177_real64, &
       0.01_real64,0.32_real64,0.0597_real64,2.059_real64,43.55_real64, 0.343_real64, &
       0.00_real64,0.43_real64,0.0065_real64,1.325_real64, 1.54_real64,-2.161_real64, &
       0.00_real64,0.46_real64,0.0094_real64,1.400_real64, 2.23_real64,-1.382_real64, &
       0.00_real64,0.55_real64,0.0532_real64,1.081_real64,15.46_real64,-8.823_real64, &
       0.00_real64,0.57_real64,0.0171_real64,1.110_real64, 3.32_real64,-4.645_real64  &
       ], [nsoil,6], order=[2,1])

  integer :: is, i, imax
  real(real64) :: ores, osat, alpha, npar, mpar, ksat, lexp
  real(real64) :: exponent, h, th, cap, kval, dcode, eps, kp, km, dfd
  real(real64) :: relsat, maxd, hmax, thmax, kmax, semax, dfdmax
  real(real64) :: max_rel_mismatch, denom

  swsophy=0
  swfrost=0
  dt=0.04_real64
  iHWCKmodel=1
  layer=1
  fluseksatexm=.false.

  write(*,'(A)') 'soil,max_abs_dKdh,h_at_max,theta_at_max,relsat_at_max,K_at_max,fd_at_max,max_rel_fd_mismatch'
  do is=1,nsoil
     ores=p(is,1); osat=p(is,2); alpha=p(is,3); npar=p(is,4)
     ksat=p(is,5); lexp=p(is,6); mpar=1.0_real64-1.0_real64/npar

     cofgen=0.0_real64
     cofgen(1,1)=ores
     cofgen(2,1)=osat
     cofgen(3,1)=ksat
     cofgen(4,1)=alpha
     cofgen(5,1)=lexp
     cofgen(6,1)=npar
     cofgen(7,1)=mpar
     cofgen(9,1)=0.0_real64
     cofgen(10,1)=-999.0_real64

     maxd=-1.0_real64
     max_rel_mismatch=0.0_real64
     imax=0
     do i=1,nscan
        exponent=7.0_real64-13.0_real64*real(i-1,real64)/real(nscan-1,real64)
        h=-10.0_real64**exponent
        th=watcon(1,h)
        cap=moiscap(1,h)
        kval=hconduc(1,h,th,1.0_real64)
        dcode=dhconduc(1,h,th,cap,1.0_real64)
        relsat=(th-ores)/(osat-ores)

        eps=max(1.0e-9_real64,abs(h)*1.0e-6_real64)
        kp=hconduc(1,h+eps,watcon(1,h+eps),1.0_real64)
        km=hconduc(1,h-eps,watcon(1,h-eps),1.0_real64)
        dfd=(kp-km)/(2.0_real64*eps)

        if (abs(dcode)>maxd) then
           maxd=abs(dcode); imax=i; hmax=h; thmax=th; kmax=kval; semax=relsat; dfdmax=dfd
        end if

        ! Ignore finite-difference comparisons exactly at residual branch changes.
        if (relsat>0.0011_real64 .and. relsat<0.999998_real64 .and. abs(h+1.0e-2_real64)>1.0e-4_real64) then
           denom=max(1.0e-10_real64,max(abs(dcode),abs(dfd)))
           max_rel_mismatch=max(max_rel_mismatch,abs(dcode-dfd)/denom)
        end if
     end do

     write(*,'(A,",",ES22.14,",",ES22.14,",",ES22.14,",",ES22.14,",",ES22.14,",",ES22.14,",",ES22.14)') &
          trim(names(is)),maxd,hmax,thmax,semax,kmax,dfdmax,max_rel_mismatch
  end do
  write(*,'(A)') 'MVG_ENVELOPE_DERIVATIVE_SCAN_COMPLETED'
end program mvg_envelope_derivative_scan
