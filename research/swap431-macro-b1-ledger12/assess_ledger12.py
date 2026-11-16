from pathlib import Path
import json,math,hashlib
R=Path(__file__).resolve().parent
# Reuse source-bound physical/dayphase/inventory assertions without rerunning models.
prior=(R.parent/'swap431-macro-b1-midnight11/assess_mid11.py').read_text();exec(compile(prior[:prior.index("for label in ['PHASE'")],str(R/'assess_ledger12.py'),'exec'))
physical_results=results
f=lambda p:{s.split()[0].lower():list(map(float,s.split()[1:])) for s in p.read_text().splitlines()}
checks=[]
for opt in ['O0','O2']:
 c=R/'data'/opt/'CONTINUE';r=R/'data'/opt/'RESUME'
 assert (c/'ledger_checkpoint.txt').read_bytes()==(r/'ledger_installed.txt').read_bytes()
 for n in ['ledger_begin','ledger_accepted']:
  assert (c/(n+'.txt')).read_bytes()==(r/(n+'.txt')).read_bytes()
 assert (c/'ledger_checkpoint.txt').read_bytes()==(c/'ledger_after_io.txt').read_bytes()
 for d in [c,r]:
  assert (d/'ledger_accepted.txt').read_bytes()==(d/'ledger_after_render.txt').read_bytes()
  a=f(d/'ledger_begin.txt');b=f(d/'ledger_accepted.txt');t=f(d/'returned.txt');dt=t['controls'][1]
  assert abs(b['cqbot'][0]-a['cqbot'][0]-dt*t['boundary_rates'][1])<1e-13
  assert abs(b['cqdra'][0]-a['cqdra'][0]-dt*math.fsum(t['matrix_drains']))<1e-13
  assert abs(b['cqmpoutdrrap'][0]-a['cqmpoutdrrap'][0]-dt*math.fsum(t['macro_rapid']))<1e-13
  net=0
  for suffix in ['1','2']:
   for part,sign in [('inintsat',1),('inmtxsat',1),('outmtxsat',-1),('outmtxuns',-1)]:
    k='cqmp'+part+'dm'+suffix;net+=sign*(b[k][0]-a[k][0])
  assert abs(net+dt*math.fsum(t['macro_exchange']))<1e-13
 def body(d):return '\n'.join(x for x in (d/'ledgerprobe.bma').read_text().splitlines() if not x.startswith('* Generated at:'))
 assert body(c)==body(r)
 # No earlier totals are invented: the inherited file lacks original initial stocks.
 assert f(c/'ledger_checkpoint.txt')['wasrdm1ini']==[0.]
 checks.append(dict(optimization=opt,ledger_fields=132,install_begin_accepted_exact=True,BMA_body_exact_excluding_wall_clock=True,primitive_ledger_increments_verified=True))
# The explicit wet-wall owner preserves the old continuous compiler result.
a=f(R/'data/O2/CONTINUE/ledger_accepted.txt');b=f(R/'preliminary-shadow/data/O2/CONTINUE/ledger_accepted.txt');assert all(a[k]==b[k] for k in b)
q=json.loads((R/'O2_RESUME_OLD_RUN.json').read_text());assert q['returncode']!=0 and 'required history absent' in q['stderr'];assert not (R/'data/O2/RESUME_OLD/ledger_installed.txt').exists()
runs=[json.loads(p.read_text()) for p in R.glob('*_RUN.json')];assert len(runs)==5 and all(not q['censored'] and q['seconds']<20 for q in runs)
q=dict(decision='B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS',local_numeric_water_output_continuity='PASS_SAME_MIDNIGHT_ONE_STEP_O0_O2',full_original_period_cumulative_validity='NOT_QUALIFIED_INHERITED_PREBOOTSTRAP_HISTORY_MISSING',physical_results=physical_results,ledger_checks=checks,output_memory_correction='Explicit FrMpWalWetIntegralOld replaces local shadow; original continuous result preserved',format='V3 with separate required 132-field ledger block; old payload rejected when ledger restoration requested',model_routes=5,preliminary_routes=4,max_seconds=max(x['seconds'] for x in runs),physics_solver_changes=False,official_promotion=False,exclusions=['No reconstruction of lost original-run cumulative history or valid full-period BMA balance claim','No byte-append/full CSV BAL BLC/PEARL integration or timestamp continuity claim','Only selected five-domain completed-day case and one nextday step; no other modes/full campaigns'])
(R/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2))
