! Real original initialization followed only by local mathematical queries. Zero model days.
program implicit_analytical_saturation_probe
use iso_fortran_env, only: output_unit
use MOD_swap_base, only: swap_configuration, sw_animo, sw_multi_swap, swhea, swdra, swsnow, swsolu
use atmosphere_interface, only: tav
use MOD_meteo, only: meteo, peva, empreva, epond
use MOD_MvG, only: fill_cofgen,watcon,moiscap,hconduc,dhconduc,cofgen,iHWCKmodel,fl_use_tables,fl_use_kh_power,sw_use_elas
use MOD_SoilWater, only: soilwater
use MOD_gwl, only: calcgwl
use MOD_SoilTemperature, only: SoilTemperature, tsoil
use MOD_snow, only: snow
use MOD_solute, only: solute
use MOD_grid,only:numnod,layer
implicit none
integer::query_unit,node,query_ios
real(8)::query_head,delta,water,capacity,conductivity,derivative,wl,wr,kl,kr,whl,whr,khl,khr

sw_animo=1
call mark('BEFORE_INITIALIZE')
call Initialize
call IterTime(1)
call mark('BEFORE_CONFIGURATION')
call swap_configuration()
call mark('BEFORE_READSWAP')
call ReadSwap
call mark('AFTER_READSWAP')
call Meteo(1)
call mark('AFTER_METEO')
call TimeControl(1)
call mark('AFTER_TIMECONTROL')
if(sw_multi_swap/=0)error stop 'Unexpected multi SWAP'
call fill_cofgen
call mark('AFTER_FILL_COFGEN')
call SoilWater(1)
call mark('AFTER_SOILWATER')
call calcgwl()
call mark('AFTER_CALCGWL')
if(swhea>0)call SoilTemperature(1)
call mark('AFTER_SOILTEMPERATURE')
write(*,*) 'ACTUAL_BRANCH_QUERY_FLAGS',numnod,fl_use_tables,fl_use_kh_power,sw_use_elas
open(newunit=query_unit,file='mathematical-head-queries.txt',status='old',action='read')
do
 read(query_unit,*,iostat=query_ios)node,query_head
 if(query_ios<0)exit
 if(query_ios/=0.or.node<1.or.node>numnod)error stop 'Invalid mathematical head query'
 delta=max(1d0,abs(query_head))*1d-5
 water=watcon(node,query_head)
 capacity=moiscap(node,query_head)
 conductivity=hconduc(node,query_head,water,1d0)
 derivative=dhconduc(node,query_head,water,capacity,1d0)
 wl=watcon(node,query_head-delta);wr=watcon(node,query_head+delta)
 kl=hconduc(node,query_head-delta,wl,1d0);kr=hconduc(node,query_head+delta,wr,1d0)
 whl=watcon(node,query_head-delta/2d0);whr=watcon(node,query_head+delta/2d0)
 khl=hconduc(node,query_head-delta/2d0,whl,1d0);khr=hconduc(node,query_head+delta/2d0,whr,1d0)
 write(*,'(a,3(1x,i0),11(1x,es25.17e3))')'ACTUAL_BRANCH_QUERY',node,layer(node),iHWCKmodel(layer(node)), &
   query_head,water,capacity,conductivity,derivative,(wr-wl)/(2d0*delta),(whr-whl)/delta, &
   (kr-kl)/(2d0*delta),(khr-khl)/delta,delta,cofgen(9,node)
end do
close(query_unit)
call mark('ACTUAL_BRANCH_QUERIES_COMPLETE_ZERO_MODEL_DAYS')
contains
subroutine mark(text)
character(len=*),intent(in)::text
write(output_unit,'(a)')'ORIGINAL_INIT_PHASE '//text
flush(output_unit)
end subroutine
end program
