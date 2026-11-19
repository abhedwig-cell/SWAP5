"""Reject actual AGE native/ledger/source/period and original raw corruptions."""
import copy,importlib.util,io,json,struct,sys,unittest,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('owner',Path(__file__).with_name('age_perstep_verify.py'));owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)


class Proof(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.q=json.loads((ROOT/owner.PROOF/'AGE_PERSTEP_QUALIFICATION.json').read_text(encoding='utf8'));sys.path.insert(0,str(Path(__file__).parent))

    def test_actual_source_scope(self):
        owner.validate(self.q);count=0
        for group in ('scope','source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):
            items=list(self.q[group].items());items=items[:1] if group.startswith('frozen') else items
            for key,value in items:
                bad=copy.deepcopy(self.q);bad[group][key]=not value if type(value) is bool else value+1 if type(value) in (int,float) else value+['FOREIGN'] if isinstance(value,list) else value+'-FOREIGN'
                with self.assertRaises(ValueError):owner.validate(bad)
                count+=1
        for key in ('runtime','functional_completion','whole_scientific_equivalence','release_readiness','water_guard_cm','chemical_mass_guard_mg_cm2','age_tolerance','age_units','native_codecs','process_domain_bytes'):
            bad=copy.deepcopy(self.q);v=bad[key];bad[key]=v+1 if type(v) in (int,float) else v+['FOREIGN'] if isinstance(v,list) else v+'-FOREIGN'
            with self.assertRaises(ValueError):owner.validate(bad)
            count+=1
        print('ACTUAL_AGE_PERSTEP_SOURCE_SCOPE_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_original_archive_receipts(self):
        count=0
        for record in self.q['archives'].values():
            for field,value in [('sha256','0'*64),('bytes',record['bytes']+1)]:
                bad=copy.deepcopy(record);bad[field]=value
                with self.assertRaises(ValueError):owner.raw_archive(bad)
                count+=1
            if 'origin_artifact' in record:
                bad=copy.deepcopy(record);bad['origin_artifact']['size_in_bytes']+=1
                with self.assertRaises(ValueError):owner.raw_archive(bad)
                count+=1
        print('ACTUAL_AGE_PERSTEP_ORIGINAL_RAW_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_native_ledger_period_and_worker_observations(self):
        from age_perstep_ci import CASES
        count=0
        for platform,opts in self.q['main'].items():
            for opt,location in opts.items():
                with zipfile.ZipFile(io.BytesIO(owner.raw_archive(self.q['archives'][location['archive']]))) as z:
                    run=owner.read(z,location['prefix']+'RESULT.json')
                    def path(value):return (owner.PureWindowsPath(value).relative_to(owner.PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')) if platform=='Windows' else owner.PurePosixPath(value).relative_to(owner.PurePosixPath(location['producer_root']))).as_posix()+'/'
                    for key,case in CASES.items():
                        item=run['cases'][key];rawbuild=z.read(path(item['build_root'])+'BUILD.json');build=json.loads(rawbuild);n=build['project']['nodes'];selected=build['identity']['original_output'];epoch=build['project']['start_date'];dz=owner.geometry(z.read(path(item['input_root'])+'swap.swp'),n)
                        for phase in ('short','full'):
                            if phase not in item:continue
                            r=item[phase];owner.period(r,case,opt,phase,build,owner.digest(rawbuild))
                            for parts,value in [(('status',),'FOREIGN'),(('parameters','hysteresis'),3),(('parameters','optimization'),'FOREIGN'),(('parameters','nprintday'),1441),(('trajectory','days'),1),(('trajectory','build_sha256'),'FOREIGN'),(('maximum_age_tolerance_fraction',),1.1),(('actual_fixed_input_cm',),2.400001),(('cold',0,'exact_physical'),False),(('cold',0,'exact_complete_native'),False),(('whole_scientific_equivalence',),'QUALIFIED')]:
                                bad=copy.deepcopy(r);target=bad
                                for field in parts[:-1]:target=target[field]
                                target[parts[-1]]=value
                                with self.assertRaises(ValueError):owner.period(bad,case,opt,phase,build,owner.digest(rawbuild))
                                count+=1
                        pp=path(item['short_root']);data=owner.rows(z,pp+'trajectory/');owner.audit(z,pp+'trajectory/',data,epoch)
                        with zipfile.ZipFile(io.BytesIO(z.read(pp+'trajectory/accepted-column-1-day-35.zip'))) as cp:raw=cp.read('macro.bin')
                        row=data[34];owner.native(raw,row,n,selected,epoch,dz);pos,h,nr=owner.calendar(raw,n);ap=pos+160+16*nr
                        def refused(bad):
                            nonlocal count
                            with self.assertRaises((ValueError,struct.error)):owner.native(bad,row,n,selected,epoch,dz)
                            count+=1
                        for index,value in [(0,2),(1,n+1),(2,h[2]+1),(3,nr+1),(4,2),(5,h[5]+1),(6,36),(7,h[7]+1),(8,2),(9,3001),(10,3001),(11,1-h[11]),(12,1-h[12]),(13,1-h[13]),(18,0),(19,0)]:
                            bad=bytearray(raw)
                            for offset in (0,80):struct.pack_into('<i',bad,pos+offset+4*index,value)
                            refused(bad)
                        for offset,value in [(ap,-1.),(ap,float('nan')),(ap+8*n,123.),(ap+16*n,123.),(ap+8*(3*n+3),1.),(ap+8*(3*n+6),1.),(len(raw)-172,-1.),(len(raw)-172,float('nan')),(len(raw)-44,1.),(len(raw)-16,1.)]:
                            bad=bytearray(raw);struct.pack_into('<d',bad,offset,value);refused(bad)
                        for offset in (len(raw)-20,len(raw)-8,len(raw)-4):
                            bad=bytearray(raw);v=struct.unpack_from('<i',bad,offset)[0];struct.pack_into('<i',bad,offset,v+1);refused(bad)
                        for bad in (raw[:-1],raw+b'x',b'S5IOA001'+raw[8:],b'S5APA001'+raw[8:] if selected['swhyst'] else b'S5APH001'+raw[8:]):refused(bad)
                        previous=data[3]['age_state_cm_day'];valid=data[4];owner.ledger([valid],1,previous)
                        for field,size in [('age_ledger_cm_day',8),('external_flux_cm',16),('stock_start_cm',6),('stock_end_cm',6),('age_state_cm_day',11),('age_effluent',24)]:
                            for index in range(size):
                                bad=copy.deepcopy(valid);bad[field][index]+=1.
                                with self.assertRaises(ValueError):owner.ledger([bad],1,previous)
                                count+=1
                        for field in ('age_start_cm_day','age_end_cm_day','age_soil_residual_cm_day','age_pond_residual_cm_day','age_combined_residual_cm_day','age_tolerance_cm_day'):
                            bad=copy.deepcopy(valid);bad[field]+=1.
                            with self.assertRaises(ValueError):owner.ledger([bad],1,previous)
                            count+=1
                        source=z.read(pp+'trajectory/original/donor.stdout').decode('utf8')
                        class Changed:
                            def __init__(self,raw):self.raw=raw
                            def read(self,name):return self.raw if name==pp+'trajectory/original/donor.stdout' else z.read(name)
                        for marker in ('HYBRID_AGE_CUMULATIVE','HYBRID_AGE_EFFLUENT','AGE_DAILY_RECEIPT'):
                            lines=source.splitlines();i=next(i for i,v in enumerate(lines) if v.startswith(marker+' '));parts=lines[i].split();parts[1]='nan' if marker!='AGE_DAILY_RECEIPT' else '99999';lines[i]=' '.join(parts)
                            with self.assertRaises(ValueError):owner.audit(Changed('\n'.join(lines).encode()),pp+'trajectory/',data,epoch)
                            count+=1
        print('ACTUAL_AGE_PERSTEP_NATIVE_LEDGER_PERIOD_WORKER_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_epoch_private_flags_and_counters(self):
        count=0
        for location in self.q['contexts']:
            if location['kind']!='epoch':continue
            platform=location['platform']
            def path(value):return (owner.PureWindowsPath(value).relative_to(owner.PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')) if platform=='Windows' else owner.PurePosixPath(value).relative_to(owner.PurePosixPath(location['producer_root']))).as_posix()+'/'
            with zipfile.ZipFile(io.BytesIO(owner.raw_archive(self.q['archives'][location['archive']]))) as z:
                q=owner.read(z,location['prefix']+'RESULT.json')
                for item in q['cases'].values():
                    report=item['report'];build=owner.read(z,path(report['build_root'])+'BUILD.json');pp=path(item['root'])+'actual/';row=owner.rows(z,pp+'trajectory/')[29];n=build['project']['nodes'];selected=build['identity']['original_output'];dz=owner.geometry(z.read(path(report['input_root'])+'swap.swp'),n)
                    with zipfile.ZipFile(io.BytesIO(z.read(pp+'trajectory/accepted-column-1-day-30.zip'))) as cp:raw=cp.read('macro.bin')
                    owner.native(raw,row,n,selected,item['epoch'],dz);pos,h,_=owner.calendar(raw,n)
                    for index,value in [(5,h[5]+1),(6,31),(7,h[7]+1),(8,2),(10,3001),(11,1-h[11])]:
                        bad=bytearray(raw)
                        for offset in (0,80):struct.pack_into('<i',bad,pos+offset+4*index,value)
                        with self.assertRaises(ValueError):owner.native(bad,row,n,selected,item['epoch'],dz)
                        count+=1
                    for offset in (len(raw)-8,len(raw)-4):
                        bad=bytearray(raw);struct.pack_into('<i',bad,offset,1-struct.unpack_from('<i',bad,offset)[0])
                        with self.assertRaises(ValueError):owner.native(bad,row,n,selected,item['epoch'],dz)
                        count+=1
        print('ACTUAL_AGE_PERSTEP_EPOCH_PRIVATE_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_selected_prior_periods(self):
        count=0
        for location in self.q['preservation'].values():
            with zipfile.ZipFile(io.BytesIO(owner.raw_archive(self.q['archives'][location['archive']]))) as z:
                for prefix in location['profiles']:
                    report=owner.read(z,prefix+'/RESULT.json')
                    for key,item in report['profiles'].items():
                        data=owner.rows(z,prefix+'/'+key+'/trajectory/');owner.preserved_period(key,item,data)
                        with self.assertRaises(ValueError):owner.preserved_period(key,item,data[:-1])
                        count+=1
                        bad=copy.deepcopy(item);bad['trajectory']['days']+=1
                        with self.assertRaises(ValueError):owner.preserved_period(key,bad,data)
                        count+=1
        print('ACTUAL_AGE_PERSTEP_PRIOR_PERIOD_CENSOR_CORRUPTIONS_REFUSED',count,flush=True)


if __name__=='__main__':unittest.main()
