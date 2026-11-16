module MOD_native09
use MOD_arrays, only:macp,madm
use MOD_grid, only:numnod
use MOD_macropore, only:NumDm,swmbf,swabs
use MOD_swap_base, only:swmacro,swhyst,swfrost,swdra,swsolu,swhea,swcrop,fl_initialize
use MOD_swap_mp, only:IDecMpRat,FlDecMpRat
use variables, only:fldecdt,flrunend
use variables, only:h,theta,k,kmean
use MOD_SoilTemperature, only:tsoil
use plant_interface, only:sw_inter,sw_drought,sw_oxygen
use MOD_cropdevelopment, only:hlim1,hlim2u,hlim2l,rdm,sw_compensate,sw_stressor
use, intrinsic :: ieee_arithmetic, only:ieee_is_finite
use MOD_macropore, only:WaSrMpDm,WaUnMpDm,WaUnMpDmCp,WaSrMp,TimAbsCumDmCp,ThtSrpRefDmCp,SorpDmCp,VlMpDmCp,VlMpDm,VlMp,ZBtDm,ZWaLevDm,FrMpWalWet,FrMpWalWetOld,FrReduQ,AwlCorFac,ArMpTp,ArMpTpDm,ICpBtDm,ICpTpWaSrDm
use MOD_swap_mp, only:VlMpDyCp,SubsidCp,ArMpSs,KsMpSs
use variables, only:t1900,tstart,t,tcum,timjan1,dt,dtold,volact,volm1,daynr,daycum,iyear,imonth,isteps,fldaystart,fldayend,fldtmin,flzerointr,flzerocumu
use MOD_meteo, only:tmn,tmx,tavd,hum,win,etr,grai,fprecnosnow,epond,peva,ptra_dry,ptra_wet,eintc,aintc,wfrac,meteo_rec,rain_rec,i_metdetail,fl_update_meteo
use atmosphere_interface, only:tav,rad
use plant_interface, only:lai,rd,vcover,siccap,sicact,cf,fco2tra,dt_interc_event,crsflx_in,crsflx_out,hlim3l,hlim3h,hlim4,dvs,tsum,noddrz,fl_cropemergence,fl_cropharvest
use MOD_cropdevelopment, only:cumdens_top
implicit none
logical,save :: pending=.false.,macro_done=.false.
integer,save :: saved_n,saved_nd
character(64),parameter :: signature='5524115f66b68d26b40f42f25a1624c8da5d33cf435158ba1634ba8cbdec19f5'
real(8),save :: b_WaSrMpDm(madm)
real(8),save :: b_WaUnMpDm(madm)
real(8),save :: b_WaUnMpDmCp(madm,macp)
real(8),save :: b_WaSrMp
real(8),save :: b_TimAbsCumDmCp(madm,macp)
real(8),save :: b_ThtSrpRefDmCp(madm,macp)
real(8),save :: b_SorpDmCp(madm,macp)
real(8),save :: b_VlMpDmCp(madm,macp)
real(8),save :: b_VlMpDm(madm)
real(8),save :: b_VlMp
real(8),save :: b_ZBtDm(madm)
real(8),save :: b_ZWaLevDm(madm)
real(8),save :: b_FrMpWalWet(madm,macp)
real(8),save :: b_FrMpWalWetOld(madm,macp)
real(8),save :: b_FrReduQ
real(8),save :: b_AwlCorFac(macp)
real(8),save :: b_ArMpTp
real(8),save :: b_ArMpTpDm(madm)
integer,save :: b_ICpBtDm(madm)
integer,save :: b_ICpTpWaSrDm(madm)
real(8),save :: b_VlMpDyCp(macp)
real(8),save :: b_SubsidCp(macp)
real(8),save :: b_ArMpSs
real(8),save :: b_KsMpSs
real(8),save :: b_t1900
real(8),save :: b_tstart
real(8),save :: b_t
real(8),save :: b_tcum
real(8),save :: b_timjan1
real(8),save :: b_dt
real(8),save :: b_dtold
real(8),save :: b_volact
real(8),save :: b_volm1
integer,save :: b_daynr
integer,save :: b_daycum
integer,save :: b_iyear
integer,save :: b_imonth
integer,save :: b_isteps
logical,save :: b_fldaystart
logical,save :: b_fldayend
logical,save :: b_fldtmin
logical,save :: b_flzerointr
logical,save :: b_flzerocumu
real(8),save :: b_tmn
real(8),save :: b_tmx
real(8),save :: b_tavd
real(8),save :: b_hum
real(8),save :: b_win
real(8),save :: b_etr
real(8),save :: b_grai
real(8),save :: b_fprecnosnow
real(8),save :: b_epond
real(8),save :: b_peva
real(8),save :: b_ptra_dry
real(8),save :: b_ptra_wet
real(8),save :: b_eintc
real(8),save :: b_aintc
real(8),save :: b_wfrac
integer,save :: b_meteo_rec
integer,save :: b_rain_rec
integer,save :: b_i_metdetail
logical,save :: b_fl_update_meteo
real(8),save :: b_tav
real(8),save :: b_rad
real(8),save :: b_lai
real(8),save :: b_rd
real(8),save :: b_vcover
real(8),save :: b_siccap
real(8),save :: b_sicact
real(8),save :: b_cf
real(8),save :: b_fco2tra
real(8),save :: b_dt_interc_event
real(8),save :: b_crsflx_in
real(8),save :: b_crsflx_out
real(8),save :: b_hlim3l
real(8),save :: b_hlim3h
real(8),save :: b_hlim4
real(8),save :: b_dvs
real(8),save :: b_tsum
integer,save :: b_noddrz
logical,save :: b_fl_cropemergence
logical,save :: b_fl_cropharvest
real(8),save :: b_cumdens_top(macp)
contains
subroutine io(u,rw)
integer,intent(in)::u,rw
integer::ios,n,nd,v
character(32)::tag
character(64)::sig
if(swmacro/=1) return
if(rw==2) then
 if(swmbf/=1.or.swabs/=1.or.IDecMpRat/=0.or.FlDecMpRat.or.fldecdt) error stop 'NATIVE09 unsupported boundary'
 tag='SWAP431_MACRO_RESTART_V1'
 write(u) tag,1,numnod,NumDm,signature
 write(u) WaSrMpDm(1:NumDm)
 write(u) WaUnMpDm(1:NumDm)
 write(u) WaUnMpDmCp(1:NumDm,1:numnod)
 write(u) WaSrMp
 write(u) TimAbsCumDmCp(1:NumDm,1:numnod)
 write(u) ThtSrpRefDmCp(1:NumDm,1:numnod)
 write(u) SorpDmCp(1:NumDm,1:numnod)
 write(u) VlMpDmCp(1:NumDm,1:numnod)
 write(u) VlMpDm(1:NumDm)
 write(u) VlMp
 write(u) ZBtDm(1:NumDm)
 write(u) ZWaLevDm(1:NumDm)
 write(u) FrMpWalWet(1:NumDm,1:numnod)
 write(u) FrMpWalWetOld(1:NumDm,1:numnod)
 write(u) FrReduQ
 write(u) AwlCorFac(1:numnod)
 write(u) ArMpTp
 write(u) ArMpTpDm(1:NumDm)
 write(u) ICpBtDm(1:NumDm)
 write(u) ICpTpWaSrDm(1:NumDm)
 write(u) VlMpDyCp(1:numnod)
 write(u) SubsidCp(1:numnod)
 write(u) ArMpSs
 write(u) KsMpSs
 write(u) t1900
 write(u) tstart
 write(u) t
 write(u) tcum
 write(u) timjan1
 write(u) dt
 write(u) dtold
 write(u) volact
 write(u) volm1
 write(u) daynr
 write(u) daycum
 write(u) iyear
 write(u) imonth
 write(u) isteps
 write(u) fldaystart
 write(u) fldayend
 write(u) fldtmin
 write(u) flzerointr
 write(u) flzerocumu
 write(u) tmn
 write(u) tmx
 write(u) tavd
 write(u) hum
 write(u) win
 write(u) etr
 write(u) grai
 write(u) fprecnosnow
 write(u) epond
 write(u) peva
 write(u) ptra_dry
 write(u) ptra_wet
 write(u) eintc
 write(u) aintc
 write(u) wfrac
 write(u) meteo_rec
 write(u) rain_rec
 write(u) i_metdetail
 write(u) fl_update_meteo
 write(u) tav
 write(u) rad
 write(u) lai
 write(u) rd
 write(u) vcover
 write(u) siccap
 write(u) sicact
 write(u) cf
 write(u) fco2tra
 write(u) dt_interc_event
 write(u) crsflx_in
 write(u) crsflx_out
 write(u) hlim3l
 write(u) hlim3h
 write(u) hlim4
 write(u) dvs
 write(u) tsum
 write(u) noddrz
 write(u) fl_cropemergence
 write(u) fl_cropharvest
 write(u) cumdens_top(1:numnod+1)
 tag='NATIVE09_COMPLETE'
 write(u) tag
 return
