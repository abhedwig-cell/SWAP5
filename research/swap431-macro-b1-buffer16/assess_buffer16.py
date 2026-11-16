"""Exact budget preservation, independent full-period inventories, own restart."""
from pathlib import Path
import json,math,hashlib,struct,csv,io
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-prefix14'
def f(p):return {s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
def body(p):return '\n'.join(s for s in p.read_text().splitlines() if not s.startswith('* Generated at:'))
result=[]
for opt in ['O0','O2']:
 d=R/'data'/opt/'PREFIX';z=R/'data'/opt/'RESUME';raw=(d/'step_budget.txt').read_text().splitlines();old=(P/'data'/opt/'PREFIX/step_budget.txt').read_text().splitlines()
 assert raw[:len(old)]==old
 a=f(d/'initial.txt');b=f(d/'checkpoint.txt');ca=f(d/'context_initial.txt');cb=f(d/'context_checkpoint.txt');L=f(d/'ledger_checkpoint.txt')
 rows=[list(map(float,s.split())) for s in raw];assert len(rows)==1453 and all(len(x)==32 and x[16]==1 for x in rows)
 assert a['controls'][0]==35795 and b['controls'][0]==rows[-1][0]==35797
 duration=math.fsum(x[1] for x in rows);assert abs(duration-2)<1e-8
 assert L['ioutdat']==[2.] and L['wasrdm1ini']==[a['macro_domain'][0]]
 assert abs(L['wasrdm2ini'][0]-math.fsum(a['macro_domain'][1:]))<1e-15
 matrix=math.fsum((y-x)*dz*fr for x,y,dz,fr in zip(a['theta'],b['theta'],a['dz'],a['fraction']))
 macro=math.fsum(y-x for x,y in zip(a['macro_domain'],b['macro_domain']));pond=b['pond'][0]-a['pond'][0];canopy=cb['sicact'][0]-ca['sicact'][0]
 net=math.fsum(x[1]*(x[14]+x[15]+x[4]-x[6]-x[7]-x[8]+x[9]-x[10]+x[11]-x[12])-x[13] for x in rows)
 gross=math.fsum(x[1]*(x[2]+x[3]+x[4]-x[5]-x[6]-x[7]-x[8]+x[9]-x[10]+x[11]-x[12])-x[13] for x in rows)
 error=matrix+macro+pond+canopy-gross;neterror=matrix+macro+pond-net;envelope=duration*1e-5
 assert abs(error)<envelope and abs(error-neterror)<1e-12
 domain=[]
 for j in range(5):
  delta=b['macro_domain'][j]-a['macro_domain'][j]
  external=math.fsum(x[1]*(x[17+j]+x[22+j]-x[27+j]-(x[12] if j==0 else 0)) for x in rows)
  assert abs(delta-external)<1e-13;domain.append(delta-external)
 # Independent primitive sums must equal real cumulative provider fields.
 for key,col in [('cgrai',2),('cgird',3),('crunon',4),('caintc',5),('cepd',6),('cevap',7),('cqrot',8),('cqbot',9),('cqdra',10),('cqssdi',11),('cqmpoutdrrap',12)]:
  assert abs(L[key][0]-math.fsum(x[1]*x[col] for x in rows))<1e-12,key
 assert abs(L['crunoff'][0]-math.fsum(x[13] for x in rows))<1e-12
 for suffix,ids in [('1',[0]),('2',[1,2,3,4])]:
  for part,col in [('intoplat',17),('intopvrt',22)]:
   assert abs(L['cqmp'+part+'dm'+suffix][0]-math.fsum(x[1]*math.fsum(x[col+j] for j in ids) for x in rows))<1e-12
  exchange=L['cqmpinintsatdm'+suffix][0]+L['cqmpinmtxsatdm'+suffix][0]-L['cqmpoutmtxsatdm'+suffix][0]-L['cqmpoutmtxunsdm'+suffix][0]
  assert abs(exchange+math.fsum(x[1]*math.fsum(x[27+j] for j in ids) for x in rows))<1e-12
 # Native CSV prints opposite-sign residual; allow only its decimal rounding.
 csvrows=list(csv.DictReader(io.StringIO('\n'.join(s for s in (d/'result_output.csv').read_text().splitlines() if s and not s.startswith('*')))))
 assert abs(error+math.fsum(float(x['BALDEV']) for x in csvrows[1:]))<1e-12
 for n in ['checkpoint','ledger_checkpoint']:
  after='after_io' if n=='checkpoint' else 'ledger_after_io';assert (d/(n+'.txt')).read_bytes()==(d/(after+'.txt')).read_bytes()
 assert (d/'context_checkpoint.txt').read_bytes()==(z/'native_installed.txt').read_bytes()
 assert (d/'ledger_checkpoint.txt').read_bytes()==(z/'ledger_installed.txt').read_bytes()
 for n in ['context_begin','context_accepted','ledger_begin','ledger_accepted','accepted']:
  assert (d/(n+'.txt')).read_bytes()==(z/(n+'.txt')).read_bytes()
 buf=(d/'midnight.end').read_bytes();assert buf==(z/'own.end').read_bytes();i=buf.index(b'PATCH_FROM_BALANCE_ORIGIN');origin,end,complete=struct.unpack_from('<ddi',buf,i-20);assert (origin,end,complete)==(35795,35797,1)
 assert f(z/'ledger_begin.txt')['wasrdm1ini']==[b['macro_domain'][0]]
 # BAL's printed storage omits canopy although its sums use gross input minus
 # canopy evaporation. Keep this output-accounting limitation separate.
 ledger_gross=L['cgrai'][0]+L['cgird'][0]+L['crunon'][0]+L['cqbot'][0]+L['cqssdi'][0]-L['caintc'][0]-L['cqrot'][0]-L['cepd'][0]-L['cevap'][0]-L['cqdra'][0]-L['cqmpoutdrrap'][0]-L['crunoff'][0]
 bal_omitting_canopy=matrix+macro+pond-ledger_gross
 assert abs(bal_omitting_canopy+canopy-error)<1e-12
 result.append(dict(optimization=opt,steps=len(rows),old_budget_rows_byte_exact=len(old),recorded_duration_days=duration,period_origin=origin,completed_boundary=end,matrix_change_cm=matrix,macro_change_cm=macro,pond_change_cm=pond,canopy_change_cm=canopy,independent_gross_external_cm=gross,whole_inventory_error_cm=error,net_soil_macro_error_cm=neterror,inherited_total_residual_integral_envelope_cm=envelope,domain_balance_errors_cm=domain,ledger_primitives_verified=True,natural_period_output=True,original_BAL_without_canopy_error_cm=bal_omitting_canopy,native_file_sha256=hashlib.sha256(buf).hexdigest(),complete_history_metadata_readback=True))
for mode in ['PREFIX','RESUME']:
 for p in (R/'data/O0'/mode).glob('*.txt'):assert p.read_bytes()==(R/'data/O2'/mode/p.name).read_bytes(),str(p)
 for name in ['result.bal','result.blc','result.bma','result_output.csv']:
  assert body(R/'data/O0'/mode/name)==body(R/'data/O2'/mode/name)
for opt in ['O0','O2']:
 identity=json.loads((R/(opt+'_IDENTITY.json')).read_text())
 for n,h in identity['sources'].items():assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h
q=json.loads((R/'O2_RESUME_INCOMPLETE_RUN.json').read_text());assert q['returncode']!=0 and 'history coverage mismatch' in q['stderr'];assert not (R/'data/O2/RESUME_INCOMPLETE/ledger_installed.txt').exists()
runs=[json.loads(p.read_text()) for p in R.glob('*_RUN.json')];assert len(runs)==5 and all(not x['censored'] and x['seconds']<20 for x in runs)
q=dict(decision='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',selected_period_water_inventory='PASS_FIXED_CANDIDATE_FROM_ORIGIN_1998_JAN1_THROUGH_JAN2_O0_O2',exact_budget_preservation=True,results=result,native_own_restart='PASS_COMPLETE_HISTORY_AND_FIRST_NEW_PERIOD_STEP_RESET_O0_O2',full_period_natural_BAL_BLC_BMA_event_executed=True,canopy_inclusive_independent_balance=True,original_BAL_presentation='NOT_QUALIFIED_AS_COMPLETE_STORAGE_ACCOUNTING: canopy inventory omitted',model_routes=5,max_seconds=max(x['seconds'] for x in runs),no_censored=True,physics_solver_changes=False,official_promotion=False,exclusions=['No481day/fullscience/othermodes qualification','Original BAL inventory display omits canopy, observed independently; no formatting/physics repair made','No arbitrary V4 origins/periods, later reset metadata lifecycle or whole append/PEARL continuity claim'])
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
