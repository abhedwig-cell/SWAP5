"""Actual raw water/native proof, with in-memory corruptions of real bytes."""
from pathlib import Path
import argparse,copy,json,re,struct,subprocess,time,zipfile
import age_groundwater_verify as predecessor
import implicit_conductivity_forensics as proof


def main():
 p=argparse.ArgumentParser();p.add_argument('--profile-root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir();root=a.profile_root
 report=json.loads((root/'RESULT.json').read_text());build=json.loads((Path(report['build_root'])/'BUILD.json').read_text());data=[json.loads(line) for line in (root/'trajectory/daily.jsonl').read_text().splitlines()]
 raw_input=(Path(report['input_root'])/'swap.swp').read_bytes();selected=copy.deepcopy(build['identity']['original_output'])
 for field,key in [('swhyst','SWHYST'),('swdra','SWDRA'),('et','SWCFBS')]:
  matches=re.findall(rb'(?mi)^\s*'+key.encode()+rb'\s*=\s*(\d+)\s*(?:!.*)?$',raw_input);assert len(matches)==1;selected[field]=int(matches[0])
 dz=predecessor.geometry(raw_input,build['project']['nodes']);q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),profile=str(root),actual_native=[],refusals=[])
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save();start=time.perf_counter()
 try:
  q['water']=proof.water(data);q['original']=proof.original_observations((root/'trajectory/original/donor.stdout').read_bytes(),data,build['project']['start_date']);save()
  sources=sorted((root/'trajectory').glob('accepted-column-1-day-*.zip'))
  assert sources
  for path in sources:
   day=int(path.stem.rsplit('-',1)[1]);row=next(row for row in data if row['day']==day);item=proof.checkpoint(path.read_bytes(),build,row,selected,dz);q['actual_native'].append(dict(day=day,path=str(path),sequential_records=len(item['sequential_record_lengths'])));save()
  path=next(path for path in sources if path.stem.endswith('-34'));row=next(row for row in data if row['day']==34)
  with zipfile.ZipFile(path) as z:raw=z.read('macro.bin');seq=z.read('result.end')
  actual=proof.implicit_water_native(raw,row,build['project']['nodes'],selected,dz,build['project']['start_date']);n=build['project']['nodes'];gp=actual['domain_offset'];hp=actual['hydraulic_offset'];cp=actual['calendar_offset']
  def refuse(label,callback):
   try:callback()
   except (ValueError,struct.error,UnicodeError) as error:q['refusals'].append(dict(label=label,error=str(error)));save()
   else:raise AssertionError('Actual forged evidence accepted: '+label)
  for label,bad in [('seq-truncate',seq[:-1]),('seq-trailing',seq+b'x'),('seq-length',struct.pack('<i',5)+seq[4:])]:refuse(label,lambda bad=bad:proof.sequential_records(bad))
  attacks=[('magic',b'FOREIGN1'+raw[8:]),('truncate',raw[:-1]),('trailing',raw+b'x')]
  for label,offset,value in [('node',8,struct.pack('<i',n+1)),('clock',12,struct.pack('<d',-1.)),('step',20,struct.pack('<d',float('nan'))),('canopy',28,struct.pack('<d',-1.))]:
   bad=bytearray(raw);bad[offset:offset+len(value)]=value;attacks.append((label,bytes(bad)))
  for i in range(13):
   bad=bytearray(raw)
   for offset in (gp+4*i,gp+52+4*i):struct.pack_into('<i',bad,offset,struct.unpack_from('<i',bad,offset)[0]+1)
   attacks.append(('paired-domain-'+str(i),bytes(bad)))
  for i in range(5*n+4):
   bad=bytearray(raw);struct.pack_into('<d',bad,hp+8*i,float('nan'));attacks.append(('hydraulic-nan-'+str(i),bytes(bad)))
  for i in range(20):
   bad=bytearray(raw)
   for offset in (cp+4*i,cp+80+4*i):struct.pack_into('<i',bad,offset,struct.unpack_from('<i',bad,offset)[0]+2)
   attacks.append(('paired-calendar-'+str(i),bytes(bad)))
  nr=actual['calendar_header'][3]
  for i in (0,nr-1):
   bad=bytearray(raw)
   for offset in (cp+160+8*i,cp+160+8*nr+8*i):struct.pack_into('<d',bad,offset,float('nan'))
   attacks.append(('paired-calendar-nan-'+str(i),bytes(bad)))
  for label,bad in attacks:refuse(label,lambda bad=bad:proof.implicit_water_native(bad,row,n,selected,dz,build['project']['start_date']))
  bad=copy.deepcopy(data);bad[0]['external_flux_cm'][0]+=1e-4;refuse('actual-water-flux',lambda:proof.water(bad))
  bad=copy.deepcopy(data);bad[0]['pressure_head_cm'][0]+=1;refuse('actual-original-pressure',lambda:proof.original_observations((root/'trajectory/original/donor.stdout').read_bytes(),bad,build['project']['start_date']))
  q.update(status='ACTUAL_IMPLICIT_WATER_STDOUT_NATIVE_FORENSICS_AND_CORRUPTIONS_PASS',seconds=time.perf_counter()-start);print(q['status'],len(q['refusals']),flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
