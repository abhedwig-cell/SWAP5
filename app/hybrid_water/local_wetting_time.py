"""Explicit memory-free time resolution for rain and above-ground irrigation."""
from pathlib import Path
import hashlib

POLICY='original-adaptive-local-wetting-v1'
SUPPLY_DEPTH_CM=0.02
IRRIGATION_SUBSTEPS=2048
MAX_WETTING_INCREMENT=0.002

def render_headcalc(text, *, original_reference=False):
    anchor='      if (.NOT.flnonconv) then      ! convergence has been reached'
    if text.count(anchor)!=1:
        raise ValueError('Foreign original local wetting HeadCalc owner')
    counter='' if original_reference else '            budget_retries=budget_retries+1\n'
    return text.replace(anchor,f'''      ! Resolve actual wetting/redistribution, not only external supply.
      ! Reuse the original rejected-step state rollback before any Integral3.
      if(.not.flnonconv)then
         if(maxval(theta(1:numnod)-thetm1(1:numnod))>{MAX_WETTING_INCREMENT:.17g}d0)then
            if(dt<=dtmin)error stop 'Local wetting resolution cannot be met at DTMIN'
            fldecdt=.true.
{counter}            return
         endif
      endif
'''+anchor)

def source(original):
    text=original.decode('cp1252')
    imports='only: irrigation, flheadirg, flirrigate, nirri, dt_irr_event'
    meteo='only: fl_update_meteo, meteo_rec, i_metdetail, rain_rec, raintim, dt_meteo'
    initial='      if (dt_irr_event < 1.0d0) dt = min(dt, dt_irr_event)'
    fresh='      if (sw_inter == 3 .AND. dt_interc_event < 1.0d0) dt = min(dt, dt_interc_event)'
    event='      ! 2.7.6 RUNON event may limit timestep'
    end='   end function get_dtevent'
    if any(text.count(s)!=1 for s in (imports,meteo,initial,fresh,event,end)):
        raise ValueError('Foreign original local wetting TimeControl owner')
    text=text.replace(imports,imports+', gird').replace(meteo,meteo+', nraidt')
    text=text.replace(initial,initial+'\n      dt=min(dt,wetting_dt_limit(.false.))')
    text=text.replace(fresh,fresh+'\n      ! Meteo3 has refreshed the actual rain rate, including the first step.\n      dt=min(dt,wetting_dt_limit(.true.))')
    text=text.replace(event,'      ! Do not seed a new day from yesterday\'s rain rate.\n      get_dtEvent=min(get_dtEvent,wetting_dt_limit(.not.flDayStart))\n\n'+event)
    return text.replace(end,end+f'''

   real(8) function wetting_dt_limit(include_rain) result(limit)
      logical,intent(in)::include_rain
      real(8)::supply
      limit=dtmax
      supply=0d0
      if(include_rain)supply=max(0d0,nraidt)
      if(gird>0d0.and.dt_irr_event>0d0)then
         if(dt_irr_event>=1d0.or.tcum-dble(int(tcum))+dtCrit<dt_irr_event)then
            supply=supply+gird
            if(dt_irr_event<1d0)limit=min(limit,dt_irr_event/{IRRIGATION_SUBSTEPS}d0)
         endif
      endif
      if(supply>0d0)limit=min(limit,{SUPPLY_DEPTH_CM:.17g}d0/supply)
      limit=max(dtmin,limit)
   end function wetting_dt_limit
''').encode('cp1252')

def metadata(original):
    sha=lambda b:hashlib.sha256(b).hexdigest()
    return dict(policy=POLICY,maximum_supply_depth_cm=SUPPLY_DEPTH_CM,
                irrigation_substeps=IRRIGATION_SUBSTEPS,
                maximum_wetting_increment=MAX_WETTING_INCREMENT,
                source_sha256=sha(Path(__file__).read_bytes()),
                original_sha256=sha(original),generated_source_sha256=sha(source(original)))
