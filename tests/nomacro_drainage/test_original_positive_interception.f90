program original_positive_interception
use MOD_meteo,only:meteo,fl_update_meteo,fprecnosnow,grai,swevap,eintc,ptra_dry,ptra_wet, &
 graidt,nraidt,aintcdt
use MOD_swap_base,only:swmacro,swdra,swmetdetail,swrain
use plant_interface,only:sw_inter,vcover,siccap,sicact,crsflx_in,crsflx_out
use MOD_irrigation,only:isua,gird,nird
use variables,only:dt
implicit none
character(32)::mode
real(8)::stock,ending,residual
integer::i
call get_command_argument(1,mode)
do i=1,3
 swmacro=0;swdra=2;swmetdetail=0;swrain=0;fl_update_meteo=.false.
 fprecnosnow=1d0;grai=.47d0;swevap=0;eintc=6.249706826351837d-7
 ptra_dry=0d0;ptra_wet=0d0;sw_inter=3;vcover=.5d0
 siccap=.01d0;sicact=siccap;isua=0;gird=0d0;dt=.01d0
 if(i==2)gird=.1d0
 if(i==3)swdra=1
 stock=sicact
 call meteo(3)
 ending=min(max(0d0,sicact+(crsflx_in-crsflx_out)*dt),siccap)
 residual=(graidt+gird-nraidt-nird-crsflx_out)*dt+stock-ending
 write(*,'(a,1x,i0,8(1x,es25.17e3))')'ACTUAL_ORIGINAL_INTERCEPTION',i,graidt,gird,nraidt,nird,aintcdt,crsflx_in,crsflx_out,residual
 if(trim(mode)=='original'.or.i==3)then
  if(abs(residual)<=1d-10)error stop 'original small positive interception defect not reproduced'
 else
  if(abs(residual)>1d-10)error stop 'positive interception conservation failed'
 end if
end do
end program
