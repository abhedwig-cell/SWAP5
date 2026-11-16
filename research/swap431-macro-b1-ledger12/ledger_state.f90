module LEDGER12
use MOD_arrays,only:macp,madr
use MOD_grid,only:numnod
use,intrinsic::ieee_arithmetic,only:ieee_is_finite
use MOD_integral,only:inqrot,inq,inqssdi,inqpotrot,inqredrot,iqdo,iqup,iqrot,iqssdi,iqredwet,iqreddry,iqredsol,iqredfrs,iintc,isintc,iepd,ipeva,iptra,ievap,iruno,irunon,iqbot,iqbdo,iqbup,iqtdo,iqtup,igrai,inrai,igird,inird,cgrai,cnrai,caintc,cqrot,cqbot,cqbotdo,cqbotup,cqssdi,cqtdo,cqtup,crunoff,crunon,cevap,cepd,cpeva,cptra,cinund,cqprai,cgird,cnird,cqdra,cqdrain,cqdrainin,cqdrainout,inqdra,inqdra_in,inqdra_out,iqdra,cgsnow,cmelt,csnrai,csubl,isnrai,igsnow,isubl
use MOD_integral_global,only:inqpotrot_day,inqredrot_day,iqrot_day,iqreddry_day,iqredsol_day,iptra_day,ialpwet_day,ialpdry_day
use MOD_swap_mp,only:WaSrDm1,WaSrDm1Ini,WaSrDm2,WaSrDm2Ini,WaUnMpDm1Cp,WaUnMpDm2Cp,cQMpInIntSatDm1,cQMpInIntSatDm2,cQMpInMtxSatDm1,cQMpInMtxSatDm2,cQMpInTopLatDm1,cQMpInTopLatDm2,cQMpInTopVrtDm1,cQMpInTopVrtDm2,cQMpOutDrRap,cQMpOutMtxSatDm1,cQMpOutMtxSatDm2,cQMpOutMtxUnsDm1,cQMpOutMtxUnsDm2,IAvFrMpWlWtDm1,IAvFrMpWlWtDm2,iQExcMtxDm1Cp,iQExcMtxDm2Cp,iQInTopLatDm1,iQInTopLatDm2,iQInTopVrtDm1,iQInTopVrtDm2,iQInIntSatDm1cp,iQInIntSatDm2cp,iQInMtxSatDm1cp,iQInMtxSatDm2cp,iQMpOutDrRap,iQOutMtxSatDm1cp,iQOutMtxSatDm2cp,iQOutMtxUnsDm1cp,iQOutMtxUnsDm2cp,iQOutDrRapCp,IQTopMpDm1Cp,IQTopMpDm2Cp,IWaSrDm1Beg,IWaSrDm2Beg,IWaUnDm1CpBeg,IWaUnDm2CpBeg
use variables,only:volini,pondini,ivolbeg,ipondbeg,isicbeg,issnowbeg,outper,ithetabeg,ioutdat,ioutdatint,nprintcount,cntper,period
use MOD_snow,only:snowinco
use MOD_timer,only:tcumold
implicit none
logical,save::loaded=.false.
real(8),save::b_inqrot(macp)
real(8),save::b_inq(macp+1)
real(8),save::b_inqssdi(macp)
real(8),save::b_inqpotrot(macp)
real(8),save::b_inqredrot(macp)
real(8),save::b_iqdo(macp+1)
real(8),save::b_iqup(macp+1)
real(8),save::b_iqrot
real(8),save::b_iqssdi
real(8),save::b_iqredwet
real(8),save::b_iqreddry
real(8),save::b_iqredsol
real(8),save::b_iqredfrs
real(8),save::b_iintc
real(8),save::b_isintc
real(8),save::b_iepd
real(8),save::b_ipeva
real(8),save::b_iptra
real(8),save::b_ievap
real(8),save::b_iruno
real(8),save::b_irunon
real(8),save::b_iqbot
real(8),save::b_iqbdo
real(8),save::b_iqbup
real(8),save::b_iqtdo
real(8),save::b_iqtup
real(8),save::b_igrai
real(8),save::b_inrai
real(8),save::b_igird
real(8),save::b_inird
real(8),save::b_cgrai
real(8),save::b_cnrai
real(8),save::b_caintc
real(8),save::b_cqrot
real(8),save::b_cqbot
real(8),save::b_cqbotdo
real(8),save::b_cqbotup
real(8),save::b_cqssdi
real(8),save::b_cqtdo
real(8),save::b_cqtup
real(8),save::b_crunoff
real(8),save::b_crunon
real(8),save::b_cevap
real(8),save::b_cepd
real(8),save::b_cpeva
real(8),save::b_cptra
real(8),save::b_cinund
real(8),save::b_cqprai
real(8),save::b_cgird
real(8),save::b_cnird
real(8),save::b_cqdra
real(8),save::b_cqdrain(madr)
real(8),save::b_cqdrainin(madr)
real(8),save::b_cqdrainout(madr)
real(8),save::b_inqdra(madr,macp)
real(8),save::b_inqdra_in(madr,macp)
real(8),save::b_inqdra_out(madr,macp)
real(8),save::b_iqdra
real(8),save::b_cgsnow
real(8),save::b_cmelt
real(8),save::b_csnrai
real(8),save::b_csubl
real(8),save::b_isnrai
real(8),save::b_igsnow
real(8),save::b_isubl
real(8),save::b_inqpotrot_day(macp)
real(8),save::b_inqredrot_day(macp)
real(8),save::b_iqrot_day
real(8),save::b_iqreddry_day
real(8),save::b_iqredsol_day
real(8),save::b_iptra_day
real(8),save::b_ialpwet_day
real(8),save::b_ialpdry_day
real(8),save::b_WaSrDm1
real(8),save::b_WaSrDm1Ini
real(8),save::b_WaSrDm2
real(8),save::b_WaSrDm2Ini
real(8),save::b_WaUnMpDm1Cp(macp)
real(8),save::b_WaUnMpDm2Cp(macp)
real(8),save::b_cQMpInIntSatDm1
real(8),save::b_cQMpInIntSatDm2
real(8),save::b_cQMpInMtxSatDm1
real(8),save::b_cQMpInMtxSatDm2
real(8),save::b_cQMpInTopLatDm1
real(8),save::b_cQMpInTopLatDm2
real(8),save::b_cQMpInTopVrtDm1
real(8),save::b_cQMpInTopVrtDm2
real(8),save::b_cQMpOutDrRap
real(8),save::b_cQMpOutMtxSatDm1
real(8),save::b_cQMpOutMtxSatDm2
real(8),save::b_cQMpOutMtxUnsDm1
real(8),save::b_cQMpOutMtxUnsDm2
real(8),save::b_IAvFrMpWlWtDm1(macp)
real(8),save::b_IAvFrMpWlWtDm2(macp)
real(8),save::b_iQExcMtxDm1Cp(macp)
real(8),save::b_iQExcMtxDm2Cp(macp)
real(8),save::b_iQInTopLatDm1
real(8),save::b_iQInTopLatDm2
real(8),save::b_iQInTopVrtDm1
real(8),save::b_iQInTopVrtDm2
real(8),save::b_iQInIntSatDm1cp(macp)
real(8),save::b_iQInIntSatDm2cp(macp)
real(8),save::b_iQInMtxSatDm1cp(macp)
real(8),save::b_iQInMtxSatDm2cp(macp)
real(8),save::b_iQMpOutDrRap
real(8),save::b_iQOutMtxSatDm1cp(macp)
real(8),save::b_iQOutMtxSatDm2cp(macp)
real(8),save::b_iQOutMtxUnsDm1cp(macp)
real(8),save::b_iQOutMtxUnsDm2cp(macp)
real(8),save::b_iQOutDrRapCp(macp)
real(8),save::b_IQTopMpDm1Cp(macp)
real(8),save::b_IQTopMpDm2Cp(macp)
real(8),save::b_IWaSrDm1Beg
real(8),save::b_IWaSrDm2Beg
real(8),save::b_IWaUnDm1CpBeg(macp)
real(8),save::b_IWaUnDm2CpBeg(macp)
real(8),save::b_volini
real(8),save::b_pondini
real(8),save::b_snowinco
real(8),save::b_ivolbeg
real(8),save::b_ipondbeg
real(8),save::b_isicbeg
real(8),save::b_issnowbeg
real(8),save::b_outper
real(8),save::b_ithetabeg(macp)
integer,save::b_ioutdat
integer,save::b_ioutdatint
integer,save::b_nprintcount
integer,save::b_cntper
integer,save::b_period
real(8),save::b_tcumold
contains
subroutine io(u,rw)
integer::u,rw,ios,n
character(32)::tag
if(rw==2) then
tag="WATER_LEDGER_V1"
write(u) tag,131
write(u) inqrot(1:numnod)
write(u) inq(1:numnod+1)
write(u) inqssdi(1:numnod)
write(u) inqpotrot(1:numnod)
write(u) inqredrot(1:numnod)
write(u) iqdo(1:numnod+1)
write(u) iqup(1:numnod+1)
write(u) iqrot
write(u) iqssdi
write(u) iqredwet
write(u) iqreddry
write(u) iqredsol
write(u) iqredfrs
write(u) iintc
write(u) isintc
write(u) iepd
write(u) ipeva
write(u) iptra
write(u) ievap
write(u) iruno
write(u) irunon
write(u) iqbot
write(u) iqbdo
write(u) iqbup
write(u) iqtdo
write(u) iqtup
write(u) igrai
write(u) inrai
write(u) igird
write(u) inird
write(u) cgrai
write(u) cnrai
write(u) caintc
write(u) cqrot
write(u) cqbot
write(u) cqbotdo
write(u) cqbotup
write(u) cqssdi
write(u) cqtdo
write(u) cqtup
write(u) crunoff
write(u) crunon
write(u) cevap
write(u) cepd
write(u) cpeva
write(u) cptra
write(u) cinund
write(u) cqprai
write(u) cgird
write(u) cnird
write(u) cqdra
write(u) cqdrain(:)
write(u) cqdrainin(:)
write(u) cqdrainout(:)
write(u) inqdra(:,1:numnod)
write(u) inqdra_in(:,1:numnod)
write(u) inqdra_out(:,1:numnod)
write(u) iqdra
write(u) cgsnow
write(u) cmelt
write(u) csnrai
write(u) csubl
write(u) isnrai
write(u) igsnow
write(u) isubl
write(u) inqpotrot_day(1:numnod)
write(u) inqredrot_day(1:numnod)
write(u) iqrot_day
write(u) iqreddry_day
write(u) iqredsol_day
write(u) iptra_day
write(u) ialpwet_day
write(u) ialpdry_day
write(u) WaSrDm1
write(u) WaSrDm1Ini
write(u) WaSrDm2
write(u) WaSrDm2Ini
write(u) WaUnMpDm1Cp(1:numnod)
write(u) WaUnMpDm2Cp(1:numnod)
write(u) cQMpInIntSatDm1
write(u) cQMpInIntSatDm2
write(u) cQMpInMtxSatDm1
write(u) cQMpInMtxSatDm2
write(u) cQMpInTopLatDm1
write(u) cQMpInTopLatDm2
write(u) cQMpInTopVrtDm1
write(u) cQMpInTopVrtDm2
write(u) cQMpOutDrRap
write(u) cQMpOutMtxSatDm1
write(u) cQMpOutMtxSatDm2
write(u) cQMpOutMtxUnsDm1
write(u) cQMpOutMtxUnsDm2
write(u) IAvFrMpWlWtDm1(1:numnod)
write(u) IAvFrMpWlWtDm2(1:numnod)
write(u) iQExcMtxDm1Cp(1:numnod)
write(u) iQExcMtxDm2Cp(1:numnod)
write(u) iQInTopLatDm1
write(u) iQInTopLatDm2
write(u) iQInTopVrtDm1
write(u) iQInTopVrtDm2
write(u) iQInIntSatDm1cp(1:numnod)
write(u) iQInIntSatDm2cp(1:numnod)
write(u) iQInMtxSatDm1cp(1:numnod)
write(u) iQInMtxSatDm2cp(1:numnod)
write(u) iQMpOutDrRap
write(u) iQOutMtxSatDm1cp(1:numnod)
write(u) iQOutMtxSatDm2cp(1:numnod)
write(u) iQOutMtxUnsDm1cp(1:numnod)
write(u) iQOutMtxUnsDm2cp(1:numnod)
write(u) iQOutDrRapCp(1:numnod)
write(u) IQTopMpDm1Cp(1:numnod)
write(u) IQTopMpDm2Cp(1:numnod)
write(u) IWaSrDm1Beg
write(u) IWaSrDm2Beg
write(u) IWaUnDm1CpBeg(1:numnod)
write(u) IWaUnDm2CpBeg(1:numnod)
write(u) volini
write(u) pondini
write(u) snowinco
write(u) ivolbeg
write(u) ipondbeg
write(u) isicbeg
write(u) issnowbeg
write(u) outper
write(u) ithetabeg(1:numnod)
write(u) ioutdat
write(u) ioutdatint
write(u) nprintcount
write(u) cntper
write(u) period
write(u) tcumold
return
end if
read(u,iostat=ios) tag,n
if(ios/=0.or.tag/="WATER_LEDGER_V1".or.n/=131) error stop "LEDGER12 missing or invalid schema"
read(u,iostat=ios) b_inqrot(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_inqrot(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_inq(1:numnod+1)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_inq(1:numnod+1)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_inqssdi(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_inqssdi(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_inqpotrot(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_inqpotrot(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_inqredrot(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_inqredrot(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqdo(1:numnod+1)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_iqdo(1:numnod+1)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqup(1:numnod+1)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_iqup(1:numnod+1)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqrot
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqrot)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqssdi
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqssdi)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqredwet
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqredwet)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqreddry
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqreddry)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqredsol
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqredsol)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqredfrs
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqredfrs)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iintc
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iintc)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_isintc
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_isintc)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iepd
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iepd)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_ipeva
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_ipeva)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iptra
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iptra)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_ievap
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_ievap)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iruno
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iruno)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_irunon
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_irunon)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqbot
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqbot)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqbdo
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqbdo)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqbup
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqbup)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqtdo
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqtdo)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqtup
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqtup)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_igrai
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_igrai)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_inrai
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_inrai)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_igird
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_igird)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_inird
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_inird)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cgrai
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cgrai)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cnrai
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cnrai)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_caintc
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_caintc)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cqrot
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cqrot)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cqbot
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cqbot)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cqbotdo
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cqbotdo)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cqbotup
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cqbotup)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cqssdi
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cqssdi)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cqtdo
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cqtdo)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cqtup
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cqtup)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_crunoff
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_crunoff)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_crunon
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_crunon)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cevap
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cevap)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cepd
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cepd)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cpeva
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cpeva)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cptra
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cptra)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cinund
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cinund)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cqprai
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cqprai)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cgird
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cgird)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cnird
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cnird)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cqdra
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cqdra)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cqdrain(:)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_cqdrain(:)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cqdrainin(:)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_cqdrainin(:)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cqdrainout(:)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_cqdrainout(:)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_inqdra(:,1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_inqdra(:,1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_inqdra_in(:,1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_inqdra_in(:,1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_inqdra_out(:,1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_inqdra_out(:,1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqdra
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqdra)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cgsnow
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cgsnow)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cmelt
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cmelt)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_csnrai
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_csnrai)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_csubl
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_csubl)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_isnrai
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_isnrai)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_igsnow
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_igsnow)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_isubl
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_isubl)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_inqpotrot_day(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_inqpotrot_day(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_inqredrot_day(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_inqredrot_day(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqrot_day
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqrot_day)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqreddry_day
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqreddry_day)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iqredsol_day
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iqredsol_day)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iptra_day
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iptra_day)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_ialpwet_day
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_ialpwet_day)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_ialpdry_day
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_ialpdry_day)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_WaSrDm1
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_WaSrDm1)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_WaSrDm1Ini
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_WaSrDm1Ini)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_WaSrDm2
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_WaSrDm2)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_WaSrDm2Ini
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_WaSrDm2Ini)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_WaUnMpDm1Cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_WaUnMpDm1Cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_WaUnMpDm2Cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_WaUnMpDm2Cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cQMpInIntSatDm1
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cQMpInIntSatDm1)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cQMpInIntSatDm2
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cQMpInIntSatDm2)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cQMpInMtxSatDm1
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cQMpInMtxSatDm1)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cQMpInMtxSatDm2
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cQMpInMtxSatDm2)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cQMpInTopLatDm1
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cQMpInTopLatDm1)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cQMpInTopLatDm2
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cQMpInTopLatDm2)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cQMpInTopVrtDm1
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cQMpInTopVrtDm1)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cQMpInTopVrtDm2
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cQMpInTopVrtDm2)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cQMpOutDrRap
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cQMpOutDrRap)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cQMpOutMtxSatDm1
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cQMpOutMtxSatDm1)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cQMpOutMtxSatDm2
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cQMpOutMtxSatDm2)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cQMpOutMtxUnsDm1
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cQMpOutMtxUnsDm1)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_cQMpOutMtxUnsDm2
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_cQMpOutMtxUnsDm2)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_IAvFrMpWlWtDm1(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_IAvFrMpWlWtDm1(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_IAvFrMpWlWtDm2(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_IAvFrMpWlWtDm2(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQExcMtxDm1Cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_iQExcMtxDm1Cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQExcMtxDm2Cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_iQExcMtxDm2Cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQInTopLatDm1
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iQInTopLatDm1)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQInTopLatDm2
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iQInTopLatDm2)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQInTopVrtDm1
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iQInTopVrtDm1)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQInTopVrtDm2
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iQInTopVrtDm2)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQInIntSatDm1cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_iQInIntSatDm1cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQInIntSatDm2cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_iQInIntSatDm2cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQInMtxSatDm1cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_iQInMtxSatDm1cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQInMtxSatDm2cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_iQInMtxSatDm2cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQMpOutDrRap
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_iQMpOutDrRap)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQOutMtxSatDm1cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_iQOutMtxSatDm1cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQOutMtxSatDm2cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_iQOutMtxSatDm2cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQOutMtxUnsDm1cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_iQOutMtxUnsDm1cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQOutMtxUnsDm2cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_iQOutMtxUnsDm2cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_iQOutDrRapCp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_iQOutDrRapCp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_IQTopMpDm1Cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_IQTopMpDm1Cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_IQTopMpDm2Cp(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_IQTopMpDm2Cp(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_IWaSrDm1Beg
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_IWaSrDm1Beg)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_IWaSrDm2Beg
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_IWaSrDm2Beg)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_IWaUnDm1CpBeg(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_IWaUnDm1CpBeg(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_IWaUnDm2CpBeg(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_IWaUnDm2CpBeg(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_volini
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_volini)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_pondini
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_pondini)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_snowinco
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_snowinco)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_ivolbeg
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_ivolbeg)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_ipondbeg
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_ipondbeg)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_isicbeg
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_isicbeg)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_issnowbeg
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_issnowbeg)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_outper
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_outper)) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_ithetabeg(1:numnod)
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.all(ieee_is_finite(b_ithetabeg(1:numnod)))) error stop "LEDGER12 nonfinite"
read(u,iostat=ios) b_ioutdat
if(ios/=0) error stop "LEDGER12 incomplete"
read(u,iostat=ios) b_ioutdatint
if(ios/=0) error stop "LEDGER12 incomplete"
read(u,iostat=ios) b_nprintcount
if(ios/=0) error stop "LEDGER12 incomplete"
read(u,iostat=ios) b_cntper
if(ios/=0) error stop "LEDGER12 incomplete"
read(u,iostat=ios) b_period
if(ios/=0) error stop "LEDGER12 incomplete"
read(u,iostat=ios) b_tcumold
if(ios/=0) error stop "LEDGER12 incomplete"
if(.not.ieee_is_finite(b_tcumold)) error stop "LEDGER12 nonfinite"
loaded=.true.
end subroutine
subroutine apply()
if(.not.loaded) return
inqrot(1:numnod)=b_inqrot(1:numnod)
inq(1:numnod+1)=b_inq(1:numnod+1)
inqssdi(1:numnod)=b_inqssdi(1:numnod)
inqpotrot(1:numnod)=b_inqpotrot(1:numnod)
inqredrot(1:numnod)=b_inqredrot(1:numnod)
iqdo(1:numnod+1)=b_iqdo(1:numnod+1)
iqup(1:numnod+1)=b_iqup(1:numnod+1)
iqrot=b_iqrot
iqssdi=b_iqssdi
iqredwet=b_iqredwet
iqreddry=b_iqreddry
iqredsol=b_iqredsol
iqredfrs=b_iqredfrs
iintc=b_iintc
isintc=b_isintc
iepd=b_iepd
ipeva=b_ipeva
iptra=b_iptra
ievap=b_ievap
iruno=b_iruno
irunon=b_irunon
iqbot=b_iqbot
iqbdo=b_iqbdo
iqbup=b_iqbup
iqtdo=b_iqtdo
iqtup=b_iqtup
igrai=b_igrai
inrai=b_inrai
igird=b_igird
inird=b_inird
cgrai=b_cgrai
cnrai=b_cnrai
caintc=b_caintc
cqrot=b_cqrot
cqbot=b_cqbot
cqbotdo=b_cqbotdo
cqbotup=b_cqbotup
cqssdi=b_cqssdi
cqtdo=b_cqtdo
cqtup=b_cqtup
crunoff=b_crunoff
crunon=b_crunon
cevap=b_cevap
cepd=b_cepd
cpeva=b_cpeva
cptra=b_cptra
cinund=b_cinund
cqprai=b_cqprai
cgird=b_cgird
cnird=b_cnird
cqdra=b_cqdra
cqdrain(:)=b_cqdrain(:)
cqdrainin(:)=b_cqdrainin(:)
cqdrainout(:)=b_cqdrainout(:)
inqdra(:,1:numnod)=b_inqdra(:,1:numnod)
inqdra_in(:,1:numnod)=b_inqdra_in(:,1:numnod)
inqdra_out(:,1:numnod)=b_inqdra_out(:,1:numnod)
iqdra=b_iqdra
cgsnow=b_cgsnow
cmelt=b_cmelt
csnrai=b_csnrai
csubl=b_csubl
isnrai=b_isnrai
igsnow=b_igsnow
isubl=b_isubl
inqpotrot_day(1:numnod)=b_inqpotrot_day(1:numnod)
inqredrot_day(1:numnod)=b_inqredrot_day(1:numnod)
iqrot_day=b_iqrot_day
iqreddry_day=b_iqreddry_day
iqredsol_day=b_iqredsol_day
iptra_day=b_iptra_day
ialpwet_day=b_ialpwet_day
ialpdry_day=b_ialpdry_day
WaSrDm1=b_WaSrDm1
WaSrDm1Ini=b_WaSrDm1Ini
WaSrDm2=b_WaSrDm2
WaSrDm2Ini=b_WaSrDm2Ini
WaUnMpDm1Cp(1:numnod)=b_WaUnMpDm1Cp(1:numnod)
WaUnMpDm2Cp(1:numnod)=b_WaUnMpDm2Cp(1:numnod)
cQMpInIntSatDm1=b_cQMpInIntSatDm1
cQMpInIntSatDm2=b_cQMpInIntSatDm2
cQMpInMtxSatDm1=b_cQMpInMtxSatDm1
cQMpInMtxSatDm2=b_cQMpInMtxSatDm2
cQMpInTopLatDm1=b_cQMpInTopLatDm1
cQMpInTopLatDm2=b_cQMpInTopLatDm2
cQMpInTopVrtDm1=b_cQMpInTopVrtDm1
cQMpInTopVrtDm2=b_cQMpInTopVrtDm2
cQMpOutDrRap=b_cQMpOutDrRap
cQMpOutMtxSatDm1=b_cQMpOutMtxSatDm1
cQMpOutMtxSatDm2=b_cQMpOutMtxSatDm2
cQMpOutMtxUnsDm1=b_cQMpOutMtxUnsDm1
cQMpOutMtxUnsDm2=b_cQMpOutMtxUnsDm2
IAvFrMpWlWtDm1(1:numnod)=b_IAvFrMpWlWtDm1(1:numnod)
IAvFrMpWlWtDm2(1:numnod)=b_IAvFrMpWlWtDm2(1:numnod)
iQExcMtxDm1Cp(1:numnod)=b_iQExcMtxDm1Cp(1:numnod)
iQExcMtxDm2Cp(1:numnod)=b_iQExcMtxDm2Cp(1:numnod)
iQInTopLatDm1=b_iQInTopLatDm1
iQInTopLatDm2=b_iQInTopLatDm2
iQInTopVrtDm1=b_iQInTopVrtDm1
iQInTopVrtDm2=b_iQInTopVrtDm2
iQInIntSatDm1cp(1:numnod)=b_iQInIntSatDm1cp(1:numnod)
iQInIntSatDm2cp(1:numnod)=b_iQInIntSatDm2cp(1:numnod)
iQInMtxSatDm1cp(1:numnod)=b_iQInMtxSatDm1cp(1:numnod)
iQInMtxSatDm2cp(1:numnod)=b_iQInMtxSatDm2cp(1:numnod)
iQMpOutDrRap=b_iQMpOutDrRap
iQOutMtxSatDm1cp(1:numnod)=b_iQOutMtxSatDm1cp(1:numnod)
iQOutMtxSatDm2cp(1:numnod)=b_iQOutMtxSatDm2cp(1:numnod)
iQOutMtxUnsDm1cp(1:numnod)=b_iQOutMtxUnsDm1cp(1:numnod)
iQOutMtxUnsDm2cp(1:numnod)=b_iQOutMtxUnsDm2cp(1:numnod)
iQOutDrRapCp(1:numnod)=b_iQOutDrRapCp(1:numnod)
IQTopMpDm1Cp(1:numnod)=b_IQTopMpDm1Cp(1:numnod)
IQTopMpDm2Cp(1:numnod)=b_IQTopMpDm2Cp(1:numnod)
IWaSrDm1Beg=b_IWaSrDm1Beg
IWaSrDm2Beg=b_IWaSrDm2Beg
IWaUnDm1CpBeg(1:numnod)=b_IWaUnDm1CpBeg(1:numnod)
IWaUnDm2CpBeg(1:numnod)=b_IWaUnDm2CpBeg(1:numnod)
volini=b_volini
pondini=b_pondini
snowinco=b_snowinco
ivolbeg=b_ivolbeg
ipondbeg=b_ipondbeg
isicbeg=b_isicbeg
issnowbeg=b_issnowbeg
outper=b_outper
ithetabeg(1:numnod)=b_ithetabeg(1:numnod)
ioutdat=b_ioutdat
ioutdatint=b_ioutdatint
nprintcount=b_nprintcount
cntper=b_cntper
period=b_period
tcumold=b_tcumold
end subroutine
subroutine dump(label)
character(*)::label
integer::u
open(newunit=u,file=label//".txt",status="replace")
write(u,*) "inqrot",inqrot(1:numnod)
write(u,*) "inq",inq(1:numnod+1)
write(u,*) "inqssdi",inqssdi(1:numnod)
write(u,*) "inqpotrot",inqpotrot(1:numnod)
write(u,*) "inqredrot",inqredrot(1:numnod)
write(u,*) "iqdo",iqdo(1:numnod+1)
write(u,*) "iqup",iqup(1:numnod+1)
write(u,*) "iqrot",iqrot
write(u,*) "iqssdi",iqssdi
write(u,*) "iqredwet",iqredwet
write(u,*) "iqreddry",iqreddry
write(u,*) "iqredsol",iqredsol
write(u,*) "iqredfrs",iqredfrs
write(u,*) "iintc",iintc
write(u,*) "isintc",isintc
write(u,*) "iepd",iepd
write(u,*) "ipeva",ipeva
write(u,*) "iptra",iptra
write(u,*) "ievap",ievap
write(u,*) "iruno",iruno
write(u,*) "irunon",irunon
write(u,*) "iqbot",iqbot
write(u,*) "iqbdo",iqbdo
write(u,*) "iqbup",iqbup
write(u,*) "iqtdo",iqtdo
write(u,*) "iqtup",iqtup
write(u,*) "igrai",igrai
write(u,*) "inrai",inrai
write(u,*) "igird",igird
write(u,*) "inird",inird
write(u,*) "cgrai",cgrai
write(u,*) "cnrai",cnrai
write(u,*) "caintc",caintc
write(u,*) "cqrot",cqrot
write(u,*) "cqbot",cqbot
write(u,*) "cqbotdo",cqbotdo
write(u,*) "cqbotup",cqbotup
write(u,*) "cqssdi",cqssdi
write(u,*) "cqtdo",cqtdo
write(u,*) "cqtup",cqtup
write(u,*) "crunoff",crunoff
write(u,*) "crunon",crunon
write(u,*) "cevap",cevap
write(u,*) "cepd",cepd
write(u,*) "cpeva",cpeva
write(u,*) "cptra",cptra
write(u,*) "cinund",cinund
write(u,*) "cqprai",cqprai
write(u,*) "cgird",cgird
write(u,*) "cnird",cnird
write(u,*) "cqdra",cqdra
write(u,*) "cqdrain",cqdrain(:)
write(u,*) "cqdrainin",cqdrainin(:)
write(u,*) "cqdrainout",cqdrainout(:)
write(u,*) "inqdra",inqdra(:,1:numnod)
write(u,*) "inqdra_in",inqdra_in(:,1:numnod)
write(u,*) "inqdra_out",inqdra_out(:,1:numnod)
write(u,*) "iqdra",iqdra
write(u,*) "cgsnow",cgsnow
write(u,*) "cmelt",cmelt
write(u,*) "csnrai",csnrai
write(u,*) "csubl",csubl
write(u,*) "isnrai",isnrai
write(u,*) "igsnow",igsnow
write(u,*) "isubl",isubl
write(u,*) "inqpotrot_day",inqpotrot_day(1:numnod)
write(u,*) "inqredrot_day",inqredrot_day(1:numnod)
write(u,*) "iqrot_day",iqrot_day
write(u,*) "iqreddry_day",iqreddry_day
write(u,*) "iqredsol_day",iqredsol_day
write(u,*) "iptra_day",iptra_day
write(u,*) "ialpwet_day",ialpwet_day
write(u,*) "ialpdry_day",ialpdry_day
write(u,*) "WaSrDm1",WaSrDm1
write(u,*) "WaSrDm1Ini",WaSrDm1Ini
write(u,*) "WaSrDm2",WaSrDm2
write(u,*) "WaSrDm2Ini",WaSrDm2Ini
write(u,*) "WaUnMpDm1Cp",WaUnMpDm1Cp(1:numnod)
write(u,*) "WaUnMpDm2Cp",WaUnMpDm2Cp(1:numnod)
write(u,*) "cQMpInIntSatDm1",cQMpInIntSatDm1
write(u,*) "cQMpInIntSatDm2",cQMpInIntSatDm2
write(u,*) "cQMpInMtxSatDm1",cQMpInMtxSatDm1
write(u,*) "cQMpInMtxSatDm2",cQMpInMtxSatDm2
write(u,*) "cQMpInTopLatDm1",cQMpInTopLatDm1
write(u,*) "cQMpInTopLatDm2",cQMpInTopLatDm2
write(u,*) "cQMpInTopVrtDm1",cQMpInTopVrtDm1
write(u,*) "cQMpInTopVrtDm2",cQMpInTopVrtDm2
write(u,*) "cQMpOutDrRap",cQMpOutDrRap
write(u,*) "cQMpOutMtxSatDm1",cQMpOutMtxSatDm1
write(u,*) "cQMpOutMtxSatDm2",cQMpOutMtxSatDm2
write(u,*) "cQMpOutMtxUnsDm1",cQMpOutMtxUnsDm1
write(u,*) "cQMpOutMtxUnsDm2",cQMpOutMtxUnsDm2
write(u,*) "IAvFrMpWlWtDm1",IAvFrMpWlWtDm1(1:numnod)
write(u,*) "IAvFrMpWlWtDm2",IAvFrMpWlWtDm2(1:numnod)
write(u,*) "iQExcMtxDm1Cp",iQExcMtxDm1Cp(1:numnod)
write(u,*) "iQExcMtxDm2Cp",iQExcMtxDm2Cp(1:numnod)
write(u,*) "iQInTopLatDm1",iQInTopLatDm1
write(u,*) "iQInTopLatDm2",iQInTopLatDm2
write(u,*) "iQInTopVrtDm1",iQInTopVrtDm1
write(u,*) "iQInTopVrtDm2",iQInTopVrtDm2
write(u,*) "iQInIntSatDm1cp",iQInIntSatDm1cp(1:numnod)
write(u,*) "iQInIntSatDm2cp",iQInIntSatDm2cp(1:numnod)
write(u,*) "iQInMtxSatDm1cp",iQInMtxSatDm1cp(1:numnod)
write(u,*) "iQInMtxSatDm2cp",iQInMtxSatDm2cp(1:numnod)
write(u,*) "iQMpOutDrRap",iQMpOutDrRap
write(u,*) "iQOutMtxSatDm1cp",iQOutMtxSatDm1cp(1:numnod)
write(u,*) "iQOutMtxSatDm2cp",iQOutMtxSatDm2cp(1:numnod)
write(u,*) "iQOutMtxUnsDm1cp",iQOutMtxUnsDm1cp(1:numnod)
write(u,*) "iQOutMtxUnsDm2cp",iQOutMtxUnsDm2cp(1:numnod)
write(u,*) "iQOutDrRapCp",iQOutDrRapCp(1:numnod)
write(u,*) "IQTopMpDm1Cp",IQTopMpDm1Cp(1:numnod)
write(u,*) "IQTopMpDm2Cp",IQTopMpDm2Cp(1:numnod)
write(u,*) "IWaSrDm1Beg",IWaSrDm1Beg
write(u,*) "IWaSrDm2Beg",IWaSrDm2Beg
write(u,*) "IWaUnDm1CpBeg",IWaUnDm1CpBeg(1:numnod)
write(u,*) "IWaUnDm2CpBeg",IWaUnDm2CpBeg(1:numnod)
write(u,*) "volini",volini
write(u,*) "pondini",pondini
write(u,*) "snowinco",snowinco
write(u,*) "ivolbeg",ivolbeg
write(u,*) "ipondbeg",ipondbeg
write(u,*) "isicbeg",isicbeg
write(u,*) "issnowbeg",issnowbeg
write(u,*) "outper",outper
write(u,*) "ithetabeg",ithetabeg(1:numnod)
write(u,*) "ioutdat",ioutdat
write(u,*) "ioutdatint",ioutdatint
write(u,*) "nprintcount",nprintcount
write(u,*) "cntper",cntper
write(u,*) "period",period
write(u,*) "tcumold",tcumold
close(u)
end subroutine
end module
subroutine ledger12_io(u,rw)
use LEDGER12,only:io
integer::u,rw
call io(u,rw)
end subroutine
subroutine ledger12_apply()
use LEDGER12,only:apply
call apply()
end subroutine
subroutine ledger12_dump(label)
use LEDGER12,only:dump
character(*)::label
call dump(label)
end subroutine
