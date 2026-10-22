"""Sealed generations for unchanged existing biological phase owners."""
from pathlib import Path
import base64,hashlib,io,json,runpy,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='80dbce8d325e9197a53b7189ad184bcdf91f6f5c'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
SOL='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
PARENT='integration/audits/verify_root_substep.py'
SELF='integration/audits/verify_nut_harvest_output.py'
KEY='harvest_generation_successor_20261022'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def historical(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))['extended_output_component_20261021'][KEY]
def projection():
 text=historical(PARENT).decode();condition="'postimages' in json.loads((ROOT/'"+STATUS+"').read_text())['extended_output_component_20261021'].get('"+KEY+"',{})"
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  offset=text.index('\n',text.index('def '+name+'('))+1
  text=text[:offset]+" if "+condition+":return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+text[offset:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('saved_residue_successor_20261022',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_saved_output.py'))['source'](reader,changed)
 r=record(reader);require(r['baseline']==git('rev-parse',BASE),'harvest baseline')
 for p,h in {**r['qualified_input_sha256'],**r['postimages']}.items():require(sha(reader(p))==h,'harvest postimage '+p)
 require(reader(PARENT)==projection(),'root substep predecessor assertions')
 require(reader(SOL)==historical(SOL),'unrelated SOL authority')
 current=json.loads(reader(STATUS));current['extended_output_component_20261021'].pop(KEY)
 require(current==json.loads(historical(STATUS)),'unrelated NUT authority')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty harvest science')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}if changed is None else changed
 require(delta==r['scientific_delta'],'foreign harvest science')
 require(all(k=='A'or p==PARENT for p,k in delta.items()),'changed incumbent harvest physics')
 return r
def capsule():
 r=record();p=ROOT/r['evidence_index'];require(sha(p.read_bytes())==r['evidence_index_sha256'],'harvest index')
 index=json.loads(p.read_text());raw=base64.b64decode(b''.join((p.parent/'evidence.tar.xz.b64').read_bytes().split()),validate=True)
 require(sha(raw)==index['decoded_sha256'],'harvest capsule')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as a:
  ms=a.getmembers();require(len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms),'harvest member safety')
  f={m.name:a.extractfile(m).read()for m in ms}
 require(f.keys()==index['members'].keys()and all(sha(v)==index['members'][p]for p,v in f.items()),'harvest member inventory')
 return f
def validate(f):
 import struct
 def js(p):return json.loads(f[p])
 def diag(raw):
  n=struct.unpack_from('<i',raw,8)[0];return raw[:8]+raw[12:152]+raw[152+n:-4]
 h=js('harvest/result.json');t=js('thermal/result.json');c=js('cold/result.json');prior=js('PREDECESSOR.json')
 require(h['status']=='HARVEST_OUTPUT_PHASE_O0_O2_ATOMIC_FRESH_PASS','harvest actual proof')
 require(t['status']=='THERMAL_OUTPUT_ACTUAL_O0_O2_RESTART_ATOMIC_PASS'and c['status']=='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS','current predecessor execution')
 require(h['cold_proof_sha256']==t['cold_proof_sha256']==sha(f['cold/result.json'])and h['thermal_proof_sha256']==sha(f['thermal/result.json']),'harvest same-build handoff')
 require(sha(f['harvest/driver.f90'])==h['generated_driver_sha256'],'harvest driver')
 require(h['results']['O0']==h['results']['O2']and t['results']['O0']==t['results']['O2']and c['results']['O0']==c['results']['O2'],'harvest optimization drift')
 for prefix in ['cold','thermal','harvest']:
  es=js(prefix+'/events.json');require(all(e['returncode']==0 for e in es),'failed final harvest event')
  for e in es:
   for k in ['stdout','stderr']:require(prefix+'/'+e[k]in f,'missing harvest stream')
 es=js('harvest/events.json')
 require(len(es)==20 and sum(e['category']=='phase_roundtrip'for e in es)==6 and sum(e['category']=='phase_continuation'for e in es)==4,'harvest actual process census')
 for opt in ['O0','O2']:
  b='harvest/'+opt+'/'
  for end in ['endpoint','fresh']:
   p=b+end+'.harvest';active=f[p+'.active'];d=diag(active)
   require(active==f[p+'.failed-before-stage']==f[p+'.before-1'],'failed initial harvest published')
   for phase in ['1','2','3']:
    stage=f[p+'.phase-'+phase]
    require(diag(stage)==d,'harvest advances diagnostics/history')
    for label in ['memory','view','view-memory','replay']:require(stage==f[p+'.'+label+'-'+phase],'harvest phase authority '+label)
    require(f[p+'.manual-'+phase]==f[p+'.automatic-'+phase],'changed original harvest physics')
    if phase!='1':require(f[p+'.before-'+phase]==f[p+'.phase-'+str(int(phase)-1)],'late harvest save leak')
   require(f[p+'.unbound-observation-after']==f[p+'.phase-2'],'unbound acknowledgement leak')
  for phase in ['1','2','3']:
   stage=f[b+'endpoint.harvest.phase-'+phase]
   require(stage==f[b+'fresh.harvest.phase-'+phase]==f[b+'roundtrip-'+phase],'harvest phase fresh drift')
   require(sha(stage)==h['results'][opt][phase]['generation'],'harvest phase receipt')
   require(sha(f[b+'endpoint.harvest.automatic-'+phase])==h['results'][opt][phase]['physical'],'harvest physical receipt')
   if phase!='1':require(stage==f[b+'fresh-phase-'+phase],'fresh biological phase progression drift')
  require(f[b+'endpoint']==f['thermal/'+opt+'/output.endpoint'],'harvest changes original thermal execution')
  require(c['results'][opt]==js('preservation.json')['cold_previous_results'][opt],'prior cold endpoint drift')
  require(t['results'][opt]==js('preservation.json')['thermal_previous_results'][opt],'prior thermal endpoint drift')
 require(prior['qualified']and prior['status']=='TRIAL_BEGINNING_ROOT_SUBSTEP_O0_O2_QUALIFIED'and prior['controls']==36,'current root substep qualification')
 require(prior['current_source_tree']==git('rev-parse',BASE+':src'),'predecessor exact source tree')
 require(h['actual_programs']==14 and h['phase_roundtrips']==6 and h['independent_phase_continuations']==4,'harvest process inventory')
 return dict(qualified=True,status='HARVEST_OUTPUT_PHASE_O0_O2_QUALIFIED',actual_programs=14,phase_roundtrips=6,fresh_phase_progressions=4,diagnostics_unchanged=True,incumbent_physics_unchanged=True,full_harvest_day_reporting=False,full_mc_nut01_closed=False)
