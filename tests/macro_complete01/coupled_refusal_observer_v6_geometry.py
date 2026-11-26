"""Observe the native branch indices and geometry at the unresolved sorption jump."""
from coupled_refusal_observer_v6 import render_head as prior
from donor_sources import replace

def render_head(source):
    source=prior(source)
    source=replace(source,'ThtSrpRefDmCp,TimAbsCumDmCp,SorpDmCp,FlEndSrpEvt','ThtSrpRefDmCp,TimAbsCumDmCp,SorpDmCp,FlEndSrpEvt,ICpTpPerZon,ICpBtPerZon,ICpBtDm,ICpTpWaSrDm,FrMpWalWet,VlMpDmCp,PpDmCp,ZBtDm')
    source=replace(source,',flunsatok,itry,factor,cap,norm',',flunsatok,itry,factor,cap,norm,ICpTpPerZon,ICpBtPerZon')
    source=replace(source,'SorpDmCp(k,worst),FlEndSrpEvt(k,worst)','SorpDmCp(k,worst),FlEndSrpEvt(k,worst),ICpBtDm(k),ICpTpWaSrDm(k),FrMpWalWet(k,worst),VlMpDmCp(k,worst),PpDmCp(k,worst),ZBtDm(k)')
    return source
