from pathlib import Path
import json,math,zipfile,hashlib
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());reports=[]
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);p=b/'GEOMETRYFD33R2_CONTEXT41TO42/original';a=list(map(float,(p/'macro_live_jacobian_fd.txt').read_text().split()));i=0;checks=[];restored=0
 for before in p.glob('replay_fd_*_before_*.bin'):
  after=p/before.name.replace('_before_','_after_');assert before.read_bytes()==after.read_bytes();restored+=1
 assert restored==3
 while i<len(a):
  h=a[i:i+9];i+=9;n=int(h[0]);v=[a[i+k*n:i+(k+1)*n] for k in range(7)];i+=7*n;e=h[3]
  f1=[(x-y)/(2*e) for x,y in zip(v[3],v[4])];f2=[(x-y)/e for x,y in zip(v[5],v[6])]
  e1=max(abs(x-y) for x,y in zip(v[2],f1));e2=max(abs(x-y) for x,y in zip(v[2],f2));worst=max(range(n),key=lambda j:abs(v[2][j]-f2[j]))
  assert max(e1,e2)<=1e-8,(opt,h,e1,e2,worst+1)
  checks.append(dict(time=h[4],dt=h[5],iteration=h[6],column=int(h[2]),Jnorm=max(map(abs,v[2])),error_e=e1,error_half_e=e2,worst_node=worst+1))
 assert len(checks)==3 and i==len(a)
 zz=[zipfile.ZipFile(b/l/'accepted-column-1-day-42.zip') for l in ['GEOMETRYFD33R2_CONTEXT41TO42','GEOMETRY_V33_CONTEXT41TO42']]
 for name in ['macro.bin','result.end']:assert zz[0].read(name)==zz[1].read(name)
 q=json.loads((p.parent/'RESULT.json').read_text());assert q['elapsed_seconds']<20 and q['rows'][0]['committed']
 reports.append(dict(opt=opt,checks=checks,physical25_matrix_flux_restore_exact=True,full_day_native_exact_to_uninstrumented_candidate=True,elapsed_seconds=q['elapsed_seconds']))
out=dict(scope='Actualoldrefusaltime35836.018, deficitbetween1e-6and1e-4, originalinactivegeometry. Threefullcoupledmacrocolumns/twoFDscales, absolute1e-8differentialbound unchanged. Noallregimes/fullperiodclaim.',results=reports,models_launched=0)
(R/'BLOCK33_LIVE_GEOMETRY_DERIVATIVE_QUALIFICATION.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
