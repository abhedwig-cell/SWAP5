"""Reject corruptions of actual private CDE, calendar and daily chemistry evidence."""
import copy,importlib.util,io,json,struct,sys,tempfile,unittest,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('owner',Path(__file__).with_name('cde_clock_verify.py'));owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)


class Proof(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.q=json.loads((ROOT/owner.PROOF/'CDE_CLOCK_QUALIFICATION.json').read_text(encoding='utf8'))
        sys.path.insert(0,str(Path(__file__).parent))

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
            bad=copy.deepcopy(self.q);v=bad[key];bad[key]=v+1 if type(v) in (int,float) else v+['FOREIGN'] if isinstance(v,list) else v+'-FOREIGN'
            with self.assertRaises(ValueError):owner.validate(bad)
            count+=1
        print('ACTUAL_CDE_CLOCK_SCOPE_SOURCE_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_native_ledger_and_period(self):
        from cde_clock_ci import CASES
        count=0
        for platform,opts in self.q['main'].items():
            for opt,loc in opts.items():
                with zipfile.ZipFile(io.BytesIO(owner.raw_archive(self.q['archives'][loc['archive']]))) as z:
                    run=owner.read(z,loc['prefix']+'RESULT.json')
                    def path(value):return owner.PureWindowsPath(value).relative_to(owner.PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')).as_posix()+'/' if platform=='Windows' else owner.PurePosixPath(value).relative_to(owner.PurePosixPath(loc['producer_root'])).as_posix()+'/'
                    for key,case in CASES.items():
                        item=run['cases'][key];bp=path(item['build_root']);buildraw=z.read(bp+'BUILD.json');build=json.loads(buildraw)
                        for phase in ('short','full'):
                            if phase not in item:continue
                            report=item[phase];owner.period(report,case,opt,phase,build,owner.digest(buildraw))
                            for parts,value in [(('status',),'FOREIGN'),(('mode',),'FOREIGN'),(('hysteresis',),3),(('optimization',),'FOREIGN'),(('trajectory','days'),1),(('trajectory','build_sha256'),'FOREIGN'),(('cold',0,'exact_physical'),False),(('cold',0,'exact_complete_native'),False),(('cold',0,'origin_unchanged'),False)]:
                                bad=copy.deepcopy(report);target=bad
                                for part in parts[:-1]:target=target[part]
                                target[parts[-1]]=value
                                with self.assertRaises(ValueError):owner.period(bad,case,opt,phase,build,owner.digest(buildraw))
                                count+=1
                        pp=path(item['short_root']);data=owner.rows(z,pp+'trajectory/');owner.ledger(data,35)
                        for day in (5,7,35):
                            for field,index in [('solute_ledger_mg_cm2',i) for i in range(9)]+[('external_flux_cm',0),('stock_end_cm',0),('stock_start_cm',0)]:
                                bad=copy.deepcopy(data[day-1]);bad[field][index]+=1
                                with self.assertRaises(ValueError):owner.ledger([bad],1)
                                count+=1
                        with zipfile.ZipFile(io.BytesIO(z.read(pp+'trajectory/accepted-column-1-day-35.zip'))) as nativezip:raw=nativezip.read('macro.bin')
                        n=build['project']['nodes'];selected=build['identity']['original_output'];owner.native(raw,data[34],n,selected);pos,h,nr=owner.calendar(raw,n);cp=pos+160+16*nr;size=20+n
                        def refused(bad):
                            nonlocal count
                            with self.assertRaises((ValueError,struct.error)):owner.native(bad,data[34],n,selected)
                            count+=1
                        for index,value in [(0,2),(1,n+1),(3,nr+1),(4,h[4]+1),(5,h[5]+1),(6,36),(7,h[7]+1),(8,2),(9,0),(10,3001),(11,1-h[11]),(12,2),(18,1-h[18]),(19,1-h[19])]:
                            bad=bytearray(raw)
                            for offset in (0,80):struct.pack_into('<i',bad,pos+offset+4*index,value)
                            refused(bad)
                        for index,value in [(0,float('nan')),(nr-1,-1.)]:
                            bad=bytearray(raw)
                            for offset in (0,8*nr):struct.pack_into('<d',bad,pos+160+offset+8*index,value)
                            refused(bad)
                        for index,value in [(0,-1.),(size-2,-1.),(size-2,float('nan')),(size-1,float('nan')),(14,1.)]:
                            bad=bytearray(raw)
                            for offset in (0,8*size):struct.pack_into('<d',bad,cp+24+offset+8*index,value)
                            refused(bad)
                        bad=bytearray(raw);anchor=struct.unpack_from('<d',bad,cp+24+8*(size-2))[0]
                        for offset in (0,8*size):struct.pack_into('<d',bad,cp+24+offset+8*(size-2),anchor+1.)
                        refused(bad)
                        for offset in (0,12):
                            for index in range(3):
                                bad=bytearray(raw);value=struct.unpack_from('<i',bad,cp+offset+4*index)[0]+1;struct.pack_into('<i',bad,cp+offset+4*index,value);refused(bad)
                        for index in (0,14,size-2,size-1):
                            bad=bytearray(raw);struct.pack_into('<d',bad,cp+24+8*index,123.);refused(bad)
                        for bad in (raw[:-1],raw+b'x',b'S5IOC001'+raw[8:],b'S5SPN001'+raw[8:]):refused(bad)
                        if case[5]:
                            head=struct.pack('<4i',1,n,1,7);d=raw.index(head+head)
                            for index in range(7):
                                for value in (-1.,float('nan')):
                                    bad=bytearray(raw);struct.pack_into('<d',bad,d+32+8*index,value);refused(bad)
                        class Changed:
                            def __init__(self,target,value):self.target=target;self.value=value
                            def read(self,name):return self.value if name==self.target else z.read(name)
                        owner.daily(z,pp+'trajectory/',data,n,item['short']['daily_chemical_receipts'])
                        source=z.read(pp+'trajectory/original/donor.stdout').decode('utf8')
                        for marker,index in [('CDE_INTERVAL_DAILY_AUDIT',i) for i in range(17)]+[('CDE_INTERVAL_INCREMENT_COUNTS',i) for i in range(6)]:
                            lines=source.splitlines();line=next(i for i,s in enumerate(lines) if s.startswith(marker+' '));parts=lines[line].split();parts[index+1]='nan' if marker.endswith('AUDIT') else '0';lines[line]=' '.join(parts)
                            bad=Changed(pp+'trajectory/original/donor.stdout','\n'.join(lines).encode())
                            with self.assertRaises(ValueError):owner.daily(bad,pp+'trajectory/',data,n,item['short']['daily_chemical_receipts'])
                            count+=1
        print('ACTUAL_CDE_CLOCK_NATIVE_PRIVATE_DAILY_PERIOD_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_archive_receipts(self):
        count=0
        for record in self.q['archives'].values():
            bad=copy.deepcopy(record);bad['sha256']='0'*64
            with self.assertRaises(ValueError):owner.raw_archive(bad)
            count+=1
            bad=copy.deepcopy(record);bad['bytes']+=1
            with self.assertRaises(ValueError):owner.raw_archive(bad)
            count+=1
            if 'byte_parts' in record:
                bad=copy.deepcopy(record);bad['byte_parts'][0]['offset']=1
                with self.assertRaises(ValueError):owner.raw_archive(bad)
                count+=1
        print('ACTUAL_CDE_CLOCK_RAW_RECEIPT_CORRUPTIONS_REFUSED',count,flush=True)

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
        print('ACTUAL_CDE_CLOCK_PRIOR_PERIOD_CENSOR_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_limit_epoch_and_local_event_data(self):
        from cde_clock_ci import LIMITS
        count=0
        for platform,opts in self.q['main'].items():
            for opt,location in opts.items():
                with zipfile.ZipFile(io.BytesIO(owner.raw_archive(self.q['archives'][location['archive']]))) as z:
                    run=owner.read(z,location['prefix']+'RESULT.json')
                    def path(value):return owner.PureWindowsPath(value).relative_to(owner.PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')).as_posix()+'/' if platform=='Windows' else owner.PurePosixPath(value).relative_to(owner.PurePosixPath(location['producer_root'])).as_posix()+'/'
                    for key,case in LIMITS.items():
                        pp=path(run['limits'][key]['root']);report=owner.read(z,pp+'RESULT.json');raw=z.read(path(report['build_root'])+'BUILD.json');build=json.loads(raw)
                        owner.period(report,case,opt,'limit',build,owner.digest(raw))
                        for field,value in [('nprintday',1441),('perstep',not report['perstep']),('requested_controls_preserved',False)]:
                            bad=copy.deepcopy(report);bad[field]=value
                            with self.assertRaises(ValueError):owner.period(bad,case,opt,'limit',build,owner.digest(raw))
                            count+=1
                        bad=copy.deepcopy(report);bad['actual_fixed_incoming_mg_cm2'][0]-=1e-7
                        with self.assertRaises(ValueError):owner.period(bad,case,opt,'limit',build,owner.digest(raw))
                        count+=1
                        text=z.read(pp+'trajectory/original/donor.stdout').decode('utf8');owner.event_rows(z,pp+'trajectory/')
                        lines=text.splitlines();found=next((i for i,v in enumerate(lines) if v.startswith('CDE_CLOCK_EVENT_CLOSURE ')),None)
                        if found is not None:
                            class Changed:
                                def __init__(self,raw):self.raw=raw
                                def read(self,name):return self.raw if name==pp+'trajectory/original/donor.stdout' else z.read(name)
                            for index in range(7):
                                bad=list(lines);parts=bad[found].split();parts[index+1]='nan';bad[found]=' '.join(parts)
                                with self.assertRaises(ValueError):owner.event_rows(Changed('\n'.join(bad).encode()),pp+'trajectory/')
                                count+=1
        for location in self.q['contexts']:
            if location['kind']!='epoch':continue
            with zipfile.ZipFile(io.BytesIO(owner.raw_archive(self.q['archives'][location['archive']]))) as z:
                epochs=owner.read(z,location['prefix']+'RESULT.json')
                for key,item in epochs['cases'].items():
                    pp=location['prefix']+key+'/actual/';build=owner.read(z,pp+'build/BUILD.json');row=owner.rows(z,pp+'trajectory/')[29]
                    with zipfile.ZipFile(io.BytesIO(z.read(pp+'trajectory/accepted-column-1-day-30.zip'))) as cp:raw=cp.read('macro.bin')
                    n=build['project']['nodes'];selected=build['identity']['original_output'];owner.native(raw,row,n,selected,item['epoch']);pos,h,_=owner.calendar(raw,n)
                    for index,value in [(5,h[5]+1),(6,31),(7,h[7]+1),(8,h[8]+1),(10,3001),(11,1-h[11])]:
                        bad=bytearray(raw)
                        for offset in (0,80):struct.pack_into('<i',bad,pos+offset+4*index,value)
                        with self.assertRaises(ValueError):owner.native(bad,row,n,selected,item['epoch'])
                        count+=1
        print('ACTUAL_CDE_CLOCK_LIMIT_EPOCH_EVENT_CORRUPTIONS_REFUSED',count,flush=True)


if __name__=='__main__':unittest.main()
