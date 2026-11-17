module SENSE23_TRANSACTION
use MOD_gwl,only:sense23_gwl_io
use MOD_macropore,only:m_SwBma=>SwBma,m_swabs=>swabs,m_swsep=>swsep,m_SwDarcy=>SwDarcy,m_SwPowM=>SwPowM
use MOD_macropore,only:m_SwShrInp=>SwShrInp,m_SwSoilShr=>SwSoilShr,m_SwSorp=>SwSorp,m_NumSbDm=>NumSbDm,m_DiPoMa=>DiPoMa
use MOD_macropore,only:m_DiPoMi=>DiPoMi,m_GeomFac=>GeomFac,m_nkwt=>nkwt,m_PowM=>PowM,m_PpIcSs=>PpIcSs
use MOD_macropore,only:m_RapDraReaExp=>RapDraReaExp,m_RapDraResRef=>RapDraResRef,m_Rzah=>Rzah,m_ShapeFacMp=>ShapeFacMp,m_SorpAlfa=>SorpAlfa
use MOD_macropore,only:m_SorpMax=>SorpMax,m_SorpFacParl=>SorpFacParl,m_ShrParA=>ShrParA,m_ShrParB=>ShrParB,m_ShrParC=>ShrParC
use MOD_macropore,only:m_ShrParD=>ShrParD,m_ShrParE=>ShrParE,m_Spoint=>Spoint,m_ThetCrMp=>ThetCrMp,m_VlMpStSs=>VlMpStSs
use MOD_macropore,only:m_Z_Ah=>Z_Ah,m_Z_Ic=>Z_Ic,m_Z_MB50=>Z_MB50,m_Z_St=>Z_St,m_Z_Tp=>Z_Tp
use MOD_macropore,only:m_ZDiPoMa=>ZDiPoMa,m_ZnCrAr=>ZnCrAr,m_FrMpWalWetIntegralOld=>FrMpWalWetIntegralOld,m_FlEndSrpEvt=>FlEndSrpEvt,m_ICpBtDm=>ICpBtDm
use MOD_macropore,only:m_ICpBtDmM1=>ICpBtDmM1,m_ICpBtDmPot=>ICpBtDmPot,m_ICpBtPerZon=>ICpBtPerZon,m_ICpTpPerZon=>ICpTpPerZon,m_ICpTpSatZon=>ICpTpSatZon
use MOD_macropore,only:m_ICpTpWaSrDm=>ICpTpWaSrDm,m_NnCrAr=>NnCrAr,m_NumDm=>NumDm,m_bma=>bma,m_ArMpTp=>ArMpTp
use MOD_macropore,only:m_ArMpTpDm=>ArMpTpDm,m_AwlCorFac=>AwlCorFac,m_CDarcy=>CDarcy,m_DiMtxSat=>DiMtxSat,m_FrMpWalWet=>FrMpWalWet
use MOD_macropore,only:m_FrMpWalWetOld=>FrMpWalWetOld,m_FrReduQ=>FrReduQ,m_KDCrRlRef=>KDCrRlRef,m_KsatCovLay=>KsatCovLay,m_PpDmCp=>PpDmCp
use MOD_macropore,only:m_QExcMtxDmCp=>QExcMtxDmCp,m_QInIntSatDmCp=>QInIntSatDmCp,m_QInMtxSatDmCp=>QInMtxSatDmCp,m_QInTopLatDm=>QInTopLatDm,m_QInTopLatDm1=>QInTopLatDm1
use MOD_macropore,only:m_QInTopLatDm2=>QInTopLatDm2,m_QInTopVrtDm=>QInTopVrtDm,m_QInTopVrtDm1=>QInTopVrtDm1,m_QInTopVrtDm2=>QInTopVrtDm2,m_QOutDrRapCp=>QOutDrRapCp
use MOD_macropore,only:m_QOutMtxSatDmCp=>QOutMtxSatDmCp,m_QOutMtxUnsDmCp=>QOutMtxUnsDmCp,m_QTopMpDmCp=>QTopMpDmCp,m_SorpDmCp=>SorpDmCp,m_SubsidCpMin=>SubsidCpMin
use MOD_macropore,only:m_ThtSrpRefDmCp=>ThtSrpRefDmCp,m_TimAbsCumDmCp=>TimAbsCumDmCp,m_VlMp=>VlMp,m_VlMpDm=>VlMpDm,m_VlMpDmCp=>VlMpDmCp
use MOD_macropore,only:m_VlMpDmCpM1=>VlMpDmCpM1,m_VlMpStCp=>VlMpStCp,m_WaSrMp=>WaSrMp,m_WaSrMpDm=>WaSrMpDm,m_WaUnsat=>WaUnsat
use MOD_macropore,only:m_WaUnMpDm=>WaUnMpDm,m_WaUnMpDmCp=>WaUnMpDmCp,m_WaUnMpDmCpM1=>WaUnMpDmCpM1,m_ZBtDm=>ZBtDm,m_ZWaLevDm=>ZWaLevDm
use MOD_swap_mp,only:p_FlDecMpRat=>FlDecMpRat,p_fldecMPmbf=>fldecMPmbf,p_IcTopMP=>IcTopMP,p_IDecMpRat=>IDecMpRat,p_NodGWlFlCpZo=>NodGWlFlCpZo
use MOD_swap_mp,only:p_NumLevRapDra=>NumLevRapDra,p_SwDrRap=>SwDrRap,p_SwMBF=>SwMBF,p_ArMpSs=>ArMpSs,p_CritUndSatVol=>CritUndSatVol
use MOD_swap_mp,only:p_dFdhMp=>dFdhMp,p_GWlFlCpZo=>GWlFlCpZo,p_KsMpSs=>KsMpSs,p_PndmxMp=>PndmxMp,p_QExcMpMtx=>QExcMpMtx
use MOD_swap_mp,only:p_QMaPo=>QMaPo,p_QMpLatSs=>QMpLatSs,p_QRapDra=>QRapDra,p_ZDraBas=>ZDraBas,p_FrArMtrx=>FrArMtrx
use MOD_swap_mp,only:p_WaSrDm1=>WaSrDm1,p_WaSrDm1Ini=>WaSrDm1Ini,p_WaSrDm2=>WaSrDm2,p_WaSrDm2Ini=>WaSrDm2Ini,p_WaUnMpDm1Cp=>WaUnMpDm1Cp
use MOD_swap_mp,only:p_WaUnMpDm2Cp=>WaUnMpDm2Cp,p_cQMpInIntSatDm1=>cQMpInIntSatDm1,p_cQMpInIntSatDm2=>cQMpInIntSatDm2,p_cQMpInMtxSatDm1=>cQMpInMtxSatDm1,p_cQMpInMtxSatDm2=>cQMpInMtxSatDm2
use MOD_swap_mp,only:p_cQMpInTopLatDm1=>cQMpInTopLatDm1,p_cQMpInTopLatDm2=>cQMpInTopLatDm2,p_cQMpInTopVrtDm1=>cQMpInTopVrtDm1,p_cQMpInTopVrtDm2=>cQMpInTopVrtDm2,p_cQMpOutDrRap=>cQMpOutDrRap
use MOD_swap_mp,only:p_cQMpOutMtxSatDm1=>cQMpOutMtxSatDm1,p_cQMpOutMtxSatDm2=>cQMpOutMtxSatDm2,p_cQMpOutMtxUnsDm1=>cQMpOutMtxUnsDm1,p_cQMpOutMtxUnsDm2=>cQMpOutMtxUnsDm2,p_DiPoCp=>DiPoCp
use MOD_swap_mp,only:p_IAvFrMpWlWtDm1=>IAvFrMpWlWtDm1,p_IAvFrMpWlWtDm2=>IAvFrMpWlWtDm2,p_iQExcMtxDm1Cp=>iQExcMtxDm1Cp,p_iQExcMtxDm2Cp=>iQExcMtxDm2Cp,p_iQInTopLatDm1=>iQInTopLatDm1
use MOD_swap_mp,only:p_iQInTopLatDm2=>iQInTopLatDm2,p_iQInTopVrtDm1=>iQInTopVrtDm1,p_iQInTopVrtDm2=>iQInTopVrtDm2,p_iQInIntSatDm1cp=>iQInIntSatDm1cp,p_iQInIntSatDm2cp=>iQInIntSatDm2cp
use MOD_swap_mp,only:p_iQInMtxSatDm1cp=>iQInMtxSatDm1cp,p_iQInMtxSatDm2cp=>iQInMtxSatDm2cp,p_iQMpOutDrRap=>iQMpOutDrRap,p_iQOutMtxSatDm1cp=>iQOutMtxSatDm1cp,p_iQOutMtxSatDm2cp=>iQOutMtxSatDm2cp
use MOD_swap_mp,only:p_iQOutMtxUnsDm1cp=>iQOutMtxUnsDm1cp,p_iQOutMtxUnsDm2cp=>iQOutMtxUnsDm2cp,p_iQOutDrRapCp=>iQOutDrRapCp,p_IQTopMpDm1Cp=>IQTopMpDm1Cp,p_IQTopMpDm2Cp=>IQTopMpDm2Cp
use MOD_swap_mp,only:p_IWaSrDm1Beg=>IWaSrDm1Beg,p_IWaSrDm2Beg=>IWaSrDm2Beg,p_IWaUnDm1CpBeg=>IWaUnDm1CpBeg,p_IWaUnDm2CpBeg=>IWaUnDm2CpBeg,p_SubsidCp=>SubsidCp
use MOD_swap_mp,only:p_VlMpDm1=>VlMpDm1,p_VlMpDm2=>VlMpDm2,p_VlMpDm1Cp=>VlMpDm1Cp,p_VlMpDm2Cp=>VlMpDm2Cp,p_VlMpDyCp=>VlMpDyCp
use MOD_swap_mp,only:p_VlMpStDm1=>VlMpStDm1,p_VlMpStDm2=>VlMpStDm2,p_WaLevDm1=>WaLevDm1
use variables,only:v_h=>h,v_theta=>theta,v_k=>k,v_kmean=>kmean,v_dimoca=>dimoca
use variables,only:v_gwl=>gwl,v_nodgwl=>nodgwl,v_bpegwl=>bpegwl,v_npegwl=>npegwl,v_pegwl=>pegwl
use variables,only:v_pegwl_bot=>pegwl_bot,v_gwlm1=>gwlm1,v_gwlconv=>gwlconv,v_pond=>pond,v_dt=>dt
use variables,only:v_t1900=>t1900
use DIAG19,only:d_macro_seq=>macro_seq
implicit none
contains
subroutine snapshot(path,mode)
character(*),intent(in)::path
integer,intent(in)::mode
integer::u
if(mode==1) then
 open(newunit=u,file=path,status='replace',access='stream',form='unformatted')
