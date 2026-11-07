"""Independent current source, compiler-command and original-output audit."""
import argparse,functools,hashlib,io,json,lzma,struct,subprocess,tarfile
from pathlib import Path,PureWindowsPath,PurePosixPath
import reference_drainage_build as g
sha=g.sha
@functools.lru_cache(maxsize=None)
def origin(ref,path):return g.raw(ref,path)
def audit(files):
 r=json.loads(files['RESULT.json']);assert r['baseline']==g.BASE and r['production_admission']is False and r['whole_scientific_admission']is False
 if subprocess.run(['git','cat-file','-e',r['head']+'^{commit}'],cwd=g.ROOT,capture_output=True).returncode:subprocess.run(['git','fetch','--no-tags','origin',r['head']],cwd=g.ROOT,check=True,capture_output=True)
 assert r['production_trees']=={a:g.git('rev-parse',r['head']+':'+a)for a in('src','app','reference')}=={a:g.git('rev-parse',g.BASE+':'+a)for a in('src','app','reference')}
 for p,h in r['script_sha256'].items():assert sha(origin(r['head'],p))==h and origin(r['head'],p)==g.postimage(p)
 events=json.loads(files['EVENTS.json']);assert len(events)==200;cursor=0;all_pass=True
 q=PureWindowsPath if r['platform']=='WINDOWS'else PurePosixPath
 for case in g.SCRIPTS:
  sources,flags,test=g.recipe(case);rows=r['results'][case]['optimizations'];stdout={}
  for opt in('O0','O2'):
   row=rows[opt];assert row['provider_count']==47 and len(row['providers'])==47
   first=events[cursor];build=q(first['command'][-1]).parent;out=build.parent;repo=q(first['command'][first['command'].index('-c')+1])
   for _ in Path(sources[0]).parts:repo=repo.parent
   def check_event(expected,label):
    nonlocal cursor
    e=events[cursor];cursor+=1;assert e['label']==label and e['command']==list(map(str,expected))
    assert e['stdout']in files and e['stderr']in files
    if label!='original-test':assert e['returncode']==0
    return e
   compiler=first['command'][0];objects=[]
   for source,binding in zip(sources,row['providers']):
    assert binding['source']==source;raw=files['source-snapshots/'+source];assert sha(raw)==binding['sha256']and g.normalized(raw)==origin(g.BASE,source)==origin(r['head'],source)
    obj=build/(Path(source).stem+'.o');assert binding['object']==obj.relative_to(out).as_posix()and sha(files[binding['object']])==binding['object_sha256'];objects.append(obj)
    extra=['-Wno-error=unused-dummy-argument']if source=='src/solver/mod_soil_water_solver_contract.f90'else[]
    check_event([compiler,*flags,*extra,'-'+opt,'-J',build,'-I',build,'-c',repo/source,'-o',obj],'provider')
   assert row['driver']==test;raw=files['source-snapshots/'+test];assert sha(raw)==row['driver_sha256']and g.normalized(raw)==origin(g.BASE,test)==origin(r['head'],test)
   obj=build/'test.o';check_event([compiler,*flags,'-'+opt,'-J',build,'-I',build,'-c',repo/test,'-o',obj],'driver')
   exe=out/row['executable'];assert sha(files[row['executable']])==row['executable_sha256'];check_event([compiler,'-fopenmp','-'+opt,*objects,obj,'-o',exe],'link')
   e=check_event([exe],'original-test');assert e['returncode']==row['returncode']and e['stdout']==row['stdout'];b=files[e['stdout']];assert sha(b)==row['stdout_sha256'];stdout[opt]=b;passed=False
   if e['returncode']==0:
    try:g.validate_output(case,b);passed=True
    except AssertionError:pass
   assert passed==row['markers_pass'];all_pass=all_pass and passed
  equal=stdout['O0']==stdout['O2'];assert equal==r['results'][case]['outputs_equal'];all_pass=all_pass and equal
 assert cursor==200 and r['status']==('BUILD_REPAIRED_ORIGINAL_GATES_PASS'if all_pass else'BUILD_REPAIRED_ORIGINAL_NUMERICAL_FAILURE_RETAINED')
 return dict(build_repaired=True,actual_provider_compiles=188,unchanged_original_driver_compiles=4,original_executions=4,original_gates_pass=all_pass,numerical_failures_retained=not all_pass,production_admission=False,whole_scientific_admission=False)
def pack(out,stem):
 files={p.relative_to(out).as_posix():p.read_bytes()for p in out.rglob('*')if p.is_file()};r=json.loads(files['RESULT.json'])
 for case in r['results'].values():
  for row in case['optimizations'].values():
   for p in [b['source']for b in row['providers']]+[row['driver']]:files['source-snapshots/'+p]=(g.ROOT/p).read_bytes()
 measured=audit(files);refusals=0
 first=next(iter(r['results'].values()))['optimizations']['O0'];paths=['source-snapshots/'+first['providers'][0]['source'],first['providers'][0]['object'],'source-snapshots/'+first['driver'],first['executable'],first['stdout'],'EVENTS.json']
 for p in paths:
  bad=dict(files);bad[p]=b''
  try:audit(bad)
  except(AssertionError,KeyError,ValueError):refusals+=1
  else:raise AssertionError('corrupted build evidence admitted '+p)
 measured['evidence_corruption_refusals']=refusals;buffer=io.BytesIO()
 with tarfile.open(fileobj=buffer,mode='w')as t:
  for p,b in files.items():info=tarfile.TarInfo(p);info.size=len(b);t.addfile(info,io.BytesIO(b))
 raw=lzma.compress(buffer.getvalue());stem.with_suffix('.tar.xz').write_bytes(raw);stem.with_suffix('.json').write_text(json.dumps(dict(archive=stem.name+'.tar.xz',sha256=sha(raw),members={p:sha(b)for p,b in files.items()},measurement=measured),indent=2)+'\n');print(json.dumps(measured))
def verify(stem):
 m=json.loads(stem.with_suffix('.json').read_text());raw=stem.with_suffix('.tar.xz').read_bytes();assert sha(raw)==m['sha256']
 with tarfile.open(fileobj=io.BytesIO(lzma.decompress(raw)),mode='r:')as t:
  members=t.getmembers();assert all(p.isfile()for p in members)and len({p.name for p in members})==len(members)
  files={p.name:t.extractfile(p).read()for p in members}
 assert {p:sha(b)for p,b in files.items()}==m['members'];measured=audit(files);assert {k:v for k,v in m['measurement'].items()if k!='evidence_corruption_refusals'}==measured;assert m['measurement']['evidence_corruption_refusals']==6;print(json.dumps(measured))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path);p.add_argument('--stem',type=Path,required=True);a=p.parse_args()
 if a.output:pack(a.output.resolve(),a.stem.resolve())
 else:verify(a.stem.resolve())
