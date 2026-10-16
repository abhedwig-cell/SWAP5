"""Negative controls for exact eligibility and real surface evidence."""
import copy,json,unittest
import verify_surface_successor as v
if (v.ROOT/'tests/nut-sol/verify_pond_successor.py').exists():
 import subprocess,sys
 subprocess.run([sys.executable,'-B',str(v.ROOT/'tests/nut-sol/check_pond_controls.py')],check=True);raise SystemExit(0)
if (v.ROOT/'docs/science/MC_SOL01_SURFACE_MASS_RESTART_CONTRACT_20261016.md').exists():
 from pathlib import Path
 import importlib,sys
 from unittest.mock import patch
 passed=[]
 def reject(label,fn):
  try:fn()
  except (ValueError,KeyError,AssertionError,IndexError,FileNotFoundError):passed.append(label);return
  raise AssertionError('accepted persistent '+label)
 positive=v.persistent_qualification();assert positive['qualified']and not positive['admitted']
 original=v.git
 for label in ['foreign_src','foreign_test','foreign_workflow','dirty','source_tree','reference','postimage']:
  def reader(*a,label=label):
   value=original(*a)
   if label.startswith('foreign_')and a[:2]==('diff','--name-status'):
    return value+'\nA\t'+{'foreign_src':'src/unknown.f90','foreign_test':'tests/unknown.py','foreign_workflow':'.github/workflows/unknown.yml'}[label]
   if label=='dirty'and a[:2]==('status','--porcelain'):return ' M src/unknown.f90'
   if label=='source_tree'and a==('rev-parse','HEAD:src'):return '0'*40
   if label=='reference'and a==('rev-parse','HEAD:reference'):return '0'*40
   if label=='postimage'and a==('rev-parse','HEAD:src/adapter/mod_matrix_joint_restart_file.f90'):return '0'*40
   return value
  reject(label,lambda:v.persistent_source(reader))
 for path in v.PERSISTENT_PRODUCTION:
  r=copy.deepcopy(v.persistent_record());r['postimages'][path]['blob']='0'*40
  with patch.object(v,'persistent_record',return_value=r):reject('stale_'+Path(path).stem,v.persistent_source)
 r=copy.deepcopy(v.persistent_record());r['science_archive']['decoded_sha256']='0'*64
 with patch.object(v,'persistent_record',return_value=r):reject('corrupt_capsule',v.persistent_evidence)
 r=copy.deepcopy(v.persistent_record());r['phase']='IMPLEMENTED'
 with patch.object(v,'persistent_record',return_value=r):reject('unfinished_phase',v.persistent_qualification)
 data=v.persistent_evidence()
 for label,mutate in [
  ('unfinished_science',lambda r:r.update(status='RUNNING')),
  ('wrong_execution',lambda r:r.update(baseline='0'*40)),
  ('wrong_authority',lambda r:r.update(authority_sha256='0'*64)),
  ('stale_input',lambda r:r['input_sha256'].update({'src/adapter/mod_matrix_joint_restart_file.f90':'0'*64})),
  ('missing_decoder',lambda r:r['runs']['O0']['surface_restart']['crc_correct_negatives'].pop()),
  ('forged_endpoint',lambda r:r['runs']['O2']['surface_restart'].update(endpoint_sha256='0'*64)),
  ('missing_incumbent_negative',lambda r:r['runs']['O0']['restart_negatives'].pop())]:
  d=copy.deepcopy(data);r=json.loads(d['stable/result.json']);mutate(r);d['stable/result.json']=json.dumps(r).encode()
  reject(label,lambda d=d:v.persistent_science(d))
 for label,mutate in [
  ('failed_command',lambda r:r[0].update(returncode=1)),
  ('missing_driver_compile',lambda r:r.pop(next(i for i,e in enumerate(r)if e['category']=='restart_compile'))),
  ('missing_native',lambda r:r.pop(next(i for i,e in enumerate(r)if e['category']=='restart_native'))),
  ('missing_traps',lambda r:next(e for e in r if '-c'in e['command'])['command'].remove('-ffpe-trap=invalid,zero,overflow'))]:
  d=copy.deepcopy(data);r=json.loads(d['stable/events.json']);mutate(r);d['stable/events.json']=json.dumps(r).encode()
  reject(label,lambda d=d:v.persistent_science(d))
 for label,path in [('missing_raw','stable/0000.stderr'),('unexecuted_driver','stable/O0/surface_restart.f90'),('wrong_native','stable/O2/surface-v2.bin')]:
  d=copy.deepcopy(data)
  if label=='missing_raw':d.pop(path)
  else:d[path]+=b'x'
  reject(label,lambda d=d:v.persistent_science(d))
 d=copy.deepcopy(data);r=json.loads(d['review/default_projections.json']);r.pop(next(iter(r)));d['review/default_projections.json']=json.dumps(r).encode()
 reject('missing_incumbent_body_review',lambda:v.persistent_science(d))
 for folder,name in [('tests/mc-irr01','verify_material_root_successor'),('tests/nut-crop','verify_b111_request_successor'),
  ('tests/root-growth','verify_daily_density_successor'),('tests/fpm','verify_int12c_successor')]:
  sys.path.insert(0,str(v.ROOT/folder));module=importlib.import_module(name)
  assert module.verify_source()['persistent_surface_restart_successor'],name
 print('PERSISTENT_SURFACE_ADMISSION_CONTROLS='+str(len(passed))+'|PASS')
 raise SystemExit(0)
