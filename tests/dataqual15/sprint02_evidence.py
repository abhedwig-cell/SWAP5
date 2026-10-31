"""Portable raw-data verification for the two narrow sprint02 experiments."""
import argparse,csv,hashlib,io,json,math,re,struct,tarfile,subprocess
from pathlib import Path,PurePosixPath,PureWindowsPath
from checkpoint_layout import layout
from qualify_donor_timestep import vectors,distance,assess_envelope
ROOT=Path(__file__).resolve().parents[2]
CAPSULE=ROOT/'integration/dataqual15/SPRINT02_EVIDENCE.tar.xz'
MANIFEST=CAPSULE.with_name('SPRINT02_EVIDENCE_MANIFEST.json')
sha=lambda b:hashlib.sha256(b).hexdigest()
INPUTS=['input.swp','grass.crp','input.met','swap.bbc','swap.dra','application.binding']

def package(heat,heldout,windows=None):
 assert json.loads((heat/'RESULT.json').read_text())['status']=='PAIRED_ORIGINAL_CURRENT_HEAT_COMPONENT_PASS'
 assert json.loads((heldout/'RESULT.json').read_text())['status']=='REGISTERED_SPRINT02_HELDOUT_MEASURED'
 files={}
 def add(path,name):assert name not in files;files[name]=Path(path).read_bytes()
 for name,folder in [('heat',heat),('heldout',heldout)]+([('windows',windows)]if windows else[]):
  for p in sorted(folder.rglob('*')):
   if not p.is_file():continue
   rel=p.relative_to(folder).as_posix()
   if '/source/'in '/'+rel or '/selected/'in '/'+rel or '/swobj/'in '/'+rel or '/ttobj/'in '/'+rel:continue
   if p.suffix in ['.json','.csv','.bin','.dat','.f90','.args','.stdout','.stderr','.swp','.crp','.met','.bbc','.dra']or p.name in ['stdout','stderr','heat','heat.exe','swap431','swap5_grass_startup','application.binding','swap.ok']:
    add(p,name+'/'+rel)
 sources={p:sha((ROOT/p).read_bytes())for p in ['tests/dataqual15/heat_oracle.f90','tests/dataqual15/qualify_heat.py','tests/dataqual15/qualify_sprint02_holdout.py','tests/dataqual15/sprint02_evidence.py','tests/dataqual15/original_sources.py','tests/dataqual15/qualify_donor_timestep.py','integration/dataqual15/SPRINT02_HELDOUT_PREREGISTRATION.json']}
 for p,digest in json.loads(files['heat/RESULT.json'])['source_sha256'].items():assert sha((ROOT/p).read_bytes())==digest;sources[p]=digest
 files['MANIFEST.json']=(json.dumps({p:sha(raw)for p,raw in sorted(files.items())},indent=2)+'\n').encode()
 with tarfile.open(CAPSULE,'w:xz',preset=6)as archive:
  for name,raw in sorted(files.items()):
   info=tarfile.TarInfo(name);info.size=len(raw);info.mode=0o644;info.mtime=0;archive.addfile(info,io.BytesIO(raw))
 record=dict(archive_sha256=sha(CAPSULE.read_bytes()),archive_files=len(files),source_sha256=sources,inherited_capsules={p:sha((ROOT/p).read_bytes())for p in ['integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz','integration/dataqual15/STRESS_EVIDENCE.tar.xz']},production_trees=json.loads((ROOT/'integration/dataqual15/GRASS_UNION_FULL_MANIFEST.json').read_text())['qualified_production_tree_oids'],canonical_modified=False,original_preregistered_gate_pass=False,production_promotion=False)
 MANIFEST.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8',newline='\n');print('PACKAGED',len(files),CAPSULE.stat().st_size,flush=True)

