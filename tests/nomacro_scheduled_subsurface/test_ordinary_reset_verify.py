"""Corrupt actual ordinary source/native/ledger/Darcy producer evidence."""
import copy,importlib.util,io,json,struct,sys,unittest,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('owner',Path(__file__).with_name('ordinary_reset_verify.py'));owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)

class Proof(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.q=json.loads((ROOT/owner.PROOF/'ORDINARY_RESET_QUALIFICATION.json').read_text(encoding='utf8'))

    def test_actual_source_scope(self):
        owner.validate(self.q);count=0
        for group in ('scope','source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):
            values=list(self.q[group].items())
            if group.startswith('frozen'):values=values[:1]
            for key,value in values:
                bad=copy.deepcopy(self.q);bad[group][key]=(not value) if type(value) is bool else value+1 if type(value) in (int,float) else value+['FOREIGN'] if isinstance(value,list) else value+'-FOREIGN'
                with self.assertRaises(ValueError):owner.validate(bad)
                count+=1
        for key in ('runtime','functional_completion','whole_scientific_equivalence','release_readiness','water_guard_cm','chemical_mass_guard_mg_cm2','native_codecs','process_domain_bytes'):
            bad=copy.deepcopy(self.q);value=bad[key];bad[key]=value+1 if type(value) in (int,float) else value+['FOREIGN'] if isinstance(value,list) else value+'-FOREIGN'
            with self.assertRaises(ValueError):owner.validate(bad)
            count+=1
        print('ACTUAL_ORDINARY_SOURCE_SCOPE_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_period_build_ledger_native(self):
        sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'));from ordinary_reset_ci import CASES
        count=0
        for platform,opts in self.q['main'].items():
            for opt,location in opts.items():
                with zipfile.ZipFile(io.BytesIO(owner.raw_archive(self.q['archives'][location['archive']]))) as z:
                    run=json.loads(z.read(location['prefix']+'RESULT.json'))
                    def path(value):
                        if platform=='Windows':return owner.PureWindowsPath(value).relative_to(owner.PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')).as_posix()+'/'
                        base=owner.PurePosixPath(run['cases']['explicit-hys0-binary']['short_root']).parent
                        return str(owner.PurePosixPath(value).relative_to(base))+'/'
                    for key,case in CASES.items():
                        item=run['cases'][key];bp=path(item['build_root']);raw=z.read(bp+'BUILD.json');build=json.loads(raw);digest=owner.digest(raw);owner.build_files(z,bp,build)
                        for group,name in [('executable_sha256','donor'),('executable_sha256','kernel')]:
                            bad=copy.deepcopy(build);bad[group][name]='0'*64
                            with self.assertRaises(ValueError):owner.build_files(z,bp,bad)
                            count+=1
                        bad=copy.deepcopy(build);name=next(iter(bad['identity']['donor_generated']));bad['identity']['donor_generated'][name]='0'*64;bad['binding']['build']=copy.deepcopy(bad['identity'])
                        with self.assertRaises(ValueError):owner.build_files(z,bp,bad)
                        count+=1
                        for phase in ('short','full'):
                            if phase not in item:continue
                            report=item[phase];owner.period(report,case,opt,phase,build,digest)
                            for parts,value in [(('status',),'FOREIGN'),(('mode',),'FOREIGN'),(('hysteresis',),3),(('optimization',),'FOREIGN'),(('nprintday',),1441),(('trajectory','days'),1),(('trajectory','build_sha256'),'FOREIGN'),(('cold',0,'exact_physical'),False),(('cold',0,'exact_complete_native'),False),(('cold',0,'origin_unchanged'),False)]:
                                bad=copy.deepcopy(report);target=bad
                                for part in parts[:-1]:target=target[part]
                                target[parts[-1]]=value
                                with self.assertRaises(ValueError):owner.period(bad,case,opt,phase,build,digest)
                                count+=1
                        prefix=path(item['short_root']);rows=[json.loads(line) for line in z.read(prefix+'trajectory/daily.jsonl').splitlines()];owner.ledger(rows,35)
                        for field,index in [('stock_end_cm',0),('stock_end_cm',2),('external_flux_cm',6),('external_flux_cm',12)]:
                            bad=copy.deepcopy(rows[0]);bad[field][index]+=1.
                            with self.assertRaises(ValueError):owner.ledger([bad],1)
                            count+=1
                        with zipfile.ZipFile(io.BytesIO(z.read(prefix+'trajectory/accepted-column-1-day-4.zip'))) as checkpoint:raw=checkpoint.read('macro.bin')
                        n=build['project']['nodes'];selected=build['identity']['original_output'];owner.native(raw,rows[3],n,case[1],selected);pos,header,nreal=owner.calendar(raw,n)
                        def refused(bad):
                            nonlocal count
                            with self.assertRaises(ValueError):owner.native(bad,rows[3],n,case[1],selected)
                            count+=1
                        for index,value in [(0,2),(1,n+1),(3,nreal+1),(4,0),(5,2),(6,5),(7,header[7]+1),(8,2),(9,0),(10,0),(11,0),(12,2),(18,0),(19,0)]:
                            bad=bytearray(raw)
                            for offset in (0,80):struct.pack_into('<i',bad,pos+offset+4*index,value)
                            refused(bad)
                        for index,value in [(0,float('nan')),(nreal-1,-1.)]:
                            bad=bytearray(raw)
                            for offset in (0,8*nreal):struct.pack_into('<d',bad,pos+160+offset+8*index,value)
                            refused(bad)
                        bad=bytearray(raw);struct.pack_into('<d',bad,pos+160,123.);refused(bad)
                        refused(raw[:-1]);refused(raw+b'x');refused(b'S5SRW001'+raw[8:]);refused((b'S5ORW001' if case[1] else b'S5ORH001')+raw[8:])
                        if case[1]:
                            domain=struct.pack('<5i',1,n,0,case[1],0);d=raw.index(domain+domain)
                            for index in range(5):
                                bad=bytearray(raw);value=struct.unpack_from('<i',bad,d+4*index)[0]+1
                                for offset in (0,20):struct.pack_into('<i',bad,d+offset+4*index,value)
                                refused(bad)
        print('ACTUAL_ORDINARY_PERIOD_BINARY_LEDGER_NATIVE_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_trial_witness_and_original_output_inventory(self):
        count=0;observed=0
        for platform,opts in self.q['main'].items():
            for opt,location in opts.items():
                with zipfile.ZipFile(io.BytesIO(owner.raw_archive(self.q['archives'][location['archive']]))) as z:
                    run=json.loads(z.read(location['prefix']+'RESULT.json'))
                    for item in run['cases'].values():
                        for phase in ('short','full'):
                            if phase not in item:continue
                            for table in item[phase]['user_output'].values():
                                days=1096 if phase=='full' else 35;stamps=table['stamps'];owner.output_clock(table,stamps,days,'2002-01-01')
                                bads=[];bad=copy.deepcopy(table);bad['records']+=1;bads.append(bad);bad=copy.deepcopy(table);bad['stamps']=bad['stamps'][:-1];bads.append(bad);bad=copy.deepcopy(table);bad['stamps'][0]='2002-01-01 01:00:00';bads.append(bad)
                                for bad in bads:
                                    with self.assertRaises(ValueError):owner.output_clock(bad,stamps,days,'2002-01-01')
                                    count+=1
                        values=item['trial_phase_witness']['actual_rows']
                        if not values:continue
                        observed+=1;row=values[0]
                        def archive(values):
                            stream=io.BytesIO()
                            with zipfile.ZipFile(stream,'w') as target:target.writestr('original/donor.stdout','ORDINARY_STALE_BOTTOM_TRIAL_WITNESS '+' '.join(map(repr,values))+'\n')
                            return zipfile.ZipFile(io.BytesIO(stream.getvalue()))
                        with archive(row) as actual:owner.trial_witness(actual,'',37256.)
                        for index in range(6):
                            bad=list(row);bad[index]+=2 if index==0 else 1
                            with archive(bad) as actual,self.assertRaises(ValueError):owner.trial_witness(actual,'',37256.)
                            count+=1
                            bad=list(row);bad[index]=float('nan')
                            with archive(bad) as actual,self.assertRaises(ValueError):owner.trial_witness(actual,'',37256.)
                            count+=1
                        with archive(row) as actual:
                            report=owner.trial_witness(actual,'',37256.)
                            for key in ('actual_trial_count','old_stale_max_cm','independent_darcy_max_cm'):
                                bad=copy.deepcopy(report);bad[key]+=1
                                with self.assertRaises(ValueError):owner.trial_witness(actual,'',37256.,bad)
                                count+=1
        self.assertGreaterEqual(observed,4)
        print('ACTUAL_ORDINARY_DARCY_PHASE_AND_OUTPUT_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_non_january_native_counter(self):
        count=0
        for location in self.q['epochs']:
            with zipfile.ZipFile(io.BytesIO(owner.raw_archive(self.q['archives'][location['archive']]))) as z:
                ep=location['prefix'];run=json.loads(z.read(ep+'RESULT.json'))
                for epoch,item in run['cases'].items():
                    prefix=ep+epoch+'/actual/';build=json.loads(z.read(prefix+'build/BUILD.json'));n=build['project']['nodes'];selected=build['identity']['original_output'];rows=[json.loads(line) for line in z.read(prefix+'trajectory/daily.jsonl').splitlines()]
                    with zipfile.ZipFile(io.BytesIO(z.read(prefix+'trajectory/accepted-column-1-day-30.zip'))) as checkpoint:raw=checkpoint.read('macro.bin')
                    owner.native(raw,rows[29],n,2,selected,epoch);pos,header,_=owner.calendar(raw,n);self.assertNotEqual(header[7],30)
                    for index,value in [(7,30),(7,header[7]+365),(7,header[7]+1),(7,0),(11,0),(18,0),(19,0),(4,0),(6,31)]:
                        bad=bytearray(raw)
                        for offset in (0,80):struct.pack_into('<i',bad,pos+offset+4*index,value)
                        with self.assertRaises(ValueError):owner.native(bad,rows[29],n,2,selected,epoch)
                        count+=1
                    with self.assertRaises(ValueError):owner.native(raw,rows[29],n,2,selected,'2002-01-01')
                    count+=1
        self.assertEqual(count,80);print('ACTUAL_ORDINARY_ANNUAL_COUNTER_EPOCH_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_raw_artifact_and_prior_parts(self):
        count=0
        for record in self.q['archives'].values():
            for key,value in [('bytes',record['bytes']+1),('sha256','0'*64)]:
                bad=copy.deepcopy(record);bad[key]=value
                with self.assertRaises(ValueError):owner.raw_archive(bad)
                count+=1
            if 'origin_artifact' in record:
                bad=copy.deepcopy(record);bad['origin_artifact']['digest']='sha256:'+'0'*64
                with self.assertRaises(ValueError):owner.raw_archive(bad)
                count+=1
            if 'byte_parts' in record:
                bad=copy.deepcopy(record);bad['byte_parts'][0]['offset']=1
                with self.assertRaises(ValueError):owner.raw_archive(bad)
                count+=1
        prior=json.loads((ROOT/owner.PROOF/'GROUNDWATER_HISTORY_QUALIFICATION.json').read_text(encoding='utf8'))
        for record in prior['archives'].values():
            if 'byte_parts' not in record:continue
            bad=copy.deepcopy(record);bad['byte_parts'][0]['offset']=1
            with self.assertRaises(ValueError):owner.raw_archive(bad)
            count+=1
        self.assertEqual(count,22);print('ACTUAL_ORDINARY_RAW_ARTIFACT_PART_CORRUPTIONS_REFUSED',count,flush=True)

if __name__=='__main__':unittest.main()
