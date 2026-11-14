"""One ordered same-laptop original431/current SaltFarm cost observation; no speedup qualification."""
import argparse,csv,hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import validate_bundle
from user_prepare import validate
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--provider',type=Path,required=True);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();a.provider=a.provider.resolve();a.bundle=a.bundle.resolve();a.output=a.output.resolve()
if a.output.exists():raise FileExistsError(a.output)
a.output.mkdir();events=[]
def call(label,cmd,*,cwd=ROOT,expected=0,timeout=60):
 begin=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,text=True,timeout=timeout);seconds=time.perf_counter()-begin
 (a.output/(label+'.stdout')).write_text(r.stdout,encoding='utf-8');(a.output/(label+'.stderr')).write_text(r.stderr,encoding='utf-8')
 events.append(dict(label=label,command=list(map(str,cmd)),cwd=str(cwd),seconds=seconds,returncode=r.returncode,cap_seconds=timeout));(a.output/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
 assert r.returncode==expected,(label,r.returncode,r.stderr)
 return seconds
begin=time.perf_counter();prepared=validate(a.provider);meta,_=validate_bundle(a.bundle,a.provider,h.SALTFARM);verify_seconds=time.perf_counter()-begin
assert meta['identity']['floating_point_profile']==prepared['floating_point_profile']==h.no_macro_fp_profile()
assert meta['identity']['compiler_sha256']==prepared['toolchain']['gfortran']['sha256']
case=a.output/'original431-case';case.mkdir();inventory={}
source=h.project_case(a.provider,h.SALTFARM)
for name,sha in meta['inputs'].items():
 data=(source/name).read_bytes();assert hashlib.sha256(data).hexdigest()==sha,name
 target=case/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data);inventory[name]=sha
exe=a.output/'swap431-common.exe';objects=sorted((a.provider/'build/swap-obj').glob('*.o'));assert objects
link=call('original-link',['gfortran','-o',exe,*objects,a.provider/'build/ttutil-obj/libttutil.a'])
original=call('original-model',[exe,'./swap.swp'],cwd=case,expected=100)
current=call('current-public',[sys.executable,'-B',ROOT/'tools/solute/run_water.py','--no-macro-release','--model',h.SALTFARM.model,'--reference-work',a.provider,'--build-bundle',a.bundle,'--days',1461,'--timeout-seconds',60,'--output',a.output/'current'])
read=lambda p:list(csv.DictReader(s for s in p.read_text().splitlines() if s.strip() and not s.startswith('*')))
o=read(case/'result_output.csv');c=read(a.output/'current/original/result_output.csv');assert len(o)==len(c)==1462 and o[-1]['DATE']==c[-1]['DATE']=='2015-12-31'
for name,sha in inventory.items():
 assert h.sha(case/name)==sha and h.sha(a.output/'current/original'/name)==sha,name
r=json.loads((a.output/'current/RESULT.json').read_text());assert r['committed_days']==1461
rows=[json.loads(v) for v in (a.output/'current/daily.jsonl').read_text().splitlines()];assert len(rows)==1461 and all(v['committed'] for v in rows)
result=dict(status='ONE_MATCHED_PROFILE_ORDERED_SALTFARM_COST_PAIR_COMPLETE',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),days=1461,input_sha256=inventory,execution_input_bytes_identical=True,profile=prepared['floating_point_profile'],toolchain=prepared['toolchain'],provider_prepared_sha256=h.sha(a.provider/'PREPARED.json'),original_objects={p.name:h.sha(p) for p in objects},original_executable_sha256=h.sha(exe),current_build=meta,verification_seconds=verify_seconds,fresh_original_link_seconds=link,original_process_wall_seconds=original,current_public_wall_seconds=current,current_model_and_controller_seconds=r['model_and_controller_seconds'],single_observed_public_wall_ratio=current/original,maximum_current_water_cm=max(abs(v['independent_residual_cm']) for v in rows),maximum_current_solute_mg_cm2=max(abs(v.get('solute_independent_residual_mg_cm2',0)) for v in rows),science='One ordered observation, not statistical speedup, accuracy-matched runtime or a new qualified scientific reference. Current stricter balance/rollback/instance contracts differ from original. No tolerance or physical/input change.',cost='Source preparation and original compilation reused unchanged, fresh link and verification measured separately. Public wall includes current host/kernel/validation/output; model_and_controller is not donor-only timing.')
(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:result[k] for k in ['status','days','original_process_wall_seconds','current_public_wall_seconds','current_model_and_controller_seconds','single_observed_public_wall_ratio']}),flush=True)
