"""Two fixed original high-line-search contexts, with unchanged ACTIVE27 harness."""
from pathlib import Path
import json
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-active27'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
(R/'select28.py').write_text((P/'active27.py').read_text().replace('swap431-active27-work','swap431-select28-work'))
a=[list(map(float,s.split())) for s in (R.parent/'swap431-macro-b1-diag19/data/O2/RESUME/attempt_trace.txt').read_text().splitlines()]
s={}
for label,att in [('D1',2630),('D2',3066)]:
 x=a[att-1];assert x[8]==4 and x[3]>1e-5 and x[4]==0 and x[10]==0
 s[label]=dict(original_attempt=att,prior_commits=int(x[1])-1,time=x[2],dt=x[3],original_max_residual=x[18],original_max_node=x[19],original_extra_line_search_trials=x[24]-x[21])
(R/'SELECTION.json').write_text(json.dumps(s,indent=2)+'\n')
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='dd47bab261c47945437492f26e9fd92e02fe7717',scope='At most2 previously untested original cases, largest extra line-search counts in node57 and node73 groups before0.31day',selection=s,routes='O2 trialD1 first, D2 onlyifneeded; qualifying active refusal gets DIRECT and O0 comparison',candidate_and_harness_changes=False,bounds='Original native35797 prefix unchanged; hard20s perroute,max4originaltargetattempts,stoponscaledrequest,no campaign',qualification_requires='Real refusal with at least1 active rank1 iteration; original rollback and direct smaller retry equality'),indent=2)+'\n')
