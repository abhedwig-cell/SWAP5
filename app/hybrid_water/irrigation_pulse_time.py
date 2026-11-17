"""Explicit bounded temporal resolution for active subdaily irrigation only."""
from pathlib import Path
import hashlib

POLICY = 'original-adaptive-irrigation-pulse-v1'
SUBSTEPS = 2048


def source(original):
    text = original.decode('cp1252')
    imports = 'only: irrigation, flheadirg, flirrigate, nirri, dt_irr_event'
    initial = '      if (dt_irr_event < 1.0d0) dt = min(dt, dt_irr_event)'
    event = '      ! 2.7.6 RUNON event may limit timestep'
    if any(text.count(s) != 1 for s in (imports, initial, event)):
        raise ValueError('Foreign original irrigation TimeControl owner')
    text = text.replace(imports, imports+', gird')
    text = text.replace(initial, initial+f'''
      ! Explicit pulse policy: no change to DTMAX, dtCrit or acceptance tests.
      if (gird>0d0.and.dt_irr_event>0d0.and.dt_irr_event<1d0) &
         dt=min(dt,max(dtmin,dt_irr_event/{SUBSTEPS}d0))''')
    text = text.replace(event, f'''      ! Original pulse clock/rate are already owned by irrigation/native state.
      if (gird>0d0.and.dt_irr_event>0d0.and.dt_irr_event<1d0) then
         if(tcum-dble(int(tcum))+dtCrit<dt_irr_event) &
            get_dtEvent=min(get_dtEvent,max(dtmin,dt_irr_event/{SUBSTEPS}d0))
      end if

'''+event)
    return text.encode('cp1252')


def metadata(original):
    sha = lambda data: hashlib.sha256(data).hexdigest()
    return dict(policy=POLICY, substeps=SUBSTEPS,
                source_sha256=sha(Path(__file__).read_bytes()),
                original_sha256=sha(original), generated_source_sha256=sha(source(original)))
