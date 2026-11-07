"""Private complete S5MJ reader postimage; production source remains immutable."""
import argparse,hashlib,json,os,struct,subprocess,zlib,time
from pathlib import Path
import matrix_crc_runtime as original
import native_n_crc_runtime as support
ROOT=original.ROOT
SOURCE='src/adapter/mod_matrix_joint_restart_file.f90'
REGISTER='integration/dataqual15_hupsel/MATRIX_LOGICAL_PREREGISTRATION_20261107.json'
sha=lambda b:hashlib.sha256(b).hexdigest()
def raw(ref,p):return subprocess.check_output(['git','show',ref+':'+p],cwd=ROOT)
def guard():
 r=json.loads((ROOT/REGISTER).read_text());base=r['baseline']
 for area in ('src','app','reference'):
  assert subprocess.check_output(['git','rev-parse','HEAD:'+area],cwd=ROOT)==subprocess.check_output(['git','rev-parse',base+':'+area],cwd=ROOT)
  assert not subprocess.check_output(['git','diff','HEAD','--',area],cwd=ROOT)
  assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',area],cwd=ROOT)
 assert sha(raw(base,SOURCE))==r['source_sha256'];return r

def postimage(b):
 text=b.decode();a=text.index('  subroutine read_matrix_joint_restart_file');z=text.index('  subroutine append_crc',a);body=text[a:z]
 decl='    integer(int8)::extra\n';added='    integer(int8)::bound_raw(storage_size(.true.)/8),history_raw(storage_size(.true.)/8)\n';assert body.count(decl)==1;body=body.replace(decl,decl+added,1)
 old='r%template_identity,r%lineage_id,r%revision,r%committed_time,r%time_bound, &\n             mode,n,has_history';new=old.replace('r%time_bound','bound_raw').replace('has_history','history_raw');assert body.count(old)==1;body=body.replace(old,new,1)
 anchor='        if(io/=0)exit decoding\n        io=1\n';assert body.count(anchor)>=1
 check=''
 for name in ('bound_raw','history_raw'):check+='        if(.not.(all('+name+'==transfer(.true.,'+name+')).or. &\n             all('+name+'==transfer(.false.,'+name+'))))exit decoding\n'
 check+='        r%time_bound=all(bound_raw==transfer(.true.,bound_raw))\n        has_history=all(history_raw==transfer(.true.,history_raw))\n'
 body=body.replace(anchor,anchor+check,1)
 reverse=body.replace(decl+added,decl,1).replace(new,old,1).replace(check,'',1);assert reverse==text[a:z]
 return (text[:a]+body+text[z:]).encode()

def build(out,fc,opt,fixture,ordered,drivers,previous=None):
 out.mkdir();events=[];objects=[];sources={};bindings=[];flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(out),'-J'+str(out),'-I'+str(fixture),'-I'+str(ROOT/'tests/nut-reactive')]
 if previous:flags+=['-I'+str(previous)]
 for i,p in enumerate(ordered):
  obj=out/('%03d.o'%i);src=p;changed=p==ROOT/SOURCE
  if previous and not changed:obj=previous/obj.name
  else:
   if previous:src=out/p.name;src.write_bytes(postimage(raw(guard()['baseline'],SOURCE)))
   support.run([fc,*flags,'-c',src,'-o',obj],out,events,'provider')
  snapshot=out/'sources'/('%03d.f90'%i);snapshot.parent.mkdir(exist_ok=True);snapshot.write_bytes(src.read_bytes());objects.append(obj)
  bindings.append(dict(original=str(p),snapshot=snapshot.relative_to(out).as_posix(),source_sha256=sha(src.read_bytes()),object=str(obj),object_sha256=sha(obj.read_bytes()),reused=bool(previous and not changed)))
 if previous:assert(out/'mod_matrix_joint_restart_file.mod').read_bytes()==(previous/'mod_matrix_joint_restart_file.mod').read_bytes()
 cc=subprocess.check_output([fc,'-print-prog-name=gcc'],text=True).strip();c=out/'publisher.c';c.write_bytes((ROOT/'app/support/restart_publish.c').read_bytes());cobj=out/'publisher.o';support.run([cc,'-'+opt,'-std=c11','-c',c,'-o',cobj],out,events,'publisher');objects.append(cobj)
 exes={};driver_meta={}
 for name,p in drivers.items():
  src=out/(name+'.f90');src.write_bytes(p.read_bytes());obj=out/(name+'.o');support.run([fc,*flags,'-c',src,'-o',obj],out,events,'driver')
  exe=out/(name+('.exe'if os.name=='nt'else'-driver'));args=[*flags]+(['-Wl,--stack,16777216']if os.name=='nt'else[])+[str(obj),*map(str,objects),'-o',str(exe)];rsp=out/(name+'.args');rsp.write_text('\n'.join('"'+x.replace('\\','/')+'"'for x in args)+'\n');support.run([fc,'@'+str(rsp)],out,events,'link');exes[name]=exe;driver_meta[name]=dict(source=src.name,source_sha256=sha(src.read_bytes()),original=str(p),executable=exe.name,executable_sha256=sha(exe.read_bytes()))
 (out/'BUILD.json').write_text(json.dumps(dict(provider_count=len(ordered),bindings=bindings,flags=flags,drivers=driver_meta),indent=2)+'\n');return exes,events

