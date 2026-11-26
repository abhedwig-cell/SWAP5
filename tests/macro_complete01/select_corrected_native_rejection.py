from pathlib import Path
import json,collections
R=Path('integration/macro-complete01');r=json.loads((R/'RESOURCE_PATHS.json').read_text());b=Path(r['O2']['path']);out=[]
for label in ['LOCALDARCY_V16_COLD2','LOCALDARCY_V16_OWN2TO3']:
 p=b/label/'original/jac37_trace.txt';groups=collections.OrderedDict()
 for l in p.read_text().splitlines():
  x=list(map(float,l.split()));groups.setdefault((x[0],x[1]),[]).append(x)
 keys=list(groups)
 for i,key in enumerate(keys[:-1]):
  tr=groups[key];nxt=keys[i+1]
  if nxt[0]!=key[0] or nxt[1]>=key[1] or max(x[2] for x in tr)<30:continue
  active=[x for x in tr if x[3]==1 and x[4]>0];v=[x for x in active if x[7]==1 or x[8]==1]
  if v:out.append(dict(label=label,time=key[0],dt=key[1],retry_dt=nxt[1],iterations=max(x[2] for x in tr),active=len(active),V=len(v)))
print(json.dumps(out[:12]));(R/'BLOCK17_REJECTION_SELECTION.json').write_text(json.dumps(dict(source='Actual V16 current O2 iteration traces; selection only, rollback/directretry not yet qualified',candidates=out),indent=2)+'\n')
