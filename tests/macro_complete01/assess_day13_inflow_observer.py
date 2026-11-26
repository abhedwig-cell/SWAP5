from pathlib import Path
import json,zipfile,hashlib
R=Path('integration/macro-complete01');res=json.loads((R/'RESOURCE_PATHS.json').read_text());proof=[]
for o in ['O0','O2']:
 b=Path(res[o]['path']);z=[zipfile.ZipFile(b/l/'accepted-column-1-day-12.zip') for l in ['OBSERVER19_DAY12','LOCALDARCY_V16_PERIOD_DAY12']]
 for n in ['macro.bin','result.end']:assert z[0].read(n)==z[1].read(n)
 p=b/'OBSERVER19_OWN12TO13/original/coupled_refusal_observer.txt';lines=p.read_text().splitlines();st=[]
 for i in range(0,len(lines),9):
  h=lines[i].split()
  if h[0]!='1':continue
  c=list(map(float,lines[i+2].split()))[11:];st.append((h,[c[d*24:(d+1)*24] for d in range(5)]))
 partial=sum(0<c[0][7]<1 for h,c in st);h,c=st[-1];assert float(h[1])==35807.612560747817 and c[0][7]==0 and all(d[15]==1 for d in c)
 proof.append(dict(opt=o,source_bound_observer_prefix12_native_exact=True,original_refusal_time=float(h[1]),partial_D1_inflow_Jacobian_states=partial,last_D1_FrIn=c[0][7],last_D1_FrOut=c[0][15],last_maximum_storage=c[0][2],last_accepted_D1_storage=c[0][0]))
a=Path(res['O0']['path'])/'OBSERVER19_OWN12TO13/original/coupled_refusal_observer.txt';b=Path(res['O2']['path'])/'OBSERVER19_OWN12TO13/original/coupled_refusal_observer.txt';assert a.read_bytes()==b.read_bytes()
(R/'BLOCK19_INFLOW_DIAGNOSIS.json').write_text(json.dumps(dict(models_launched=0,results=proof,causal_scope='Original max-storage inflow projection with omitted nonlocal gradient; no physical threshold change. Observer20s approachcensors retained honestly, own12->13 realrefusal observed.',O0_O2_operator_traces_exact=True),indent=2)+'\n');print(json.dumps(proof))
