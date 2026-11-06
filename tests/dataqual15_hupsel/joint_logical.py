"""Complete private S5AJ/S5NJ/S5RN raw-logical reader observation."""
import argparse,base64,hashlib,inspect,io,json,os,shutil,struct,subprocess,tarfile,time,zlib
from pathlib import Path
import native_n_crc_runtime as prior
ROOT=prior.ROOT
BASE='6bcacb0af5890db0d54fa9b24a7f322f36de76c2'
NAMES=('age','mineral','reactive_n')
SOURCES={n:'src/adapter/mod_'+n+'_joint_restart_file.f90' for n in NAMES}
HELPER='''  logical function logical_raw_valid(raw)result(ok)
    integer(int8),intent(in)::raw(:)
    integer(int8)::yes(storage_size(.true.)/8),no(storage_size(.false.)/8)
    yes=transfer(.true.,yes);no=transfer(.false.,no)
    ok=.false.;if(size(raw)/=size(yes))return
    ok=all(raw==yes).or.all(raw==no)
  end function
'''
normal=lambda b:b.replace(b'\r\n',b'\n')
sha=lambda b:hashlib.sha256(b).hexdigest()

def guard():
 for area in ('src','app','reference'):
  assert subprocess.check_output(['git','rev-parse','HEAD:'+area],cwd=ROOT)==subprocess.check_output(['git','rev-parse',BASE+':'+area],cwd=ROOT)
  assert not subprocess.check_output(['git','diff','HEAD','--',area],cwd=ROOT)
 assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','src','app','reference'],cwd=ROOT)
 return dict(source_sha256={p:sha(normal((ROOT/p).read_bytes())) for p in SOURCES.values()})

def candidate(name):
 text=normal((ROOT/SOURCES[name]).read_bytes()).decode()
 marker='  subroutine read_'+name+'_joint_restart_file('
 start=text.index(marker);end=text.index('\n  end subroutine',start)+len('\n  end subroutine')
 old=text[start:end];new=old
 replacements=[('    logical::ok,has_history\n','    logical::ok,has_history\n    integer(int8)::bound_raw(storage_size(.true.)/8),history_raw(storage_size(.true.)/8)\n'),
 ('r%committed_time,r%time_bound, &','r%committed_time,bound_raw, &'),
 ('             mode,n,has_history\n','             mode,n,history_raw\n'),
 ('        if(io/=0)exit decoding\n        io=1\n','        if(io/=0)exit decoding\n        io=1\n        if(.not.logical_raw_valid(bound_raw).or..not.logical_raw_valid(history_raw))exit decoding\n        r%time_bound=all(bound_raw==transfer(.true.,bound_raw))\n        has_history=all(history_raw==transfer(.true.,history_raw))\n')]
 # Only the initial header has this read/check adjacency; later native reads
 # keep their original tentative-owner, finite, size and EOF assertions.
 for before,after in replacements:
  if before.startswith('        if(io/=0)'):assert new.count(before)>=1;new=new.replace(before,after,1)
  else:assert new.count(before)==1,(name,before);new=new.replace(before,after)
 result=text[:start]+new+text[end:];assert result.count('contains\n')>=1
 result=result.replace('contains\n','contains\n'+HELPER,1)
 restored=result.replace(HELPER,'',1)
 for before,after in reversed(replacements):restored=restored.replace(after,before,1)
 assert restored==text
 return result.encode()

def age_literal():
 text=(ROOT/'tests/nut-sol/run_age.py').read_text()
 prefix=text[text.index("archive = ROOT/"):text.index('results = dict(')]
 namespace=dict(ROOT=ROOT,tarfile=tarfile,io=io,base64=base64,hashlib=hashlib)
 exec(prefix,namespace)
 return namespace['oracle']

def prepare(out):
 text=inspect.getsource(prior.prepare)
 anchor="    decl=fixture/'wofost_soil_declarations.f90';mapping={}"
 insert="    age_oracle=fixture/'age_literal.f90';age_oracle.write_bytes(age_literal().encode())\n"
 assert text.count(anchor)==1;text=text.replace(anchor,insert+anchor)
 before="for p in [*sorted((ROOT/'src').rglob('*.f90')),grid,oracle_fixture,decl]:"
 assert text.count(before)==1;text=text.replace(before,"for p in [*sorted((ROOT/'src').rglob('*.f90')),grid,oracle_fixture,decl,age_oracle]:")
 namespace=dict(prior.__dict__,age_literal=age_literal);exec(text,namespace)
 return namespace['prepare'](out)

