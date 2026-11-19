"""Corrupt actual sealed native/receipt/input bytes; execute no models."""
from pathlib import Path
import copy,io,json,re,struct,tempfile,unittest,zipfile
import implicit_conductivity_verify as owner
import implicit_conductivity_forensics as p
from age_groundwater_verify import geometry


class ActualEvidence(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.q=json.loads((owner.ROOT/owner.PROOF/'IMPLICIT_CONDUCTIVITY_QUALIFICATION.json').read_text());key='IMPLICIT_CONDUCTIVITY_WINDOWS_O0_RAW_ARCHIVE.json';cls.z=zipfile.ZipFile(io.BytesIO(owner.raw_archive(cls.q['archives'][key])))
        cls.water=cls.load('implicit-conductivity-water-cde-windows-O0-v5/short-water-groundwater/')
        cls.chemical=cls.load('implicit-conductivity-positive-cde-windows-O0-current-v7/short-head/')
        cls.refusals=0

    @classmethod
    def load(cls,prefix):
        report=owner.read(cls.z,prefix+'RESULT.json');location=cls.q['main']['Windows']['O0'];bp=owner.locate(report['build_root'],location);ip=owner.locate(report['input_root'],location);build=owner.read(cls.z,bp+'BUILD.json');raw=cls.z.read(ip+'swap.swp');selected=dict(build['identity']['original_output'])
        import re
        for name,field in [('SWHYST','swhyst'),('SWDRA','swdra'),('SWCFBS','et')]:selected[field]=int(re.findall(rb'(?mi)^\s*'+name.encode()+rb'\s*=\s*(\d+)',raw)[0])
        data=owner.rows(cls.z,prefix+'trajectory/')
        with zipfile.ZipFile(io.BytesIO(cls.z.read(prefix+'trajectory/accepted-column-1-day-34.zip'))) as z:wire=z.read('macro.bin');seq=z.read('result.end')
        dz=geometry(raw,build['project']['nodes']);actual=p.general_native(wire,build,data[33],selected,dz)
        return dict(prefix=prefix,report=report,build=build,input=raw,selected=selected,data=data,wire=wire,seq=seq,dz=dz,actual=actual)

    def refuse(self,callback):
        with self.assertRaises((ValueError,struct.error,UnicodeError,IndexError)):callback()
        type(self).refusals+=1

    def native(self,item,raw):return p.general_native(raw,item['build'],item['data'][33],item['selected'],item['dz'])

    def test_actual_water_typed_native_corruptions(self):
        a=self.water;raw=a['wire'];info=a['actual']['water'];gp=info['domain_offset'];hp=info['hydraulic_offset'];cp=info['calendar_offset'];n=a['build']['project']['nodes']
        for bad in [b'FOREIGN1'+raw[8:],raw[:-1],raw+b'x']:
            self.refuse(lambda bad=bad:self.native(a,bad))
        for at,fmt,value in [(8,'i',n+1),(12,'d',-1.),(20,'d',float('nan')),(28,'d',-1.)]:
            bad=bytearray(raw);struct.pack_into('<'+fmt,bad,at,value);self.refuse(lambda bad=bad:self.native(a,bad))
        for i in range(13):
            bad=bytearray(raw)
            for at in [gp+4*i,gp+52+4*i]:struct.pack_into('<i',bad,at,struct.unpack_from('<i',bad,at)[0]+1)
            self.refuse(lambda bad=bad:self.native(a,bad))
        for i in range(5*n+4):
            bad=bytearray(raw);struct.pack_into('<d',bad,hp+8*i,float('nan'));self.refuse(lambda bad=bad:self.native(a,bad))
        for i in range(20):
            bad=bytearray(raw)
            for at in [cp+4*i,cp+80+4*i]:struct.pack_into('<i',bad,at,struct.unpack_from('<i',bad,at)[0]+2)
            self.refuse(lambda bad=bad:self.native(a,bad))
        for bad in [a['seq'][:-1],a['seq']+b'x',struct.pack('<i',5)+a['seq'][4:]]:self.refuse(lambda bad=bad:p.sequential_records(bad))

    def test_actual_chemical_private_state_corruptions(self):
        a=self.chemical;raw=a['wire'];at=a['actual']['calendar']['calendar_end'];n=a['build']['project']['nodes'];size=n+20
        for i in range(size):
            bad=bytearray(raw)
            for offset in [at+24+8*i,at+24+8*size+8*i]:struct.pack_into('<d',bad,offset,float('nan'))
            self.refuse(lambda bad=bad:self.native(a,bad))
        for i in range(n+2):
            bad=bytearray(raw);struct.pack_into('<d',bad,48+8*i,-1.);self.refuse(lambda bad=bad:self.native(a,bad))
        for i in range(3):
            bad=bytearray(raw)
            for offset in [at+4*i,at+12+4*i]:struct.pack_into('<i',bad,offset,struct.unpack_from('<i',bad,offset)[0]+1)
            self.refuse(lambda bad=bad:self.native(a,bad))

    def test_actual_receipts_stdout_and_policy_corruptions(self):
        a=self.chemical
        for field,index in [('stock_end_cm',0),('external_flux_cm',0),('pressure_head_cm',0)]:
            data=copy.deepcopy(a['data']);data[0][field][index]+=1
            if field=='pressure_head_cm':self.refuse(lambda:p.original_observations(self.z.read(a['prefix']+'trajectory/original/donor.stdout'),data,a['build']['project']['start_date']))
            else:self.refuse(lambda:p.water(data))
        expected=owner.numerical_policy(a['input'],3);self.assertEqual(expected,a['report']['numerical_policy'])
        for mean in [0,7,True]:self.refuse(lambda mean=mean:owner.numerical_policy(a['input'],mean))
        bad,count=re.subn(rb'(?mi)^([ \t]*)ORES([ \t]+OSAT\b)',rb'\1FOREIGN\2',a['input'],count=1);self.assertEqual(count,1)
        self.refuse(lambda:owner.numerical_policy(bad,3))
        raw=self.z.read(a['prefix']+'trajectory/original/donor.stdout');lines=raw.decode().splitlines();end=next(i for i,line in enumerate(lines) if line.startswith('HYBRID_DAY_RETURN '));index=max(i for i in range(end) if lines[i].startswith('HYBRID_SOLUTE_LEDGER '));parts=lines[index].split();parts[1]='999';lines[index]=' '.join(parts)
        self.refuse(lambda:p.original_observations('\n'.join(lines).encode(),a['data'],a['build']['project']['start_date']))

    def test_actual_saved_output_reader_equivalence(self):
        from original_output_files import records
        prefixes=['implicit-conductivity-water-cde-windows-O0-v5/short-water-head/trajectory/original/','implicit-conductivity-water-cde-windows-O0-v5/short-water-air-history/trajectory/original/']
        checked=0
        with tempfile.TemporaryDirectory(prefix='s5-implicit-real-output-') as folder:
            for prefix in prefixes:
                for name in self.z.namelist():
                    if name.startswith(prefix) and Path(name).name in ('result_output.csv','result_output.bin'):
                        raw=self.z.read(name);path=Path(folder)/Path(name).name;path.write_bytes(raw);self.assertEqual(p.output_records(raw,name),records(path));checked+=1
        self.assertEqual(checked,2)

    @classmethod
    def tearDownClass(cls):print('ACTUAL_NATIVE_LEDGER_POLICY_BYTE_CORRUPTIONS_REFUSED',cls.refusals,flush=True);cls.z.close()


if __name__=='__main__':unittest.main()
