"""Pure read-only Jacobian-file observer for constraint and budget diagnosis."""
from pathlib import Path
import sys,os,json,copy,shutil,subprocess,time,traceback
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';os.environ['PATH']=r'C:\msys64\ucrt64\bin;C:\Program Files\Git\cmd;'+os.environ.get('PATH','');sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from coupled_macro_policy import validate_bundle
from donor_sources import replace
opt=sys.argv[1];res=json.loads((R/'RESOURCE_PATHS.json').read_text());ref=Path(res['O2']['path'])/'original-worker-reference';base=Path(res[opt]['path'])/'worker-coupled-domain1-two-sided-v25';out=Path(res[opt]['path'])/'worker-ordinary-absorption-observer26';q=dict(opt=opt,status='RUNNING',models_launched=0);started=time.perf_counter()
try:
 meta,case=validate_bundle(base,ref);shutil.copytree(base,out);meta=copy.deepcopy(meta)
 p=out/'macro_stock_rank2.f90';s=p.read_text().replace('\r\n','\n');s=replace(s,'call macro_saturated_data(cm,pot,pu,valid);meta(15)=valid;meta(1)=-2\nif(valid/=1d0)return','call macro_saturated_data(cm,pot,pu,valid);meta(15)=valid;meta(1)=-2\nif(valid/=1d0)return\ncall observe_constraint_budget(n,cm)');s+='\n'+Path(__file__).with_name('ordinary_absorption_probe.f90').read_text();p.write_text(s)
 obj=ref/'build/swap-obj';tt=ref/'build/ttutil-obj';flags=meta['identity']['coupled_macro']['owner_flags'];repl={Path(n).with_suffix('.o').name:out/Path(n).with_suffix('.o').name for n in meta['identity']['donor_generated']}
 commands=[['gfortran',*flags,'-I',str(obj),'-I',str(tt),'-c','macro_stock_rank2.f90'],['gfortran','-o',str(h.executable(out,'day_donor')),*(str(repl.get(p.name,p)) for p in sorted(obj.glob('*.o'))),str(out/'macro_stock_rank2.o'),str(out/'macro_stock_complete.o'),str(out/'hybrid_step_budget.o'),str(tt/'libttutil.a')]]
 logs=[]
 for cmd in commands:
  p=subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=45);logs.append(dict(command=cmd,code=p.returncode,stdout=p.stdout,stderr=p.stderr));(out/'OBSERVER_BUILD.json').write_text(json.dumps(logs,indent=2)+'\n');assert p.returncode==0,p.stderr
 meta['identity']['donor_generated']['macro_stock_rank2.f90']=h.sha(out/'macro_stock_rank2.f90')
 for field in ['coupled_macro','macro_policy']:
  key='owner_objects_sha256' if field=='coupled_macro' else 'objects_sha256';meta['identity'][field][key]['macro_stock_rank2.o']=h.sha(out/'macro_stock_rank2.o')
 meta['identity']['observer']=dict(pure_observer=True,probe_sha256=h.sha(Path(__file__).with_name('ordinary_absorption_probe.f90')),builder_sha256=h.sha(Path(__file__)),parent_donor_sha256=h.sha(h.executable(base,'day_donor')),physical_writes=False,scope='Read-only original ordinaryunsaturated absorption above currentGWLcell whileoutfactorpartial, plusD1/budgetcontext; bounded64+64+128records')
 meta['binding']['build']=copy.deepcopy(meta['identity']);meta['executable_sha256']['donor']=h.sha(h.executable(out,'day_donor'));(out/'BUILD.json').write_text(json.dumps(meta,indent=2)+'\n');validate_bundle(out,ref);q['status']='BUILT_SOURCE_BOUND_READ_ONLY_OBSERVER'
except Exception:q.update(status='FAILED',error=traceback.format_exc())
q['seconds']=time.perf_counter()-started;(R/('OBSERVER26_'+opt+'_BUILD.json')).write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q));raise SystemExit(1 if q['status']=='FAILED' else 0)
