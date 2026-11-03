"""Real Git mutation controls for the narrowly admitted current successor."""
import hashlib,importlib.util,json,subprocess,tempfile,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('current_gate',Path(__file__).with_name('verify_current_native_admission.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class Boundary(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(prefix='swap5-current-boundary-');self.root=Path(self.temp.name)
  self.previous=m.ROOT;m.ROOT=self.root
  self.git('init','-q');self.git('config','user.name','Fixture');self.git('config','user.email','fixture@example.invalid')
  self.git('config','core.autocrlf','false')
  for path in m.ENDPOINT_PATHS:self.write(path,'original physical owner\n')
  self.write('reference/input','original input\n')
  for path in m.REQUIRED_ASSETS|m.CURRENT_GATES:self.write(path,'unchanged authority\n')
  self.commit();self.base=self.git('rev-parse','HEAD')
  for path in m.ENDPOINT_PATHS:self.write(path,'accepted exact endpoint successor\n')
  self.commit();self.merge=self.git('rev-parse','HEAD')
  self.scope=dict(predecessor=self.base,production_delta={p:dict(before=m.blob(self.base,p),after=m.blob('HEAD',p))for p in m.ENDPOINT_PATHS},
                  predecessor_production_trees={p:m.blob(self.base,p)for p in m.AREAS},canonical_admission=True,
                  physical_correction=True,whole_scientific_admission=False,canonical_merge=self.merge)
  self.write_json(m.SCOPE,self.scope)
  self.write_json(m.ENDPOINT_RECEIPT,dict(merge=self.merge,whole_scientific_admission=False))
  self.write_json(m.ROTATION_RECEIPT,dict(merge=self.merge,whole_scientific_admission=False))
  self.commit()
  self.record=dict(schema=1,baseline=self.git('rev-parse','HEAD'),whole_scientific_admission=False,canonical_merges=[self.merge,self.merge],
   frozen_assets={p:m.blob('HEAD',p)for p in m.REQUIRED_ASSETS},
   current_gate_sha256={p:hashlib.sha256((self.root/p).read_bytes()).hexdigest()for p in m.CURRENT_GATES})
 def tearDown(self):m.ROOT=self.previous;self.temp.cleanup()
 def git(self,*args):return m.git(*args)
 def write(self,p,text):
  path=self.root/p;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text,newline='\n')
 def write_json(self,p,value):self.write(p,json.dumps(value,indent=2)+'\n')
 def commit(self):self.git('add','.');self.git('commit','-qm','fixture')
 def test_exact_accepted_source_boundary(self):m.guard(self.record)
 def test_unknown_committed_production_rejected(self):
  self.write('src/unapproved.f90','unknown physics\n');self.commit()
  with self.assertRaisesRegex(AssertionError,'unreviewed'):m.guard(self.record)
 def test_changed_approved_postimage_rejected(self):
  self.write('src/kernel/mod_kernel_transactions.f90','different kernel\n');self.commit()
  with self.assertRaises(AssertionError):m.guard(self.record)
 def test_dirty_production_rejected(self):
  self.write('app/solute_project/main.f90','dirty application\n')
  with self.assertRaisesRegex(AssertionError,'uncommitted'):m.guard(self.record)
 def test_untracked_production_rejected(self):
  self.write('src/foreign.f90','untracked owner\n')
  with self.assertRaisesRegex(AssertionError,'untracked'):m.guard(self.record)
 def test_old_gate_drift_rejected(self):
  self.write('tests/dataqual15/verify_native_restart_admission.py','weakened old gate\n');self.commit()
  with self.assertRaises(AssertionError):m.guard(self.record)
 def test_current_gate_drift_rejected(self):
  self.write('tests/dataqual15/verify_current_native_admission.py','unbound gate\n')
  with self.assertRaises(AssertionError):m.guard(self.record)
 def test_repinning_changed_old_gate_does_not_rewrite_its_origin(self):
  path='tests/dataqual15/verify_native_restart_admission.py'
  self.write(path,'weakened old gate\n');self.commit();self.record['frozen_assets'][path]=m.blob('HEAD',path)
  with self.assertRaisesRegex(AssertionError,'frozen origin'):m.guard(self.record)
 def test_frozen_authority_drift_rejected(self):
  self.write('integration/dataqual15/STATUS.json','different inventory\n');self.commit()
  with self.assertRaises(AssertionError):m.guard(self.record)
 def test_omitted_authority_refused(self):
  self.record['frozen_assets'].pop(m.ENDPOINT_RECEIPT)
  with self.assertRaisesRegex(AssertionError,'frozen authority'):m.guard(self.record)
 def test_expanded_footprint_refused_even_with_new_pins(self):
  path='src/foreign.f90';self.write(path,'foreign physics\n');self.commit()
  self.scope['production_delta'][path]=dict(before=None,after=m.blob('HEAD',path))
  self.write_json(m.SCOPE,self.scope);self.commit();self.record['frozen_assets'][m.SCOPE]=m.blob('HEAD',m.SCOPE)
  self.record['baseline']=self.git('rev-parse','HEAD')
  with self.assertRaisesRegex(AssertionError,'footprint'):m.guard(self.record)
 def test_nonancestor_receipt_refused_even_with_resealed_metadata(self):
  tree=self.git('rev-parse','HEAD^{tree}')
  foreign=self.git('commit-tree',tree,'-m','unmerged alleged acceptance')
  self.scope['canonical_merge']=foreign;self.write_json(m.SCOPE,self.scope)
  self.write_json(m.ENDPOINT_RECEIPT,dict(merge=foreign,whole_scientific_admission=False));self.commit()
  for p in (m.SCOPE,m.ENDPOINT_RECEIPT):self.record['frozen_assets'][p]=m.blob('HEAD',p)
  self.record['baseline']=self.git('rev-parse','HEAD')
  self.record['canonical_merges'][0]=foreign
  with self.assertRaises(subprocess.CalledProcessError):m.guard(self.record)

if __name__=='__main__':unittest.main(verbosity=2)
