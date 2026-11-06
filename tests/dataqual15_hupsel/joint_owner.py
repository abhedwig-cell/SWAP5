"""Occupied-target qualification using complete admitted private reader objects."""
import argparse,functools,io,json,lzma,os,re,shutil,struct,subprocess,tarfile,zlib
from pathlib import Path
import joint_logical as p
import joint_logical_evidence as evidence
ROOT=p.ROOT
STORE=evidence.STORE
BASE='0c85785b65653155718e17ecc5d5590cc2de52c6'
RECONCILED='db42f99e2de9cae43dfe04bbf291e8e214edd6f7'
PEER='src/solver/mod_reference_bordered_solver.f90'
sha=p.sha

def guard():
 for area in ('src','app','reference'):
  assert subprocess.check_output(['git','rev-parse','HEAD:'+area],cwd=ROOT)==subprocess.check_output(['git','rev-parse',RECONCILED+':'+area],cwd=ROOT)
  assert not subprocess.check_output(['git','diff','HEAD','--',area],cwd=ROOT)
 assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','src','app','reference'],cwd=ROOT)
 assert subprocess.check_output(['git','diff','--name-only',BASE,RECONCILED,'--','src','app','reference'],cwd=ROOT,text=True).splitlines()==[PEER]
 assert subprocess.run(['git','grep','-i','-n','use mod_reference_bordered_solver',RECONCILED,'--','src','app'],cwd=ROOT,capture_output=True).returncode==1
 assert subprocess.run(['git','merge-base','--is-ancestor',RECONCILED,'HEAD'],cwd=ROOT,capture_output=True).returncode==0
 assert subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT,capture_output=True).returncode==0

@functools.lru_cache(maxsize=1)
def load(stem):
 m=json.loads((STORE/(stem+'.json')).read_text());chunks=[]
 for x in m['parts']:
  raw=(STORE/x['path']).read_bytes();assert sha(raw)==x['sha256']and len(raw)==x['size'];chunks.append(raw)
 with tarfile.open(fileobj=io.BytesIO(lzma.decompress(b''.join(chunks))),mode='r:')as t:files={v.name:t.extractfile(v).read()for v in t.getmembers()}
 assert {n:sha(b)for n,b in files.items()}==m['members'];assert evidence.audit(files)==m['measurement']
 return m,files

def driver_source(files,name):
 return evidence.original('tests/nut-mineral/test_mineral_joint.f90')if name=='mineral'else files['fixture/'+('reactive_driver.f90'if name=='reactive_n'else'age_driver.f90')]

def driver(source,name):
 text=p.normal(source).decode();age=name=='age';chem='solute'if age else'nitrogen';ctype={'age':'age_state_t','mineral':'mineral_state_t','reactive_n':'reactive_state_t'}[name]
 seed='restart_path'if age else'path';endpoint='endpoint_path'if age else'endpoint'
 read=f'call read_{name}_joint_restart_file(trim(ATTACK),column,cfg%tiles(1)%template,670001_int64,9001_int64,p,water,{chem},status)'
 write=f'call write_{name}_joint_restart_file(trim(OUTPUT),column,cfg%tiles(1)%template,670001_int64,water,{chem},status)'
 branch=f'''  if(trim(mode)=='occupied')then
    block
      type(kernel_committed_state_t)::saved_water,empty_water
      type({ctype})::saved_chemical,empty_chemical
      character(512)::attack,before_path,after_path
      character(16)::occupancy,layout
      call get_command_argument(3,attack)
      call get_command_argument(4,before_path)
      call get_command_argument(5,after_path)
      call get_command_argument(6,occupancy)
      call get_command_argument(7,layout)
      if(trim(layout)=='plain')cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
      {read.replace('trim(ATTACK)',f'trim({seed})')}
      call require(status==0.and.water%ready().and.{chem}%ready(),'occupied seed reconstruction')
      saved_water=water;saved_chemical={chem}
      {write.replace('trim(OUTPUT)','trim(before_path)')}
      call require(status==0,'occupied pre-refusal export')
      call require(trim(occupancy)=='both'.or.trim(occupancy)=='water'.or.trim(occupancy)=='chemical','known occupancy')
      if(trim(occupancy)=='water'){chem}=empty_chemical
      if(trim(occupancy)=='chemical')water=empty_water
      {read.replace('ATTACK','attack')}
      call require(status/=0,'occupied target must refuse')
      call require(water%ready().eqv.(trim(occupancy)/='chemical'),'water readiness preserved')
      call require({chem}%ready().eqv.(trim(occupancy)/='water'),'chemical readiness preserved')
      if(trim(occupancy)=='water'){chem}=saved_chemical
      if(trim(occupancy)=='chemical')water=saved_water
      {write.replace('trim(OUTPUT)','trim(after_path)')}
      call require(status==0,'occupied post-refusal export')
      print '(A)','OCCUPIED_ATOMIC_REFUSAL=PASS'
    end block
    stop
  end if
'''
 anchor=next(s for s in text.splitlines(True)if "if(trim(mode)=='reject')then"in s)
 result=text.replace(anchor,branch+anchor,1);assert result.replace(branch,'',1)==text
 return result.encode()

