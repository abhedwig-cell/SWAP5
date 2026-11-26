"""Build a source-bound observer-only variant of current valid worker; no models."""
from pathlib import Path
import os,sys,json,copy,shutil,subprocess,time,traceback
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01'
os.environ['PATH']=r'C:\msys64\ucrt64\bin;C:\Program Files\Git\cmd;'+os.environ.get('PATH','')
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(Path(__file__).resolve().parent)]
import daily_host as h
import coupled_macro_policy as c
from coupled_refusal_observer_v6 import render_head
opt=sys.argv[1];res=json.loads((R/'RESOURCE_PATHS.json').read_text());ref=Path(res['O2']['path'])/'original-worker-reference';base=Path(res[opt]['path'])/'worker-coupled-dtmin-v6';out=Path(res[opt]['path'])/'worker-dtmin-observer07'
q=dict(opt=opt,status='RUNNING',models_launched=0);t=time.perf_counter()
try:
 meta,case=c.validate_bundle(base,ref);shutil.copytree(base,out);meta=copy.deepcopy(meta)
 p=out/'headcalc.f90';p.write_text(render_head(p.read_text()),encoding='cp1252');flags=meta['identity']['coupled_macro']['owner_flags'];obj=ref/'build/swap-obj';tt=ref/'build/ttutil-obj'
 commands=[['gfortran',*flags,'-I',str(obj),'-I',str(tt),'-c','headcalc.f90']]
 repl={Path(n).with_suffix('.o').name:out/Path(n).with_suffix('.o').name for n in meta['identity']['donor_generated']}
 commands.append(['gfortran','-o',str(h.executable(out,'day_donor')),*(str(repl.get(p.name,p)) for p in sorted(obj.glob('*.o'))),str(out/'macro_stock_rank2.o'),str(out/'hybrid_step_budget.o'),str(tt/'libttutil.a')])
 logs=[]
 for cmd in commands:
  p=subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=45);logs.append(dict(command=cmd,code=p.returncode,stdout=p.stdout,stderr=p.stderr));(out/'OBSERVER_BUILD.json').write_text(json.dumps(logs,indent=2)+'\n');assert p.returncode==0,p.stderr
 meta['identity']['donor_generated']['headcalc.f90']=h.sha(out/'headcalc.f90')
 for field in ['coupled_macro','macro_policy']:
  key='owner_objects_sha256' if field=='coupled_macro' else 'objects_sha256';meta['identity'][field][key]['headcalc.o']=h.sha(out/'headcalc.o')
 meta['identity']['observer']=dict(source_sha256=h.sha(Path(__file__).with_name('coupled_refusal_observer_v6.py')),builder_sha256=h.sha(Path(__file__)),parent_donor_sha256=h.sha(h.executable(base,'day_donor')),pure_observer=True,provider_probes=0,scope='Only35797.504..506; no scientific or budget policy change')
 meta['binding']['build']=copy.deepcopy(meta['identity']);meta['executable_sha256']['donor']=h.sha(h.executable(out,'day_donor'));(out/'BUILD.json').write_text(json.dumps(meta,indent=2)+'\n');c.validate_bundle(out,ref);q['status']='BUILT_SOURCE_BOUND_PURE_OBSERVER'
except Exception:q.update(status='FAILED',error=traceback.format_exc())
q['seconds']=time.perf_counter()-t;(R/('OBSERVER07_'+opt+'_BUILD.json')).write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q));sys.exit(1 if q['status']=='FAILED' else 0)