def verify():
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('saved_residue_successor_20261022',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_saved_output.py'))['verify']()
 source();files=capsule();r=validate(files);owner=runpy.run_path(str(ROOT/PARENT));old=owner['capsule']();prior=owner['validate'](old)
 nut=runpy.run_path(str(ROOT/'integration/audits/verify_nut_thermal_output.py'))
 current={p[len('nut/'):]:v for p,v in old.items()if p.startswith('nut/')}
 current.update({p:v for p,v in files.items()if p.startswith(('cold/','thermal/'))})
 r['fresh_thermal_science']=nut['validate'](current)
 r['incumbent_root_substep']=prior
 for key in ['current_calendar_nut','current_concurrent_nut','frozen_daily_predecessor']:r[key]=prior[key]
 return r
def self_test():
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('saved_residue_successor_20261022',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_saved_output.py'))['self_test']()
 source();f=capsule();validate(f);controls=[]
 def reject(name,fn):
  try:fn()
  except(ValueError,KeyError,AssertionError,UnicodeError):controls.append(name);return
  raise ValueError('harvest corruption accepted '+name)
 for p in ['src/adapter/mod_crop_soil_n_output_harvest.f90','src/crop/mod_crop_soil_n_day.f90','src/adapter/mod_crop_n_output_generation.f90','src/runtime/mod_fmr_serialized_reference_backend.f90',PARENT]:
  reject('source '+p,lambda p=p:source(lambda x:(ROOT/x).read_bytes()+(b'!'if x==p else b'')))
 for p in ['harvest/result.json','thermal/result.json','cold/result.json','PREDECESSOR.json','harvest/driver.f90','harvest/O0/endpoint.harvest.phase-1','harvest/O2/fresh-phase-3']:
  bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
 for p in ['harvest/O0/endpoint.harvest.failed-before-stage','harvest/O2/endpoint.harvest.manual-2','harvest/O0/endpoint.harvest.view-memory-3','harvest/O2/endpoint.harvest.unbound-observation-after','harvest/O0/roundtrip-1']:
  bad=dict(f);bad[p]+=b'!';reject('changed '+p,lambda bad=bad:validate(bad))
 bad=dict(record()['scientific_delta']);bad['src/foreign_harvest.f90']='A';reject('foreign harvest science',lambda:source(changed=bad))
 return controls
if __name__=='__main__':print(json.dumps(verify(),indent=2))
