program f_pdi_vt03_harness
  use variables, only: cofgen,iHWCKmodel,BiModal,NoVap,layer
  use WC_K_models_04_11, only: functionvalue_04_11
  implicit none
  integer::j,k
  real(8)::temps(7),heads(3),t,h,wc,kw,kn,kv,ref,rel
  real(8)::tk,mgr,mgrt,da,rhosv,fkvap,ksi,d,hr
  real(8),parameter::conv=100d0*86400d0,rhow=1000d0,p=7d0/3d0
  logical::pass
  temps=(/-20d0,-5d0,0d0,5d0,20d0,35d0,50d0/)
  heads=(/-1d3,-1d5,-1d7/)
  layer=1;iHWCKmodel(1)=8;BiModal(1)=.false.;NoVap(1)=.false.;cofgen=0d0
  cofgen(1,1)=0.05d0;cofgen(2,1)=0.45d0;cofgen(3,1)=50d0;cofgen(4,1)=0.02d0
  cofgen(5,1)=0.5d0;cofgen(6,1)=1.6d0;cofgen(7,1)=1d0-1d0/cofgen(6,1)
  cofgen(18,1)=1d7;cofgen(19,1)=1d4;cofgen(20,1)=-1.5d0;cofgen(21,1)=0.01d0
  mgr=0.018015d0*9.81d0/8.314d0;pass=.true.
  do j=1,size(temps)
    t=temps(j)
    do k=1,size(heads)
      h=heads(k)
      wc=functionvalue_04_11(1,1,h)
      NoVap(1)=.false.;kw=functionvalue_04_11(2,1,h,wc,t)
      NoVap(1)=.true.;kn=functionvalue_04_11(2,1,h,wc,t)
      kv=kw-kn
      tk=t+273.15d0;mgrt=mgr/tk;da=2.14d-5*(tk/273.15d0)**2
      rhosv=1d-3*dexp(31.3716d0-6014.79d0/tk-7.92495d-3*tk)/tk
      fkvap=rhosv/rhow*mgrt;ksi=(cofgen(2,1)-wc)**p/cofgen(2,1)**2
      d=ksi*(cofgen(2,1)-wc)*da;hr=dexp(h/100d0*mgrt);ref=fkvap*d*hr*conv
      rel=dabs(kv-ref)/dmax1(dabs(ref),1d-300)
      if(.not.(kv>=0d0).or.rel>1d-11)pass=.false.
      write(*,'(A,1X,F7.2,1X,ES12.4,1X,ES18.10,1X,ES18.10,1X,ES12.4)') 'FPDIVT03',t,h,kv,ref,rel
    end do
  end do
  if(.not.pass) error stop 2
  write(*,'(A)') 'F-PDI-VT03_ACTUAL_SOURCE_GATE=PASS'
end program