write(u) m_SwBma,m_swabs,m_swsep,m_SwDarcy,m_SwPowM
write(u) m_SwShrInp,m_SwSoilShr,m_SwSorp,m_NumSbDm,m_DiPoMa
write(u) m_DiPoMi,m_GeomFac,m_nkwt,m_PowM,m_PpIcSs
write(u) m_RapDraReaExp,m_RapDraResRef,m_Rzah,m_ShapeFacMp,m_SorpAlfa
write(u) m_SorpMax,m_SorpFacParl,m_ShrParA,m_ShrParB,m_ShrParC
write(u) m_ShrParD,m_ShrParE,m_Spoint,m_ThetCrMp,m_VlMpStSs
write(u) m_Z_Ah,m_Z_Ic,m_Z_MB50,m_Z_St,m_Z_Tp
write(u) m_ZDiPoMa,m_ZnCrAr,m_FrMpWalWetIntegralOld,m_FlEndSrpEvt,m_ICpBtDm
write(u) m_ICpBtDmM1,m_ICpBtDmPot,m_ICpBtPerZon,m_ICpTpPerZon,m_ICpTpSatZon
write(u) m_ICpTpWaSrDm,m_NnCrAr,m_NumDm,m_bma,m_ArMpTp
write(u) m_ArMpTpDm,m_AwlCorFac,m_CDarcy,m_DiMtxSat,m_FrMpWalWet
write(u) m_FrMpWalWetOld,m_FrReduQ,m_KDCrRlRef,m_KsatCovLay,m_PpDmCp
write(u) m_QExcMtxDmCp,m_QInIntSatDmCp,m_QInMtxSatDmCp,m_QInTopLatDm,m_QInTopLatDm1
write(u) m_QInTopLatDm2,m_QInTopVrtDm,m_QInTopVrtDm1,m_QInTopVrtDm2,m_QOutDrRapCp
write(u) m_QOutMtxSatDmCp,m_QOutMtxUnsDmCp,m_QTopMpDmCp,m_SorpDmCp,m_SubsidCpMin
write(u) m_ThtSrpRefDmCp,m_TimAbsCumDmCp,m_VlMp,m_VlMpDm,m_VlMpDmCp
write(u) m_VlMpDmCpM1,m_VlMpStCp,m_WaSrMp,m_WaSrMpDm,m_WaUnsat
write(u) m_WaUnMpDm,m_WaUnMpDmCp,m_WaUnMpDmCpM1,m_ZBtDm,m_ZWaLevDm
write(u) p_FlDecMpRat,p_fldecMPmbf,p_IcTopMP,p_IDecMpRat,p_NodGWlFlCpZo
write(u) p_NumLevRapDra,p_SwDrRap,p_SwMBF,p_ArMpSs,p_CritUndSatVol
write(u) p_dFdhMp,p_GWlFlCpZo,p_KsMpSs,p_PndmxMp,p_QExcMpMtx
write(u) p_QMaPo,p_QMpLatSs,p_QRapDra,p_ZDraBas,p_FrArMtrx
write(u) p_WaSrDm1,p_WaSrDm1Ini,p_WaSrDm2,p_WaSrDm2Ini,p_WaUnMpDm1Cp
write(u) p_WaUnMpDm2Cp,p_cQMpInIntSatDm1,p_cQMpInIntSatDm2,p_cQMpInMtxSatDm1,p_cQMpInMtxSatDm2
write(u) p_cQMpInTopLatDm1,p_cQMpInTopLatDm2,p_cQMpInTopVrtDm1,p_cQMpInTopVrtDm2,p_cQMpOutDrRap
write(u) p_cQMpOutMtxSatDm1,p_cQMpOutMtxSatDm2,p_cQMpOutMtxUnsDm1,p_cQMpOutMtxUnsDm2,p_DiPoCp
write(u) p_IAvFrMpWlWtDm1,p_IAvFrMpWlWtDm2,p_iQExcMtxDm1Cp,p_iQExcMtxDm2Cp,p_iQInTopLatDm1
write(u) p_iQInTopLatDm2,p_iQInTopVrtDm1,p_iQInTopVrtDm2,p_iQInIntSatDm1cp,p_iQInIntSatDm2cp
write(u) p_iQInMtxSatDm1cp,p_iQInMtxSatDm2cp,p_iQMpOutDrRap,p_iQOutMtxSatDm1cp,p_iQOutMtxSatDm2cp
write(u) p_iQOutMtxUnsDm1cp,p_iQOutMtxUnsDm2cp,p_iQOutDrRapCp,p_IQTopMpDm1Cp,p_IQTopMpDm2Cp
write(u) p_IWaSrDm1Beg,p_IWaSrDm2Beg,p_IWaUnDm1CpBeg,p_IWaUnDm2CpBeg,p_SubsidCp
write(u) p_VlMpDm1,p_VlMpDm2,p_VlMpDm1Cp,p_VlMpDm2Cp,p_VlMpDyCp
write(u) p_VlMpStDm1,p_VlMpStDm2,p_WaLevDm1,v_h,v_theta
write(u) v_k,v_kmean,v_dimoca,v_gwl,v_nodgwl
write(u) v_bpegwl,v_npegwl,v_pegwl,v_pegwl_bot,v_gwlm1
write(u) v_gwlconv,v_pond,v_dt,v_t1900,d_macro_seq
else
 open(newunit=u,file=path,status='old',access='stream',form='unformatted')
