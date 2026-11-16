"""Final bounded three-context selection; see preserved SCOPE_REVISION history."""
from pathlib import Path
import json,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-reject26'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
s=(R/'soilwater_native.f90').read_text();old=s
s=s.replace('integer,save :: budget_unit,budget_count=0','integer,save :: budget_unit,budget_count=0,prefix_unit',1)
s=s.replace(' use_patch=.false.\n call start()',' use_patch=.true.\n call start()\n open(newunit=prefix_unit,file=\'prefix_budget.txt\',status=\'replace\')',1)
s=s.replace(' integer::i,u\n handled=.true.',' integer::i,u\n real(8)::selected_time,selected_dt\n character(80)::env_value\n handled=.true.',1)
needle=' if(abs(t1900-35796.9513533331d0)>1d-9.or.abs(dt-2d-5)>1d-14) then\n  call headcalc'
assert needle in s
s=s.replace(needle,''' call get_environment_variable('SELECT27_T',env_value)
 read(env_value,*) selected_time
 call get_environment_variable('SELECT27_DT',env_value)
 read(env_value,*) selected_dt
 accepted_dt=dt
 if(abs(t1900-selected_time)>1d-10.or.abs(dt-selected_dt)>1d-14) then
  call headcalc''',1)
s=s.replace("'REJECT26", "'ACTIVE27")
needle=' if(.not.reject26_pending) return'
assert needle in s
write=''' write(prefix_unit,*) t1900,accepted_dt,graidt,gird,runon,crsflx_out,epd,reva,sum(qrot(1:numnod)),qbot,sum(qdra(1:nrlevs,1:numnod)),sum(qssdi(1:numnod)),sum(QOutDrRapCp(1:numnod)),runots,nraidt,nird,FrReduQ, &
  QInTopLatDm(1:NumDm),QInTopVrtDm(1:NumDm),sum(QExcMtxDmCp(1:NumDm,1:numnod),dim=2)
'''
s=s.replace(needle,''' if(.not.reject26_pending) then
'''+write+'''  return
 end if
 close(prefix_unit)''',1)
(R/'soilwater_native.f90').write_text(s)
(R/'driver_only.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='REJECT26/soilwater_native.f90',tofile='ACTIVE27/soilwater_native.f90')))
s=(P/'reject26.py').read_text().replace('swap431-reject26-work','swap431-active27-work')
s=s.replace("mode=='RESUME'","mode in ['TRIAL','DIRECT']")
needle="env['DAY10_MODE']=mode;"
assert needle in s
s=s.replace(needle,"env['DAY10_MODE']=mode;selected=json.loads((R/'SELECTION.json').read_text())[label];env['SELECT27_T']=format(selected['time'],'.17g');env['SELECT27_DT']=format(selected['dt'],'.17g');",1)
(R/'active27.py').write_text(s)
oldtrace=R.parent/'swap431-macro-b1-diag19/data/O2/RESUME/attempt_trace.txt'
rows=[list(map(float,x.split())) for x in oldtrace.read_text().splitlines()]
selection={}
for label,att in [('C1',624),('C2',3502),('C3',224)]:
 x=rows[att-1];assert x[8]==4 and x[10]==0 and x[3]>1e-5
 selection[label]=dict(original_attempt=att,prior_commits=int(x[1])-1,time=x[2],dt=x[3],original_max_residual=x[18],original_max_node=x[19])
(R/'SELECTION.json').write_text(json.dumps(selection,indent=2)+'\n')
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='ba70d2f2eca6c5112223c0bf50ea94e3723554cc',selection=selection,scope='Final max3 existing DIAG19 contexts; original two plus recorded final earliest-context revision; O0 confirms selection, direct only for suitable active refusal',candidate_changes=False,bounds='Same native35797 original unchanged prefix; original30/60iterations and dt/reduction rules; max4selectedheadattempts, hard20sec perroute; no campaign',qualification_requires='Genuine solver refusal with at least1 active rank1 iteration, physical rollback, equality to direct smaller retry'),indent=2)+'\n')
