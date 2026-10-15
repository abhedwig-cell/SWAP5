"""Negative controls for exact eligibility and real surface evidence."""
import copy,json,unittest
import verify_surface_successor as v
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