end if
read(u,iostat=ios) tag,v,n,nd,sig
if(ios/=0) error stop 'NATIVE09 missing trailer'
if(tag/='SWAP431_MACRO_RESTART_V1'.or.v/=1.or.sig/=signature) error stop 'NATIVE09 version or identity mismatch'
if(n/=numnod.or.n<1.or.nd<1.or.nd>madm) error stop 'NATIVE09 dimensions mismatch'
saved_n=n;saved_nd=nd
read(u,iostat=ios) b_WaSrMpDm(1:nd)
if(ios/=0) error stop 'NATIVE09 incomplete WaSrMpDm'
if(.not.all(ieee_is_finite(b_WaSrMpDm(1:nd)))) error stop 'NATIVE09 nonfinite WaSrMpDm'
read(u,iostat=ios) b_WaUnMpDm(1:nd)
if(ios/=0) error stop 'NATIVE09 incomplete WaUnMpDm'
if(.not.all(ieee_is_finite(b_WaUnMpDm(1:nd)))) error stop 'NATIVE09 nonfinite WaUnMpDm'
read(u,iostat=ios) b_WaUnMpDmCp(1:nd,1:n)
if(ios/=0) error stop 'NATIVE09 incomplete WaUnMpDmCp'
if(.not.all(ieee_is_finite(b_WaUnMpDmCp(1:nd,1:n)))) error stop 'NATIVE09 nonfinite WaUnMpDmCp'
read(u,iostat=ios) b_WaSrMp
if(ios/=0) error stop 'NATIVE09 incomplete WaSrMp'
if(.not.ieee_is_finite(b_WaSrMp)) error stop 'NATIVE09 nonfinite WaSrMp'
read(u,iostat=ios) b_TimAbsCumDmCp(1:nd,1:n)
if(ios/=0) error stop 'NATIVE09 incomplete TimAbsCumDmCp'
if(.not.all(ieee_is_finite(b_TimAbsCumDmCp(1:nd,1:n)))) error stop 'NATIVE09 nonfinite TimAbsCumDmCp'
read(u,iostat=ios) b_ThtSrpRefDmCp(1:nd,1:n)
if(ios/=0) error stop 'NATIVE09 incomplete ThtSrpRefDmCp'
if(.not.all(ieee_is_finite(b_ThtSrpRefDmCp(1:nd,1:n)))) error stop 'NATIVE09 nonfinite ThtSrpRefDmCp'
read(u,iostat=ios) b_SorpDmCp(1:nd,1:n)
if(ios/=0) error stop 'NATIVE09 incomplete SorpDmCp'
if(.not.all(ieee_is_finite(b_SorpDmCp(1:nd,1:n)))) error stop 'NATIVE09 nonfinite SorpDmCp'
read(u,iostat=ios) b_VlMpDmCp(1:nd,1:n)
if(ios/=0) error stop 'NATIVE09 incomplete VlMpDmCp'
if(.not.all(ieee_is_finite(b_VlMpDmCp(1:nd,1:n)))) error stop 'NATIVE09 nonfinite VlMpDmCp'
read(u,iostat=ios) b_VlMpDm(1:nd)
if(ios/=0) error stop 'NATIVE09 incomplete VlMpDm'
if(.not.all(ieee_is_finite(b_VlMpDm(1:nd)))) error stop 'NATIVE09 nonfinite VlMpDm'
read(u,iostat=ios) b_VlMp
if(ios/=0) error stop 'NATIVE09 incomplete VlMp'
if(.not.ieee_is_finite(b_VlMp)) error stop 'NATIVE09 nonfinite VlMp'
read(u,iostat=ios) b_ZBtDm(1:nd)
if(ios/=0) error stop 'NATIVE09 incomplete ZBtDm'
if(.not.all(ieee_is_finite(b_ZBtDm(1:nd)))) error stop 'NATIVE09 nonfinite ZBtDm'
read(u,iostat=ios) b_ZWaLevDm(1:nd)
if(ios/=0) error stop 'NATIVE09 incomplete ZWaLevDm'
if(.not.all(ieee_is_finite(b_ZWaLevDm(1:nd)))) error stop 'NATIVE09 nonfinite ZWaLevDm'
read(u,iostat=ios) b_FrMpWalWet(1:nd,1:n)
if(ios/=0) error stop 'NATIVE09 incomplete FrMpWalWet'
if(.not.all(ieee_is_finite(b_FrMpWalWet(1:nd,1:n)))) error stop 'NATIVE09 nonfinite FrMpWalWet'
read(u,iostat=ios) b_FrMpWalWetOld(1:nd,1:n)
if(ios/=0) error stop 'NATIVE09 incomplete FrMpWalWetOld'
if(.not.all(ieee_is_finite(b_FrMpWalWetOld(1:nd,1:n)))) error stop 'NATIVE09 nonfinite FrMpWalWetOld'
read(u,iostat=ios) b_FrReduQ
if(ios/=0) error stop 'NATIVE09 incomplete FrReduQ'
if(.not.ieee_is_finite(b_FrReduQ)) error stop 'NATIVE09 nonfinite FrReduQ'
read(u,iostat=ios) b_AwlCorFac(1:n)
if(ios/=0) error stop 'NATIVE09 incomplete AwlCorFac'
if(.not.all(ieee_is_finite(b_AwlCorFac(1:n)))) error stop 'NATIVE09 nonfinite AwlCorFac'
read(u,iostat=ios) b_ArMpTp
if(ios/=0) error stop 'NATIVE09 incomplete ArMpTp'
if(.not.ieee_is_finite(b_ArMpTp)) error stop 'NATIVE09 nonfinite ArMpTp'
read(u,iostat=ios) b_ArMpTpDm(1:nd)
if(ios/=0) error stop 'NATIVE09 incomplete ArMpTpDm'
if(.not.all(ieee_is_finite(b_ArMpTpDm(1:nd)))) error stop 'NATIVE09 nonfinite ArMpTpDm'
read(u,iostat=ios) b_ICpBtDm(1:nd)
if(ios/=0) error stop 'NATIVE09 incomplete ICpBtDm'
read(u,iostat=ios) b_ICpTpWaSrDm(1:nd)
if(ios/=0) error stop 'NATIVE09 incomplete ICpTpWaSrDm'
read(u,iostat=ios) b_VlMpDyCp(1:n)
if(ios/=0) error stop 'NATIVE09 incomplete VlMpDyCp'
if(.not.all(ieee_is_finite(b_VlMpDyCp(1:n)))) error stop 'NATIVE09 nonfinite VlMpDyCp'
read(u,iostat=ios) b_SubsidCp(1:n)
if(ios/=0) error stop 'NATIVE09 incomplete SubsidCp'
if(.not.all(ieee_is_finite(b_SubsidCp(1:n)))) error stop 'NATIVE09 nonfinite SubsidCp'
read(u,iostat=ios) b_ArMpSs
if(ios/=0) error stop 'NATIVE09 incomplete ArMpSs'
if(.not.ieee_is_finite(b_ArMpSs)) error stop 'NATIVE09 nonfinite ArMpSs'
read(u,iostat=ios) b_KsMpSs
if(ios/=0) error stop 'NATIVE09 incomplete KsMpSs'
if(.not.ieee_is_finite(b_KsMpSs)) error stop 'NATIVE09 nonfinite KsMpSs'
read(u,iostat=ios) b_t1900
if(ios/=0) error stop 'NATIVE09 incomplete t1900'
if(.not.ieee_is_finite(b_t1900)) error stop 'NATIVE09 nonfinite t1900'
read(u,iostat=ios) b_tstart
if(ios/=0) error stop 'NATIVE09 incomplete tstart'
if(.not.ieee_is_finite(b_tstart)) error stop 'NATIVE09 nonfinite tstart'
read(u,iostat=ios) b_t
if(ios/=0) error stop 'NATIVE09 incomplete t'
if(.not.ieee_is_finite(b_t)) error stop 'NATIVE09 nonfinite t'
read(u,iostat=ios) b_tcum
if(ios/=0) error stop 'NATIVE09 incomplete tcum'
if(.not.ieee_is_finite(b_tcum)) error stop 'NATIVE09 nonfinite tcum'
read(u,iostat=ios) b_timjan1
if(ios/=0) error stop 'NATIVE09 incomplete timjan1'
if(.not.ieee_is_finite(b_timjan1)) error stop 'NATIVE09 nonfinite timjan1'
read(u,iostat=ios) b_dt
if(ios/=0) error stop 'NATIVE09 incomplete dt'
if(.not.ieee_is_finite(b_dt)) error stop 'NATIVE09 nonfinite dt'
read(u,iostat=ios) b_dtold
if(ios/=0) error stop 'NATIVE09 incomplete dtold'
if(.not.ieee_is_finite(b_dtold)) error stop 'NATIVE09 nonfinite dtold'
read(u,iostat=ios) b_volact
if(ios/=0) error stop 'NATIVE09 incomplete volact'
if(.not.ieee_is_finite(b_volact)) error stop 'NATIVE09 nonfinite volact'
read(u,iostat=ios) b_volm1
if(ios/=0) error stop 'NATIVE09 incomplete volm1'
if(.not.ieee_is_finite(b_volm1)) error stop 'NATIVE09 nonfinite volm1'
read(u,iostat=ios) b_daynr
if(ios/=0) error stop 'NATIVE09 incomplete daynr'
read(u,iostat=ios) b_daycum
if(ios/=0) error stop 'NATIVE09 incomplete daycum'
read(u,iostat=ios) b_iyear
if(ios/=0) error stop 'NATIVE09 incomplete iyear'
read(u,iostat=ios) b_imonth
if(ios/=0) error stop 'NATIVE09 incomplete imonth'
read(u,iostat=ios) b_isteps
if(ios/=0) error stop 'NATIVE09 incomplete isteps'
read(u,iostat=ios) b_fldaystart
if(ios/=0) error stop 'NATIVE09 incomplete fldaystart'
read(u,iostat=ios) b_fldayend
if(ios/=0) error stop 'NATIVE09 incomplete fldayend'
read(u,iostat=ios) b_fldtmin
if(ios/=0) error stop 'NATIVE09 incomplete fldtmin'
read(u,iostat=ios) b_flzerointr
if(ios/=0) error stop 'NATIVE09 incomplete flzerointr'
read(u,iostat=ios) b_flzerocumu
if(ios/=0) error stop 'NATIVE09 incomplete flzerocumu'
read(u,iostat=ios) b_tmn
if(ios/=0) error stop 'NATIVE09 incomplete tmn'
if(.not.ieee_is_finite(b_tmn)) error stop 'NATIVE09 nonfinite tmn'
read(u,iostat=ios) b_tmx
if(ios/=0) error stop 'NATIVE09 incomplete tmx'
if(.not.ieee_is_finite(b_tmx)) error stop 'NATIVE09 nonfinite tmx'
read(u,iostat=ios) b_tavd
if(ios/=0) error stop 'NATIVE09 incomplete tavd'
if(.not.ieee_is_finite(b_tavd)) error stop 'NATIVE09 nonfinite tavd'
read(u,iostat=ios) b_hum
if(ios/=0) error stop 'NATIVE09 incomplete hum'
if(.not.ieee_is_finite(b_hum)) error stop 'NATIVE09 nonfinite hum'
read(u,iostat=ios) b_win
if(ios/=0) error stop 'NATIVE09 incomplete win'
if(.not.ieee_is_finite(b_win)) error stop 'NATIVE09 nonfinite win'
read(u,iostat=ios) b_etr
if(ios/=0) error stop 'NATIVE09 incomplete etr'
if(.not.ieee_is_finite(b_etr)) error stop 'NATIVE09 nonfinite etr'
read(u,iostat=ios) b_grai
if(ios/=0) error stop 'NATIVE09 incomplete grai'
if(.not.ieee_is_finite(b_grai)) error stop 'NATIVE09 nonfinite grai'
read(u,iostat=ios) b_fprecnosnow
if(ios/=0) error stop 'NATIVE09 incomplete fprecnosnow'
if(.not.ieee_is_finite(b_fprecnosnow)) error stop 'NATIVE09 nonfinite fprecnosnow'
read(u,iostat=ios) b_epond
if(ios/=0) error stop 'NATIVE09 incomplete epond'
if(.not.ieee_is_finite(b_epond)) error stop 'NATIVE09 nonfinite epond'
read(u,iostat=ios) b_peva
if(ios/=0) error stop 'NATIVE09 incomplete peva'
if(.not.ieee_is_finite(b_peva)) error stop 'NATIVE09 nonfinite peva'
read(u,iostat=ios) b_ptra_dry
if(ios/=0) error stop 'NATIVE09 incomplete ptra_dry'
if(.not.ieee_is_finite(b_ptra_dry)) error stop 'NATIVE09 nonfinite ptra_dry'
read(u,iostat=ios) b_ptra_wet
if(ios/=0) error stop 'NATIVE09 incomplete ptra_wet'
if(.not.ieee_is_finite(b_ptra_wet)) error stop 'NATIVE09 nonfinite ptra_wet'
read(u,iostat=ios) b_eintc
if(ios/=0) error stop 'NATIVE09 incomplete eintc'
if(.not.ieee_is_finite(b_eintc)) error stop 'NATIVE09 nonfinite eintc'
read(u,iostat=ios) b_aintc
if(ios/=0) error stop 'NATIVE09 incomplete aintc'
if(.not.ieee_is_finite(b_aintc)) error stop 'NATIVE09 nonfinite aintc'
read(u,iostat=ios) b_wfrac
if(ios/=0) error stop 'NATIVE09 incomplete wfrac'
if(.not.ieee_is_finite(b_wfrac)) error stop 'NATIVE09 nonfinite wfrac'
read(u,iostat=ios) b_meteo_rec
if(ios/=0) error stop 'NATIVE09 incomplete meteo_rec'
read(u,iostat=ios) b_rain_rec
if(ios/=0) error stop 'NATIVE09 incomplete rain_rec'
read(u,iostat=ios) b_i_metdetail
if(ios/=0) error stop 'NATIVE09 incomplete i_metdetail'
read(u,iostat=ios) b_fl_update_meteo
if(ios/=0) error stop 'NATIVE09 incomplete fl_update_meteo'
read(u,iostat=ios) b_tav
if(ios/=0) error stop 'NATIVE09 incomplete tav'
if(.not.ieee_is_finite(b_tav)) error stop 'NATIVE09 nonfinite tav'
read(u,iostat=ios) b_rad
if(ios/=0) error stop 'NATIVE09 incomplete rad'
if(.not.ieee_is_finite(b_rad)) error stop 'NATIVE09 nonfinite rad'
read(u,iostat=ios) b_lai
if(ios/=0) error stop 'NATIVE09 incomplete lai'
if(.not.ieee_is_finite(b_lai)) error stop 'NATIVE09 nonfinite lai'
read(u,iostat=ios) b_rd
if(ios/=0) error stop 'NATIVE09 incomplete rd'
if(.not.ieee_is_finite(b_rd)) error stop 'NATIVE09 nonfinite rd'
read(u,iostat=ios) b_vcover
if(ios/=0) error stop 'NATIVE09 incomplete vcover'
if(.not.ieee_is_finite(b_vcover)) error stop 'NATIVE09 nonfinite vcover'
read(u,iostat=ios) b_siccap
if(ios/=0) error stop 'NATIVE09 incomplete siccap'
if(.not.ieee_is_finite(b_siccap)) error stop 'NATIVE09 nonfinite siccap'
read(u,iostat=ios) b_sicact
if(ios/=0) error stop 'NATIVE09 incomplete sicact'
if(.not.ieee_is_finite(b_sicact)) error stop 'NATIVE09 nonfinite sicact'
read(u,iostat=ios) b_cf
if(ios/=0) error stop 'NATIVE09 incomplete cf'
if(.not.ieee_is_finite(b_cf)) error stop 'NATIVE09 nonfinite cf'
read(u,iostat=ios) b_fco2tra
if(ios/=0) error stop 'NATIVE09 incomplete fco2tra'
if(.not.ieee_is_finite(b_fco2tra)) error stop 'NATIVE09 nonfinite fco2tra'
read(u,iostat=ios) b_dt_interc_event
if(ios/=0) error stop 'NATIVE09 incomplete dt_interc_event'
if(.not.ieee_is_finite(b_dt_interc_event)) error stop 'NATIVE09 nonfinite dt_interc_event'
read(u,iostat=ios) b_crsflx_in
if(ios/=0) error stop 'NATIVE09 incomplete crsflx_in'
if(.not.ieee_is_finite(b_crsflx_in)) error stop 'NATIVE09 nonfinite crsflx_in'
read(u,iostat=ios) b_crsflx_out
if(ios/=0) error stop 'NATIVE09 incomplete crsflx_out'
if(.not.ieee_is_finite(b_crsflx_out)) error stop 'NATIVE09 nonfinite crsflx_out'
read(u,iostat=ios) b_hlim3l
if(ios/=0) error stop 'NATIVE09 incomplete hlim3l'
if(.not.ieee_is_finite(b_hlim3l)) error stop 'NATIVE09 nonfinite hlim3l'
read(u,iostat=ios) b_hlim3h
if(ios/=0) error stop 'NATIVE09 incomplete hlim3h'
if(.not.ieee_is_finite(b_hlim3h)) error stop 'NATIVE09 nonfinite hlim3h'
read(u,iostat=ios) b_hlim4
if(ios/=0) error stop 'NATIVE09 incomplete hlim4'
if(.not.ieee_is_finite(b_hlim4)) error stop 'NATIVE09 nonfinite hlim4'
read(u,iostat=ios) b_dvs
if(ios/=0) error stop 'NATIVE09 incomplete dvs'
if(.not.ieee_is_finite(b_dvs)) error stop 'NATIVE09 nonfinite dvs'
read(u,iostat=ios) b_tsum
if(ios/=0) error stop 'NATIVE09 incomplete tsum'
if(.not.ieee_is_finite(b_tsum)) error stop 'NATIVE09 nonfinite tsum'
read(u,iostat=ios) b_noddrz
if(ios/=0) error stop 'NATIVE09 incomplete noddrz'
read(u,iostat=ios) b_fl_cropemergence
if(ios/=0) error stop 'NATIVE09 incomplete fl_cropemergence'
read(u,iostat=ios) b_fl_cropharvest
if(ios/=0) error stop 'NATIVE09 incomplete fl_cropharvest'
read(u,iostat=ios) b_cumdens_top(1:n+1)
if(ios/=0) error stop 'NATIVE09 incomplete cumdens_top'
if(.not.all(ieee_is_finite(b_cumdens_top(1:n+1)))) error stop 'NATIVE09 nonfinite cumdens_top'
read(u,iostat=ios) tag
if(ios/=0.or.tag/='NATIVE09_COMPLETE') error stop 'NATIVE09 incomplete trailer'
if(b_tstart/=tstart.or.b_dt<=0.or.b_dtold<=0) error stop 'NATIVE09 time/origin mismatch'
if(b_fldaystart.or.b_fldayend) error stop 'NATIVE09 only accepted subday supported'
if(any(b_WaSrMpDm(1:nd)<0).or.any(b_TimAbsCumDmCp(1:nd,1:n)<0)) error stop 'NATIVE09 invalid inventory/history'
if(any(b_VlMpDmCp(1:nd,1:n)<0).or.any(b_WaUnMpDmCp(1:nd,1:n)<0)) error stop 'NATIVE09 invalid geometry'
if(any(b_ICpBtDm(1:nd)<1).or.any(b_ICpBtDm(1:nd)>n)) error stop 'NATIVE09 bottom index'
if(abs(sum(b_WaUnMpDm(1:nd))-b_WaSrMp)>1d-12) error stop 'NATIVE09 total inventory mismatch'
do v=1,nd
 if(abs(sum(b_WaUnMpDmCp(v,1:n))-b_WaUnMpDm(v))>1d-12) error stop 'NATIVE09 compartment inventory mismatch'
 if(abs(b_WaUnMpDm(v)-b_WaSrMpDm(v))>1d-12) error stop 'NATIVE09 bypass inventory mismatch'
