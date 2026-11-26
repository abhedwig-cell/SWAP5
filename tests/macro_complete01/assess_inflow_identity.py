import json,pathlib,zipfile,hashlib
R=pathlib.Path('integration/macro-complete01');r=json.loads((R/'RESOURCE_PATHS.json').read_text());roots=[pathlib.Path(r[o]['path']) for o in ['O0','O2']]
q=dict(models_launched=0,scope='Current V10 two-day native payload, rows and retained derivative traces only',checks={})
a,b=[json.loads((p/'INFLOW_V10_COLD2/RESULT.json').read_text()) for p in roots];assert a['rows']==b['rows'];q['checks']['cold_rows_exact']=True;q['day_inventory_residual_cm']=[x['independent_residual_cm'] for x in a['rows']]
z=[zipfile.ZipFile(p/'INFLOW_V10_COLD2/accepted-column-1-day-2.zip') for p in roots]
for n in ['result.end','macro.bin']:
 assert z[0].read(n)==z[1].read(n);q['checks'][n]=hashlib.sha256(z[0].read(n)).hexdigest()
for n in ['jac37_trace.txt','macro_rank2_systems.txt','macro_saturated_mass_base.txt','macro_complete_trace.txt','macro_complete_systems.txt','macro_complete_mass_base.txt']:
 d=[(p/'INFLOW_V10_OWN2TO3/original'/n).read_bytes() for p in roots];assert d[0]==d[1];q['checks'][n]=hashlib.sha256(d[0]).hexdigest()
q['remaining_refusal']=dict(time=35797.698009999840,kind='Fresh unscaled coupled refusal; saturated helper guard -4: incoming projection or excess',full_day3_pass=False)
(R/'BLOCK09_QUALIFICATION.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
