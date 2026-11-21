"""Read original initial heads, fixed mass and unchanged calendar/native state."""
import argparse,io,json,struct,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import SHA
from initial_pressure_profile_science import initialized_heads,PROVIDER
from analytical_cde_calendar_science import cadence_ledger_cold
from implicit_conductivity_forensics import output_calendar
from implicit_snow_forensics import native as snow_native
from output_hysteresis_baseline import history
from cde_interval_runtime import audit_daily
from experimental_project import switches
BASE='71db24532f006bc78ac570d1fccdd04b22482e0e'
CORE='929764dcdb7dd66da1dccf2a29d5a3b7022c0d8b'
GUARD_CORE='f929bc88793953710774b593ce9364615734c804'
CODECS={'analytic-clock6-cde':'S5CCC001','vapor-monthly6-cde':'S5HCC006','vapor-dra0-clock8-cde':'S5HCC006','vapor-dra0-explicit5-cde':'S5HCC006','hys1-clock-water':'S5IHW001','hys2-periodic-cde':'S5CIH001','hys2-monthly-water':'S5IHW001','implicit-monthly-cde':'S5CIC001','implicit-snow-clock-cde':'S5IRC002','implicit-perstep-water':'S5OPW001','snow-monthly-cde':'S5CIS001','plain-periodic-water':'S5IOW001'}
git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT)


def audit(profile,reference,locations=None):
 q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_INITIAL_PROFILE_CALENDAR_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED' and q['days']==35 and q['case'] in CODECS
 epochs=[epoch for epoch in (CORE,GUARD_CORE) if not git('diff',epoch,q['source'],'--','app','src','tools/solute','tools/vq','reference')]
 assert len(epochs)==1,'Unreviewed original initial-profile calendar producer'
 build=locations['build'] if locations else Path(q['build_root']);inputs=locations['inputs'] if locations else Path(q['input_root']);meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity'];selected=identity['original_output'];n=meta['project']['nodes'];text=(inputs/'swap.swp').read_text(encoding='cp1252');s=switches(text)
 assert s['SWINCO']==1 and selected['kind']==q['kind'] and q['native_codec']==CODECS[q['case']]==selected['native_codec']
 for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
 for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
 for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
 for name,digest in PROVIDER.items():assert SHA((reference/('build/swap-selected/'+name)).read_bytes().replace(b'\r\n',b'\n'))==digest
 for field in ('donor_flags','kernel_flags'):assert '-'+q['optimization'] in identity[field]
 for role,digest in meta['executable_sha256'].items():
  paths=[p for p in (build/('day_'+role),build/('day_'+role+'.exe')) if p.is_file()];assert len(paths)==1 and SHA(paths[0].read_bytes())==digest
 for path in ('tests/nomacro_drainage/initial_pressure_profile_science.py','tests/nomacro_drainage/analytical_cde_calendar_science.py','tests/nomacro_drainage/implicit_snow_forensics.py','tests/nomacro_scheduled_subsurface/output_hysteresis_baseline.py','tests/nomacro_scheduled_subsurface/cde_interval_runtime.py'):
  assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':'+path),'Frozen original numerical/native observer changed'
 result=cadence_ledger_cold(q['native_codec'].encode())(profile,meta,dict(q,own=q['cold']),build)
 expected,initial=initialized_heads(text);actual=next(list(map(float,line.split()[3:])) for line in (profile/'trajectory/original/donor.stdout').read_text().splitlines() if line.startswith('HYBRID_HYDRAULIC '));assert len(actual)==n and actual==expected,'Actual original pressure initialization differs'
 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];chemical=q['kind']=='cde';daily=audit_daily(profile/'trajectory',35,n) if chemical else None
 samples=[];active_history=False;root_rates=0
 for path in (profile/'trajectory').glob('accepted-column-1-day-*.zip'):
  day=int(path.name.split('-')[-1].split('.')[0])
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:raw=z.read('macro.bin');end=z.read('result.end')
  assert raw[:8].decode()==CODECS[q['case']] and struct.unpack_from('<i',raw,8)[0]==n;parent=raw
  if raw[:8]==b'S5HCC006':
   v=identity['hydraulic_vapor'];models=v['models'];flags=[f if m>=8 else 0 for m,f in zip(models,v['SWVAPOR'])];domain=[6,n,v['numlay'],0,1,0,0,0,0,0,1,2,s['SWDRA'],s['SWBOTB']]+models+flags;packed=struct.pack('<'+str(len(domain))+'i',*domain);assert raw[48:48+2*len(packed)]==packed+packed;parent=raw[:48]+raw[48+2*len(packed):]
  if s['SWSNOW']:
   rates=snow_native(raw,rows[day-1],meta,selected,s)
   if selected.get('implicit_snow_root_carry'):assert rates is not None;root_rates+=1;parent=raw[:-96]
  details=output_calendar(parent,n,rows[day-1],selected,meta['project']['start_date'],chemical);samples.append(dict(day=day,calendar_header=details['calendar_header'],private_stock_exact=chemical))
  if s['SWHYST']:
   observed=history(end);assert observed['mode']==s['SWHYST'];active_history|=any(v!=(1 if s['SWHYST']==1 else -1) for v in observed['index']) or any(v!=1.0 for v in observed['fhyst'])
 assert {sample['day'] for sample in samples}=={2,4,19,23,30,34,35}
 snow_max=max(row['stock_end_cm'][2] for row in rows)
 if s['SWSNOW']:assert snow_max>0
 if s['SWHYST']:assert active_history,'No actual original hysteresis scanning/reversal observed'
 if chemical:assert max(row['solute_end_mg_cm2'] for row in rows)>0
 result.update(status='INDEPENDENT_ORIGINAL_INITIAL_PROFILE_CALENDAR_HEADS_FIXED_MASS_PRIVATE_STATE_EXACT_COLD_PASS',producer=q['source'],kind=q['kind'],optimization=q['optimization'],native_codec=q['native_codec'],exact_initial_pressure_nodes=n,initial_profile=initial,native_calendar_samples=sorted(samples,key=lambda v:v['day']),exact_private_CDE_samples=7 if chemical else 0,actual_hysteresis_reversal_or_scanning=bool(active_history),maximum_Snow_stock_cm=snow_max,exact_root_diagnostic_witnesses=root_rates,actual_CDE_daily_increment_rows=daily['actual_days'] if daily else 0,compiler_executions=0,model_executions=0,canonical_admission=False)
 return result


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=audit(a.profile,a.reference_work)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],q['kind'],q['optimization'],q['native_codec'])
