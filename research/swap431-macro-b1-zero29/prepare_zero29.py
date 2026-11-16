"""Three original node52 failures inside the previously measured zero-inflow phase."""
from pathlib import Path
import json
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-select28'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
(R/'zero29.py').write_text((P/'select28.py').read_text().replace('swap431-select28-work','swap431-zero29-work'))
a=[list(map(float,s.split())) for s in (R.parent/'swap431-macro-b1-diag19/data/O2/RESUME/attempt_trace.txt').read_text().splitlines()]
s={}
for label,att in [('E1',54),('E2',279),('E3',50)]:
 x=a[att-1];assert x[8]==4 and x[19]==52 and x[3]>1e-5 and x[4]==0 and x[10]==0
 s[label]=dict(original_attempt=att,prior_commits=int(x[1])-1,time=x[2],dt=x[3],original_max_residual=x[18],original_max_node=x[19],original_extra_line_search_trials=x[24]-x[21])
(R/'SELECTION.json').write_text(json.dumps(s,indent=2)+'\n')
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='74b2482f9af8488e64f1800683d28b4f8c1cc320',selection=s,scope='Final maximum3, revised before E3 as recorded in SCOPE_REVISION.json; E3 starts partially limited in existing LIMIT21',candidate_and_harness_changes=False,routes='O2 trialE1 first; E2 onlyifneeded; O0 confirms; direct onlyif genuine refusal with eligible partial zero inflow branch',bounds='hard20sec perroute,max4originaltargetattempts,stoponscaledrequest,no campaign',qualification_requires='Actual Jacobian iteration with I=0,L<W,partialoutlimit and rank1active, plus real refusal/rollback/direct equality'),indent=2)+'\n')
