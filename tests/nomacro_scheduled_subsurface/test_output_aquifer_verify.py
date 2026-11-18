"""Actual immutable producer and source/scope corruption tests."""
import copy
import importlib.util
import io
import json
from pathlib import Path
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('output_aquifer_owner',Path(__file__).with_name('output_aquifer_verify.py'));owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)

class Proof(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.q=json.loads((ROOT/owner.PROOF/'OUTPUT_AQUIFER_QUALIFICATION.json').read_text())

    def test_actual_scope_and_source(self):
        owner.validate(self.q);refused=0
        for group in ('scope','source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):
            for key,value in self.q[group].items():
                bad=copy.deepcopy(self.q);bad[group][key]=(not value) if isinstance(value,bool) else value+1 if isinstance(value,(int,float)) else value+['FOREIGN'] if isinstance(value,list) else value+'-FOREIGN'
                with self.assertRaises(ValueError,msg=group+'/'+key):owner.validate(bad)
                refused+=1
        for key in ('runtime','functional_completion','whole_scientific_equivalence','release_readiness','water_guard_cm','chemical_mass_guard_mg_cm2','native_codec','native_domain_bytes','conserved_cde_prefix_offset_bytes'):
            bad=copy.deepcopy(self.q);v=bad[key];bad[key]=v+1 if isinstance(v,(int,float)) else v+'-FOREIGN'
            with self.assertRaises(ValueError,msg=key):owner.validate(bad)
            refused+=1
        print('ACTUAL_AQUIFER_SOURCE_SCOPE_GUARD_REFUSALS',refused,flush=True)

    def test_actual_period_claims(self):
        import sys,hashlib
        sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'));from output_aquifer_ci import CASES
        refused=0
        for platform,opts in self.q['main'].items():
            for opt,location in opts.items():
                with zipfile.ZipFile(io.BytesIO(owner.raw_archive(self.q['archives'][location['archive']]))) as z:
                    run=json.loads(z.read(location['prefix']+'RESULT.json'))
                    for key,case in CASES.items():
                        sp=location['prefix']+'short-'+key+'/'
                        if platform=='Windows' and key=='box-csv3':sp='output-aquifer-receipt-refined-'+opt+'-v2/'
                        raw=z.read(sp+'build/BUILD.json');build=json.loads(raw);digest=hashlib.sha256(raw).hexdigest()
                        for phase in ('short','full'):
                            if phase not in run['cases'][key]:continue
                            actual=run['cases'][key][phase];owner.period(actual,case,opt,phase,build,digest)
                            for path,value in [(('status',),'FOREIGN'),(('trajectory','days'),1),(('trajectory','build_sha256'),'FOREIGN'),(('own',0,'exact_physical'),False),(('native_domains','2','bytes'),57),(('maximum_residuals','soil_aquifer_residual_mg_cm2'),1e-9),(('output','native_codec'),'FOREIGN')]:
                                bad=copy.deepcopy(actual);p=bad
                                for part in path[:-1]:p=p[part]
                                p[path[-1]]=value
                                with self.assertRaises(ValueError,msg=str((platform,opt,key,phase,path))):owner.period(bad,case,opt,phase,build,digest)
                                refused+=1
        self.assertEqual(refused,868);print('ACTUAL_AQUIFER_PERIOD_PRODUCER_CORRUPTIONS_REFUSED',refused,flush=True)

    def test_actual_archive_part_offset(self):
        for record in self.q['archives'].values():
            if 'byte_parts' not in record:continue
            bad=copy.deepcopy(record);bad['byte_parts'][0]['offset']=1
            with self.assertRaises(ValueError):owner.raw_archive(bad)

if __name__=='__main__':unittest.main()
