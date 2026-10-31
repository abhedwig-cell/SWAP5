"""Registered disjoint-profile/finer-reference test; preserve failed predecessor.

Native profiles come from one-day authentic same-executable checkpoint forks.
Only the original reference needs fresh full-period output at the new dates.
"""
import argparse,csv,hashlib,io,json,math,os,struct,subprocess,sys,tarfile,time
from pathlib import Path
from checkpoint_layout import layout
from original_sources import build_original
from qualify_donor_timestep import vectors,distance,assess_envelope
ROOT=Path(__file__).resolve().parents[2]
sha=lambda raw:hashlib.sha256(raw).hexdigest()
file_sha=lambda p:sha(Path(p).read_bytes())
INPUTS=['input.swp','grass.crp','input.met','swap.bbc','swap.dra','application.binding']

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);fc=str(a.compiler.resolve())
 registration_path=ROOT/'integration/dataqual15/SPRINT02_HELDOUT_PREREGISTRATION.json';plan=json.loads(registration_path.read_text());(out/'PREREGISTRATION.json').write_bytes(registration_path.read_bytes())
 report=dict(status='IN_PROGRESS',scope=__doc__,registration_sha256=file_sha(registration_path),original_preregistered_gate_pass=False,scientific_equivalence=False,events=[])
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
 def run(command,label,cwd=out,timeout=240,expected=0):
  print('SPRINT02_START',label,flush=True);begin=time.monotonic();i=len(report['events'])
  with (out/f'{i}.stdout').open('wb')as so,(out/f'{i}.stderr').open('wb')as se:
   try:r=subprocess.run(list(map(str,command)),cwd=cwd,stdout=so,stderr=se,timeout=timeout);code=r.returncode;censored=False
   except subprocess.TimeoutExpired:code=None;censored=True
  report['events'].append(dict(label=label,command=list(map(str,command)),returncode=code,censored=censored,seconds=time.monotonic()-begin,stdout=f'{i}.stdout',stderr=f'{i}.stderr'));save()
  assert code==expected and not censored,(label,code,(out/f'{i}.stderr').read_text(errors='replace')[-2500:])
  print('SPRINT02_DONE',label,report['events'][-1]['seconds'],flush=True)
  return(out/f'{i}.stdout').read_bytes()
 run([sys.executable,'-B',ROOT/'tests/dataqual15/stress_evidence.py'],'verify-inherited-study')
 full_capsule=ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz';full_manifest=json.loads((ROOT/'integration/dataqual15/GRASS_UNION_FULL_MANIFEST.json').read_text());assert file_sha(full_capsule)==full_manifest['evidence_sha256']
 full_tar=tarfile.open(full_capsule);study_tar=tarfile.open(ROOT/'integration/dataqual15/STRESS_EVIDENCE.tar.xz')
 get=lambda archive,name:archive.extractfile(name).read()
 frozen_raw=get(study_tar,'donor/PREREGISTRATION.json');assert sha(frozen_raw)==plan['frozen_registration_sha256'];frozen=json.loads(frozen_raw);assert frozen['bounds']==plan['frozen_bounds']
 old_donor=json.loads(get(study_tar,'donor/RESULT.json'));assert old_donor['numerical_resolution_gate_pass']is False
 rows=lambda raw:list(csv.DictReader(line for line in raw.decode().splitlines()if line.strip()and not line.startswith('*')))
 profiles=lambda raw:list(csv.DictReader(io.StringIO(raw.decode())))
 native={};spec=json.loads(get(full_tar,'SPEC.json'));old_profile_source=get(full_tar,spec['reference_B0_nodal']+'/swapoutput_profiles.f90').decode()
 old_dates=[0,63,71,72,73,113,140,367,731,918,922,1096,1461,1800,1827];new_dates=plan['new_profile_days'];assert not set(new_dates)&set(old_dates)
 anchors=plan['native_origin_days'];assert len(anchors)==len(new_dates)==12 and all(day==origin+1 for origin,day in zip(anchors,new_dates))
 report['inherited_capsules_sha256']={str(p.relative_to(ROOT)):file_sha(p)for p in [full_capsule,ROOT/'integration/dataqual15/STRESS_EVIDENCE.tar.xz']};save()
 # Source/binary/binding/CRC remain exactly as archived. No model rebuild here.
 for policy in ['coarse','fine']:
  folder=out/policy;folder.mkdir();archive=full_tar if policy=='coarse'else study_tar
  prefix=spec['full']if policy=='coarse'else'thermal/native';binary=get(archive,'build/O2/swap5_grass_startup'if policy=='coarse'else'thermal/build/swap5_grass_startup')
  exe=folder/'swap5_grass_startup';exe.write_bytes(binary);exe.chmod(0o755)
  inputs={n:get(archive,prefix+'/'+n)for n in INPUTS};binding=json.loads(inputs['application.binding']);assert binding['executable_sha256']==sha(binary)
  checkpoints={}
  for name in archive.getnames():
   if name.startswith(prefix+'/checkpoint')and name.endswith('.bin'):
    raw=get(archive,name);checkpoints[int(layout(raw)['clock'])]=raw
  budgets=rows(get(archive,prefix+'/budget.csv'));crops=rows(get(archive,prefix+'/crop.csv'));assert len(budgets)==len(crops)==1827
  records={}
  for origin,day in zip(anchors,new_dates):
   case=folder/str(day);case.mkdir();origin_raw=checkpoints[origin]
   for name,raw in inputs.items():(case/name).write_bytes(raw)
   (case/'origin.bin').write_bytes(origin_raw)
   run([exe,day,'retain-step',100000,case/'origin.bin'],f'native-{policy}-{origin}-{day}',cwd=case,timeout=plan['cost']['native_window_wall_cap_seconds'])
   assert file_sha(exe)==sha(binary)and(case/'origin.bin').read_bytes()==origin_raw
   raw=(case/'checkpoint.bin').read_bytes();s=layout(raw);assert s['clock']==day
   pos=8
   for name in INPUTS:
    size=struct.unpack_from('=i',raw,pos)[0];pos+=4;assert raw[pos:pos+size]==inputs[name],('checkpoint binding changed',policy,day,name);pos+=size
   b=rows((case/'budget.csv').read_bytes());c=rows((case/'crop.csv').read_bytes());assert len(b)==len(c)==1 and int(b[0]['day'])==int(c[0]['day'])==day
   assert b[0]==budgets[day-1]and c[0]==crops[day-1],('same-executable fork diverged',policy,day)
   assert abs(float(b[0]['residual_cm']))<1e-10 and abs(float(b[0]['heat_residual_j_cm2']))<1e-8
   assert abs(float(b[0]['water_end_cm'])-float(b[0]['water_start_cm'])-float(b[0]['input_cm'])+float(b[0]['output_cm']))<1e-10
   checkpoints[day]=raw;records[str(day)]=dict(origin_day=origin,origin_sha256=sha(origin_raw),checkpoint_sha256=sha(raw),daily_budget_crop_exact=True)
  native[policy]=dict(budget=budgets,crop=crops,checkpoints=checkpoints)
  report[policy]=dict(executable_sha256=sha(binary),input_sha256={n:sha(raw)for n,raw in inputs.items()},forks=records);save()
 # Rebuild the pinned original providers, changing only the existing output date list.
 reference=out/'reference';reference.mkdir();begin=time.monotonic();provider=build_original(reference/'providers',fc,'O2')
 report['events'].append(dict(label='original-provider-build',returncode=0,censored=False,seconds=time.monotonic()-begin,build_sha256=file_sha(provider/'BUILD.json')));save()
 needle='['+','.join(map(str,old_dates))+']';assert old_profile_source.count(needle)==1
 expanded=old_profile_source.replace(needle,'['+','.join(map(str,sorted(set(old_dates+new_dates))))+']');source=reference/'swapoutput_profiles.f90';source.write_text(expanded,newline='\n')
 flags=['-O2','-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-I'+str(provider/'swobj'),'-I'+str(provider/'ttobj'),'-J'+str(provider/'swobj')]
 objects=[]
 for src,name in [(source,'profiles'),(provider/'selected/swap_main.f90','main')]:
  obj=reference/(name+'.o');run([fc,*flags,'-c',src,'-o',obj],'reference-compile-'+name);objects.append(obj)
 objects+=[p for p in sorted((provider/'swobj').glob('*.o'))if p.name!='swapoutput.o'];exe=reference/'swap431';link=reference/'link.args';link.write_text('\n'.join('"'+str(v)+'"'for v in [*objects,provider/'ttobj/libttutil.a','-o',exe]),newline='\n');run([fc,'@'+str(link)],'reference-link')
 report['reference_build']=dict(compiler=json.loads((provider/'BUILD.json').read_text())['compiler'],provider_build_sha256=file_sha(provider/'BUILD.json'),old_collector_sha256=sha(old_profile_source.encode()),new_collector_sha256=file_sha(source),executable_sha256=file_sha(exe),only_changed_original_source='Output-only soilwateroutput collector date list; all physical providers are pinned original sources');save()
 scalar={};nodal={};report['reference_runs']={}
 for cap,timeout in zip(plan['original_reference_dtmax_days'],plan['cost']['reference_wall_caps_seconds']):
  label=str(cap);case=reference/label;case.mkdir();base='donor/dtmax-'+(label if label in old_donor['runs']else'0.000625')
  for name in ['swap.swp','grass.crp','260.met','swap.bbc','swap.dra']:(case/name).write_bytes(get(study_tar,base+'/'+name))
  if cap==.0003125:
   old=(case/'swap.swp').read_bytes();assert old.count(b'DTMAX')>=1
   import re
   pattern=re.compile(rb'(?im)^(\s*DTMAX\s*=\s*)([\d.eE+\-]+)([^\r\n]*)$');assert len(list(pattern.finditer(old)))==1
   changed=pattern.sub(lambda m:m[1]+b'0.0003125'+m[3],old);assert pattern.sub(rb'\1DTMAX_NUMERICAL\3',old)==pattern.sub(rb'\1DTMAX_NUMERICAL\3',changed);(case/'swap.swp').write_bytes(changed)
  run([exe],f'reference-{label}',cwd=case,timeout=timeout,expected=100);assert(case/'swap.ok').exists();scalar[cap]=rows((case/'result_output.csv').read_bytes());assert len(scalar[cap])==1828 and scalar[cap][-1]['DATE']=='1984-12-31'
  parsed=profiles((case/'nodal_profiles.csv').read_bytes());nodal[cap]={}
  for row in parsed:nodal[cap].setdefault(int(row['day']),[]).append(row)
  assert set(nodal[cap])==set(old_dates+new_dates)
  if cap in [.00125,.000625]:
   assert scalar[cap]==rows(get(study_tar,base+'/result_output.csv')),'output-only scalar noninterference failed'
   assert [row for row in parsed if int(row['day'])in old_dates]==profiles(get(study_tar,base+'/nodal_profiles.csv')),'output-only old-profile noninterference failed'
  report['reference_runs'][label]=dict(returncode=100,completed_days=1827,scalar_sha256=file_sha(case/'result_output.csv'),profiles_sha256=file_sha(case/'nodal_profiles.csv'),input_sha256={p.name:file_sha(p)for p in case.iterdir()if p.name in ['swap.swp','grass.crp','260.met','swap.bbc','swap.dra']},old_scalar_and_profile_exact=cap in [.00125,.000625]);save()
 # Same unchanged bounds and metric. This is a new independent fine-policy test.
 previous={}
 fine=native['fine'];_,one,_,_=vectors(scalar[.00125],nodal[.00125],fine['budget'],fine['crop'],fine['checkpoints']);_,two,_,_=vectors(scalar[.000625],nodal[.000625],fine['budget'],fine['crop'],fine['checkpoints'])
 previous={key:distance(key,one[key],two[key])for key in one}
 report['assessments']={}
 for policy,data in native.items():report['assessments'][policy]=assess_envelope(frozen,scalar[.000625],scalar[.0003125],nodal[.000625],nodal[.0003125],data['budget'],data['crop'],data['checkpoints'],previous)
 report.update(status='REGISTERED_SPRINT02_HELDOUT_MEASURED',fine_configuration_pass=report['assessments']['fine']['pass'],original_preregistered_gate_pass=False,production_promoted=False);save();print(json.dumps(report,indent=2))
if __name__=='__main__':main()
