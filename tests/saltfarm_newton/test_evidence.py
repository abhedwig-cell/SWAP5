"""Corrupt actual complete records, not copied model formulas."""
from pathlib import Path
import importlib.util,io,json,unittest,zipfile
p=Path(__file__).with_name('verify_successor.py');spec=importlib.util.spec_from_file_location('newton',p);owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)

class Changed:
    def __init__(self,z,edits):self.z,self.edits=z,edits
    def read(self,path):return self.edits.get(path,self.z.read(path))

class ActualRecords(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.z=zipfile.ZipFile(owner.ROOT/owner.PROOF/'WINDOWS_CURRENT.zip')
    @classmethod
    def tearDownClass(cls):cls.z.close()
    def refuse(self,edits):
        with self.assertRaises((ValueError,AssertionError)):owner.audit(Changed(self.z,edits),'Windows')
    def test_foreign_runtime_and_optimization(self):
        p='accept-O0/RESULT.json';v=json.loads(self.z.read(p));v['source_commit']='FOREIGN';self.refuse({p:json.dumps(v).encode()})
        p='qualified-O0/BUILD.json';v=json.loads(self.z.read(p));v['identity']['donor_flags'][0]='-O2';raw=json.dumps(v).encode();r=json.loads(self.z.read('accept-O0/RESULT.json'));r['build_sha256']=owner.digest(raw);self.refuse({p:raw,'accept-O0/RESULT.json':json.dumps(r).encode()})
    def test_actual_daily_balance_and_missing_day(self):
        p='accept-O0/full/daily.jsonl';rows=[json.loads(s) for s in self.z.read(p).splitlines()]
        for bad in (1.0001e-10,float('nan')):
            rows[0]['independent_residual_cm']=bad;self.refuse({p:'\n'.join(map(json.dumps,rows)).encode()})
        self.refuse({p:b'\n'.join(self.z.read(p).splitlines()[:-1])})
    def test_actual_cold_state_and_csv(self):
        p='accept-O0/restart109-111/daily.jsonl';rows=[json.loads(s) for s in self.z.read(p).splitlines()];rows[0]['pressure_head_cm'][0]+=1e-4;self.refuse({p:'\n'.join(map(json.dumps,rows)).encode()})
        p='accept-O0/restart109-111/original/result_output.csv';self.refuse({p:self.z.read(p)+b'FOREIGN\n'})
    def test_actual_flow_with_unchanged_claimed_residual(self):
        p='accept-O0/full/daily.jsonl';rows=[json.loads(s) for s in self.z.read(p).splitlines()];rows[0]['external_flux_cm'][0]+=1e-4;self.refuse({p:'\n'.join(map(json.dumps,rows)).encode()})
    def test_actual_native_and_instance_payload(self):
        for p in ('accept-O0/restart109-111/accepted-column-1-day-111.zip','transactions/O0/left/accepted-column-1-day-454.zip'):
            with zipfile.ZipFile(io.BytesIO(self.z.read(p))) as q:
                out=io.BytesIO()
                with zipfile.ZipFile(out,'w') as changed:
                    for name in q.namelist():changed.writestr(name,q.read(name)+(b'FOREIGN' if name=='macro.bin' else b''))
            self.refuse({p:out.getvalue()})
    def test_stopping_policy_and_window_omission(self):
        p='qualified-O0/BUILD.json';v=json.loads(self.z.read(p));v['identity']['water_polish_policy']='FOREIGN';raw=json.dumps(v).encode();r=json.loads(self.z.read('accept-O0/RESULT.json'));r['build_sha256']=owner.digest(raw);self.refuse({p:raw,'accept-O0/RESULT.json':json.dumps(r).encode()})
        p='accept-O0/RESULT.json';r=json.loads(self.z.read(p));r['restarts'].pop();self.refuse({p:json.dumps(r).encode()})
if __name__=='__main__':unittest.main()
