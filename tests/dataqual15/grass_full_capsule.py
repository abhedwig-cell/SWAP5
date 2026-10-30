"""Portable final Grassgrowth proof, independent of the historical521 receipt.

Roles are explicit, but the full-period, source, balance and restart assertions
are fixed. Packaging never snapshots an unfinished model or qualification run.
"""
import argparse,csv,hashlib,io,json,math,struct,subprocess,tarfile,tempfile
from pathlib import Path
from checkpoint_layout import layout,payload
from check_history import check as history_check

ROOT=Path(__file__).resolve().parents[2]
CAPSULE=ROOT/'integration/dataqual15/GRASS_FULL_EVIDENCE.tar.xz'
MANIFEST=ROOT/'integration/dataqual15/GRASS_FULL_MANIFEST.json'
SPEC=ROOT/'integration/dataqual15/GRASS_FULL_SPEC.json'
sha=lambda b:hashlib.sha256(b).hexdigest()
INPUTS={'input.swp':'swap.swp','grass.crp':'grass.crp','input.met':'260.met','swap.bbc':'swap.bbc','swap.dra':'swap.dra'}
PROJECT=ROOT/'reference/swap-4.3.1/projects/2.grassgrowth'

def read_json(path):return json.loads(Path(path).read_text())
def production_delta(base):
 lines=subprocess.check_output(['git','diff','--name-status',base,'HEAD','--','src','app','reference'],cwd=ROOT,text=True).splitlines()
 return {line.split('\t')[1]:line.split('\t')[0]for line in lines}
def production_trees(ref='HEAD'):
 return {name:subprocess.check_output(['git','rev-parse',ref+':'+name],cwd=ROOT,text=True).strip()for name in ['src','app','reference']}
def planned_folders(spec):
 return [spec['full'],spec['year_O0'],*[r['folder']for r in spec['restarts']],*spec['negative'].values(),spec['runtime'],spec['mowing'],spec['reference_B0'],spec['reference_B0_nodal'],spec['reference_B1']]
def preflight(spec,workspace):
 pending=[]
 for folder in planned_folders(spec):
  if not(workspace/folder/'RESULT.json').exists():pending.append(folder+'/RESULT.json')
 return pending
def output_paths(spec,capsule=None,manifest=None):
 return (Path(capsule)if capsule else ROOT/spec.get('capsule','integration/dataqual15/GRASS_FULL_EVIDENCE.tar.xz'),Path(manifest)if manifest else ROOT/spec.get('manifest','integration/dataqual15/GRASS_FULL_MANIFEST.json'))