if v.composition() is not None:
 import subprocess,sys
 from pathlib import Path
 from unittest.mock import patch
 root=v.ROOT.parent/'surface-original'
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),v.ORIGINAL_FINAL],cwd=v.ROOT,check=True,capture_output=True)
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==v.ORIGINAL_FINAL
 old=subprocess.run([sys.executable,'-B','tests/nut-sol/check_surface_evidence_controls.py'],cwd=root,capture_output=True,text=True)
 assert old.returncode==0 and 'Ran 24 tests'in old.stderr,old.stderr
 source=v.verify_qualification();assert source['qualified']and source['surface_successor']
 passed=[]
 def reject(label,fn):
  try:fn()
  except (ValueError,KeyError,AssertionError,IndexError):passed.append(label);return
  raise AssertionError('accepted '+label)
 for mode in ['foreign_src','foreign_test','source_blob','source_tree','reference','dirty']:
  def reader(*a):
   value=v.git(*a)
   if mode.startswith('foreign_')and a[:2]==('diff','--name-status'):return value+'\nA\t'+('src/foreign.f90'if mode=='foreign_src'else'tests/foreign.py')
   if mode=='source_blob'and a==('rev-parse','HEAD:src/process/mod_b111_surface_supply.f90'):return'0'*40
   if mode=='source_tree'and a==('rev-parse','HEAD:src'):return'0'*40
   if mode=='reference'and a==('rev-parse','HEAD:reference'):return'0'*40
   if mode=='dirty'and a[:2]==('status','--porcelain'):return'M src/foreign.f90'
   return value
  reject(mode,lambda:v.verify_source(reader))
 data=v.current_evidence();execution=v.composition()['execution_commit']
 for label,mutation in [('unfinished',lambda r:r.update(status='RUNNING')),('wrong_source',lambda r:r.update(baseline='0'*40)),('wrong_authority',lambda r:r.update(authority_sha256='0'*64)),('stale_input',lambda r:r['input_sha256'].update({'src/process/mod_b111_surface_supply.f90':'0'*64})),('lost_negative',lambda r:r['runs']['O0']['restart_negatives'].pop()),('forged_endpoint',lambda r:r['runs']['O2'].update(endpoint_sha256='0'*64))]:
  altered=data.copy();r=json.loads(altered['stable/result.json']);mutation(r);altered['stable/result.json']=json.dumps(r).encode();reject(label,lambda:v.validate_evidence(altered,execution))
 altered=data.copy();e=json.loads(altered['stable/events.json']);e[0]['returncode']=1;altered['stable/events.json']=json.dumps(e).encode();reject('failed_actual_command',lambda:v.validate_evidence(altered,execution))
 for directory,name in [('root-growth','verify_swrd2_successor'),('root-growth','verify_swrd3_successor'),('nut-calendar','verify_calendar_successor'),('nut-senescence','verify_senescence_successor'),('crop-co2','verify_co2_successor'),('nut-input','verify_input_successor'),('nut-thermal','verify_thermal_successor'),('crop-harvest','verify_harvest_successor')]:
  sys.path.insert(0,str(v.ROOT/'tests'/directory));module=__import__(name);route=module.verify_qualification
  result=route();assert result['qualified']and result['surface_successor']and result['harvest_successor'];passed.append(name+':positive')
  for label,target in [('new_science','current_evidence'),('admitted_owner','incumbent_qualification'),('current_source','verify_source')]:
   with patch.object(v,target,side_effect=ValueError(label)):reject(name+':'+label,route)
 capsule=v.ROOT/v.composition()['evidence']['path'];read=Path.read_bytes
 with patch.object(Path,'read_bytes',lambda self:bytes([read(self)[0]^1])+read(self)[1:]if self==capsule else read(self)):
  reject('current_capsule_corruption',v.current_evidence)
 print(json.dumps(dict(status='PASS',original_controls=24,current_controls=len(passed),controls=passed),indent=2));raise SystemExit(0)

