"""Qualification-only natural rejection and direct smaller-proposal harness."""
from pathlib import Path
import os,sys,json,copy,shutil,subprocess,time,traceback,re
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01'
os.environ['PATH']=r'C:\msys64\ucrt64\bin;C:\Program Files\Git\cmd;'+os.environ.get('PATH','')
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(Path(__file__).resolve().parent)]
import daily_host as h
import coupled_macro_policy as c
from donor_sources import replace
from macro_trial_origin import PHYSICAL_FIELDS
opt=sys.argv[1];res=json.loads((R/'RESOURCE_PATHS.json').read_text());ref=Path(res['O2']['path'])/'original-worker-reference';base=Path(res[opt]['path'])/'worker-coupled-stock-kink-v13';out=Path(res[opt]['path'])/'worker-live-jacobian-v15r1'
q=dict(opt=opt,status='RUNNING',models_launched=0);t=time.perf_counter()
try:
 meta,case=c.validate_bundle(base,ref);shutil.copytree(base,out);meta=copy.deepcopy(meta)
 from coupled_jacobian_probe import render_head
 p=out/'headcalc.f90';p.write_text(render_head(p.read_text()))
 definitions={}
 src=(out/'macropore.f90').read_text().split('contains',1)[0]+'\n'+(ref/'build/swap-selected/variables.f90').read_text(encoding='cp1252').split('module MOD_swap_mp\n',1)[1].split('end module',1)[0]
 for line in src.splitlines():
  m=re.match(r'\s*(real\(8\)|integer|logical)\s*,(.*?)save\s*::\s*(\w+)\s*=',line,re.I)
  if m:
   dims=re.search(r'dimension\(([^)]+)\)',m[2],re.I);definitions[m[3].lower()]=(m[1],dims[1].lower().split(',') if dims else [])
 writes=[];layout=[]
 for name in PHYSICAL_FIELDS:
  kind,dims=definitions[name.lower()];section='('+','.join('1:'+{'madm':'NumDm','macp':'NumNod'}[d] for d in dims)+')' if dims else ''
  writes.append('write(u)'+name+section);layout.append(dict(name=name,kind=kind,shape=dims))
 s=Path(__file__).with_name('native_rejection_probe.f90').read_text().replace('@PHYSICAL_WRITES@','\n'.join(writes));(out/'native_rejection_probe.f90').write_text(s)
 (out/'REPLAY_PHYSICAL_LAYOUT.json').write_text(json.dumps(layout,indent=2)+'\n')
 flags=meta['identity']['coupled_macro']['owner_flags'];obj=ref/'build/swap-obj';tt=ref/'build/ttutil-obj'
 meta['identity']['donor_generated']['native_rejection_probe.f90']=h.sha(out/'native_rejection_probe.f90')
 commands=[['gfortran',*flags,'-I',str(obj),'-I',str(tt),'-c',n] for n in ['headcalc.f90','native_rejection_probe.f90']]
 repl={Path(n).with_suffix('.o').name:out/Path(n).with_suffix('.o').name for n in meta['identity']['donor_generated']}
 commands.append(['gfortran','-o',str(h.executable(out,'day_donor')),*(str(repl.get(p.name,p)) for p in sorted(obj.glob('*.o'))),str(out/'macro_stock_rank2.o'),str(out/'macro_stock_complete.o'),str(out/'native_rejection_probe.o'),str(out/'hybrid_step_budget.o'),str(tt/'libttutil.a')])
 logs=[]
 for cmd in commands:
  p=subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=45);logs.append(dict(command=cmd,code=p.returncode,stdout=p.stdout,stderr=p.stderr));(out/'REPLAY_BUILD.json').write_text(json.dumps(logs,indent=2)+'\n');assert p.returncode==0,p.stderr
 for n in ['headcalc.f90','native_rejection_probe.f90']:meta['identity']['donor_generated'][n]=h.sha(out/n)
 for field in ['coupled_macro','macro_policy']:
  key='owner_objects_sha256' if field=='coupled_macro' else 'objects_sha256'
  for n in ['headcalc.o','native_rejection_probe.o']:meta['identity'][field][key][n]=h.sha(out/n)
 meta['identity']['observer']=dict(builder_sha256=h.sha(Path(__file__)),probe_sha256=h.sha(Path(__file__).with_name('native_rejection_probe.f90')),parent_donor_sha256=h.sha(h.executable(base,'day_donor')),pure_observer=True,qualification_only=True,renderer_sha256=h.sha(Path(__file__).with_name('coupled_jacobian_probe.py')),scope='First current eligible negative contact, positive surface and stock states only; 3columns at2finite-difference scales; no criterion/physics changes; exact restoration required')
 meta['binding']['build']=copy.deepcopy(meta['identity']);meta['executable_sha256']['donor']=h.sha(h.executable(out,'day_donor'));(out/'BUILD.json').write_text(json.dumps(meta,indent=2)+'\n');c.validate_bundle(out,ref);q['status']='BUILT_SOURCE_BOUND_QUALIFICATION_HARNESS'
except Exception:q.update(status='FAILED',error=traceback.format_exc())
q['seconds']=time.perf_counter()-t;(R/('JACOBIAN15R1_'+opt+'_BUILD.json')).write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q));sys.exit(1 if q['status']=='FAILED' else 0)
