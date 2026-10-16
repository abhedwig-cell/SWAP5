"""Reject forged terminal science or drift; do not relax the existing guards."""
import copy,json,unittest
import verify_co2_successor as v
class Controls(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.data,cls.manifest=v.nonlinear_evidence()
 def mutate(self,path,change):
  data=dict(self.data);r=json.loads(data[path]);change(r);data[path]=json.dumps(r).encode()
  with self.assertRaises((ValueError,KeyError)):v.validate_nonlinear_evidence(data,self.manifest)
 def test_positive(self):v.validate_nonlinear_evidence(self.data,self.manifest)
 def test_terminal(self):self.mutate('nonlinear-joint-strengthened-final/result.json',lambda r:r.__setitem__('status','FAILED'))
 def test_no_physical(self):self.mutate('nonlinear-physical-first/result.json',lambda r:r.__setitem__('process_only',True))
 def test_missing_exponent(self):self.mutate('nonlinear-physical-first/result.json',lambda r:r['exponents'].pop())
 def test_missing_native(self):self.mutate('nonlinear-joint-strengthened-final/events.json',lambda r:r.pop())
 def test_failed_native(self):self.mutate('nonlinear-joint-strengthened-final/events.json',lambda r:r[-1].__setitem__('exit',1))
 def test_compile_flags(self):self.mutate('nonlinear-joint-strengthened-final/events.json',lambda r:r[0]['command'].remove('-fcheck=all'))
 def test_wrong_final_source(self):self.mutate('nonlinear-joint-strengthened-final/result.json',lambda r:r['inputs'].__setitem__('tests/nut-sol/test_matrix_joint.f90','0'*64))
 def test_endpoint(self):self.mutate('nonlinear-joint-strengthened-final/result.json',lambda r:r['receipts']['O0']['endpoints'].__setitem__('2','0'*64))
 def test_raw_assertions(self):
  d=dict(self.data);d['nonlinear-joint-strengthened-final/0002.stdout']=b'forged'
  with self.assertRaises(ValueError):v.validate_nonlinear_evidence(d,self.manifest)
 def test_missing_raw(self):
  d=dict(self.data);d.pop('nonlinear-joint-strengthened-final/0002.stderr')
  with self.assertRaises(ValueError):v.validate_nonlinear_evidence(d,self.manifest)
 def test_foreign_delta(self):
  rows={p:'A'for p in v.MATRIX_ADDITIONS};rows[v.GUARD]='M';rows[v.MOVING]='M';rows['src/foreign.f90']='A'
  with self.assertRaises(ValueError):v.validate_matrix_delta(rows,dict(v.MATRIX_ADDITIONS),'guard','moving')
 def test_wrong_postimage(self):
  rows={p:'A'for p in v.MATRIX_ADDITIONS};rows[v.GUARD]='M';rows[v.MOVING]='M'
  tree=dict(v.MATRIX_ADDITIONS);tree[v.GUARD]='guard';tree[v.MOVING]='moving';tree[next(iter(v.MATRIX_ADDITIONS))]='foreign'
  with self.assertRaises(ValueError):v.validate_matrix_delta(rows,tree,'guard','moving')
if __name__=='__main__':unittest.main()