read(u) m_SwBma,m_swabs,m_swsep,m_SwDarcy,m_SwPowM
read(u) m_SwShrInp,m_SwSoilShr,m_SwSorp,m_NumSbDm,m_DiPoMa
read(u) m_DiPoMi,m_GeomFac,m_nkwt,m_PowM,m_PpIcSs
read(u) m_RapDraReaExp,m_RapDraResRef,m_Rzah,m_ShapeFacMp,m_SorpAlfa
read(u) m_SorpMax,m_SorpFacParl,m_ShrParA,m_ShrParB,m_ShrParC
read(u) m_ShrParD,m_ShrParE,m_Spoint,m_ThetCrMp,m_VlMpStSs
read(u) m_Z_Ah,m_Z_Ic,m_Z_MB50,m_Z_St,m_Z_Tp
read(u) m_ZDiPoMa,m_ZnCrAr,m_FrMpWalWetIntegralOld,m_FlEndSrpEvt,m_ICpBtDm
read(u) m_ICpBtDmM1,m_ICpBtDmPot,m_ICpBtPerZon,m_ICpTpPerZon,m_ICpTpSatZon
read(u) m_ICpTpWaSrDm,m_NnCrAr,m_NumDm,m_bma,m_ArMpTp
read(u) m_ArMpTpDm,m_AwlCorFac,m_CDarcy,m_DiMtxSat,m_FrMpWalWet
read(u) m_FrMpWalWetOld,m_FrReduQ,m_KDCrRlRef,m_KsatCovLay,m_PpDmCp
read(u) m_QExcMtxDmCp,m_QInIntSatDmCp,m_QInMtxSatDmCp,m_QInTopLatDm,m_QInTopLatDm1
read(u) m_QInTopLatDm2,m_QInTopVrtDm,m_QInTopVrtDm1,m_QInTopVrtDm2,m_QOutDrRapCp
read(u) m_QOutMtxSatDmCp,m_QOutMtxUnsDmCp,m_QTopMpDmCp,m_SorpDmCp,m_SubsidCpMin
read(u) m_ThtSrpRefDmCp,m_TimAbsCumDmCp,m_VlMp,m_VlMpDm,m_VlMpDmCp
read(u) m_VlMpDmCpM1,m_VlMpStCp,m_WaSrMp,m_WaSrMpDm,m_WaUnsat
read(u) m_WaUnMpDm,m_WaUnMpDmCp,m_WaUnMpDmCpM1,m_ZBtDm,m_ZWaLevDm
read(u) p_FlDecMpRat,p_fldecMPmbf,p_IcTopMP,p_IDecMpRat,p_NodGWlFlCpZo
read(u) p_NumLevRapDra,p_SwDrRap,p_SwMBF,p_ArMpSs,p_CritUndSatVol
read(u) p_dFdhMp,p_GWlFlCpZo,p_KsMpSs,p_PndmxMp,p_QExcMpMtx
read(u) p_QMaPo,p_QMpLatSs,p_QRapDra,p_ZDraBas,p_FrArMtrx
read(u) p_WaSrDm1,p_WaSrDm1Ini,p_WaSrDm2,p_WaSrDm2Ini,p_WaUnMpDm1Cp
read(u) p_WaUnMpDm2Cp,p_cQMpInIntSatDm1,p_cQMpInIntSatDm2,p_cQMpInMtxSatDm1,p_cQMpInMtxSatDm2
read(u) p_cQMpInTopLatDm1,p_cQMpInTopLatDm2,p_cQMpInTopVrtDm1,p_cQMpInTopVrtDm2,p_cQMpOutDrRap
read(u) p_cQMpOutMtxSatDm1,p_cQMpOutMtxSatDm2,p_cQMpOutMtxUnsDm1,p_cQMpOutMtxUnsDm2,p_DiPoCp
read(u) p_IAvFrMpWlWtDm1,p_IAvFrMpWlWtDm2,p_iQExcMtxDm1Cp,p_iQExcMtxDm2Cp,p_iQInTopLatDm1
read(u) p_iQInTopLatDm2,p_iQInTopVrtDm1,p_iQInTopVrtDm2,p_iQInIntSatDm1cp,p_iQInIntSatDm2cp
read(u) p_iQInMtxSatDm1cp,p_iQInMtxSatDm2cp,p_iQMpOutDrRap,p_iQOutMtxSatDm1cp,p_iQOutMtxSatDm2cp
read(u) p_iQOutMtxUnsDm1cp,p_iQOutMtxUnsDm2cp,p_iQOutDrRapCp,p_IQTopMpDm1Cp,p_IQTopMpDm2Cp
read(u) p_IWaSrDm1Beg,p_IWaSrDm2Beg,p_IWaUnDm1CpBeg,p_IWaUnDm2CpBeg,p_SubsidCp
read(u) p_VlMpDm1,p_VlMpDm2,p_VlMpDm1Cp,p_VlMpDm2Cp,p_VlMpDyCp
read(u) p_VlMpStDm1,p_VlMpStDm2,p_WaLevDm1,v_h,v_theta
read(u) v_k,v_kmean,v_dimoca,v_gwl,v_nodgwl
read(u) v_bpegwl,v_npegwl,v_pegwl,v_pegwl_bot,v_gwlm1
read(u) v_gwlconv,v_pond,v_dt,v_t1900,d_macro_seq
end if
call sense23_rate_io(u,mode)
call sense23_sat_io(u,mode)
call sense23_abs_io(u,mode)
call sense23_gwl_io(u,mode)
close(u)
end subroutine
end module

