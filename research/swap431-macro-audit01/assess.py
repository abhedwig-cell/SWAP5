from pathlib import Path
import json,hashlib,csv,io
R=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
groups=[]
for line in (R/'run-observer/audit_samples.txt').read_text().splitlines():
 k,*v=line.split()
 if k=='META':groups.append({})
 groups[-1][k]=[float(x) for x in v]
assert len(groups)==20
for g in groups:
 assert len(g['OLD_F'])==len(g['NEW_F'])==len(g['OLD_Q'])==len(g['NEW_Q'])==112
 assert max(abs(b-a+d-c) for a,b,c,d in zip(g['OLD_F'],g['NEW_F'],g['OLD_Q'],g['NEW_Q']))==g['EXCHANGE'][1]
 assert all(v==0 for key in ('REPEAT','ROUNDTRIP','REFRESH_STATE') for v in g[key])
 assert max(map(abs,g['OLD_F']))<=g['META'][6]
 assert abs(sum(g['OLD_F']))<=g['META'][7]
fails=[g for g in groups if g['RESIDUAL'][2]>g['META'][6]]
totalfails=[g for g in groups if abs(g['RESIDUAL'][3])>g['META'][7]]
assert len(fails)==16 and len(totalfails)==17
def normalized(p):
 return b'\n'.join(l for l in p.read_bytes().splitlines() if not l.startswith(b'* Generated at:'))
comparisons=[]
for a,b in [('run-control','run-observer'),('run-control-output','run-observer-output')]:
 for name in ['result_output.csv','macrogeom.csv','soilshrinkchar.csv']+(['result.end'] if 'output' in a else []):
  x,y=R/a/name,R/b/name
  equal=x.read_bytes()==y.read_bytes();norm=normalized(x)==normalized(y)
  assert norm,(a,name)
  comparisons.append({'a':a,'b':b,'file':name,'byte_exact':equal,'equal_excluding_only_generation_timestamp':norm,'a_sha256':sha(x),'b_sha256':sha(y)})
def rows(p):
 return list(csv.DictReader(io.StringIO('\n'.join(l for l in p.read_text().splitlines() if not l.startswith('*')))))
initial=rows(R/'run-control/result_output.csv');expanded=rows(R/'run-control-output/result_output.csv')
assert [{k:r[k] for k in initial[0]} for r in expanded]==initial
assert (R/'run-observer/audit_samples.txt').read_bytes()==(R/'run-observer-output/audit_samples.txt').read_bytes()
report={'status':'B0_FROZEN_ACCEPTANCE_INCONSISTENCY_CONFIRMED','baseline':'f2377211d2be58d03d96e50fb0a6bc35ced3c90f',
 'source_sha256':sha(R/'SWAP.ZIP'),'observations':len(groups),'fresh_local_failures':len(fails),'fresh_total_failures':len(totalfails),
 'max_fresh_local':max(g['RESIDUAL'][2] for g in groups),'max_fresh_total_abs':max(abs(g['RESIDUAL'][3]) for g in groups),
 'max_exchange_attribution_remainder':max(g['EXCHANGE'][1] for g in groups),'same_input_repeat_and_roundtrip_exact':True,
 'first_total_failure':totalfails[0],'first_local_failure':fails[0],'worst_local_sample':max(groups,key=lambda g:g['RESIDUAL'][2]),
 'sample_summaries':[{k:v for k,v in g.items() if k not in ['OLD_F','NEW_F','OLD_Q','NEW_Q']} for g in groups],
 'noninterference':comparisons,'expanded_output_preserves_initial_rain_drain_gwl':True,
 'printed_daily_balances':[{k:r[k] for k in ['DATE','BALDEV','MP_BALDEV_1','MP_BALDEV_2']} for r in expanded],
 'runs':json.loads((R/'RUNS.json').read_text()),
 'limitations':['No actual B0 day438 native state tested','No full B0 Jacobian finite difference audit','No rejected timestep replay or general rollback qualification','No qualified B1 patch','No full481 run','Output end file is standard legacy export, not complete SAVE state']}
(R/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['first_total_failure','first_local_failure','worst_local_sample','sample_summaries','noninterference']},indent=2))