def package(spec_path=SPEC,workspace=ROOT.parent,capsule=None,manifest=None):
 spec=read_json(spec_path);workspace=workspace.resolve();pending=preflight(spec,workspace)
 capsule,manifest=output_paths(spec,capsule,manifest)
 assert not pending,'unfinished or missing evidence: '+', '.join(pending)
 assert production_delta(spec['baseline'])==spec['reviewed_production_delta'],'unreviewed production delta'
 assert not subprocess.check_output(['git','diff','HEAD','--','src','app','reference'],cwd=ROOT),'uncommitted production source'
 assert set(spec['qualified_production_tree_oids'])=={'src','app','reference'}
 assert production_trees(spec['scientific_source_commit'])==spec['qualified_production_tree_oids'],'local scientific provenance does not identify qualified production trees'
 assert production_trees()==spec['qualified_production_tree_oids'],'current production tree differs from qualified postimage'
 files={};sources={};external={};executables={};archives={}
 def add(path,name):
  raw=Path(path).read_bytes();assert name not in files or files[name]==raw,name;files[name]=raw
 def bind(mapping):
  for name,h in mapping.items():
   path=Path(name);relative=None
   if not path.is_absolute():relative=path
   else:
    for root in spec['source_roots']:
     try:relative=path.relative_to(root);break
     except ValueError:pass
   if relative is not None:
    assert not relative.is_absolute()and'..'not in relative.parts
    assert relative.parts[0]in ['src','app','tests','tools','reference'],name
    assert sha((ROOT/relative).read_bytes())==h,name
    key=relative.as_posix();assert key not in sources or sources[key]==h;sources[key]=h
   else:
    # Only existing generated input readers and the frozen runtime context
    # may be external SWAP5 providers. Unknown production roots fail closed.
    assert path.name in ['original_input_helpers.f90','context.f90'],name
    assert sha(path.read_bytes())==h,name
    member='external/'+h+'-'+path.name;add(path,member);external[name]=member
 def tree(folder,prefix):
  selected=[p for p in folder.rglob('*')if p.is_file()and(p.suffix.lower()in ['.json','.csv','.bin','.f90','.crp','.swp','.met','.bbc','.dra','.stdout','.stderr']or p.name in ['stdout','stderr','application.binding','swap.ok','swap.err','swap.log','swap.wrn'])]
  for p in selected:add(p,prefix+'/'+p.relative_to(folder).as_posix())
  assert all(sha(p.read_bytes())==sha(files[prefix+'/'+p.relative_to(folder).as_posix()])for p in selected),'evidence mutated while packaging'
 def bind_report(report):
  if isinstance(report.get('source_sha256'),dict):bind(report['source_sha256'])
 for opt,folder in spec['builds'].items():
  build=workspace/folder;report=read_json(build/'BUILD.json');bind_report(report)
  add(build/'BUILD.json','build/'+opt+'/BUILD.json')
  exe=build/'swap5_grass_startup';assert sha(exe.read_bytes())==report['executable_sha256']
  member='build/'+opt+'/swap5_grass_startup';add(exe,member);executables[member]=report['executable_sha256']
  library=[Path(arg)for e in report['events']if e['label']=='link'for arg in e['command']if arg.endswith('.a')]
  assert len(library)==1 and sha(library[0].read_bytes())==report['original_input_archive_sha256']
  member='build/'+opt+'/libttutil.a';add(library[0],member);archives[member]=report['original_input_archive_sha256']
  for p in [*build.glob('*.stdout'),*build.glob('*.stderr')]:add(p,'build/'+opt+'/'+p.name)
 for folder in planned_folders(spec):
  path=workspace/folder;report=read_json(path/'RESULT.json');bind_report(report)
  if(folder==spec['full']or folder==spec['year_O0']or folder in [r['folder']for r in spec['restarts']]):
   assert report['returncode']==0 and not report['censored'],folder
   bind_report(read_json(path/'application.binding'))
  tree(path,folder)
 donor=Path(spec['original_donor']);donor_report=read_json(donor/'BUILD.json')
 add(donor/'BUILD.json','original431/BUILD.json')
 for name,h in donor_report['original_provider_build']['source_sha256'].items():
  path=donor/'providers'/name;assert sha(path.read_bytes())==h,name;add(path,'original431/providers/'+name)
 for path in (donor/'providers/selected').glob('*.f90'):add(path,'original431/providers/selected/'+path.name)
 # Retain reference executables, not opaque object/module caches. Their exact
 # bytes and actual compile/link records permit native same-build replay.
 for path,name,h in [(donor/'swap431','original431/swap431',donor_report['executable_sha256']),
  (workspace/spec['reference_B0_nodal']/'swap431_profiles','original431/swap431_profiles',read_json(workspace/spec['reference_B0_nodal']/'RESULT.json')['executable_sha256']),
  (workspace/spec['reference_B1']/'swap431_continuous_reference','original431/swap431_continuous_reference',read_json(workspace/spec['reference_B1']/'RESULT.json')['executable_sha256'])]:
  assert sha(path.read_bytes())==h;add(path,name);executables[name]=h
 diagnostic_receipts={}
 for path in spec.get('repository_diagnostics',[]):
  add(ROOT/path,'diagnostics/repository/'+path);diagnostic_receipts['diagnostics/repository/'+path]='Recorded cause evidence; not additional current native qualification'
 for record in spec.get('diagnostic_files',[]):
  assert record['scope'].startswith('DIAGNOSTIC_ONLY_')
  member='diagnostics/'+record['path'];add(workspace/record['path'],member);diagnostic_receipts[member]=record['scope']
 files['SPEC.json']=(json.dumps(spec,indent=2)+'\n').encode()
 files['RECOVERY.md']=b'''# Exact native recovery\n\nVerify every archive digest with verify_grass_full_evidence.py first. Retain the\noriginal application.binding bytes. For O2, copy build/O2/swap5_grass_startup and\nthe five literal input files plus application.binding from the full native case\nto a new working directory. Verify the executable SHA256 against the manifest,\nthen restore owner execute permission. Run that exact executable from the new\ncase directory with arguments: 1827 retain-step 100000 /absolute/captured/checkpoint-1800.bin\n(the captured checkpoint is from the archived full O2 case). Compare the terminal\ncheckpoint and daily suffix with the archived full case. No source rebinding is\npermitted. Original absolute build paths in application.binding are opaque\nprovenance; retain them byte for byte. The TTUTIL archive and complete source\nidentity are included for rebuild audit; exact recovery uses the retained binary.\n'''
 inner={name:sha(raw)for name,raw in sorted(files.items())}
 files['MANIFEST.json']=(json.dumps(inner,indent=2)+'\n').encode()
 with tarfile.open(capsule,'w:xz',preset=6)as tar:
  for name,raw in sorted(files.items()):
   info=tarfile.TarInfo(name);info.mode=0o644;info.mtime=0;info.size=len(raw);tar.addfile(info,io.BytesIO(raw))
 receipt=dict(schema=1,baseline=spec['baseline'],scientific_source_commit=spec['scientific_source_commit'],qualified_production_tree_oids=spec['qualified_production_tree_oids'],reviewed_production_delta=spec['reviewed_production_delta'],expected_provider_count=spec.get('expected_provider_count',203),source_sha256=sources,external_source_members=external,executables_sha256=executables,libraries_sha256=archives,diagnostic_receipts=diagnostic_receipts,evidence_sha256=sha(capsule.read_bytes()),archive_files=len(files),full_original_days=1827,independent_O0_days=367,scientific_equivalence=False,scope='Original physical inputs and all1827days, current stricter SWAP5 numerical acceptance. B0 literal donor and separately labelled B1 corrected donor. No whole energy or scientific equivalence promotion.')
 manifest.write_text(json.dumps(receipt,indent=2)+'\n')
 return verify(capsule,manifest)

