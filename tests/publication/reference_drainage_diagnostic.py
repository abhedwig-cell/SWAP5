"""Private post-solve diagnostic availability witness; no original gate changes."""
import argparse,json,os,re,subprocess
from pathlib import Path
import reference_drainage_build as g
import reference_drainage_evidence as e

def execute(original,out,compiler):
 g.guard(); e.verify(g.ROOT/'integration/dataqual15_hupsel/REFERENCE_DRAINAGE_BUILD_WINDOWS_20261107')
 r=json.loads((original/'RESULT.json').read_text()); sources,flags,test=g.recipe('bc_sweeps')
 out.mkdir(parents=True,exist_ok=False); source=g.normalized((g.ROOT/test).read_bytes()).decode()
 anchor='      call residual_diagnostics(workspace,'; assert source.count(anchor)==2
 mask=lambda b:re.sub(rb'\|BAL=-?\d+\|HEAD=-?\d+',b'|BAL=OBSERVED|HEAD=OBSERVED',b)
 expected=None;events=[];rows=[]
 for opt in ('O0','O2'):
  row=r['results']['bc_sweeps']['optimizations'][opt]; base=(original/row['stdout']).read_bytes()
  if expected is None:expected=mask(base)
  assert mask(base)==expected
  build=original/('bc_sweeps-'+opt); objects=[]
  for binding in row['providers']:
   p=original/binding['object'];assert g.sha(p.read_bytes())==binding['object_sha256'];assert g.sha((g.ROOT/binding['source']).read_bytes())==binding['sha256'];objects.append(p)
  for value in ('false','true'):
   private=out/(opt+'-'+value+'.f90'); block='      workspace%richards%nonconverged_balance = .'+value+'.\n      workspace%richards%nonconverged_head = .'+value+'.\n'
   modified=source.replace(anchor,block+anchor);assert modified.replace(block,'')==source;private.write_text(modified)
   obj=private.with_suffix('.o');exe=private.with_suffix('.exe' if os.name=='nt' else '')
   commands=[[compiler,*flags,'-'+opt,'-J',str(build),'-I',str(build),'-c',str(private),'-o',str(obj)],[compiler,'-fopenmp','-'+opt,*map(str,objects),str(obj),'-o',str(exe)],[str(exe)]]
   for cmd in commands:
    cp=subprocess.run(cmd,cwd=g.ROOT,capture_output=True,timeout=120);stem=str(len(events)).zfill(3)
    (out/(stem+'.stdout')).write_bytes(cp.stdout);(out/(stem+'.stderr')).write_bytes(cp.stderr);events.append(dict(command=cmd,returncode=cp.returncode));assert cp.returncode==0,cp.stderr[-2000:]
   g.validate_output('bc_sweeps',cp.stdout);assert mask(cp.stdout)==expected
   counts=re.findall(rb'\|BAL=(\d+)\|HEAD=(\d+)',cp.stdout);assert len(counts)==55 and all(a==b and (int(a)>0)==(value=='true') for a,b in counts)
   rows.append(dict(optimization=opt,poison=value,observations=55,counts=sorted(set((int(a),int(b))for a,b in counts)),masked_output_sha256=g.sha(mask(cp.stdout)),private_source_sha256=g.sha(private.read_bytes()),executable_sha256=g.sha(exe.read_bytes())))
 (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
 result=dict(status='PRIVATE_POST_SOLVE_OBSERVER_DEPENDENCE_CONFIRMED',head=g.git('rev-parse','HEAD'),original_head=r['head'],rows=rows,original_gate_failures_retained=True,production_admission=False,whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--original',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',required=True);a=p.parse_args();os.environ['OMP_NUM_THREADS']='1';execute(a.original.resolve(),a.output.resolve(),a.compiler)
