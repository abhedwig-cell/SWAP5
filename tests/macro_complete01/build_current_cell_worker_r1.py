"""Build the CONTRACT06 worker using the already-qualified current base; no models."""
from pathlib import Path
import os,sys,json,time,traceback
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01'
os.environ['PATH']=r'C:\msys64\ucrt64\bin;C:\Program Files\Git\cmd;'+os.environ.get('PATH','')
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import coupled_macro_policy as c
res=json.loads((R/'RESOURCE_PATHS.json').read_text());ref=Path(res['O2']['path'])/'original-worker-reference'
opt=sys.argv[1];assert opt in ['O0','O2'];base=Path(res[opt]['path'])/'worker-base-v2';target=Path(res[opt]['path'])/'worker-coupled-current-cell-v9r1'
t=time.perf_counter();q=dict(optimization=opt,status='RUNNING',models_launched=0)
try:
 src=(ref/'build/swap-selected/macrorate.f90').read_text(encoding='cp1252');dst=c.render_macrorate(src)
 assert dst.replace('if (HMp > 1.d-8) then     ! Adapted for GEM','if (H(ic) < cofgen(9,lay)-1.d-8 .AND. HMp > 1.d-8) then     ! Adapted for GEM')==src
 c.build_bundle(base,ref,target,owner_optimization=opt)
 meta,case=c.validate_bundle(target,ref);q.update(status='BUILT_VALIDATED_NOT_MODEL_QUALIFIED',build=meta)
except Exception:q.update(status='FAILED',error=traceback.format_exc())
q['seconds']=time.perf_counter()-t;(R/('CURRENT_V9R1_'+opt+'_BUILD.json')).write_text(json.dumps(q,indent=2)+'\n');print(json.dumps({k:v for k,v in q.items() if k!='build'}))
sys.exit(1 if q['status']=='FAILED' else 0)