def verify(capsule=CAPSULE,manifest=MANIFEST):
 m=read_json(manifest);raw=Path(capsule).read_bytes();assert sha(raw)==m['evidence_sha256']
 if (ROOT/'.git').exists():
  assert production_delta(m['baseline'])==m['reviewed_production_delta'],'unreviewed production delta'
  assert not subprocess.check_output(['git','diff','HEAD','--','src','app','reference'],cwd=ROOT),'uncommitted production source'
  # Connector publication can create a new commit identity for the exact same
  # tree. Verify the full qualified production trees without requiring the
  # local-only scientific commit object to exist in the published checkout.
  assert set(m['qualified_production_tree_oids'])=={'src','app','reference'}
  assert production_trees()==m['qualified_production_tree_oids'],'qualified production postimage changed'
 for path,h in m['source_sha256'].items():assert sha((ROOT/path).read_bytes())==h,path
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as tar:
  members=tar.getmembers();assert len({p.name for p in members})==len(members)
  assert all(p.isfile()and not Path(p.name).is_absolute()and'..'not in Path(p.name).parts for p in members)
  f={p.name:tar.extractfile(p).read()for p in members}
 assert len(f)==m['archive_files'];assert json.loads(f.pop('MANIFEST.json'))=={name:sha(b)for name,b in f.items()}
 spec=json.loads(f['SPEC.json']);assert spec['baseline']==m['baseline']and spec['scientific_source_commit']==m['scientific_source_commit']
 assert spec['qualified_production_tree_oids']==m['qualified_production_tree_oids']
 expected_providers=spec.get('expected_provider_count',203);assert expected_providers in [203,211]and expected_providers==m.get('expected_provider_count',203)
 for name,h in {**m['executables_sha256'],**m['libraries_sha256']}.items():assert sha(f[name])==h
 def load(name):return json.loads(f[name])
 def rows(name):return list(csv.DictReader(io.StringIO(f[name].decode())))
 def bind(report):
  for path,h in report['source_sha256'].items():
   if path in m['external_source_members']:assert sha(f[m['external_source_members'][path]])==h;continue
   relative=None
   if not Path(path).is_absolute():relative=Path(path)
   else:
    for root in spec['source_roots']:
     try:relative=Path(path).relative_to(root);break
     except ValueError:pass
   assert relative is not None and '..'not in relative.parts,path
   assert m['source_sha256'][relative.as_posix()]==h
 def build(opt):return load('build/'+opt+'/BUILD.json')
 for opt in ['O0','O2']:
  b=build(opt);bind(b)
  assert b['provider_count']==expected_providers and '-'+opt in b['flags']and'-fcheck=all'in b['flags']and'-ffast-math'not in b['flags']
  assert all(e['returncode']==0 for e in b['events'])and b['native_returncode']==0
  assert b['source_authority_sha256']==sha((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())
  assert sha(f['build/'+opt+'/swap5_grass_startup'])==b['executable_sha256']
  assert sha(f['build/'+opt+'/libttutil.a'])==b['original_input_archive_sha256']
  assert all(h==sha((PROJECT/INPUTS[name]).read_bytes())for name,h in b['original_inputs_sha256'].items())
 def stock(raw):
  s=layout(raw);n=s['nodes'];dz=struct.unpack_from('='+str(n)+'d',raw,s['header']+48+8*n)
  theta=struct.unpack_from('='+str(n)+'d',raw,s['physical']+8*n);pond=struct.unpack_from('=d',raw,s['physical']+16*n)[0]
  assert n==113 and min(dz)>0 and abs(math.fsum(dz)-600)<1e-12
  assert all(math.isfinite(v)and 0<=v<=1 for v in theta)and math.isfinite(pond)and pond>=0
  return math.fsum(t*w for t,w in zip(theta,dz))+pond
 def native(folder,opt,origin=None,end=None):
  r=load(folder+'/RESULT.json');assert r['returncode']==0 and not r['censored'],folder
  b=rows(folder+'/budget.csv');c=rows(folder+'/crop.csv');assert b and len(b)==len(c)
  if origin is not None:assert int(b[0]['day'])==origin+1
  if end is not None:assert int(b[-1]['day'])==end==r['completed_days']
  binding=load(folder+'/application.binding');bind(binding);assert binding['executable_sha256']==build(opt)['executable_sha256']
  assert r['executable_sha256']==binding['executable_sha256'];bind(r)
  for name,old in INPUTS.items():assert f[folder+'/'+name]==(PROJECT/old).read_bytes()
  for i,(water,crop)in enumerate(zip(b,c)):
   assert int(water['day'])==int(b[0]['day'])+i==int(crop['day'])
   assert all(math.isfinite(float(v))for v in [*water.values(),*crop.values()])
   assert abs(float(water['residual_cm']))<1e-10 and abs(float(water['heat_residual_j_cm2']))<1e-8
   assert abs(math.fsum([float(water['water_end_cm']),-float(water['water_start_cm']),-float(water['input_cm']),float(water['output_cm'])]))<1e-10
   assert abs(math.fsum([float(water['potential_cm']),-float(water['uptake_cm']),-float(water['drought_cm']),-float(water['oxygen_cm'])]))<1e-10
   if i:assert abs(float(water['water_start_cm'])-float(b[i-1]['water_end_cm']))<1e-10
  cumulative=math.fsum([float(b[-1]['water_end_cm']),-float(b[0]['water_start_cm']),*[-float(q['input_cm'])for q in b],*[float(q['output_cm'])for q in b]])
  assert abs(cumulative)<1e-8,('cumulative water stock/flux discrepancy',folder,cumulative)
  raw=f[folder+'/checkpoint.bin'];assert layout(raw)['clock']==int(b[-1]['day'])
  assert abs(stock(raw)-float(b[-1]['water_end_cm']))<1e-10
  return b,c,dict(rows=len(b),maximum_water_residual_cm=max(abs(float(q['residual_cm']))for q in b),cumulative_water_stock_flux_residual_cm=cumulative,maximum_heat_accounting_residual_j_cm2=max(abs(float(q['heat_residual_j_cm2']))for q in b))
 full=spec['full'];year=spec['year_O0'];water,crop,balances=native(full,'O2',0,1827);w0,c0,year_balances=native(year,'O0',0,367)
 assert water[:367]==w0 and crop[:367]==c0
 assert payload(f[full+'/checkpoint-367.bin'])==payload(f[year+'/checkpoint.bin'])
 checked_restarts=[];purposes=set()
 for role in spec['restarts']:
  folder=role['folder'];opt=role['optimization'];start=role['origin_day'];end=role['end_day'];purpose=role['purpose'];purposes.add(purpose)
  b,c,_=native(folder,opt,start,end);base=full if opt=='O2'else year
  reference_budget=water if opt=='O2'else w0;reference_crop=crop if opt=='O2'else c0
  origin=base+f'/checkpoint-{start}.bin';expected=base+('/checkpoint.bin'if end==len(reference_budget)else f'/checkpoint-{end}.bin')
  assert f[folder+'/restart-origin.bin']==f[origin]
  assert f[folder+'/checkpoint.bin']==f[expected]
  assert b==reference_budget[start:end]and c==reference_crop[start:end]
  if purpose=='distinct_delay':
   raw=f[origin];s=layout(raw);actual=struct.unpack_from('=i',raw,s['actual']['start']+164+24*s['actual']['leaves']-4)[0];potential=struct.unpack_from('=i',raw,s['management'])[0]
   assert actual!=potential and max(actual,potential)>0,(actual,potential)
  checked_restarts.append(dict(optimization=opt,origin=start,end=end,purpose=purpose))
 assert {'year','mowing','distinct_delay','oxygen','final'}<=purposes
 assert any(q['origin']==365 and q['end']==367 for q in checked_restarts)
 assert any(q['origin']<=1786 and q['end']==1827 and q['purpose']=='oxygen'for q in checked_restarts)
 for opt,folder in spec['negative'].items():
  r=load(folder+'/RESULT.json');bind(r);assert r['executable_sha256']==build(opt)['executable_sha256']
  cases={e['case']for e in r['events']};assert len(r['events'])==11 and cases=={'crc','truncated','layout','clock','source','roots','delay','potential_delay','cut_index','yield_nan','compatibility_nan'}
  base=year if opt=='O0'else full;assert r['checkpoint_sha256']==sha(f[base+'/checkpoint-117.bin'])
  for e in r['events']:
   prefix=folder+'/'+e['case']+'/';assert e['returncode']!=0 and b'bound grass prefix restart rejected'in f[prefix+'stdout']
   assert prefix+'checkpoint.bin'not in f and prefix+'budget.csv'not in f
 runtime=load(spec['runtime']+'/RESULT.json');bind(runtime);assert runtime['status']=='CURRENT_REFERENCE_GROUNDWATER_DEFAULT_AND_OXYGEN_PASS'
 assert all(e['returncode']==0 for e in runtime['events'])and len([e for e in runtime['events']if e['label']=='native_existing_contract'])==8
 for opt in ['O0','O2']:
  for name in ['groundwater_runtime_driver','groundwater_table_runtime_driver','test_ppa_wu01_production_application_bootstrap','test_bartholomeus_application']:assert b'PASS'in f[spec['runtime']+'/'+opt+'/'+name+'.stdout']
 mowing=load(spec['mowing']+'/RESULT.json');bind(mowing);assert all(e['returncode']==0 for e in mowing['events'])
 for opt in ['O0','O2']:
  lines=[line.split()for line in f[spec['mowing']+'/'+opt+'/stdout'].decode().splitlines()if line.strip().startswith('GRASS_BODY')]
  assert len(lines)==8 and [int(line[1])for line in lines]==list(range(1,9))and all(float(line[2])==0 for line in lines)
 reference_report=verify_references(f,spec)
 with tempfile.TemporaryDirectory(prefix='swap5-grass-full-')as temp:
  root=Path(temp)
  # Only native output/reference files are needed by the existing history
  # comparator. Exact binaries remain in the capsule, avoiding duplicate disk.
  for name,raw in f.items():
   if name.startswith(full+'/')or name.startswith(spec['reference_B0']+'/')or name.startswith(spec['reference_B1']+'/'):
    path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
  b0=history_check([root/full],root/spec['reference_B0']/'result_output.csv')
  b1=history_check([root/full],root/spec['reference_B1']/'original/result_output.csv')
 assert b0['full_original_execution']and b1['full_original_execution']and not m['scientific_equivalence']
 profiles=profile_differences(f,spec,full)
 return dict(status='SOURCE_BOUND_FULL_ORIGINAL_GRASS_EXECUTION_PASS',full_original_days=1827,independent_O0_O2_exact_days=367,balances=balances,O0_balances=year_balances,exact_restarts=checked_restarts,invalid_restart_controls_per_optimization=11,native_preservation_contracts=8,whole_original_grass_cases_per_build=8,reference=reference_report,B0_maximum_scalar_differences=b0['maximum_reference_differences'],B1_maximum_scalar_differences=b1['maximum_reference_differences'],B0_harvest_at_checkpoints=b0['harvest_at_native_checkpoints'],B1_harvest_at_checkpoints=b1['harvest_at_native_checkpoints'],nodal_profiles=profiles,scientific_equivalence=False,canonical_admission_claim=False)

def verify_references(f,spec):
 load=lambda n:json.loads(f[n]);b0=spec['reference_B0'];nodal=spec['reference_B0_nodal'];b1=spec['reference_B1']
 original=load('original431/BUILD.json');r0=load(b0+'/RESULT.json');rn=load(nodal+'/RESULT.json');r1=load(b1+'/RESULT.json')
 assert r0['returncode']==100 and not r0['physical_input_changes']and r0['executable_sha256']==original['executable_sha256']
 assert sha(f['original431/BUILD.json'])==r0['original_provider_build_json_sha256']==rn['original_build_sha256']==r1['original_build_sha256']
 for name,h in original['original_provider_build']['source_sha256'].items():assert sha(f['original431/providers/'+name])==h
 assert sha(f['original431/providers/selected/swap_main.f90'])==original['source_sha256']
 original_mowing=f['original431/providers/selected/wofost.f90'].decode().replace('\r\n','\n')
 assert f[spec['mowing']+'/original_wofost.f90'].decode()==original_mowing.replace('   private\n','   private\n   public :: read_wofost,initialize_wofost,initialize_grass,update_dvs_rate,update_wofost,r_act\n',1)
 def scalar(name):return list(csv.DictReader(line for line in f[name].decode().splitlines()if line.strip()and not line.startswith('*')))
 rows0=scalar(b0+'/result_output.csv');rowsn=scalar(nodal+'/original/result_output.csv');rows1=scalar(b1+'/original/result_output.csv')
 assert len(rows0)==len(rowsn)==len(rows1)==1828 and rowsn==rows0
 assert rows0[-1]['DATE']==rows1[-1]['DATE']=='1984-12-31'
 assert rn['scalar_trajectory_exact']and rn['profile_rows']==113*len(rn['profile_days'])and rn['status']=='ORIGINAL1827_SCALAR_EXACT_WITH_NODAL_DIAGNOSTICS'
 assert r1['status']=='B1_ORIGINAL1827_COMPLETE'and not r1['physical_input_changes']and r1['original_days']==1827
 assert all(e['returncode']==(100 if e['label']=='native'else 0)for r in [rn,r1]for e in r['events'])
 source=f['original431/providers/selected/MOD_MvG_functions.f90'].decode().replace('\r\n','\n');marker='relsat > (1.0d0-1.0d-6)';assert source.count(marker)==2
 corrected=f[b1+'/MOD_MvG_continuous_reference.f90'];assert corrected.decode()==source.replace(marker,'relsat >= 1.0d0')and sha(corrected)==r1['corrected_source_sha256']
 assert sha(f[nodal+'/swapoutput_profiles.f90'])==rn['instrumented_source_sha256']
 def physical(raw):return [line for line in raw.decode().splitlines()if line.strip()and not line.lstrip().startswith(('INLIST_CSV','NUM_DECIMALS'))]
 for name in ['swap.swp','grass.crp','260.met','swap.bbc','swap.dra']:
  raw=f[b0+'/'+name]
  if name=='swap.swp':assert physical(raw)==physical((PROJECT/name).read_bytes())
  else:assert raw==(PROJECT/name).read_bytes()
  assert raw==f[nodal+'/original/'+name]==f[b1+'/original/'+name]
 return dict(B0='Literal original4.3.1 physical implementation; output-only diagnostics',B1='Two documented early-Ksat threshold tests corrected; distinct counterfactual reference',days_each=1827,read_only_B0_nodal_instrumentation_scalar_exact=True,scientific_equivalence=False)

def profile_differences(f,spec,full):
 output={}
 for role,base in [('B0',spec['reference_B0_nodal']),('B1',spec['reference_B1'])]:
  table=list(csv.DictReader(io.StringIO(f[base+'/original/nodal_profiles.csv'].decode())));byday={}
  scalar=list(csv.DictReader(line for line in f[base+'/original/result_output.csv'].decode().splitlines()if line.strip()and not line.startswith('*')))
  for row in table:byday.setdefault(int(row['day']),[]).append(row)
  measurements=[]
  for name,raw in f.items():
   if not name.startswith(full+'/checkpoint')or not name.endswith('.bin'):continue
   state=layout(raw);day=int(state['clock'])
   if day not in byday:continue
   source=sorted(byday[day],key=lambda r:int(r['node']));assert len(source)==113
   n=state['nodes'];pos=state['physical'];vectors={'head_cm':struct.unpack_from('='+str(n)+'d',raw,pos),'water_content':struct.unpack_from('='+str(n)+'d',raw,pos+8*n),'temperature_c':struct.unpack_from('='+str(n)+'d',raw,pos+16*n+16)}
   dz=struct.unpack_from('='+str(n)+'d',raw,state['header']+48+8*n)
   reference_stock=math.fsum(float(row['water_content'])*width for row,width in zip(source,dz))+float(scalar[day]['PD_VOL'])
   assert abs(reference_stock-float(scalar[day]['WTOT']))<1e-8,(role,day,'profile/scalar stock mismatch')
   measurement=dict(day=day)
   for field,values in vectors.items():
    differences=[abs(v-float(row[field]))for v,row in zip(values,source)];assert all(math.isfinite(v)for v in differences)
    measurement[field]=dict(maximum_absolute_difference=max(differences),node=differences.index(max(differences))+1)
   measurements.append(measurement)
  unique={r['day']:r for r in measurements};assert {367,1827}<=set(unique)
  output[role]=dict(sampled_days=sorted(unique),maximum_over_sampled_profiles={field:max(row[field]['maximum_absolute_difference']for row in unique.values())for field in ['head_cm','water_content','temperature_c']},measurements=[unique[d]for d in sorted(unique)],scope='Only actually retained checkpoint dates; no daily-profile or energy-equivalence claim')
 return output

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['preflight','package','verify']);p.add_argument('--spec',type=Path,default=SPEC);p.add_argument('--workspace',type=Path,default=ROOT.parent);p.add_argument('--capsule',type=Path);p.add_argument('--manifest',type=Path);p.add_argument('--output',type=Path);a=p.parse_args()
 if a.action=='preflight':result=dict(pending=preflight(read_json(a.spec),a.workspace.resolve()),archive_written=False)
 elif a.action=='package':result=package(a.spec,a.workspace,a.capsule,a.manifest)
 else:result=verify(*output_paths(read_json(a.spec),a.capsule,a.manifest))
 if a.output:a.output.write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({k:v for k,v in result.items()if k not in ['B0_harvest_at_checkpoints','B1_harvest_at_checkpoints','nodal_profiles']},indent=2))
