"""Read-only live macro differential test, restoration and native preservation."""
from pathlib import Path
import json,math,zipfile,hashlib
R=Path('integration/macro-complete01');res=json.loads((R/'RESOURCE_PATHS.json').read_text());reports=[]
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])
 for label in ['JACOBIAN15_COLD2','JACOBIAN15R1_COLD2','JACOBIAN15R1_OWN2TO3']:
  p=b/label/'original';a=list(map(float,(p/'macro_live_jacobian_fd.txt').read_text().split()));i=0;checks=[]
  for before in p.glob('replay_fd_*_before_*.bin'):
   after=p/before.name.replace('_before_','_after_');assert before.read_bytes()==after.read_bytes()
  while i<len(a):
   h=a[i:i+9];i+=9;n=int(h[0]);v=[a[i+k*n:i+(k+1)*n] for k in range(7)];i+=7*n;e=h[3]
   f1=[(x-y)/(2*e) for x,y in zip(v[3],v[4])];f2=[(x-y)/e for x,y in zip(v[5],v[6])]
   err1=max(abs(x-y) for x,y in zip(v[2],f1));err2=max(abs(x-y) for x,y in zip(v[2],f2));worst=max(range(n),key=lambda j:abs(v[2][j]-f2[j]))
   checks.append(dict(kind=int(h[1]),col=int(h[2]),time=h[4],dt=h[5],conductivity_policy=int(h[7]),Jnorm=max(map(abs,v[2])),error_e=err1,error_half_e=err2,worst_node=worst+1,head=v[0][worst],theta=v[1][worst]))
  rr=json.loads((b/label/'RESULT.json').read_text());assert rr['status'] in ['FRESH_WINDOW_COMPLETE','OWN_RESTART_WINDOW_COMPLETE'] and rr['elapsed_seconds']<20
  day=2 if label.endswith('COLD2') else 3;original='KINK_V13_COLD2' if day==2 else 'KINK_V13_OWN2TO3'
  z=[zipfile.ZipFile(b/l/('accepted-column-1-day-'+str(day)+'.zip')) for l in [label,original]]
  for name in ['macro.bin','result.end']:assert z[0].read(name)==z[1].read(name)
  compiler_delta=0.
  if opt=='O2':
   other=list(map(float,(Path(res['O0']['path'])/label/'original/macro_live_jacobian_fd.txt').read_text().split()));assert len(other)==len(a)
   for x,y in zip(a,other):
    compiler_delta=max(compiler_delta,abs(x-y));assert abs(x-y)<=2*max(math.ulp(x),math.ulp(y))
  reports.append(dict(opt=opt,label=label,probe_physical25_matrix_flux_and_native_exact=True,max_compiler_trace_delta=compiler_delta,checks=checks))
out=dict(decision='LOCAL_UNSATURATED_DARCY_JACOBIAN_GAP_FOUND_NOT_BLANKET_PASS',cause='At35797.514,col46,H=-1.071608942,thetaS-theta=7.98e-7, observed derivative gap7.56495e-6. Original ABSORPTION2 Darcy derivative -Q/DelH omits the moisture-dependent SorpFac derivative. K frozen SWKIMPL0; current volume geometry fixed at this near-saturated deficit. Contact and saturated normalization/surface columns otherwise agree to <=6.63e-10.',negative_control='Original initial hydrostatic state has zero actual gradient inside1e-8 flow deadband.1e-5 perturbation crosses deadband/flow reversal; retained as excluded nonsmooth test, not a local derivative failure or PASS.',results=reports,models_launched=0)
(R/'BLOCK15_LIVE_JACOBIAN_ASSESSMENT.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(dict(decision=out['decision'],restoration_and_native_exact=True,contexts=len(reports))))
