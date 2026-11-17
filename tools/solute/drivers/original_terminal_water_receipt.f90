program terminal_receipt_contract
 use MOD_grid, only:numnod,dz
 use MOD_swap_base, only:swmacro,swsnow,swdra
 use MOD_integral, only:Integral,igrai,isnrai,igsnow,igird,irunon,iqssdi,iqbup,iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,iqbdo
 use MOD_meteo, only:graidt,nraidt,aintcdt,ptra,peva
 use MOD_irrigation, only:gird,nird,qssdi,qssdisum
 use MOD_snow, only:gsnow,snrai,subl,ssnow
 use MOD_drain, only:qdrtot,nrlevs,qdra,qdrain
 use MOD_re_global, only:qrosum
 use plant_interface, only:sw_inter,sicact,siccap,crsflx_in,crsflx_out,noddrz,siccaploss
 use variables, only:theta,pond,dt,runon,runots,qbot,epd,reva,ivolbeg,ipondbeg,issnowbeg,isicbeg,q,volact,flzerocumu,flzerointr
 use hybrid_terminal_water_receipt
 implicit none
 real(8)::predicted(28),actual(28),saved_canopy,saved_volume,receipt
 integer::case_index
 character(16)::mode
 numnod=2;noddrz=0;nrlevs=1;swmacro=0;swsnow=1;swdra=1
 call get_command_argument(1,mode)
 if(trim(mode)=='macro')swmacro=1
 if(trim(mode)=='no-snow')swsnow=0
 if(trim(mode)=='no-drain')swdra=0
 dz(1:2)=100d0;theta(1:2)=[.3d0,.4d0];q=0d0;qdra=0d0;qdrain=0d0
 flzerocumu=.true.;flzerointr=.true.;ptra=0d0;peva=0d0
 do case_index=1,12
 call Integral(1)
 dt=.01d0*case_index
 sw_inter=1
 if(mod(case_index,2)==0)sw_inter=3
 qbot=(-1d0)**case_index*.07d0;qdrtot=.13d0
 graidt=.17d0;nraidt=.11d0;aintcdt=.03d0;gird=.05d0;nird=.04d0
 gsnow=.2d0;snrai=.4d0;subl=.02d0;ssnow=9d0
 qssdi(1:2)=[.02d0,.01d0];qssdisum=.03d0;qrosum=.08d0
 runon=.06d0;runots=.001d0;epd=.014d0;reva=.021d0
 siccaploss=0d0;sicact=.2d0;siccap=.5d0;crsflx_in=.4d0;crsflx_out=.3d0
 if(case_index==5.or.case_index==6)siccap=.201d0
 if(case_index>=9)then
 sicact=0d0;crsflx_in=0d0;crsflx_out=0d0
 endif
 ivolbeg=70d0;ipondbeg=.2d0;issnowbeg=10d0;isicbeg=.2d0
 pond=.3d0;volact=70d0
 igrai=.31d0;isnrai=.21d0;igsnow=.11d0;igird=.14d0;irunon=.15d0;iqssdi=.17d0;iqbup=.18d0
 iintc=.12d0;iruno=.13d0;iqrot=.19d0;iepd=.22d0;ievap=.23d0;isubl=.24d0;iqdra=.25d0;iqbdo=.26d0
 saved_canopy=sicact;saved_volume=volact
 call terminal_water_terms(predicted)
 receipt=terminal_water_residual()
 if(sicact/=saved_canopy.or.volact/=saved_volume)error stop 'Projection mutated physical state'
 call Watstor()
 call Integral(3)
 actual(1:7)=[igrai,isnrai,igsnow,igird,irunon,iqssdi,iqbup]
 actual(8:16)=-[iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,0d0,iqbdo]
 actual(17:22)=[ivolbeg,ipondbeg,issnowbeg,isicbeg,0d0,0d0]
 actual(23:28)=-[volact,pond,ssnow,sicact,0d0,0d0]
 if(any(predicted/=actual))then
 write(*,*)case_index,predicted-actual
 error stop 'Projection differs from actual original Integral3 Watstor'
 endif
 write(*,'(a,i3,29es26.17)')'TERMINAL',case_index,receipt,actual
 enddo
end program
