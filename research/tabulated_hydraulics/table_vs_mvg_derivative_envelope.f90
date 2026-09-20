program table_vs_mvg_derivative_envelope
  use iso_fortran_env, only: real64
  use variables, only: cofgen, swsophy, iHWCKmodel, layer, fluseksatexm, swfrost, dt, &
       numtab, sptab, ientrytab
  use soilhydraulics_utils, only: watcon, moiscap, hconduc, dhconduc
  use swap_array_dimensions, only: matabentries
  implicit none

  integer, parameter :: maxn=1000
  real(real64) :: hraw(maxn), theta_raw(maxn), kraw(maxn), x(maxn), logk(maxn)
  real(real64) :: dydx(maxn), sigma(maxn)
  real(real64) :: ores, osat, alpha, npar, ksat, lexp, mpar
  real(real64) :: h, ta, ca, ka, da, tt, ct, kt, dtbl
  real(real64) :: dummy, frac, exponent, ratio
  integer :: n, i, j, q, iu, ios
  character(len=512) :: path
  character(len=32) :: soil

  if(command_argument_count()<2) error stop 'usage: derivative-envelope SOIL INPUT_DAT'
  call get_command_argument(1,soil)
  call get_command_argument(2,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'cannot open input'
  read(iu,*,iostat=ios) n, ores, osat, alpha, npar, ksat, lexp
  if(ios/=0 .or. n<4 .or. n>maxn) error stop 'invalid header'
  do i=1,n
    read(iu,*,iostat=ios) hraw(i),theta_raw(i),kraw(i)
    if(ios/=0) error stop 'invalid row'
  end do
  close(iu)

  swfrost=0
  dt=0.04_real64
  iHWCKmodel=1
  layer=1
  fluseksatexm=.false.
  mpar=1.0_real64-1.0_real64/npar

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

  sptab=0.0_real64
  ientrytab=0
  numtab(1)=n
  do i=1,n
    x(i)=-log(-hraw(i)+1.0_real64)
    logk(i)=log(kraw(i))
    dummy=hraw(i)
    if(dummy > -1.0e-5_real64) then
      j=0
    else
      j=int(1000.0_real64*(log10(-dummy)+1.0_real64))+4001
    end if
    if(j<0 .or. j>matabentries) error stop 'lookup index out of range'
    ientrytab(1,j)=i
    sptab(1,1,i)=x(i)
    sptab(2,1,i)=theta_raw(i)
    sptab(3,1,i)=logk(i)
  end do
  ientrytab(1,1)=0
  do j=matabentries-1,1,-1
    if(ientrytab(1,j)==0) ientrytab(1,j)=ientrytab(1,j+1)
  end do

  call PreProcTabulatedFunction(1,n,x,theta_raw,dydx,sigma)
  do i=1,n
    sptab(4,1,i)=dydx(i)
    sptab(6,1,i)=sigma(i)
  end do
  call PreProcTabulatedFunction(2,n,x,logk,dydx,sigma)
  do i=1,n
    sptab(5,1,i)=dydx(i)
    sptab(7,1,i)=sigma(i)
  end do

  write(*,'(A)') 'soil,h_cm,K_analytic,dKdh_analytic,K_table,dKdh_table,table_over_analytic'
  do q=1,401
    frac=real(q-1,real64)/400.0_real64
    exponent=3.0_real64-8.0_real64*frac
    h=-10.0_real64**exponent

    swsophy=0
    ta=watcon(1,h)
    ca=moiscap(1,h)
    ka=hconduc(1,h,ta,1.0_real64)
    da=dhconduc(1,h,ta,ca,1.0_real64)

    swsophy=1
    tt=watcon(1,h)
    ct=moiscap(1,h)
    kt=hconduc(1,h,tt,1.0_real64)
    dtbl=dhconduc(1,h,tt,ct,1.0_real64)

    if(abs(da)>1.0e-20_real64) then
      ratio=dtbl/da
    else
      ratio=0.0_real64
    end if
    write(*,'(A,",",ES22.14,",",ES22.14,",",ES22.14,",",ES22.14,",",ES22.14,",",ES22.14)') &
      trim(soil),h,ka,da,kt,dtbl,ratio
  end do
  write(*,'(A)') 'TABLE_VS_MVG_DERIVATIVE_ENVELOPE_COMPLETED'
end program table_vs_mvg_derivative_envelope
