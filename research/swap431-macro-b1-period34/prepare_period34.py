from pathlib import Path
import json,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-trajectory33'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
s=(R/'diag_state.f90').read_text();assert 'done=steps>=512.or.elapsed>=16d0.or.t1900>=35797.125d0' in s
s=s.replace('done=steps>=512.or.elapsed>=16d0.or.t1900>=35797.125d0','done=elapsed>=16d0.and.t1900<35798d0')
(R/'diag_state.f90').write_text(s)
s=(R/'soilwater_native.f90').read_text()
needle=" handled=.true.\n call get_environment_variable('DAY10_MODE',mode)"
assert s.count(needle)==1
s=s.replace(needle,""" handled=.true.
 if(.not.period_begin_done) then
  period_begin_done=.true.
  call inventory_dump('begin')
  call native09_dump('context_begin')
  call ledger12_dump('ledger_begin')
 end if
 call get_environment_variable('DAY10_MODE',mode)""",1)
s=s.replace("if(commit()) call finish33('BOUNDED_CANDIDATE_TRAJECTORY')","if(commit()) call finish33('INTERNAL_BUDGET_BEFORE_PERIOD_END')")
old="""  if(budget_open) close(budget_unit)
  open(newunit=u,file='outcome.txt',status='replace');write(u,*) 'NEXT18_PERIOD_COMPLETE';close(u)
  stop 0"""
assert old in s;s=s.replace(old,"  call finish33('CANDIDATE_PERIOD_COMPLETE')",1)
(R/'soilwater_native.f90').write_text(s)
(R/'period34.py').write_text((P/'trajectory33.py').read_text().replace('swap431-trajectory33-work','swap431-period34-work'))
patch=''
for p in P.glob('*.f90'):
 if p.read_bytes()!=(R/p.name).read_bytes():patch+=''.join(difflib.unified_diff(p.read_text().splitlines(True),(R/p.name).read_text().splitlines(True),fromfile='TRAJECTORY33/'+p.name,tofile='PERIOD34/'+p.name))
(R/'period_observation_only.patch').write_text(patch)
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='6406eacea39de3aa533a39669f59453fc7536ae0',remote_main='be481cfb40f953e337116ef4a6dc5bc3ef64d4f7',workstream='isolated SWAP431 B1 research',scope='ONE fixed next balanceperiod originalnative35797->35798, own continuous candidate, O0/O2 hard20s each. Internal16s budget stop preserved, firstactivefailure/scaledrequest stops. No other period, no broad campaign, no own restart in this round.',candidate_and_physical_rules='All numericalcandidate arithmetic/guards/freshV1/MAXIT/tolerances/dt/reduction unchanged. Only observationhorizon and firstpostresetledger capture differ from TRAJECTORY33.',changes='diag_state observationend removes short512step/.125day cutoff for explicitfullperiod, keeps16sinternal20sexternal; soilwater_driver firstheadperiodbegin snapshot, full endpointstop AFTER natural BAL/CSV output. Originalphysics/host/outputcode unchanged.',failure_contract='Same firstactualactiverank1 refusal stop+physicalrollback. ConditionalTRIAL andDIRECT bothopts with originalTimeControl5, no forcedrefusal, max4targetattempts,20s each. Only if event.',qualification_requires='Exact postresetbeginledger with nonzeroSICINI, O0/O2 sameprefix/end, perstep+fullperiodphysicalinventories, primitivefluxledger/BALstorage+flux/CSV balance, originaldtCrit envelope. If censored/noendpoint no periodPASS.',protected='B0/B1.12/canonical/no-macrorelease unaffected; no nativeformat/restart/admission change',official_promotion=False),indent=2)+'\n')