end do
pending=.true.
end subroutine
subroutine install_macro()
if(.not.pending) return
if(NumDm/=saved_nd.or.numnod/=saved_n.or.swmbf/=1.or.swabs/=1.or.swhyst/=0.or.swfrost/=0.or.swdra/=1.or.swsolu/=0.or.swhea/=1.or.swcrop/=1) error stop 'NATIVE09 incompatible mode'
WaSrMpDm(1:NumDm)=b_WaSrMpDm(1:NumDm)
WaUnMpDm(1:NumDm)=b_WaUnMpDm(1:NumDm)
WaUnMpDmCp(1:NumDm,1:numnod)=b_WaUnMpDmCp(1:NumDm,1:numnod)
WaSrMp=b_WaSrMp
TimAbsCumDmCp(1:NumDm,1:numnod)=b_TimAbsCumDmCp(1:NumDm,1:numnod)
ThtSrpRefDmCp(1:NumDm,1:numnod)=b_ThtSrpRefDmCp(1:NumDm,1:numnod)
SorpDmCp(1:NumDm,1:numnod)=b_SorpDmCp(1:NumDm,1:numnod)
VlMpDmCp(1:NumDm,1:numnod)=b_VlMpDmCp(1:NumDm,1:numnod)
VlMpDm(1:NumDm)=b_VlMpDm(1:NumDm)
VlMp=b_VlMp
ZBtDm(1:NumDm)=b_ZBtDm(1:NumDm)
ZWaLevDm(1:NumDm)=b_ZWaLevDm(1:NumDm)
FrMpWalWet(1:NumDm,1:numnod)=b_FrMpWalWet(1:NumDm,1:numnod)
FrMpWalWetOld(1:NumDm,1:numnod)=b_FrMpWalWetOld(1:NumDm,1:numnod)
FrReduQ=b_FrReduQ
AwlCorFac(1:numnod)=b_AwlCorFac(1:numnod)
ArMpTp=b_ArMpTp
ArMpTpDm(1:NumDm)=b_ArMpTpDm(1:NumDm)
ICpBtDm(1:NumDm)=b_ICpBtDm(1:NumDm)
ICpTpWaSrDm(1:NumDm)=b_ICpTpWaSrDm(1:NumDm)
VlMpDyCp(1:numnod)=b_VlMpDyCp(1:numnod)
SubsidCp(1:numnod)=b_SubsidCp(1:numnod)
ArMpSs=b_ArMpSs
KsMpSs=b_KsMpSs
macro_done=.true.
end subroutine
subroutine install_host()
if(.not.pending) return
if(.not.macro_done) error stop 'NATIVE09 macro install order'
t1900=b_t1900
tstart=b_tstart
t=b_t
tcum=b_tcum
timjan1=b_timjan1
dt=b_dt
dtold=b_dtold
volact=b_volact
volm1=b_volm1
daynr=b_daynr
daycum=b_daycum
iyear=b_iyear
imonth=b_imonth
isteps=b_isteps
fldaystart=b_fldaystart
fldayend=b_fldayend
fldtmin=b_fldtmin
flzerointr=b_flzerointr
flzerocumu=b_flzerocumu
tmn=b_tmn
tmx=b_tmx
tavd=b_tavd
hum=b_hum
win=b_win
etr=b_etr
grai=b_grai
fprecnosnow=b_fprecnosnow
epond=b_epond
peva=b_peva
ptra_dry=b_ptra_dry
ptra_wet=b_ptra_wet
eintc=b_eintc
aintc=b_aintc
wfrac=b_wfrac
meteo_rec=b_meteo_rec
rain_rec=b_rain_rec
i_metdetail=b_i_metdetail
fl_update_meteo=b_fl_update_meteo
tav=b_tav
rad=b_rad
lai=b_lai
rd=b_rd
vcover=b_vcover
siccap=b_siccap
sicact=b_sicact
cf=b_cf
fco2tra=b_fco2tra
dt_interc_event=b_dt_interc_event
crsflx_in=b_crsflx_in
crsflx_out=b_crsflx_out
hlim3l=b_hlim3l
hlim3h=b_hlim3h
hlim4=b_hlim4
dvs=b_dvs
tsum=b_tsum
noddrz=b_noddrz
fl_cropemergence=b_fl_cropemergence
fl_cropharvest=b_fl_cropharvest
cumdens_top(1:numnod+1)=b_cumdens_top(1:numnod+1)
fldecdt=.false.;FlDecMpRat=.false.;IDecMpRat=0
flrunend=.false.;fl_initialize=.false.
pending=.false.
end subroutine
subroutine dump(label)
character(*),intent(in)::label
integer::u
open(newunit=u,file=label//'.txt',status='replace')
write(u,*) 'WaSrMpDm',WaSrMpDm(1:NumDm)
write(u,*) 'WaUnMpDm',WaUnMpDm(1:NumDm)
write(u,*) 'WaUnMpDmCp',WaUnMpDmCp(1:NumDm,1:numnod)
write(u,*) 'WaSrMp',WaSrMp
write(u,*) 'TimAbsCumDmCp',TimAbsCumDmCp(1:NumDm,1:numnod)
write(u,*) 'ThtSrpRefDmCp',ThtSrpRefDmCp(1:NumDm,1:numnod)
write(u,*) 'SorpDmCp',SorpDmCp(1:NumDm,1:numnod)
write(u,*) 'VlMpDmCp',VlMpDmCp(1:NumDm,1:numnod)
write(u,*) 'VlMpDm',VlMpDm(1:NumDm)
write(u,*) 'VlMp',VlMp
write(u,*) 'ZBtDm',ZBtDm(1:NumDm)
write(u,*) 'ZWaLevDm',ZWaLevDm(1:NumDm)
write(u,*) 'FrMpWalWet',FrMpWalWet(1:NumDm,1:numnod)
write(u,*) 'FrMpWalWetOld',FrMpWalWetOld(1:NumDm,1:numnod)
write(u,*) 'FrReduQ',FrReduQ
write(u,*) 'AwlCorFac',AwlCorFac(1:numnod)
write(u,*) 'ArMpTp',ArMpTp
write(u,*) 'ArMpTpDm',ArMpTpDm(1:NumDm)
write(u,*) 'ICpBtDm',ICpBtDm(1:NumDm)
write(u,*) 'ICpTpWaSrDm',ICpTpWaSrDm(1:NumDm)
write(u,*) 'VlMpDyCp',VlMpDyCp(1:numnod)
write(u,*) 'SubsidCp',SubsidCp(1:numnod)
write(u,*) 'ArMpSs',ArMpSs
write(u,*) 'KsMpSs',KsMpSs
write(u,*) 't1900',t1900
write(u,*) 'tstart',tstart
write(u,*) 't',t
write(u,*) 'tcum',tcum
write(u,*) 'timjan1',timjan1
write(u,*) 'dt',dt
write(u,*) 'dtold',dtold
write(u,*) 'volact',volact
write(u,*) 'volm1',volm1
write(u,*) 'daynr',daynr
write(u,*) 'daycum',daycum
write(u,*) 'iyear',iyear
write(u,*) 'imonth',imonth
write(u,*) 'isteps',isteps
write(u,*) 'fldaystart',merge(1,0,fldaystart)
write(u,*) 'fldayend',merge(1,0,fldayend)
write(u,*) 'fldtmin',merge(1,0,fldtmin)
write(u,*) 'flzerointr',merge(1,0,flzerointr)
write(u,*) 'flzerocumu',merge(1,0,flzerocumu)
write(u,*) 'tmn',tmn
write(u,*) 'tmx',tmx
write(u,*) 'tavd',tavd
write(u,*) 'hum',hum
write(u,*) 'win',win
write(u,*) 'etr',etr
write(u,*) 'grai',grai
write(u,*) 'fprecnosnow',fprecnosnow
write(u,*) 'epond',epond
write(u,*) 'peva',peva
write(u,*) 'ptra_dry',ptra_dry
write(u,*) 'ptra_wet',ptra_wet
write(u,*) 'eintc',eintc
write(u,*) 'aintc',aintc
write(u,*) 'wfrac',wfrac
write(u,*) 'meteo_rec',meteo_rec
write(u,*) 'rain_rec',rain_rec
write(u,*) 'i_metdetail',i_metdetail
write(u,*) 'fl_update_meteo',merge(1,0,fl_update_meteo)
write(u,*) 'tav',tav
write(u,*) 'rad',rad
write(u,*) 'lai',lai
write(u,*) 'rd',rd
write(u,*) 'vcover',vcover
write(u,*) 'siccap',siccap
write(u,*) 'sicact',sicact
write(u,*) 'cf',cf
write(u,*) 'fco2tra',fco2tra
write(u,*) 'dt_interc_event',dt_interc_event
write(u,*) 'crsflx_in',crsflx_in
write(u,*) 'crsflx_out',crsflx_out
write(u,*) 'hlim3l',hlim3l
write(u,*) 'hlim3h',hlim3h
write(u,*) 'hlim4',hlim4
write(u,*) 'dvs',dvs
write(u,*) 'tsum',tsum
write(u,*) 'noddrz',noddrz
write(u,*) 'fl_cropemergence',merge(1,0,fl_cropemergence)
write(u,*) 'fl_cropharvest',merge(1,0,fl_cropharvest)
write(u,*) 'cumdens_top',cumdens_top(1:numnod+1)
write(u,*) 'tsoil',tsoil(1:numnod)
write(u,*) 'hydraulic_k',k(1:numnod)
write(u,*) 'hydraulic_kmean',kmean(1:numnod+1)
write(u,*) 'crop_switches',sw_inter,sw_drought,sw_oxygen,sw_compensate,sw_stressor
write(u,*) 'root_constants',hlim1,hlim2u,hlim2l,rdm
close(u)
end subroutine
end module MOD_native09
subroutine native09_io(u,rw)
use MOD_native09, only:io
integer::u,rw
call io(u,rw)
end subroutine
logical function native09_pending()
use MOD_native09, only:pending
native09_pending=pending
end function
subroutine native09_macro()
use MOD_native09, only:install_macro
call install_macro()
end subroutine
subroutine native09_host()
use MOD_native09, only:pending,install_host,dump
use MOD_SoilWater, only:soilwater
use MOD_cropdevelopment, only:cropdevelopment
use MOD_swap_base, only:pathcrop,iun_min2,iun_max2
use plant_interface, only:crpfilnam,cropfil,icrop,unit_crp,croptype
integer,external :: getun2
if(.not.pending) return
if(croptype(icrop)/=1) error stop 'NATIVE09 only simple crop supported'
! Read the same crop constants without cropdevelopment2/3 or daystart.
! Rutter's parameter reader resets SICACT; accepted host installation below
! restores that native reservoir and the saved daily geometry afterwards.
crpfilnam=trim(pathcrop)//trim(cropfil(icrop))//'.crp'
unit_crp=getun2(iun_min2,iun_max2,2)
call cropdevelopment(1)
! Refresh matrix hydraulic caches against restored H and initialized FrArMtrx;
! SoilWater1 does not integrate water or sorption for SWINCO3/SWHYST0.
call soilwater(1)
call install_host()
call dump('native_installed')
end subroutine
subroutine native09_dump(label)
use MOD_native09, only:dump
character(*)::label
call dump(label)
end subroutine
