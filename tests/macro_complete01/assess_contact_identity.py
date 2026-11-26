from pathlib import Path
import json,zipfile,hashlib
R=Path('integration/macro-complete01');res=json.loads((R/'RESOURCE_PATHS.json').read_text());roots=[Path(res[o]['path']) for o in ['O0','O2']];q=dict(models_launched=0,checks={},scope='V12 original first3days, accepted native payload, O0/O2 and split routes; original1e-6cm independent inventory gate')
for label in ['ALLCONTACT_V12_COLD2','ALLCONTACT_V12_OWN2TO3','ALLCONTACT_V12_OWN1TO3','OBSERVER12_COLD2','OBSERVER12_OWN2TO3']:
 rr=[json.loads((r/label/'RESULT.json').read_text()) for r in roots];assert rr[0]['rows']==rr[1]['rows'];q['checks'][label+'_O0_O2_rows_exact']=True
for r in roots:
 z=[zipfile.ZipFile(r/l/'accepted-column-1-day-3.zip') for l in ['ALLCONTACT_V12_OWN2TO3','ALLCONTACT_V12_OWN1TO3','OBSERVER12_OWN2TO3']]
 for n in ['macro.bin','result.end']:
  assert all(a.read(n)==z[0].read(n) for a in z);q['checks'][str(r.name)+'_'+n+'_split_observer_exact']=hashlib.sha256(z[0].read(n)).hexdigest()
for n in ['macro_saturated_contact_systems.txt','macro_saturated_contact_mass_base.txt','coupled_refusal_observer.txt']:
 d=[(r/'OBSERVER12_OWN2TO3/original'/n).read_bytes() for r in roots];assert d[0]==d[1];q['checks'][n+'_O0_O2_exact']=hashlib.sha256(d[0]).hexdigest()
q['inventory_residuals_cm']=[x['independent_residual_cm'] for l in ['ALLCONTACT_V12_COLD2','ALLCONTACT_V12_OWN2TO3'] for x in json.loads((roots[0]/l/'RESULT.json').read_text())['rows']]
q['next_refusal']=dict(time=35798.642030000010,day=4,helper_active=True,no_full_day4=True)
(R/'BLOCK11_NATIVE_QUALIFICATION.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