subroutine sense23_probe()
use,intrinsic::ieee_exceptions,only:ieee_status_type,ieee_get_status,ieee_set_status
use SENSE23_TRANSACTION,only:snapshot
use DIAG19,only:probe_busy,probe_u,point_id,point_node,point_delta
use variables,only:h,theta,k,swkimpl,dt
use MOD_MvG,only:watcon,hconduc
use MOD_frost,only:rfcp
use MOD_grid,only:numnod,disnod,dz,z
use MOD_swap_mp,only:FrArMtrx,QExcMpMtx,dFdhMp
use MOD_macropore,only:QExcMtxDmCp,VlMpDmCp,WaSrMpDm,SwSoilShr
implicit none
integer::j,lev,sgn,u,flux_u,fp_u
type(ieee_status_type)::fp_before,fp_after
real(8)::eps
character(60)::path
call ieee_get_status(fp_before)
call snapshot('trial23_base.bin',1)
open(newunit=u,file='probe_context.txt',status='replace')
write(u,*) 'h',h(50:52)
write(u,*) 'z',z(50:51)
write(u,*) 'disnod51',disnod(51)
write(u,*) 'volume_density3_50',VlMpDmCp(3,50)/dz(50)
write(u,*) 'dt',dt
write(u,*) 'existing_dFdhMp52',dFdhMp(52)
write(u,*) 'existing_macro_J52_50',0d0
write(u,*) 'swkimpl',swkimpl
write(u,*) 'SwSoilShr',SwSoilShr
close(u)
open(newunit=probe_u,file='probe_limit.txt',status='replace')
open(newunit=flux_u,file='probe_flux.txt',status='replace')
open(newunit=fp_u,file='probe_fp_status.txt',status='replace')
write(fp_u,*) 0,transfer(fp_before,[0])
point_id=0;probe_busy=.true.
call evaluate(0,0d0)
do lev=1,2
 eps=1d-4/dble(lev)
 do j=50,52
  do sgn=-1,1,2
   call evaluate(j,dble(sgn)*eps)
  end do
 end do
