"""Corrupt real sealed groundwater water bytes and ledgers; execute no models."""
from pathlib import Path
import copy,io,json,struct,unittest,zipfile
import groundwater_water_verify as owner


class ActualEvidence(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.q=json.loads((owner.ROOT/owner.PROOF/'GROUNDWATER_WATER_QUALIFICATION.json').read_text());key='GROUNDWATER_WATER_WINDOWS_O0_RAW_ARCHIVE.json';cls.z=zipfile.ZipFile(io.BytesIO(owner.old.raw_archive(cls.q['archives'][key])));cls.refusals=0;cls.actual=[]
  for name in ('explicit-ordinary','explicit-history-step','implicit-ordinary-step'):
   item=next(v for v in cls.q['profiles'] if (v['platform'],v['optimization'],v['phase'],v['name'])==('Windows','O0','short',name));loc=cls.q['locations'][item['location']];report=owner.read(cls.z,item['report']);bp=owner.old.locate(report['build_root'],loc);ip=owner.old.locate(report['input_root'],loc);build=owner.read(cls.z,bp+'BUILD.json');data=owner.rows(cls.z,item['root']+'trajectory/');dz=owner.geometry(cls.z.read(ip+'swap.swp'),build['project']['nodes'])
   with zipfile.ZipFile(io.BytesIO(cls.z.read(item['root']+'trajectory/accepted-column-1-day-4.zip'))) as native:wire=native.read('macro.bin')
   selected=build['identity']['original_output'];implicit=owner.CASES[name][0];parsed=owner.f.native(wire,data[3],build,selected,dz,implicit);cls.actual.append(dict(wire=wire,row=data[3],build=build,selected=selected,dz=dz,implicit=implicit,parsed=parsed,data=data,root=item['root']))

 def refuse(self,callback):
  with self.assertRaises((ValueError,struct.error,UnicodeError,IndexError)):callback()
  type(self).refusals+=1

 def native(self,item,raw):return owner.f.native(raw,item['row'],item['build'],item['selected'],item['dz'],item['implicit'])

 def test_actual_typed_hydraulic_and_prefix_corruptions(self):
  for item in self.actual:
   wire=item['wire'];self.native(item,wire);n=item['build']['project']['nodes'];pos=item['parsed']['domain_offset'];offset=item['parsed']['hydraulic_offset']
   for raw in [b'FOREIGN1'+wire[8:],wire[:-1],wire+b'x']:self.refuse(lambda raw=raw:self.native(item,raw))
   for i in range(13):
    raw=bytearray(wire)
    for at in (pos,pos+52):struct.pack_into('<i',raw,at+4*i,struct.unpack_from('<i',wire,at+4*i)[0]+1)
    self.refuse(lambda:self.native(item,raw))
   for i in range(5*n+4):
    raw=bytearray(wire);struct.pack_into('<d',raw,offset+8*i,float('nan'));self.refuse(lambda:self.native(item,raw))
   for at,value in [(12,float('nan')),(12,struct.unpack_from('<d',wire,12)[0]+1),(20,0.),(20,float('nan')),(28,-1.),(28,item['row']['stock_end_cm'][3]+1)]:
    raw=bytearray(wire);struct.pack_into('<d',raw,at,value);self.refuse(lambda:self.native(item,raw))
   raw=bytearray(wire);struct.pack_into('<i',raw,8,n+1);self.refuse(lambda:self.native(item,raw))

 def test_actual_complete_calendar_corruptions(self):
  for item in self.actual:
   wire=item['wire'];self.native(item,wire);pos=item['parsed']['calendar_offset'];header=struct.unpack_from('<20i',wire,pos)
   for i in range(20):
    raw=bytearray(wire);value=2 if i>=12 else 2147483647 if i in (9,10) else header[i]+1
    for at in (pos,pos+80):struct.pack_into('<i',raw,at+4*i,value)
    self.refuse(lambda:self.native(item,raw))
   for i in (0,header[3]//2,header[3]-1):
    raw=bytearray(wire)
    for at in (pos+160,pos+160+8*header[3]):struct.pack_into('<d',raw,at+8*i,float('nan'))
    self.refuse(lambda:self.native(item,raw))
   if item['selected']['swhyst']:
    at=item['parsed']['domain_offset']-40
    for i in range(5):
     raw=bytearray(wire)
     for start in (at,at+20):struct.pack_into('<i',raw,start+4*i,struct.unpack_from('<i',wire,start+4*i)[0]+1)
     self.refuse(lambda:self.native(item,raw))

 def test_actual_original_observations_and_conservation(self):
  for item in self.actual:
   data=item['data'];raw=self.z.read(item['root']+'trajectory/original/donor.stdout');epoch=item['build']['project']['start_date'];owner.p.water(data);owner.p.original_observations(raw,data,epoch)
   for field in ('stock_start_cm','stock_end_cm','external_flux_cm'):
    bad=copy.deepcopy(data);bad[0][field][0]+=1e-4;self.refuse(lambda:owner.p.water(bad))
   lines=raw.decode().splitlines();end=next(i for i,line in enumerate(lines) if line.startswith('HYBRID_DAY_RETURN '));index=max(i for i in range(end) if lines[i].startswith('HYBRID_HYDRAULIC'));fields=lines[index].split();fields[1]='999';lines[index]=' '.join(fields);self.refuse(lambda:owner.p.original_observations('\n'.join(lines).encode(),data,epoch))

 @classmethod
 def tearDownClass(cls):print('ACTUAL_GROUNDWATER_NATIVE_CALENDAR_LEDGER_CORRUPTIONS_REFUSED',cls.refusals,flush=True);cls.z.close()


if __name__=='__main__':unittest.main()
