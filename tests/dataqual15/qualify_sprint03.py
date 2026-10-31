"""Prospective thermal-policy experiment, original inputs and authentic restarts."""
import argparse,csv,hashlib,io,json,math,os,re,shutil,struct,subprocess,sys,tarfile,time
from pathlib import Path
from original_sources import build_original
from checkpoint_layout import layout,payload
from qualify_donor_timestep import vectors,distance
ROOT=Path(__file__).resolve().parents[2]
sha=lambda raw:hashlib.sha256(raw).hexdigest()
file_sha=lambda p:sha(Path(p).read_bytes())
INPUTS=['input.swp','grass.crp','input.met','swap.bbc','swap.dra']
rows=lambda raw:list(csv.DictReader(line for line in raw.decode().splitlines()if line.strip()and not line.startswith('*')))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);fc=str(a.compiler.resolve())
 planpath=ROOT/'integration/dataqual15/SPRINT03_PREREGISTRATION.json';plan=json.loads(planpath.read_text());(out/'PREREGISTRATION.json').write_bytes(planpath.read_bytes())
 report=dict(status='IN_PROGRESS',scope=__doc__,events=[],registration_sha256=file_sha(planpath),production_promoted=False,canonical_modified=False,original_gate_pass=False)
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
 def run(command,label,cwd=ROOT,timeout=240,expected=0,capture=None):
  print('SPRINT03_START',label,flush=True);start=time.monotonic();i=len(report['events']);censored=False;captured=set()
  with (out/f'{i}.stdout').open('wb')as so,(out/f'{i}.stderr').open('wb')as se:
   proc=subprocess.Popen(list(map(str,command)),cwd=cwd,stdout=so,stderr=se)
   while proc.poll()is None:
    if capture:
     try:
      raw=(Path(cwd)/'checkpoint.bin').read_bytes();day=layout(raw)['clock']
      if day in capture and day not in captured:(Path(cwd)/f'checkpoint-{int(day)}.bin').write_bytes(raw);captured.add(day);(out/'PROGRESS.json').write_text(json.dumps(dict(label=label,day=day,elapsed_seconds=time.monotonic()-start))+'\n')
     except(FileNotFoundError,AssertionError,struct.error):pass
    if time.monotonic()-start>timeout:proc.kill();proc.wait();censored=True;break
    time.sleep(.02 if capture else .2)
  event=dict(label=label,command=list(map(str,command)),cwd=str(cwd),seconds=time.monotonic()-start,returncode=proc.returncode,censored=censored,stdout=f'{i}.stdout',stderr=f'{i}.stderr',captured=sorted(captured));report['events'].append(event);save()
  assert not censored and(proc.returncode!=0 if expected=='nonzero'else proc.returncode==expected),(label,event,(out/f'{i}.stderr').read_text(errors='replace')[-2000:])
  print('SPRINT03_DONE',label,event['seconds'],flush=True)
  return event
 # The immutable capsules remain predecessor references, never rebound to this source.
 archives={}
 for name,manifest,key in [('GRASS_UNION_FULL','GRASS_UNION_FULL_MANIFEST.json','evidence_sha256'),('STRESS','STRESS_EVIDENCE_MANIFEST.json','capsule_sha256'),('SPRINT02','SPRINT02_EVIDENCE_MANIFEST.json','archive_sha256')]:
  path=ROOT/f'integration/dataqual15/{name}_EVIDENCE.tar.xz';m=json.loads((path.parent/manifest).read_text())
  if name=='STRESS':key='evidence_sha256'if'evidence_sha256'in m else'capsule_sha256'
  assert file_sha(path)==m[key];archives[name]=tarfile.open(path)
 full,old,prior=[archives[name]for name in ['GRASS_UNION_FULL','STRESS','SPRINT02']];get=lambda t,n:t.extractfile(n).read();spec=json.loads(get(full,'SPEC.json'))
 frozen=json.loads(get(old,'donor/PREREGISTRATION.json'));assert sha(get(old,'donor/PREREGISTRATION.json'))==plan['criteria']['frozen_registration_sha256'];assert frozen['bounds']==plan['criteria']['frozen_bounds']
 report['capsules_sha256']={name:file_sha(ROOT/f'integration/dataqual15/{name}_EVIDENCE.tar.xz')for name in archives};save()
 utilities=build_original(out/'original-utilities',fc,'O2',utilities_only=True);builds={};native={}
 def makecase(bundle,path,thermal):
  path.mkdir();build=json.loads((bundle/'BUILD.json').read_text());exe=bundle/'swap5_grass_startup';assert file_sha(exe)==build['executable_sha256']
  for name in INPUTS:
   raw=(bundle/'original-interval'/name).read_bytes();assert sha(raw)==build['original_inputs_sha256'][name];(path/name).write_bytes(raw)
  raw=(bundle/'original-interval/application.binding').read_bytes()
  if thermal:
   binding=json.loads(raw);binding['grass_numerical_profile']='thermal-control-1e-5C';raw=(json.dumps(binding,sort_keys=True)+'\n').encode()
  (path/'application.binding').write_bytes(raw)
  return exe
 def readnative(case):
  budget=rows((case/'budget.csv').read_bytes());crop=rows((case/'crop.csv').read_bytes());points={}
  for path in case.glob('checkpoint*.bin'):
   raw=path.read_bytes();points[int(layout(raw)['clock'])]=raw
  assert len(budget)==len(crop)>0
  assert max(abs(float(r['residual_cm']))for r in budget)<=1e-10
  assert max(abs(float(r['heat_residual_j_cm2']))for r in budget)<=1e-8
  return dict(budget=budget,crop=crop,checkpoints=points)
 oldbudget=rows(get(full,spec['full']+'/budget.csv'));oldcrop=rows(get(full,spec['full']+'/crop.csv'))
 oldpoints={}
 for name in full.getnames():
  if name.startswith(spec['full']+'/checkpoint')and name.endswith('.bin'):
   raw=get(full,name);oldpoints[int(layout(raw)['clock'])]=raw
 for opt in ['O0','O2']:
  bundle=out/('build-'+opt);run([sys.executable,'-B',ROOT/'tools/solute/build_grass_startup.py','--compiler',fc,'--input-archive',utilities/'ttobj/libttutil.a','--output',bundle,'--optimization',opt,'--profile','checked','--end','.01','--policy','retained'],'build-'+opt,timeout=600);builds[opt]=bundle
  case=out/('default-'+opt);exe=makecase(bundle,case,False);run([exe,140,'retain-step',100000],'default-'+opt,cwd=case,timeout=900,capture=[63,71,72,73,113,117,126,127,140]);data=readnative(case)
  assert len(data['budget'])==140 and data['budget']==oldbudget[:140]and data['crop']==oldcrop[:140]
  assert all(payload(raw)==payload(oldpoints[day])for day,raw in data['checkpoints'].items());report['default_'+opt]='EXACT_PREDECESSOR140_SCALARS_AND_CAPTURED_PAYLOAD';save()
  case=out/('adaptive-'+opt);exe=makecase(bundle,case,True);end=140 if opt=='O0'else 1827;capture=[d for d in plan['native_capture_days']if d<=end]
  run([exe,end,'retain-step',100000,'','thermal-control'],'adaptive-'+opt,cwd=case,timeout=7200 if opt=='O2'else 1200,capture=capture);data=readnative(case);assert len(data['budget'])==end
  assert set(capture)<=set(data['checkpoints']),('missed atomic observation',set(capture)-set(data['checkpoints']));native[opt]=data
 assert native['O0']['budget']==native['O2']['budget'][:140]and native['O0']['crop']==native['O2']['crop'][:140]
 assert all(payload(raw)==payload(native['O2']['checkpoints'][day])for day,raw in native['O0']['checkpoints'].items());report['adaptive_O0_O2_140_exact']=True;save()
 # Genuine same-executable restarts; origin bytes and source/application binding remain fixed.
 data=native['O2'];exe=builds['O2']/'swap5_grass_startup';report['restarts']=[]
 for origin,end in [(126,140),(365,367),(918,922),(1786,1787),(1800,1827)]:
  case=out/f'restart-{origin}-{end}';makecase(builds['O2'],case,True);raw=data['checkpoints'][origin];(case/'origin.bin').write_bytes(raw)
  run([exe,end,'retain-step',100000,case/'origin.bin','thermal-control'],f'restart-{origin}-{end}',cwd=case,timeout=180)
  assert(case/'origin.bin').read_bytes()==raw and(case/'checkpoint.bin').read_bytes()==data['checkpoints'][end]
  assert rows((case/'budget.csv').read_bytes())==data['budget'][origin:end]and rows((case/'crop.csv').read_bytes())==data['crop'][origin:end];report['restarts'].append([origin,end]);save()
 for label,thermal,flag in [('missing-profile-marker',False,True),('missing-profile-argument',True,False)]:
  case=out/label;makecase(builds['O2'],case,thermal);(case/'origin.bin').write_bytes(data['checkpoints'][126]);cmd=[exe,127,'retain-step',100000,case/'origin.bin']+(['thermal-control']if flag else[])
  run(cmd,label,cwd=case,expected='nonzero');assert not(case/'checkpoint.bin').exists()
 def stock(raw):
  s=layout(raw);n=s['nodes'];dz=struct.unpack_from('='+str(n)+'d',raw,s['header']+48+8*n);theta=struct.unpack_from('='+str(n)+'d',raw,s['physical']+8*n);pond=struct.unpack_from('=d',raw,s['physical']+16*n)[0];return math.fsum(a*b for a,b in zip(dz,theta))+pond
 residuals=[];points=sorted(data['checkpoints'])
 for first,last in zip(points,points[1:]):residuals.append(stock(data['checkpoints'][last])-stock(data['checkpoints'][first])-math.fsum(float(r['input_cm'])-float(r['output_cm'])for r in data['budget'][first:last]))
 report['maximum_independent_stock_flux_residual_cm']=max(map(abs,residuals));assert report['maximum_independent_stock_flux_residual_cm']<1e-10;save()
 # Only the original output collector date list changes. Verify every old output.
 reference=out/'reference';reference.mkdir();provider=build_original(reference/'providers',fc,'O2');original=get(prior,'heldout/reference/swapoutput_profiles.f90').decode();old_dates=sorted([0]+plan['old_profile_days']);needle='['+','.join(map(str,old_dates))+']';assert original.count(needle)==1
 all_dates=sorted(set(old_dates+plan['new_profile_days']));source=reference/'swapoutput_profiles.f90';source.write_text(original.replace(needle,'['+','.join(map(str,all_dates))+']'),newline='\n')
 flags=['-O2','-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-I'+str(provider/'swobj'),'-I'+str(provider/'ttobj'),'-J'+str(provider/'swobj')];objects=[]
 for src,name in [(source,'profiles'),(provider/'selected/swap_main.f90','main')]:
  obj=reference/(name+'.o');run([fc,*flags,'-c',src,'-o',obj],'reference-compile-'+name);objects.append(obj)
 objects+=[p for p in sorted((provider/'swobj').glob('*.o'))if p.name!='swapoutput.o'];reference_exe=reference/'swap431';args=reference/'link.args';args.write_text('\n'.join('"'+str(p)+'"'for p in [*objects,provider/'ttobj/libttutil.a','-o',reference_exe]),newline='\n');run([fc,'@'+str(args)],'reference-link')
 report['reference_build']=dict(executable_sha256=file_sha(reference_exe),collector_sha256=file_sha(source),provider_build_sha256=file_sha(provider/'BUILD.json'));save()
 scalar={};nodal={}
 for cap,timeout in [(.000625,1500),(.0003125,2700)]:
  case=reference/str(cap);case.mkdir();base='heldout/reference/'+str(cap)
  for name in ['swap.swp','grass.crp','260.met','swap.bbc','swap.dra']:(case/name).write_bytes(get(prior,base+'/'+name))
  run([reference_exe],'reference-'+str(cap),cwd=case,timeout=timeout,expected=100);assert(case/'swap.ok').exists();scalar[cap]=rows((case/'result_output.csv').read_bytes());assert len(scalar[cap])==1828 and scalar[cap]==rows(get(prior,base+'/result_output.csv'))
  profile=rows((case/'nodal_profiles.csv').read_bytes());assert [r for r in profile if int(r['day'])in old_dates]==rows(get(prior,base+'/nodal_profiles.csv'));nodal[cap]={}
  for row in profile:nodal[cap].setdefault(int(row['day']),[]).append(row)
  assert set(nodal[cap])==set(all_dates)
 observed,ref,units,floors=vectors(scalar[.0003125],nodal[.0003125],**data);_,previous,_,_=vectors(scalar[.000625],nodal[.000625],**data)
 report['assessment']={}
 for key,bound in frozen['bounds'].items():
  assert all(math.isfinite(v)for v in observed[key]+ref[key]+previous[key]);error=distance(key,observed[key],ref[key]);change=distance(key,previous[key],ref[key]);limit=bound['limit'];profile=key.startswith('PROFILE_');resolution_limit=limit/3+bound['floor']
  report['assessment'][key]=dict(native_error=error,limit=limit,inside_frozen_envelope=error<=limit,reference_change=change,reference_resolution_limit=resolution_limit,reference_resolution_pass=not profile or change<=resolution_limit,unit=units[key])
 report.update(status='SPRINT03_THERMAL_POLICY_MEASURED',full_days=1827,registered_gate_pass=all(v['inside_frozen_envelope']and v['reference_resolution_pass']for v in report['assessment'].values()),scientific_equivalence=False,production_promoted=False,original_gate_pass=False)
 report['raw_sha256']={str(p.relative_to(out)):file_sha(p)for p in out.rglob('*')if p.is_file()and p!=out/'RESULT.json'and p.suffix not in ['.o','.mod']and '/source/'not in str(p)and '/selected/'not in str(p)};save()
 print(json.dumps({k:v for k,v in report.items()if k not in ['raw_sha256']},indent=2),flush=True)
if __name__=='__main__':main()