end do
call evaluate(0,0d0)
call snapshot('trial23_base.bin',2)
call snapshot('trial23_final.bin',1)
probe_busy=.false.
close(probe_u);close(flux_u)
call ieee_set_status(fp_before)
call ieee_get_status(fp_after)
write(fp_u,*) 99,transfer(fp_after,[0])
close(fp_u)
contains
subroutine evaluate(node,delta)
integer,intent(in)::node
real(8),intent(in)::delta
call snapshot('trial23_base.bin',2)
call ieee_set_status(fp_before)
point_id=point_id+1;point_node=node;point_delta=delta
if(node/=0) then
 h(node)=h(node)+delta
 theta(node)=watcon(node,h(node))
 if(swkimpl==1) k(node)=FrArMtrx(node)*hconduc(node,h(node),theta(node),rfcp(node))
end if
call MACRORATE(1)
write(flux_u,*) point_id,node,delta,QExcMpMtx(52),QExcMtxDmCp(3,52),QExcMpMtx(1:numnod)
call snapshot('trial23_base.bin',2)
write(path,'(a,i0,a)') 'trial23_restored_',point_id,'.bin'
call snapshot(trim(path),1)
call ieee_set_status(fp_before)
call ieee_get_status(fp_after)
write(fp_u,*) point_id,transfer(fp_after,[0])
end subroutine
end subroutine


