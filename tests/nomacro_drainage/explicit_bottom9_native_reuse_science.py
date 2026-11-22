"""Reread real O0 native continuations without relabelling their old producers."""
import argparse,io,json,struct,zipfile
from pathlib import Path
from explicit_bottom9_source_inverse import CORE,complete_inverse,git
from explicit_bottom9_water_science import audit
from analytical_hydraulic_archives import SHA
from implicit_conductivity_forensics import general_checkpoint
from analytical_calendar_native_state import decode,terminal_terms
from original_output_files import compare


def read(evidence,reference):
 complete_inverse();summary=json.loads((evidence/'EXPLICIT_BOTTOM9_O0_REUSED_PILOT_NATIVE_CAMPAIGNS_V1.json').read_text(encoding='utf8'));observations=[]
 assert summary['status']=='BOTH_O0_PILOTS_NATIVE_RESTART_QUALIFIED_WITHOUT_REPLAYING_INITIAL35_PERIOD' and len(summary['observations'])==2
 for item in summary['observations']:
  assert item['status']=='ACTUAL_OLD35DAY_PILOT_REUSED_REAL_NATIVE2_CONTINUATION_AND_THREE_EXACT_COLD_WINDOWS_PASS'
  assert item['actual_compiled_producer']==CORE and not git('diff',CORE,item['controller_source'],'--','app','src','tools/solute','tools/vq','reference')
  pilot=Path(item['original35day_pilot']);original=audit(pilot,reference);q=json.loads((pilot/'RESULT.json').read_text(encoding='utf8'));build=Path(item['build_root']);meta=json.loads((build/'BUILD.json').read_text(encoding='utf8'));original_rows=[json.loads(line) for line in (pilot/'trajectory/daily.jsonl').read_text().splitlines()]
  directory=evidence/('explicit-bottom9-'+item['case']+'-O0-native-campaign-v1');assert json.loads((directory/'RESULT.json').read_text(encoding='utf8'))==item
  full=directory/'reference-from-real-day2';rows=[json.loads(line) for line in (full/'daily.jsonl').read_text().splitlines()];assert len(rows)==33 and [r['day'] for r in rows]==list(range(3,36))
  fields=('stock_start_cm','stock_end_cm','external_flux_cm','pressure_head_cm','groundwater_cm','drainage_outward_cm','bottom_outward_cm')
  for a,b in zip(rows,original_rows[2:]):
   for field in fields:assert a[field]==b[field]
  source=Path(item['actual_origin_checkpoint']);assert SHA(source.read_bytes())==item['actual_origin_sha256'] and source.read_bytes()==(full/source.name).read_bytes()
  # Preserve each real producer's receipt (including its own instance revision).
  # The inherited day2 packet belongs to the original trajectory; fresh packets
  # belong to the actual native continuation, whose physical rows match above.
  receipts={2:original_rows[1],**{row['day']:row for row in rows}}
  native=[];selected={**meta['identity']['original_output'],'swhyst':0}
  for path in sorted(full.glob('accepted-column-1-day-*.zip')):
   day=int(path.name.split('-')[-1].split('.')[0]);row=receipts[day];raw=path.read_bytes();observed=general_checkpoint(raw,meta,row,selected,[])
   with zipfile.ZipFile(io.BytesIO(raw)) as z:
    state,header=decode(z.read('macro.bin'),(build/'integral.f90').read_text(encoding='cp1252'),34);terms=terminal_terms(state,row['stock_end_cm']);assert abs(sum(terms))<=1e-10
    end=z.read('result.end');offset=0;records=[]
    while offset<len(end):
     size=struct.unpack_from('<i',end,offset)[0];assert 0<=size<=len(end)-offset-8 and struct.unpack_from('<i',end,offset+4+size)[0]==size;records.append(end[offset+4:offset+4+size]);offset+=size+8
    assert records[:3]==[struct.pack('<i',value) for value in (1,0,34)] and list(struct.unpack('<34d',records[3]))==row['pressure_head_cm'] and struct.unpack('<d',records[4])[0]==row['stock_end_cm'][1]
   native.append(dict(day=day,actual_observer=observed,complete_original_calendar_header=list(header),independent_calendar_28term_residual_cm=sum(terms)))
  assert sorted(row['day'] for row in native)==[2,4,19,23,30,34,35]
  cold=[];assert len(item['cold'])==3
  for window in item['cold']:
   start,end=window['start'],window['end'];own=directory/('own-'+str(start));actual=[json.loads(line) for line in (own/'daily.jsonl').read_text().splitlines()];assert len(actual)==end-start
   for a,b in zip(actual,original_rows[start:end]):
    for field in fields:assert a[field]==b[field]
   with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(own/f'accepted-column-1-day-{end}.zip') as b:
    for name in ('macro.bin','result.end'):assert a.read(name)==b.read(name)
   outputs=compare(full/'original',own/'original',meta['identity']['original_output'],start,end,meta['project']['start_date']);assert outputs==window['exact_user_output'];cold.append(dict(start=start,end=end,complete_native_byte_exact=True,physical_exact=True,actual_user_output=outputs))
  observations.append(dict(case=item['case'],actual_original_compiled_producer=CORE,actual_native_campaign_controller_source=item['controller_source'],original35day_science=original,all33_actual_continuation_rows_exact_to_original=True,actual_native=native,actual_cold=cold,original_day2_native_unchanged=True))
 return dict(status='INDEPENDENT_BOTH_O0_OLD_PILOTS_REAL_DAY2_NATIVE_CONTINUATION_AND_THREE_EXACT_COLD_WINDOWS_PASS',contexts=2,native_checkpoints=14,exact_cold_windows=6,observations=observations,compiler_executions=0,model_executions=0,original_full_initial35_periods_replayed=0,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for name in ('evidence','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args();result=read(a.evidence,a.reference_work)
 with a.output.open('x',encoding='utf8') as out:json.dump(result,out,indent=2);out.write('\n')
 print(result['status'])
