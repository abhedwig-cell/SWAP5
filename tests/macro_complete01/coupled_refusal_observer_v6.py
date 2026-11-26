"""Observe every actual line trial of the corrected dtmin policy, no probes."""
from coupled_refusal_observer import render_head as base_render
from donor_sources import replace

def render_head(source):
    source=base_render(source)
    source=replace(source,'         call vector_F(2, hgrad)','         call vector_F(2, hgrad)\n         call observe_coupled_refusal(3)')
    source=replace(source,'         QOutMtxSatDmCp,QOutMtxUnsDmCp,QInMtxSatDmCp,QInIntSatDmCp','         QOutMtxSatDmCp,QOutMtxUnsDmCp,QInMtxSatDmCp,QInIntSatDmCp,ThtSrpRefDmCp,TimAbsCumDmCp,SorpDmCp,FlEndSrpEvt')
    source=replace(source,'      real(8)::cm(24,madm),pot(macp,2),valid','      real(8)::cm(24,madm),pot(macp,2),valid,cap,norm')
    source=replace(source,'      worst=maxloc(abs(F(1:NN)),dim=1)', '''      cap=1d0
      if(fldtmin.and.numbit>MaxIt)cap=factmax1
      norm=maxval(abs(difh(1:NN))/max(1d0,abs(hold(1:NN))))
      worst=maxloc(abs(F(1:NN)),dim=1)''')
    source=replace(source,',worst,flunsatok',',worst,flunsatok,itry,factor,cap,norm')
    source=replace(source,'F(1:NN),QExcMpMtx(1:NN),dFdhMp(1:NN)','F(1:NN),QExcMpMtx(1:NN),dFdhMp(1:NN),hold(1:NN),difh(1:NN)')
    source=replace(source,'QInMtxSatDmCp(k,worst),QInIntSatDmCp(k,worst)','QInMtxSatDmCp(k,worst),QInIntSatDmCp(k,worst),ThtSrpRefDmCp(k,worst),TimAbsCumDmCp(k,worst),SorpDmCp(k,worst),FlEndSrpEvt(k,worst)')
    return source