subroutine probe35_maybe()
use,intrinsic::ieee_exceptions,only:ieee_status_type,ieee_get_status,ieee_set_status,ieee_all,ieee_get_flag
use SENSE23_TRANSACTION,only:snapshot
use DIAG19,only:probe_busy,probe_u,point_id,point_node,point_delta
use variables,only:h,theta,k,swkimpl,dt
use MOD_arrays,only:macp
use MOD_MvG,only:watcon,hconduc
use MOD_frost,only:rfcp
use MOD_grid,only:numnod,z,dz
use MOD_swap_mp,only:FrArMtrx,QExcMpMtx,dFdhMp
use MOD_macropore,only:QExcMtxDmCp
implicit none
character(8)::enable
integer::u,ru,fu,cu,node,lev,sgn,j,nbytes,partid
integer,parameter::nodes(4)=[50,51,52,57]
integer(1),allocatable::original(:),restored(:)
real(8)::eps,pot(macp),meta(12)
type(ieee_status_type)::fp
logical::before_flags(size(ieee_all)),after_flags(size(ieee_all)),same
call get_environment_variable('PROBE35_ENABLE',enable)
if(trim(enable)/='1') return
call ieee_get_status(fp)
call ieee_get_flag(ieee_all,before_flags)
call snapshot('probe35_base.bin',1)
inquire(file='probe35_base.bin',size=nbytes)
allocate(original(nbytes),restored(nbytes))
open(newunit=u,file='probe35_base.bin',access='stream',form='unformatted',status='old')
read(u) original
close(u)
open(newunit=cu,file='probe35_context.txt',status='replace')
write(cu,*) 'h',h(1:numnod)
write(cu,*) 'z',z(1:numnod)
write(cu,*) 'dz',dz(1:numnod)
write(cu,*) 'dt',dt
write(cu,*) 'swkimpl',swkimpl
write(cu,*) 'q_total_before',QExcMpMtx(1:numnod)
write(cu,*) 'q_domain3_before',QExcMtxDmCp(3,1:numnod)
write(cu,*) 'existing_local_macro_derivative',dFdhMp(1:numnod)
write(cu,*) 'ieee_flags_before',merge(1,0,before_flags)
call diagnose35_get(pot,meta)
write(cu,*) 'meta_before',meta
write(cu,*) 'pot_before',pot(1:numnod)
close(cu)
open(newunit=ru,file='probe35_restore.txt',status='replace')
open(newunit=fu,file='probe35_points.txt',status='replace')
open(newunit=probe_u,file='probe35_limits.txt',status='replace')
probe_busy=.true.;partid=0
call evaluate(0,0d0)
do lev=1,2
 eps=1d-5/dble(lev)
 do j=1,4
  node=nodes(j)
  do sgn=-1,1,2
   call evaluate(node,dble(sgn)*eps)
  end do
 end do