def verify():
 record=json.loads(MANIFEST.read_text());assert not record['original_preregistered_gate_pass']and not record['canonical_modified']
 for p,digest in record['source_sha256'].items():assert sha((ROOT/p).read_bytes())==digest,p
 for p,digest in record['inherited_capsules'].items():assert sha((ROOT/p).read_bytes())==digest,p
 for name,oid in record['production_trees'].items():assert subprocess.check_output(['git','rev-parse','HEAD:'+name],cwd=ROOT,text=True).strip()==oid
 assert not subprocess.check_output(['git','diff','HEAD','--','src','app','reference'],cwd=ROOT)
 assert sha(CAPSULE.read_bytes())==record['archive_sha256']
 with tarfile.open(CAPSULE)as archive:
  members=archive.getmembers();assert len(members)==record['archive_files']==len({m.name for m in members})
  assert all(m.isfile()and not PurePosixPath(m.name).is_absolute()and not PureWindowsPath(m.name).drive and '..'not in PurePosixPath(m.name).parts and '\\'not in m.name for m in members)
  files={m.name:archive.extractfile(m).read()for m in members}
 assert json.loads(files.pop('MANIFEST.json'))=={p:sha(raw)for p,raw in files.items()}
 load=lambda p:json.loads(files[p]);rows=lambda raw:list(csv.DictReader(line for line in raw.decode().splitlines()if line.strip()and not line.startswith('*')))
 with tarfile.open(ROOT/'integration/dataqual15/STRESS_EVIDENCE.tar.xz')as old,tarfile.open(ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz')as full:
  get=lambda a,n:a.extractfile(n).read();plan=load('heldout/PREREGISTRATION.json');frozen=json.loads(get(old,'donor/PREREGISTRATION.json'))
  assert files['heldout/PREREGISTRATION.json']==(ROOT/'integration/dataqual15/SPRINT02_HELDOUT_PREREGISTRATION.json').read_bytes()
  assert frozen['bounds']==plan['frozen_bounds']and sha(get(old,'donor/PREREGISTRATION.json'))==plan['frozen_registration_sha256']
  assert json.loads(get(old,'donor/RESULT.json'))['numerical_resolution_gate_pass']is False
  for label in ['heat']+(['windows']if'windows/RESULT.json'in files else[]):
   heat=load(label+'/RESULT.json');assert heat['status']=='PAIRED_ORIGINAL_CURRENT_HEAT_COMPONENT_PASS'
   assert heat['input_sha256']==sha(files[label+'/heat-inputs.dat'])
   assert files[label+'/input.swp']==(ROOT/'reference/swap-4.3.1/projects/2.grassgrowth/swap.swp').read_bytes()
   assert heat['criteria']==load(label+'/CRITERIA_BEFORE_EXECUTION.json')
   for p,digest in heat['source_sha256'].items():assert sha((ROOT/p).read_bytes())==digest
   for opt in ['O0','O2']:
    run=heat['runs'][opt];assert run['cases']==96 and run['frozen_water_cases']==72 and run['interpolated_water_cases']==24
    assert run['stdout_sha256']==sha(files[label+'/'+opt+'/stdout'])
    binary=label+'/'+opt+'/heat'+('.exe'if label=='windows'else'');assert sha(files[binary])==run['executable_sha256']
    data=[list(map(float,line.split(',')[1:]))for line in files[label+'/'+opt+'/stdout'].decode().splitlines()if line.startswith('HEAT_PAIR,')];assert data==run['rows']and len(data)==96
    assert all(math.isfinite(v)for row in data for v in row)
    assert max(max(r[2],r[5])for r in data)<=5e-10 and max(r[3]for r in data)<=5e-10 and max(r[4]for r in data)<=5e-9
    original=load(label+'/original-'+opt+'/BUILD.json');prior=json.loads(get(old,'whole/original-'+opt+'/BUILD.json'))
    for key in ['source_sha256','selected_sha256','authority_sha256','manifest_sha256']:assert {name.replace(chr(92),'/'):digest for name,digest in original[key].items()}==prior[key]
    assert original['status']=='BUILT'and all(e['returncode']==0 for e in original['events'])
  result=load('heldout/RESULT.json');assert result['status']=='REGISTERED_SPRINT02_HELDOUT_MEASURED'and result['original_preregistered_gate_pass']is False
  assert result['registration_sha256']==sha(files['heldout/PREREGISTRATION.json'])and all(e['returncode']in [0,100]and not e['censored']for e in result['events'])
  spec=json.loads(get(full,'SPEC.json'));native={};maximum_stock_residual=0.
  def stock(raw):
   s=layout(raw);n=s['nodes'];dz=struct.unpack_from('='+str(n)+'d',raw,s['header']+48+8*n);theta=struct.unpack_from('='+str(n)+'d',raw,s['physical']+8*n);pond=struct.unpack_from('=d',raw,s['physical']+16*n)[0]
   return math.fsum(a*b for a,b in zip(dz,theta))+pond
  for policy in ['coarse','fine']:
   archive=full if policy=='coarse'else old;prefix=spec['full']if policy=='coarse'else'thermal/native';binary=get(archive,'build/O2/swap5_grass_startup'if policy=='coarse'else'thermal/build/swap5_grass_startup')
   assert files['heldout/'+policy+'/swap5_grass_startup']==binary
   inputs={p:get(archive,prefix+'/'+p)for p in INPUTS};assert sha(binary)==json.loads(inputs['application.binding'])['executable_sha256']
   budgets=rows(get(archive,prefix+'/budget.csv'));crops=rows(get(archive,prefix+'/crop.csv'));checkpoints={}
   for name in archive.getnames():
    if name.startswith(prefix+'/checkpoint')and name.endswith('.bin'):
     raw=get(archive,name);checkpoints[int(layout(raw)['clock'])]=raw
   for origin,day in zip(plan['native_origin_days'],plan['new_profile_days']):
    case='heldout/'+policy+'/'+str(day);assert files[case+'/origin.bin']==checkpoints[origin]
    raw=files[case+'/checkpoint.bin'];assert layout(raw)['clock']==day;pos=8
    for name in INPUTS:
     size=struct.unpack_from('=i',raw,pos)[0];pos+=4;assert raw[pos:pos+size]==inputs[name]==files[case+'/'+name];pos+=size
    b=rows(files[case+'/budget.csv']);c=rows(files[case+'/crop.csv']);assert b==budgets[day-1:day]and c==crops[day-1:day]
    residual=stock(raw)-stock(checkpoints[origin])-float(b[0]['input_cm'])+float(b[0]['output_cm']);assert abs(residual)<1e-10;maximum_stock_residual=max(maximum_stock_residual,abs(residual))
    assert abs(float(b[0]['residual_cm']))<1e-10 and abs(float(b[0]['heat_residual_j_cm2']))<1e-8;checkpoints[day]=raw
   native[policy]=dict(budget=budgets,crop=crops,checkpoints=checkpoints)
  reference={};nodal={};old_dates=[0,63,71,72,73,113,140,367,731,918,922,1096,1461,1800,1827]
  source=get(full,spec['reference_B0_nodal']+'/swapoutput_profiles.f90').decode();needle='['+','.join(map(str,old_dates))+']'
  expected=source.replace(needle,'['+','.join(map(str,sorted(set(old_dates+plan['new_profile_days']))))+']').encode();assert expected==files['heldout/reference/swapoutput_profiles.f90']
  assert sha(files['heldout/reference/swap431'])==result['reference_build']['executable_sha256']
  original=load('heldout/reference/providers/BUILD.json');prior=json.loads(get(old,'whole/original-O2/BUILD.json'))
  for key in ['source_sha256','selected_sha256','authority_sha256','manifest_sha256']:assert {name.replace(chr(92),'/'):digest for name,digest in original[key].items()}==prior[key]
  for cap in plan['original_reference_dtmax_days']:
   label=str(cap);case='heldout/reference/'+label;reference[cap]=rows(files[case+'/result_output.csv']);assert len(reference[cap])==1828
   profile=rows(files[case+'/nodal_profiles.csv']);nodal[cap]={}
   for r in profile:nodal[cap].setdefault(int(r['day']),[]).append(r)
   assert set(nodal[cap])==set(old_dates+plan['new_profile_days'])
   base='donor/dtmax-'+(label if cap in [.00125,.000625]else'0.000625')
   pattern=re.compile(rb'(?im)^(\s*DTMAX\s*=\s*)([\d.eE+\-]+)([^\r\n]*)$')
   supplied=files[case+'/swap.swp'];literal=get(old,base+'/swap.swp');assert len(list(pattern.finditer(supplied)))==1 and float(pattern.search(supplied)[2])==cap
   assert pattern.sub(rb'\1NUMERICAL_DTMAX\3',supplied)==pattern.sub(rb'\1NUMERICAL_DTMAX\3',literal)
   for name in ['grass.crp','260.met','swap.bbc','swap.dra']:assert files[case+'/'+name]==get(old,base+'/'+name)
   for name in ['swap.swp','grass.crp','260.met','swap.bbc','swap.dra']:assert sha(files[case+'/'+name])==result['reference_runs'][label]['input_sha256'][name]
   if cap in [.00125,.000625]:
    assert reference[cap]==rows(get(old,'donor/dtmax-'+label+'/result_output.csv'))
    assert [r for r in profile if int(r['day'])in old_dates]==rows(get(old,'donor/dtmax-'+label+'/nodal_profiles.csv'))
  fine=native['fine'];_,a,_,_=vectors(reference[.00125],nodal[.00125],**fine);_,b,_,_=vectors(reference[.000625],nodal[.000625],**fine);previous={key:distance(key,a[key],b[key])for key in a}
  for policy,data in native.items():
   for cap in plan['original_reference_dtmax_days']:
    observed,ref,_,_=vectors(reference[cap],nodal[cap],**data);assert all(math.isfinite(v)for vector in [*observed.values(),*ref.values()]for v in vector)
   assessment=assess_envelope(frozen,reference[.000625],reference[.0003125],nodal[.000625],nodal[.0003125],data['budget'],data['crop'],data['checkpoints'],previous);assert assessment==result['assessments'][policy]
  assert result['fine_configuration_pass']==result['assessments']['fine']['pass']
 answer=dict(status='SOURCE_BOUND_SPRINT02_EVIDENCE_PASS',heat_cases_per_optimization=96,new_profile_days=plan['new_profile_days'],native_forks=24,maximum_independent_checkpoint_stock_flux_residual_cm=maximum_stock_residual,registered_fine_configuration_pass=result['fine_configuration_pass'],original_preregistered_gate_pass=False,production_promotion=False,canonical_modified=False)
 print(json.dumps(answer,indent=2));return answer

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--package',action='store_true');p.add_argument('--heat',type=Path);p.add_argument('--heldout',type=Path);p.add_argument('--windows',type=Path);a=p.parse_args()
 if a.package:package(a.heat,a.heldout,a.windows)
 verify()
