"""Execute original additive runner linkage with the uninstrumented publisher."""
import argparse,difflib,json,os,subprocess,textwrap
from pathlib import Path,PureWindowsPath,PurePosixPath
import joint_writer_production as g
import joint_logical as native

def delta(path):
 before=g.raw(g.BASE,path).decode().splitlines(keepends=True);after=g.runner_postimage(path).decode().splitlines(keepends=True)
 changes=[(tag,a,b,c,d)for tag,a,b,c,d in difflib.SequenceMatcher(None,before,after,autojunk=False).get_opcodes()if tag!='equal']
 assert len(changes)==1 and changes[0][0]=='insert'
 _,a,b,c,d=changes[0];assert a==b and after[:c]+after[d:]==before
 return textwrap.dedent(''.join(after[c:d]))

def execute(out):
 g.guard_source();r=json.loads((out/'RESULT.json').read_text());assert r['production_trees']==g.guard_source()
 root=out/'production-linkage';root.mkdir();events=[];objects=[b['object']for b in r['bindings']];fc=None
 original_events=json.loads((out/'EVENTS.json').read_text());fc=next(e['command'][0]for e in original_events if e['label']=='provider')
 flags=r['flags']+(['-Wl,--stack,16777216']if os.name=='nt'else[])
 def run(args,cwd,label):
  args=list(map(str,args));cp=subprocess.run(args,cwd=cwd,capture_output=True,timeout=300)
  key='%03d-%s'%(len(events),label)
  for stream in('stdout','stderr'):(root/(key+'.'+stream)).write_bytes(getattr(cp,stream))
  events.append(dict(command=args,label=label,returncode=cp.returncode,stdout=key+'.stdout',stderr=key+'.stderr'))
  assert cp.returncode==0,cp.stderr[-4000:]
 exes={};rows=[]
 for name,path in [('age','tests/nut-sol/run_age.py'),('mineral','tests/nut-mineral/run_mineral.py'),('reactive_n','tests/nut-reactive/run_reactive.py')]:
  build=root/name;build.mkdir();driver=out/r['executables']['native-'+name]['object'];context=dict(ROOT=g.ROOT,build=build,opt=r['optimization'],FC=[fc],objects=[*objects,*([str(driver)]if name=='age'else[])],ordered=[g.ROOT/p for p in g.SOURCES.values()],inputs={},subprocess=subprocess,sha=lambda p:g.sha(p.read_bytes()),bind=lambda p:None,run=run,cmd=run)
  fragment=delta(path);exec(compile(fragment,path,'exec'),context)
  obj=context['publication_obj'];linked=context['objects']+([]if name=='age'else[str(driver)])
  names=[name,'reactive_original']if name=='reactive_n'else[name]
  for n in names:
   args=list(linked)
   if n=='reactive_original':args[-1]=str(out/r['executables']['native-reactive_original']['object'])
   exe=root/(n+('.exe'if os.name=='nt'else'-driver'));rsp=root/(n+'.args');command=[*flags,*map(str,args),'-o',str(exe)]
   rsp.write_text('\n'.join('"'+a.replace('\\','/')+'"'for a in command)+'\n');run([fc,'@'+str(rsp)],root,'normal-link-'+n);exes[n]=exe
   rows.append(dict(codec=n,runner=path,fragment=fragment,publisher_object=obj.relative_to(root).as_posix(),publisher_object_sha256=g.sha(obj.read_bytes()),executable=exe.relative_to(root).as_posix(),executable_sha256=g.sha(exe.read_bytes()),response=rsp.relative_to(root).as_posix()))
  assert g.normal((g.ROOT/path).read_bytes())==g.runner_postimage(path)
 source=g.ROOT/'app/support/restart_publish.c';(root/'publisher.c').write_bytes(source.read_bytes())
 directory=root/'native';directory.mkdir();native_events=[];measured=native.measure(directory,exes,native_events,'candidate')
 for name in g.NAMES:
  expected={p.name:p.read_bytes()for p in(out/name).iterdir()if p.is_file()};actual={p.name:p.read_bytes()for p in(directory/name).iterdir()if p.is_file()};assert actual==expected
 assert len(native_events)==56
 result=dict(status='UNINSTRUMENTED_PRODUCTION_PUBLISHER_ORIGINAL_NATIVE_PASS',head=g.git('rev-parse','HEAD'),runner_sha256=g.sha(g.normal(Path(__file__).read_bytes())),root=str(root),events=events,rows=rows,native=measured,native_events=56,compiler=fc,platform=r['platform'],optimization=r['optimization'],no_test_macro=True)
 (root/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 return result

def audit(files,r,root):
 q=PureWindowsPath if r['platform']=='WINDOWS'else PurePosixPath
 prefix='production-linkage/';m=json.loads(files[prefix+'RESULT.json']);assert m['status']=='UNINSTRUMENTED_PRODUCTION_PUBLISHER_ORIGINAL_NATIVE_PASS'and m['platform']==r['platform']and m['optimization']==r['optimization']and m['no_test_macro']is True
 path='tests/dataqual15_hupsel/joint_writer_production_linkage.py';assert m['runner_sha256']==g.sha(g.raw(m['head'],path))==g.sha(g.normal((g.ROOT/path).read_bytes()))
 assert g.normal(files[prefix+'publisher.c'])==g.raw(g.BASE,'app/support/restart_publish.c')
 events=m['events'];compiles=[e for e in events if e['label']=='publication_compile'];assert len(compiles)==3
 assert len(m['rows'])==4 and {row['codec']for row in m['rows']}=={'age','mineral','reactive_n','reactive_original'}
 repo=q(r['repo_root']);build=root/'production-linkage';objects=[x['object']for x in r['bindings']]
 for row in m['rows']:
  n=row['codec'];name='reactive_n'if n=='reactive_original'else n
  runner={'age':'tests/nut-sol/run_age.py','mineral':'tests/nut-mineral/run_mineral.py','reactive_n':'tests/nut-reactive/run_reactive.py'}[name]
  assert row['runner']==runner and row['fragment']==delta(runner)
  obj=build/name/'restart_publish.o';assert row['publisher_object']==name+'/restart_publish.o'and g.sha(files[prefix+row['publisher_object']])==row['publisher_object_sha256']
  compiled=[e for e in compiles if e['command'][-1]==str(obj)];assert len(compiled)==1
  assert compiled[0]['command'][1:]==['-'+r['optimization'],'-std=c11','-c',str(repo/'app/support/restart_publish.c'),'-o',str(obj)]
  driver=str(root/r['executables']['native-'+n]['object']);exe=build/row['executable'];assert g.sha(files[prefix+row['executable']])==row['executable_sha256']
  args=r['flags']+(['-Wl,--stack,16777216']if r['platform']=='WINDOWS'else[])+objects+[str(obj),driver,'-o',str(exe)]
  expected='\n'.join('"'+a.replace('\\','/')+'"'for a in args)+'\n'
  assert files[prefix+row['response']].decode().replace('\r\n','\n')==expected
  linked=[e for e in events if e['label']=='normal-link-'+n];assert len(linked)==1 and linked[0]['command']==[m['compiler'],'@'+str(build/row['response'])]
 for e in events:assert e['returncode']==0 and prefix+e['stdout']in files and prefix+e['stderr']in files
 native_events=json.loads(files[prefix+'native/EVENTS.json']);assert len(native_events)==m['native_events']==56
 expected_native=[e for e in json.loads(files['EVENTS.json'])[:r['native_events']]if e['label']not in('provider','native-driver','native-link','publisher','shim')];assert len(expected_native)==56
 def translate(value):
  for n in('age','mineral','reactive_n','reactive_original'):
   if value==str(root/r['executables']['native-'+n]['executable']):return str(build/(n+('.exe'if r['platform']=='WINDOWS'else'-driver')))
  before=str(root).replace('\\','/')+'/'
  if value.replace('\\','/').startswith(before):return str(build/'native'/value.replace('\\','/')[len(before):])
  return value
 for actual,prior in zip(native_events,expected_native):
  assert actual['command']==[translate(s)for s in prior['command']]and actual['label']==prior['label']and actual['returncode']==prior['returncode']
  assert g.normal(files[prefix+'native/'+actual['stdout']])==g.normal(files[prior['stdout']])
 for n in g.NAMES:assert {k.removeprefix(prefix+'native/'):v for k,v in files.items()if k.startswith(prefix+'native/'+n+'/')}=={k:v for k,v in files.items()if k.startswith(n+'/')}
 return 56

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();execute(a.output.resolve())
 import joint_writer_production_evidence as evidence
 r=json.loads((a.output/'RESULT.json').read_text());evidence.pack(a.output.resolve(),'JOINT_WRITER_PRODUCTION_'+r['platform']+'_'+r['optimization']+'_20261106')