def malformed(exe,out,events,enforce):
 rows=[]
 for exponent in original.EXPONENTS:
  case=out/('n'+exponent)
  for filename in ('restart.bin','restart.bin.base'):
   rawdata=(case/filename).read_bytes();assert zlib.crc32(rawdata[:-4])==struct.unpack('<I',rawdata[-4:])[0];assert rawdata[:8]in(b'S5MJ0001',b'S5MJ0002',b'S5MJ0003')
   for field,offset in (('time_bound',148),('has_history',156)):
    assert rawdata[offset:offset+4]in(b'\0'*4,b'\1\0\0\0')
    for value in (2,-1,256):
     b=bytearray(rawdata[:-4]);struct.pack_into('<i',b,offset,value);mutated=bytes(b)+struct.pack('<I',zlib.crc32(b));path=case/(filename+'-'+field+'-'+str(value)+'.bin');path.write_bytes(mutated)
     p=support.run([exe,'reject',path,case/'unused.bin',exponent],out,events,'logical',False);refused=p.returncode==0 and b'MATRIX_JOINT_INVALID_FILE=PASS'in p.stdout
     if enforce:assert refused,(exponent,filename,field,value,p.stdout,p.stderr)
     rows.append(dict(exponent=exponent,file=path.relative_to(out).as_posix(),field=field,offset=offset,value=value,returncode=p.returncode,refused=refused))
 return rows

def execute(out,fc,opt):
 r=guard();os.environ['OMP_NUM_THREADS']='1';fixture,ordered,drivers=original.prepare(out);results={};start=time.monotonic()
 for role in ('incumbent','candidate'):
  builddir=out/role;exes,events=build(builddir,fc,opt,fixture,ordered,drivers,out/'incumbent'if role=='candidate'else None)
  old=original.execute(exes,builddir,events,True);bad=malformed(exes['joint'],builddir,events,role=='candidate');results[role]=dict(original=old,logical=bad)
 for exponent in original.EXPONENTS:
  for name in ('restart.bin','restart.bin.base','end.bin','fresh.bin'):
   assert(out/'incumbent'/('n'+exponent)/name).read_bytes()==(out/'candidate'/('n'+exponent)/name).read_bytes()
 guard();result=dict(status='PRIVATE_MATRIX_RAW_LOGICAL_FULL_NATIVE_QUALIFIED',baseline=r['baseline'],head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),platform='WINDOWS'if os.name=='nt'else'POSIX',optimization=opt,compiler=subprocess.check_output([fc,'--version'],text=True).splitlines()[0],seconds=time.monotonic()-start,provider_count=len(ordered),results=results,production_admission=False,whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],opt,'providers',len(ordered),'baseline malformed refusals',sum(x['refused']for x in results['incumbent']['logical']),'candidate refusals',len(bad))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();execute(a.output.resolve(),str(Path(a.compiler).resolve()),a.optimization)
