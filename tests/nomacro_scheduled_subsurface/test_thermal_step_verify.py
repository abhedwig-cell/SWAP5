"""Actual Snow calendar period, seven-total/native, source and raw proof corruptions."""
import copy,importlib.util,io,json,struct,sys,unittest,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('snow_owner',Path(__file__).with_name('thermal_step_verify.py'))
owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)

class Proof(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.q=json.loads((ROOT/owner.PROOF/'THERMAL_STEP_QUALIFICATION.json').read_text(encoding='utf8'))

    def test_actual_source_scope(self):
        owner.validate(self.q);count=0
        for group in ('scope','source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):
            values=list(self.q[group].items())
            if group.startswith('frozen'):values=values[:1]
            for key,value in values:
                bad=copy.deepcopy(self.q);bad[group][key]=(not value) if type(value) is bool else value+1 if type(value) in (int,float) else value+['FOREIGN'] if isinstance(value,list) else value+'-FOREIGN'
                with self.assertRaises(ValueError,msg=group+'/'+key):owner.validate(bad)
                count+=1
        for key in ('runtime','functional_completion','whole_scientific_equivalence','release_readiness','water_guard_cm','chemical_mass_guard_mg_cm2','native_codec','process_domain_bytes','snow_domain_bytes','snow_value_bytes','snow_fields'):
            bad=copy.deepcopy(self.q);value=bad[key];bad[key]=value+1 if type(value) in (int,float) else value+['FOREIGN'] if isinstance(value,list) else value+'-FOREIGN'
            with self.assertRaises(ValueError,msg=key):owner.validate(bad)
            count+=1
        print('ACTUAL_SNOW_CALENDAR_SOURCE_SCOPE_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_period_ledger_seven_totals_native(self):
        sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'));from thermal_step_ci import CASES
        count=0
        for platform,opts in self.q['main'].items():
            for opt,location in opts.items():
                with zipfile.ZipFile(io.BytesIO(owner.raw_archive(self.q['archives'][location['archive']]))) as z:
                    run=json.loads(z.read(location['prefix']+'RESULT.json'))
                    def path(value):
                        if platform=='Windows':return owner.PureWindowsPath(value).relative_to(owner.PureWindowsPath('C:/Users/Veldh012/swap5-complete01-evidence')).as_posix()+'/'
                        base=owner.PurePosixPath(run['cases']['monthly-hys2-binary']['short_root']).parent
                        return str(owner.PurePosixPath(value).relative_to(base))+'/'
                    for key,case in CASES.items():
                        item=run['cases'][key];raw=z.read(path(item['build_root'])+'BUILD.json');build=json.loads(raw);digest=owner.digest(raw)
                        owner.build_files(z,path(item['build_root']),build)
                        for group,key in [('executable_sha256','donor'),('executable_sha256','kernel')]:
                            bad=copy.deepcopy(build);bad[group][key]='0'*64
                            with self.assertRaises(ValueError):owner.build_files(z,path(item['build_root']),bad)
                            count+=1
                        bad=copy.deepcopy(build);key=next(iter(bad['identity']['donor_generated']));bad['identity']['donor_generated'][key]='0'*64
                        bad['binding']['build']=copy.deepcopy(bad['identity'])
                        with self.assertRaises(ValueError):owner.build_files(z,path(item['build_root']),bad)
                        count+=1
                        for phase in ('short','full'):
                            if phase not in item:continue
                            report=item[phase];owner.period(report,case,opt,phase,build,digest)
                            for parts,value in [(('status',),'FOREIGN'),(('mode',),'FOREIGN'),(('hysteresis',),3),(('optimization',),'FOREIGN'),(('nprintday',),1441),
                                (('trajectory','days'),1),(('trajectory','build_sha256'),'FOREIGN'),(('cold',0,'exact_physical'),False),
                                (('cold',0,'exact_complete_native'),False),(('cold',0,'origin_unchanged'),False)]:
                                bad=copy.deepcopy(report);target=bad
                                for part in parts[:-1]:target=target[part]
                                target[parts[-1]]=value
                                with self.assertRaises(ValueError,msg=str((platform,opt,key,phase,parts))):owner.period(bad,case,opt,phase,build,digest)
                                count+=1
                        prefix=path(item['short_root']);rows=[json.loads(line) for line in z.read(prefix+'trajectory/daily.jsonl').splitlines()];owner.ledger(rows,35)
                        for field,index in [('stock_end_cm',0),('stock_end_cm',2),('external_flux_cm',6),('external_flux_cm',12)]:
                            row=copy.deepcopy(rows[0]);row[field][index]+=1.
                            with self.assertRaises(ValueError,msg=field):owner.ledger([row],1)
                            count+=1
                        with zipfile.ZipFile(io.BytesIO(z.read(prefix+'trajectory/accepted-column-1-day-4.zip'))) as checkpoint:
                            raw=checkpoint.read('macro.bin');n=build['project']['nodes'];selected=build['identity']['original_output'];owner.native(raw,rows[3],n,case[1],selected)
                            domain=struct.pack('<10i',1,n,0,0,case[1],1,0,1,1,2);d=raw.index(domain+domain)
                            snow=struct.pack('<4i',1,n,0,7);s=raw.index(snow+snow);c=s+88;nreal=struct.unpack_from('<i',raw,c+12)[0]
                            def refused(label,bad):
                                nonlocal count
                                with self.assertRaises(ValueError,msg=label):owner.native(bad,rows[3],n,case[1],selected)
                                count+=1
                            for i in range(7):
                                for label,value in [('nonfinite',float('nan')),('negative',-1.)]:
                                    bad=bytearray(raw);struct.pack_into('<d',bad,s+32+8*i,value);refused(f'{label}-snow-{i}',bad)
                            for label,pos,value in [('process-domain',d,2),('snow-domain',s,2),('calendar-witness',c,2)]:
                                bad=bytearray(raw);struct.pack_into('<i',bad,pos,value);refused(label,bad)
                            bad=bytearray(raw)
                            for pos in (c+12,c+92):struct.pack_into('<i',bad,pos,nreal+1)
                            refused('calendar-shape',bad)
                            bad=bytearray(raw)
                            for pos in (c+160,c+160+8*nreal):struct.pack_into('<d',bad,pos,float('nan'))
                            refused('calendar-nonfinite',bad)
                            bad=bytearray(raw);struct.pack_into('<d',bad,c+160,123.);refused('calendar-value-witness',bad)
                            refused('incomplete-prototype-codec',b'S5CTW002'+raw[8:]);refused('truncated',raw[:-1])
                            refused('foreign-subdaily-codec',b'S5STW001'+raw[8:])
                            bad=bytearray(raw)
                            for pos in (c+32,c+112):struct.pack_into('<i',bad,pos,2)
                            refused('foreign-per-step-print-counter',bad)
        self.assertEqual(count,1472)
        print('ACTUAL_SNOW_PERIOD_LEDGER_SEVEN_TOTALS_NATIVE_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_soil_and_subdaily_cadence_corruptions(self):
        count=0
        for platform,opts in self.q['main'].items():
            for opt,location in opts.items():
                with zipfile.ZipFile(io.BytesIO(owner.raw_archive(self.q['archives'][location['archive']]))) as z:
                    run=json.loads(z.read(location['prefix']+'RESULT.json'))
                    for item in run['cases'].values():
                        for phase in ('short','full'):
                            if phase not in item:continue
                            report=item[phase]
                            for table in report['user_output'].values():
                                stamps=table['stamps'];days=1096 if phase=='full' else 35
                                owner.output_clock(table,stamps,days,'2002-01-01')
                                bad_cases=[]
                                bad=copy.deepcopy(table);bad['records']+=1;bad_cases.append(bad)
                                bad=copy.deepcopy(table);bad['stamps']=bad['stamps'][:-1];bad_cases.append(bad)
                                bad=copy.deepcopy(table);bad['stamps'][0]='2002-01-01 01:00:00';bad_cases.append(bad)
                                for bad in bad_cases:
                                    with self.assertRaises(ValueError):owner.output_clock(bad,stamps,days,'2002-01-01')
                                    count+=1
                        row=item['short']['soil_receipts']['actual_rows'][0]
                        def archive(values):
                            raw=io.BytesIO()
                            with zipfile.ZipFile(raw,'w') as actual:
                                line='HYBRID_SNOW_SOIL_RECEIPT '+' '.join(map(repr,values))+'\n'
                                actual.writestr('original/donor.stdout',line)
                            return zipfile.ZipFile(io.BytesIO(raw.getvalue()))
                        with archive(row) as actual:owner.soil_receipts(actual,'',1)
                        for index in (0,6,14,27,28,3):
                            bad=list(row);bad[index]+=1.
                            with archive(bad) as actual,self.assertRaises(ValueError):owner.soil_receipts(actual,'',1)
                            count+=1
                        bad=list(row);bad[14]=float('nan')
                        with archive(bad) as actual,self.assertRaises(ValueError):owner.soil_receipts(actual,'',1)
                        count+=1
                        with archive(row) as actual,self.assertRaises(ValueError):owner.soil_receipts(actual,'',2)
                        count+=1
        self.assertEqual(count,388)
        print('ACTUAL_SNOW_SOIL_AND_CADENCE_CORRUPTIONS_REFUSED',count,flush=True)

    def test_actual_raw_artifact_and_prior_part_bindings(self):
        count=0
        for record in self.q['archives'].values():
            for key,value in [('bytes',record['bytes']+1),('sha256','0'*64)]:
                bad=copy.deepcopy(record);bad[key]=value
                with self.assertRaises(ValueError,msg=key):owner.raw_archive(bad)
                count+=1
            if 'origin_artifact' in record:
                bad=copy.deepcopy(record);bad['origin_artifact']['digest']='sha256:'+'0'*64
                with self.assertRaises(ValueError):owner.raw_archive(bad)
                count+=1
        old=json.loads((ROOT/owner.PROOF/'GROUNDWATER_HISTORY_QUALIFICATION.json').read_text(encoding='utf8'))
        for record in old['archives'].values():
            if 'byte_parts' not in record:continue
            bad=copy.deepcopy(record);bad['byte_parts'][0]['offset']=1
            with self.assertRaises(ValueError):owner.raw_archive(bad)
            count+=1
        self.assertEqual(count,22)
        print('ACTUAL_SNOW_RAW_ARTIFACT_PRIOR_PART_BINDING_CORRUPTIONS_REFUSED',count,flush=True)

if __name__=='__main__':unittest.main()