class Controls(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.data=v.read_evidence();cls.s=json.loads((v.ROOT/v.STATUS).read_text())
 def mutation(self,path,change):
  d=dict(self.data);r=json.loads(d[path]);change(r);d[path]=json.dumps(r).encode()
  with self.assertRaises((ValueError,KeyError,IndexError)):v.validate_evidence(d)
 def test_positive(self):v.validate_evidence(self.data)
 def test_unfinished(self):self.mutation('stable/result.json',lambda r:r.__setitem__('status','FAILED'))
 def test_wrong_authority(self):self.mutation('stable/result.json',lambda r:r.__setitem__('authority_sha256','0'*64))
 def test_wrong_execution(self):self.mutation('stable/result.json',lambda r:r.__setitem__('baseline','0'*40))
 def test_wrong_literal(self):self.mutation('stable/result.json',lambda r:r.__setitem__('literal_lines',[361,455]))
 def test_stale_input(self):self.mutation('stable/result.json',lambda r:r['input_sha256'].__setitem__('src/process/mod_b111_surface_supply.f90','0'*64))
 def test_missing_production(self):self.mutation('stable/result.json',lambda r:r['input_sha256'].pop('src/runtime/mod_fmr_b111_surface_solute_route.f90'))
 def test_no_process(self):self.mutation('stable/result.json',lambda r:r['runs']['O0'].__setitem__('process_stdout',''))
 def test_one_actual_direction(self):self.mutation('stable/result.json',lambda r:r['runs']['O0'].__setitem__('physical_stdout','SURFACE_JOINT_ATOMIC_BALANCE_LITERAL_RESTART=PASS'))
 def test_missing_compile(self):self.mutation('stable/events.json',lambda r:r.pop(next(i for i,e in enumerate(r) if e['category']=='physical_compile')))
 def test_missing_flag(self):self.mutation('stable/events.json',lambda r:next(e for e in r if e['category']=='physical_compile')['command'].remove('-fcheck=all'))
 def test_failed_event(self):self.mutation('stable/events.json',lambda r:r[-1].__setitem__('returncode',1))
 def test_missing_native(self):self.mutation('stable/events.json',lambda r:r.pop())
 def test_decoder_coverage(self):self.mutation('stable/result.json',lambda r:r['runs']['O0']['restart_negatives'].pop())
 def test_forged_endpoint(self):self.mutation('stable/result.json',lambda r:r['runs']['O0'].__setitem__('endpoint_sha256','0'*64))
 def test_raw_assertion(self):
  d=dict(self.data);events=json.loads(d['stable/events.json']);e=next(e for e in events if e['category']=='physical_native');d['stable/'+e['stdout']]=b'forged'
  with self.assertRaises(ValueError):v.validate_evidence(d)
 def test_restart_bytes(self):
  d=dict(self.data);d['stable/O0/fresh.bin']=b'forged'
  with self.assertRaises(ValueError):v.validate_evidence(d)
 def test_preimage_acceptance_witness(self):self.mutation('preimage/RESULT.json',lambda r:r['events'][-1].__setitem__('exit',0))
 def test_preimage_different_driver(self):self.mutation('preimage/RESULT.json',lambda r:r.__setitem__('final_driver_sha256','0'*64))
 def delta(self,change):
  rows={p:'A' for p in self.s['added_blobs']};rows.update({p:'M' for p in v.GUARDS});tree={**self.s['added_blobs'],**self.s['guard_blobs']}
  change(rows,tree)
  with self.assertRaises(ValueError):v.validate_delta(rows,tree,self.s)
 def test_foreign_source(self):self.delta(lambda r,t:r.__setitem__('src/foreign.f90','A'))
 def test_foreign_tool(self):self.delta(lambda r,t:r.__setitem__('tools/foreign.py','A'))
 def test_missing_delta(self):self.delta(lambda r,t:r.pop('src/runtime/mod_fmr_b111_surface_solute_route.f90'))
 def test_wrong_postimage(self):self.delta(lambda r,t:t.__setitem__('src/runtime/mod_fmr_b111_surface_solute_route.f90','0'*40))
 def test_wrong_guard(self):self.delta(lambda r,t:t.__setitem__('tests/crop-co2/verify_co2_successor.py','0'*40))
if __name__=='__main__':unittest.main()
