#!/usr/bin/env python3
"""Paired checked/production native file-application benchmarks with exact output gates."""
import argparse,csv,hashlib,json,os,resource,statistics,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--before','--checked',dest='before',type=Path,required=True)
 ap.add_argument('--after','--production',dest='after',type=Path,required=True)
 ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--repeat',type=int,default=7);ap.add_argument('--windows',type=int,default=8);a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 bins={k:getattr(a,k).resolve()/'swap5_solute_column'for k in ['before','after']};report=dict(builds={},runs=[],summary=[],scope='Real file application with synthetic scenarios; native CPU/wall includes model input and output, excludes build and Python preparation')
 for k,p in bins.items():
  build=json.loads((p.parent/'build-complete.json').read_text())
  if build['executable_sha256']!=sha(p):raise ValueError('executable identity')
  report['builds'][k]=build
 for n in [4,32,256]:
  text=(ROOT/'examples/solute_column'/('positive_pond.nml'if n==4 else'deep_grid.nml')).read_text()
  if n==256:text=text.replace('nodes=32','nodes=256').replace('cell_thickness_cm=0.5,0.5,1,1,2,3,26*5','cell_thickness_cm=256*1').replace('32*0.2','256*0.2').replace('32*0.0000125','256*0.0000015625')
  ends=','.join(format(.001*(i+1),'.10f')for i in range(a.windows))
  text=text.replace('windows=2','windows='+str(a.windows)).replace('ends_day=0.001,0.002','ends_day='+ends)
  for field,value in [('rain_cm_day','0.25'),('irrigation_cm_day','0.25'),('runon_cm_day','0.5'),('evaporation_cm_day','0.05')]:
   text=text.replace(field+'='+value+','+value,field+'='+str(a.windows)+'*'+value)
  source=out/f'input-{n}.nml';source.write_text(text)
  for repeat in range(a.repeat):
   for arm in (['before','after']if repeat%2==0 else['after','before']):
    b=out/f'{n}-{repeat}-{arm}';b.mkdir();before=resource.getrusage(resource.RUSAGE_CHILDREN);t=time.monotonic();p=subprocess.run([str(bins[arm]),str(source),'-',str(a.windows)],cwd=b,capture_output=True,preexec_fn=lambda:os.sched_setaffinity(0,{max(os.sched_getaffinity(0))}),timeout=90);wall=time.monotonic()-t;after=resource.getrusage(resource.RUSAGE_CHILDREN)
    (b/'stdout').write_bytes(p.stdout);(b/'stderr').write_bytes(p.stderr)
    rec=dict(nodes=n,arm=arm,repeat=repeat,exit=p.returncode,wall=wall,cpu=after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime)
    if p.returncode:report['failure']=dict(record=rec,stderr=p.stderr.decode(),stdout=p.stdout.decode());(out/'CONTROL.json').write_text(json.dumps(report,indent=2));raise RuntimeError(str(b))
    rec['files']={f:sha(b/f)for f in ['budget.csv','state.csv','endpoint.csv','restart.bin']};budget=list(csv.DictReader((b/'budget.csv').open()));rec['accepted_substeps']=sum(int(x['accepted_substeps'])for x in budget)
    report['runs'].append(rec);(out/'CONTROL.json').write_text(json.dumps(report,indent=2))
  rr=[x for x in report['runs']if x['nodes']==n];row=dict(nodes=n,windows=a.windows,days=.001*a.windows,byte_exact=all(x['files']==rr[0]['files']for x in rr),accepted_substeps=sorted({x['accepted_substeps']for x in rr}))
  if not row['byte_exact']:raise RuntimeError('physical output mismatch')
  for arm in bins:
   r=[x for x in rr if x['arm']==arm];row[arm]={k:dict(median=statistics.median(x[k]for x in r),min=min(x[k]for x in r),max=max(x[k]for x in r))for k in ['cpu','wall']}
  row['speedup']=row['before']['cpu']['median']/row['after']['cpu']['median'];report['summary'].append(row);(out/'CONTROL.json').write_text(json.dumps(report,indent=2));print(json.dumps(row),flush=True)
if __name__=='__main__':main()
