program ordinary_pond_switch
use MOD_top,only:boundtop,pondrunoff,ftoph,flrunoff,hsurf
use MOD_MvG,only:cofgen,swsophy,iHWCKmodel,sw_use_elas,fl_use_tables,fl_use_kh_power,set_cofgen_pointers,calc_cofgen_extra
use MOD_grid,only:numnod,layer,dz,disnod
use MOD_swap_base,only:swmacro,swfrost,swhyst,swdra,swrunon,swpondmx
use MOD_meteo,only:epond,peva,empreva,nraidt
use MOD_snow,only:melt
use MOD_irrigation,only:nird
use MOD_frost,only:rfcp
use MOD_swap_mp,only:ArMpSs
use MOD_drain,only:wls
use variables,only:indeks,fhyst,fluseksatexm,ksatfit,k,h,swkmean,swredu,pondm1,dt,pondmx,pond,qtop,kmean
implicit none
integer::i,j,mean
real(8)::head0,flux,expected_pond,expected_flux,conductance,base
real(8),external::hcomean
real(8),parameter::heads(*)=[-1d-6,-1d-9,0d0,1d-9,3.39593749676403434d-7,9.999d-7,1d-6,1.0001d-6,2d-6]
numnod=1;layer(1)=1;dz(1)=1d0;disnod(1)=.5d0;swsophy=0;swmacro=0;swfrost=0;swhyst=0;sw_use_elas=0
fl_use_tables=.false.;fl_use_kh_power=.false.;iHWCKmodel(1)=1;indeks(1)=-1;fhyst(1)=1d0;fluseksatexm(1)=.false.
call set_cofgen_pointers()
cofgen=0d0;cofgen(1:10,1)=[.02d0,.433878d0,83.24164d0,.021645d0,7.202077d0,1.34877d0,1d0-1d0/1.34877d0,.04329d0,0d0,0d0]
call calc_cofgen_extra(1)
swdra=1;swrunon=0;swpondmx=0;swkmean=1;swredu=0;rfcp(1)=1d0;ksatfit(1)=cofgen(3,1);k(1)=ksatfit(1)
epond=0d0;peva=0d0;empreva=0d0;nraidt=.264667099721356325d0;melt=0d0;nird=0d0;ArMpSs=0d0;pondm1=0d0;pondmx=.2d0;wls=-90d0
do mean=1,6
swkmean=mean;k(1)=.4d0*ksatfit(1)
call boundtop(1)
conductance=hcomean(swkmean,k(1),ksatfit(1),dz(1),dz(1),1,0d0,0d0)/disnod(1)
base=disnod(1)*(1d0-nraidt/(conductance*disnod(1)))
do j=1,2
 dt=1d-4;if(j==2)dt=1.52415790275872555d-10
 do i=1,size(heads)
  h(1)=base+heads(i);head0=h(1)-base;call boundtop(2);if(flrunoff)call pondrunoff()
  if(ftoph)then
   flux=-kmean(1)*((hsurf-h(1))/disnod(1)+1d0)
  else
   flux=qtop
  end if
  expected_pond=max(0d0,conductance*dt*head0/(1d0+conductance*dt))
  expected_flux=-nraidt+expected_pond/dt
  write(*,'(a,3(1x,i0),1x,l1,7(1x,es25.17e3))')'ACTUAL_ORDINARY_POND_SWITCH',mean,j,i,ftoph,dt,head0,pond,flux,expected_pond,expected_flux,flux-expected_flux
 end do
end do
end do
end program