def build(out,fc,opt,fixture,ordered,drivers,baseline=None):
 out.mkdir();events=[];objects=[];sources={};flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(out),'-J'+str(out),'-I'+str(fixture),'-I'+str(ROOT/'tests/nut-reactive')]
 if baseline:flags+=['-I'+str(baseline)]
 for i,p in enumerate(ordered):
  obj=out/('%03d.o'%i);source=p;name=next((n for n,path in SOURCES.items() if p==ROOT/path),None)
  if baseline and not name:obj=baseline/obj.name
  else:
   if baseline:source=out/p.name;source.write_bytes(candidate(name))
   prior.run([fc,*flags,'-c',source,'-o',obj],out,events,'provider')
  assert obj.is_file();objects.append(obj);sources[str(source)]=sha(source.read_bytes())
 exes={}
 for name,p in drivers.items():
  obj=out/(name+'.o');prior.run([fc,*flags,'-c',p,'-o',obj],out,events,'driver')
  exe=out/(name+('.exe'if os.name=='nt'else'-driver'));args=flags+(['-Wl,--stack,16777216']if os.name=='nt'else[])+[str(obj),*map(str,objects),'-o',str(exe)]
  rsp=out/(name+'.args');rsp.write_text('\n'.join('"'+s.replace('\\','/')+'"'for s in args)+'\n')
  prior.run([fc,'@'+str(rsp)],out,events,'link');exes[name]=exe
 (out/'BUILD.json').write_text(json.dumps(dict(compiler=subprocess.check_output([fc,'--version'],text=True).splitlines()[0],flags=flags,provider_count=len(ordered),role='candidate'if baseline else'baseline',sources_sha256=sources,objects_sha256={str(p):sha(p.read_bytes())for p in objects},drivers_sha256={n:sha(p.read_bytes())for n,p in drivers.items()},executables_sha256={n:sha(p.read_bytes())for n,p in exes.items()}),indent=2)+'\n')
 return exes,events

def measure(out,exes,events,role):
 old=prior.execute(exes,out,events,True)
 age=out/'age';age.mkdir();exe=exes['age']
 prior.run([exe,'write',age/'restart.bin',age/'end.bin'],out,events,'age-write')
 prior.run([exe,'resume',age/'restart.bin',age/'fresh.bin'],out,events,'age-resume')
 assert (age/'end.bin').read_bytes()==(age/'fresh.bin').read_bytes()
 observations=[];proper=[]
 for name in NAMES:
  paths=[out/name/'restart.bin']
  if name=='age':assert Path(str(paths[0])+'.base').is_file();paths.append(Path(str(paths[0])+'.base'))
  for path in paths:
   blob=path.read_bytes();assert blob[:8] in (b'S5AJ0001',b'S5NJ0001',b'S5RN0001')
   assert zlib.crc32(blob[:-4])==struct.unpack('<I',blob[-4:])[0]
   assert struct.unpack_from('<i',blob,152)[0]==4 and struct.unpack_from('<i',blob,144)[0]in(0,1) and struct.unpack_from('<i',blob,156)[0]in(0,1)
   proper.append(dict(path=str(path),sha256=sha(blob),mode=struct.unpack_from('<i',blob,148)[0],history=struct.unpack_from('<i',blob,156)[0]))
   for field,offset in [('time_bound',144),('history',156)]:
    for word in (2,-1,2147483647):
     payload=bytearray(blob[:-4]);struct.pack_into('<i',payload,offset,word);bad=bytes(payload)+struct.pack('<I',zlib.crc32(payload))
     target=out/name/(path.name+'.'+field+'.'+str(word)+'.bin');target.write_bytes(bad)
     result=prior.run([exes[name],'reject',target,out/name/'unused.bin'],out,events,'logical-'+name+'-'+field,False)
     refused=result.returncode==0 and b'INVALID_DISK=PASS'in result.stdout
     if role=='candidate':assert refused,(name,field,word,result.stdout,result.stderr)
     observations.append(dict(codec=name,proper=path.name,field=field,word=word,path=str(target),returncode=result.returncode,refused=refused))
 return dict(unchanged_native_n=old,proper=proper,logical=observations)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--compiler',default=shutil.which('gfortran'));a=p.parse_args();guard();os.environ['OMP_NUM_THREADS']='1'
 out=a.output.resolve();prior.guard=guard;prior.DRIVERS=dict(prior.DRIVERS,age='tests/nut-sol/test_age_joint.f90')
 fixture,ordered,drivers=prepare(out);result=dict(status='RUNNING',baseline=BASE,optimization=a.optimization,production_admission=False,whole_scientific_admission=False,roles={})
 for role in ('baseline','candidate'):
  builddir=out/role;exes,events=build(builddir,Path(a.compiler).resolve(),a.optimization,fixture,ordered,drivers,out/'baseline'if role=='candidate'else None)
  result['roles'][role]=measure(builddir,exes,events,role)
  (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(role,'complete original physical/native and logical observations',flush=True)
  if role=='candidate':
   for name in NAMES:
    for leaf in ('restart.bin','end.bin','fresh.bin'):
     assert (out/'baseline'/name/leaf).read_bytes()==(builddir/name/leaf).read_bytes(),(name,leaf)
 result['status']='COMPLETE_PRIVATE_JOINT_LOGICAL_READER_CLUSTER_PASS';(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');guard()

if __name__=='__main__':main()