def inputs(files,role):
 for name in p.NAMES:
  seeds=[role+'/'+name+'/restart.bin']
  if name=='age':seeds.append(role+'/age/restart.bin.base')
  for seed in seeds:
   proper=files[seed];probes={'proper':proper,'bad-crc':proper[:-1]+bytes([proper[-1]^1]),'truncated':proper[:159],'missing':None}
   for field,offset in [('time_bound',144),('history',156)]:
    for word in (2,-1,2147483647):
     raw=bytearray(proper[:-4]);struct.pack_into('<i',raw,offset,word);probes[field+'-'+str(word)]=bytes(raw)+struct.pack('<I',zlib.crc32(raw))
   yield name,seed,probes

def execute(out,platform,opt,fc):
 guard();stem='JOINT_LOGICAL_'+platform+'_'+opt+'_20261106';manifest,files=load(stem)
 out.mkdir(parents=True);base=out/'providers';base.mkdir()
 for name,raw in files.items():
  path=base/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
 role='candidate';build=json.loads(files[role+'/BUILD.json']);assert build['compiler']==subprocess.check_output([fc,'--version'],text=True).splitlines()[0]
 flags=[f for f in build['flags']if not f.startswith(('-I','-J'))]+['-I'+str(base/role),'-I'+str(base/'baseline'),'-I'+str(base/'fixture'),'-I'+str(ROOT/'tests/nut-reactive'),'-J'+str(out)]
 meta=json.loads(files['PROVENANCE.json']);original_root=meta['root'];objects=[base/evidence.local(s,original_root)for s in build['objects_sha256']]
 events=[];sources={};exes={}
 for name in p.NAMES:
  source=out/(name+'.f90');source.write_bytes(driver(driver_source(files,name),name));sources[name]=sha(source.read_bytes())
  obj=out/(name+'.o');p.prior.run([fc,*flags,'-c',source,'-o',obj],out,events,'driver')
  exe=out/(name+('.exe'if os.name=='nt'else'-driver'));args=flags+(['-Wl,--stack,16777216']if os.name=='nt'else[])+[str(obj),*map(str,objects),'-o',str(exe)];rsp=out/(name+'.args');rsp.write_text('\n'.join('"'+s.replace('\\','/')+'"'for s in args)+'\n');p.prior.run([fc,'@'+str(rsp)],out,events,'link');exes[name]=exe
 rows=[]
 for name,seed,probes in inputs(files,role):
  for probe,raw in probes.items():
   for occupied in ('both','water','chemical'):
    key=f'{name}-{Path(seed).name}-{probe}-{occupied}';attack=out/(key+'.input');before=out/(key+'.before');after=out/(key+'.after')
    if raw is not None:attack.write_bytes(raw)
    event=p.prior.run([exes[name],'occupied',base/seed,attack,before,after,occupied,'plain'if seed.endswith('.base')else'history'],out,events,'occupied')
    assert b'OCCUPIED_ATOMIC_REFUSAL=PASS'in event.stdout
    assert before.read_bytes()==after.read_bytes()==files[seed]
    rows.append(dict(codec=name,seed=seed,probe=probe,occupancy=occupied,key=key,event=len(events)-1))
 result=dict(status='COMPLETE_OCCUPIED_TARGET_ATOMIC_REFUSAL_PASS',baseline=BASE,platform=platform,optimization=opt,root=str(out),input_stem=stem,input_manifest_sha256=sha(p.normal((STORE/(stem+'.json')).read_bytes())),sources=sources,objects={str(s):sha(s.read_bytes())for s in objects},flags=flags,rows=rows,production_admission=False,whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');guard();pack(out,platform,opt)

def audit(files):
 r=json.loads(files['RESULT.json']);assert r['status']=='COMPLETE_OCCUPIED_TARGET_ATOMIC_REFUSAL_PASS'and r['baseline']==BASE
 assert r['production_admission']is False and r['whole_scientific_admission']is False
 assert r['input_stem']=='JOINT_LOGICAL_'+r['platform']+'_'+r['optimization']+'_20261106'
 assert sha(p.normal((STORE/(r['input_stem']+'.json')).read_bytes()))==r['input_manifest_sha256']
 _,old=load(r['input_stem']);root=r['root'];build=json.loads(old['candidate/BUILD.json']);origin=json.loads(old['PROVENANCE.json'])['root']
 expected_objects={str(Path(root)/'providers'/evidence.local(s,origin)):h for s,h in build['objects_sha256'].items()}
 assert r['objects']==expected_objects
 flags=[f for f in build['flags']if not f.startswith(('-I','-J'))];assert [f for f in r['flags']if not f.startswith(('-I','-J'))]==flags
 events=json.loads(files['EVENTS.json']);assert len([e for e in events if e['label']=='driver'])==3 and len([e for e in events if e['label']=='link'])==3
 for name in p.NAMES:
  source=driver(driver_source(old,name),name);assert files[name+'.f90']==source and r['sources'][name]==sha(source)
  event=next(e for e in events if e['label']=='driver'and e['command'][e['command'].index('-c')+1]==str(Path(root)/(name+'.f90')))
  assert event['command'][1:-4]==r['flags'] and event['command'][-2:]==['-o',str(Path(root)/(name+'.o'))]
  args=re.findall(r'^"(.*)"$',files[name+'.args'].decode().replace('\r\n','\n'),re.M);assert [s for s in args if s.endswith('.o')]==[str(Path(root)/(name+'.o')).replace('\\','/'),*[s.replace('\\','/')for s in expected_objects]]
  exe=name+('.exe'if r['platform']=='WINDOWS'else'-driver');assert files[exe][:2]==b'MZ'if r['platform']=='WINDOWS'else files[exe][:4]==b'\x7fELF'
  assert files[name+'.o']
 expected=[]
 for name,seed,probes in inputs(old,'candidate'):
  for probe,raw in probes.items():
   for occupied in ('both','water','chemical'):
    key=f'{name}-{Path(seed).name}-{probe}-{occupied}';expected.append((name,seed,probe,occupied,key));row=r['rows'][len(expected)-1];assert tuple(row[k]for k in ('codec','seed','probe','occupancy','key'))==expected[-1]
    assert files.get(key+'.input')==raw and files[key+'.before']==files[key+'.after']==old[seed]
    e=events[row['event']];exe=name+('.exe'if r['platform']=='WINDOWS'else'-driver')
    assert e['label']=='occupied'and e['command']==[str(Path(root)/exe),'occupied',str(Path(root)/'providers'/seed),str(Path(root)/(key+'.input')),str(Path(root)/(key+'.before')),str(Path(root)/(key+'.after')),occupied,'plain'if seed.endswith('.base')else'history']
    assert e['returncode']==0 and b'OCCUPIED_ATOMIC_REFUSAL=PASS'in files[e['stdout']]
 assert len(r['rows'])==len(expected)==120
 assert len(events)==126 and all(e['returncode']==0 and e['stdout']in files and e['stderr']in files for e in events)
 return dict(occupied_refusals=120,complete_drivers=3,layouts=4,production_admission=False)

def pack(out,platform,opt):
 files={v.relative_to(out).as_posix():v.read_bytes()for v in out.iterdir()if v.is_file()};summary=audit(files);buf=io.BytesIO()
 with tarfile.open(fileobj=buf,mode='w:xz')as t:
  for name,raw in files.items():
   info=tarfile.TarInfo(name);info.size=len(raw);t.addfile(info,io.BytesIO(raw))
 stem='JOINT_OWNER_'+platform+'_'+opt+'_20261106';data=buf.getvalue();name=stem+'.tar.xz';(STORE/name).write_bytes(data);m=dict(summary=summary,archive=name,sha256=sha(data),members={n:sha(b)for n,b in files.items()});(STORE/(stem+'.json')).write_text(json.dumps(m,indent=2)+'\n');print(json.dumps(verify(stem,True)))

def verify(stem,controls=False):
 m=json.loads((STORE/(stem+'.json')).read_text());raw=(STORE/m['archive']).read_bytes();assert sha(raw)==m['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:files={v.name:t.extractfile(v).read()for v in t.getmembers()}
 assert {n:sha(b)for n,b in files.items()}==m['members'];assert audit(files)==m['summary']
 if controls:
  for name in ['age.f90','age.o','EVENTS.json',next(n for n in files if n.endswith('.after')),next(n for n in files if n.endswith('.before'))]:
   old=files[name];files[name]=b''
   try:audit(files)
   except (AssertionError,KeyError,ValueError):pass
   else:raise AssertionError('accepted evidence corruption '+name)
   finally:files[name]=old
 return m['summary']

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--output',type=Path);a.add_argument('--platform',choices=('WINDOWS','POSIX'));a.add_argument('--optimization',choices=('O0','O2'));a.add_argument('--compiler',default=shutil.which('gfortran'));a.add_argument('--verify');a.add_argument('--self-test',action='store_true');v=a.parse_args()
 if v.verify:print(json.dumps(verify(v.verify,v.self_test)))
 else:assert v.output and v.platform and v.optimization;execute(v.output.resolve(),v.platform,v.optimization,str(Path(v.compiler).resolve()))