end do
call evaluate(0,0d0)
call restore_state()
probe_busy=.false.
close(probe_u);close(fu);close(ru)
call ieee_set_status(fp)
deallocate(original,restored)
contains
subroutine restore_state()
call snapshot('probe35_base.bin',2)
call snapshot('probe35_restored.bin',1)
open(newunit=u,file='probe35_restored.bin',access='stream',form='unformatted',status='old')
read(u) restored
close(u)
same=all(restored==original)
call ieee_set_status(fp)
call ieee_get_flag(ieee_all,after_flags)
write(ru,*) partid,nbytes,merge(1,0,same),merge(1,0,all(before_flags.eqv.after_flags))
if(.not.same.or..not.all(before_flags.eqv.after_flags)) error stop 'PROBE35 transaction restore mismatch'
end subroutine
subroutine evaluate(ic,delta)
integer,intent(in)::ic
real(8),intent(in)::delta
call restore_state()
partid=partid+1;point_id=partid;point_node=ic;point_delta=delta
if(ic/=0) then
 h(ic)=h(ic)+delta
 theta(ic)=watcon(ic,h(ic))
 if(swkimpl==1) k(ic)=FrArMtrx(ic)*hconduc(ic,h(ic),theta(ic),rfcp(ic))
end if
call MACRORATE(1)
call diagnose35_get(pot,meta)
write(fu,*) partid,ic,delta,meta,h(50:52),QExcMtxDmCp(3,1:numnod),QExcMpMtx(1:numnod),pot(1:numnod)
end subroutine
end subroutine
