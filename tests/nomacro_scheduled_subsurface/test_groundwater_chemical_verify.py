"""Actual immutable groundwater producer, source, native and ledger corruptions."""
import copy
import importlib.util
import io
import json
from pathlib import Path
import struct
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('groundwater_owner',Path(__file__).with_name('groundwater_chemical_verify.py'))
owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)


class Proof(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.q=json.loads((ROOT/owner.PROOF/'GROUNDWATER_CHEMICAL_QUALIFICATION.json').read_text(encoding='utf8'))

    def test_actual_source_scope(self):
        owner.validate(self.q);refused=0
        for group in ('scope','source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):
            values=list(self.q[group].items())
            if group.startswith('frozen'):values=values[:1]
            for key,value in values:
                bad=copy.deepcopy(self.q)
                bad[group][key]=(not value) if type(value) is bool else value+1 if type(value) in (int,float) else value+['FOREIGN'] if isinstance(value,list) else value+'-FOREIGN'
                with self.assertRaises(ValueError,msg=group+'/'+key):owner.validate(bad)
                refused+=1
        for key in ('runtime','functional_completion','whole_scientific_equivalence','release_readiness','water_guard_cm','chemical_mass_guard_mg_cm2','native_codecs','native_domain_bytes','conserved_cde_prefix_offset_bytes'):
            bad=copy.deepcopy(self.q);value=bad[key]
            bad[key]=value+1 if type(value) in (int,float) else value+['FOREIGN'] if isinstance(value,list) else value+'-FOREIGN'
            with self.assertRaises(ValueError,msg=key):owner.validate(bad)
            refused+=1
        print('ACTUAL_GROUNDWATER_SOURCE_SCOPE_REFUSALS',refused,flush=True)

    def test_actual_period_ledger_native(self):
        import sys
        sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
        from groundwater_chemical_ci import CASES
        refused=0
        for platform,opts in self.q['main'].items():
            for opt,location in opts.items():
                with zipfile.ZipFile(io.BytesIO(owner.raw_archive(self.q['archives'][location['archive']]))) as z:
                    run=json.loads(z.read(location['prefix']+'RESULT.json'))
                    def path(value):
                        if platform=='Windows':return owner.PureWindowsPath(value).relative_to(owner.PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')).as_posix()+'/'
                        base=owner.PurePosixPath(run['cases']['within-csv3']['short_root']).parent
                        return str(owner.PurePosixPath(value).relative_to(base))+'/'
                    for key,case in CASES.items():
                        item=run['cases'][key];raw=z.read(path(item['build_root'])+'BUILD.json');build=json.loads(raw);digest=owner.digest(raw)
                        for phase in ('short','full'):
                            if phase not in item:continue
                            report=item[phase];owner.period(report,case[0],opt,phase,build,digest)
                            for parts,value in [(('status',),'FOREIGN'),(('optimization',),'FOREIGN'),(('kind',),'FOREIGN'),(('trajectory','days'),1),
                                                (('trajectory','build_sha256'),'FOREIGN'),(('cold',0,'exact_physical'),False),
                                                (('cold',0,'exact_complete_native'),False),(('cold',0,'origin_unchanged'),False)]:
                                bad=copy.deepcopy(report);target=bad
                                for part in parts[:-1]:target=target[part]
                                target[parts[-1]]=value
                                with self.assertRaises(ValueError,msg=str((platform,opt,key,phase,parts))):owner.period(bad,case[0],opt,phase,build,digest)
                                refused+=1
                        prefix=path(item['short_root']);rows=[json.loads(line) for line in z.read(prefix+'trajectory/daily.jsonl').splitlines()]
                        owner.ledger(rows,10)
                        for field,index in [('stock_end_cm',0),('external_flux_cm',6),('solute_ledger_mg_cm2',0),('solute_ledger_mg_cm2',3)]:
                            row=copy.deepcopy(rows[0]);row[field][index]+=1.
                            with self.assertRaises(ValueError,msg=field):owner.ledger([row],1)
                            refused+=1
                        with zipfile.ZipFile(io.BytesIO(z.read(prefix+'trajectory/accepted-column-1-day-4.zip'))) as checkpoint:
                            native=checkpoint.read('macro.bin');n=build['project']['nodes'];codec=build['identity']['groundwater_native_state']['magic']
                            owner.native(native,rows[3],n,codec)
                            header=struct.pack('<9i',1,n,0,1,1,0,0,0,1);offset=native.index(header+header)+72
                            for label,pos,value in [('head',offset,123.),('water',offset+8*n,-1.),('level',offset+8*(5*n+2),123.),
                                                    ('volume',offset+8*(5*n+3),123.),('cde',48+8*(n+1),123.),('nonfinite',offset,float('nan'))]:
                                bad=bytearray(native);struct.pack_into('<d',bad,pos,value)
                                with self.assertRaises(ValueError,msg=label):owner.native(bad,rows[3],n,codec)
                                refused+=1
        self.assertEqual(refused,800)
        print('ACTUAL_GROUNDWATER_PERIOD_LEDGER_NATIVE_CORRUPTIONS_REFUSED',refused,flush=True)

    def test_actual_part_offsets(self):
        count=0
        for record in self.q['archives'].values():
            if 'byte_parts' not in record:continue
            bad=copy.deepcopy(record);bad['byte_parts'][0]['offset']=1
            with self.assertRaises(ValueError):owner.raw_archive(bad)
            count+=1
        self.assertGreater(count,0)


if __name__=='__main__':unittest.main()
