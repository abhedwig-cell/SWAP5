"""Real old/new native publisher file-state and CRC regression, with fault stages."""
import argparse,ctypes,hashlib,json,os,subprocess,time,zlib
from pathlib import Path
import generation_publication_policy as policy
ROOT=policy.ROOT;sha=policy.sha

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args();policy.guard();out=a.output.resolve();out.mkdir(parents=True);events=[];reports={}
 for opt in ('O0','O2'):
  results={}
  for role in ('incumbent','candidate'):
   case=out/(opt+'-'+role);case.mkdir();source=case/'publication.c';source.write_text(policy.before(policy.C)if role=='incumbent'else policy.candidate_c(),encoding='utf-8',newline='\n');dll=case/('probe.dll'if os.name=='nt'else'probe.so')
   flags=['-'+opt,'-std=c11','-DSWAP5_RESTART_TESTING','-shared']+([]if os.name=='nt'else['-fPIC']);cmd=[str(a.compiler.resolve()),*flags,str(source),'-o',str(dll)];start=time.monotonic();r=subprocess.run(cmd,capture_output=True,cwd=case)
   for stream in ('stdout','stderr'):(case/('build.'+stream)).write_bytes(getattr(r,stream))
   events.append(dict(command=cmd,returncode=r.returncode,seconds=time.monotonic()-start));assert r.returncode==0,r.stderr
   lib=ctypes.CDLL(str(dll));pub=lib.swap5_restart_publish_test;pub.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int];pub.restype=ctypes.c_int
   def file_case(label,fn,fault,expected,after,sibling=True,unicode=False):
    folder=case/label;folder.mkdir();target=folder/('authority-é-水'if unicode else'authority');pending=folder/'pending';old=b'old complete authority\0\xff';new=b'new complete authority\xff\x80';target.write_bytes(old);pending.write_bytes(new)
    if not sibling:
     other=folder/'other';other.mkdir();target=other/'authority';target.write_bytes(old)
    code=fn(os.fsencode(pending),os.fsencode(target),fault);assert code==expected,(opt,role,label,code)
    assert target.read_bytes()==(new if after else old)and pending.exists()==(not after),(opt,role,label)
    return dict(label=label,fault=fault,status=code,published=after,target_sha256=sha(target.read_bytes()),pending_exists=pending.exists())
   rows=[]
   for failure in (0,2,3,4,5,6):
    after=failure in (0,6);expected=failure if failure in (2,3,4,5)or(failure==6 and os.name!='nt')else 0
    rows.append(file_case('restart-'+str(failure),pub,failure,expected,after))
   rows.append(file_case('restart-wrong-parent',pub,0,1,False,False))
   rows.append(file_case('restart-utf8',pub,0,0,True,unicode=True))
   crc=lib.swap5_restart_crc32;crc.argtypes=[ctypes.POINTER(ctypes.c_int8),ctypes.c_size_t];crc.restype=ctypes.c_int32
   corpus=[b'',b'123456789',b'\0',b'\xff',bytes(range(256)),bytes(reversed(range(256))),b'\xff'*4096,b'\0'*4096,bytes(range(256))*256,bytes((i*73+(i>>3)+19)%256 for i in range(65537))]
   checks=[]
   for raw in corpus:
    data=(ctypes.c_int8*len(raw)).from_buffer_copy(raw);value=ctypes.c_uint32(crc(data,len(raw))).value;assert value==zlib.crc32(raw);checks.append(dict(bytes=len(raw),sha256=sha(raw),crc=value))
   gen=[]
   if role=='candidate':
    fn=lib.swap5_generation_publish_test;fn.argtypes=pub.argtypes;fn.restype=ctypes.c_int
    for failure in (0,2,3,4,5,6):gen.append(file_case('generation-'+str(failure),fn,failure,1 if failure==6 else failure,failure==0))
    gen.append(file_case('generation-wrong-parent',fn,0,1,False,False))
    gen.append(file_case('generation-utf8',fn,0,1 if os.name=='nt'else 0,os.name!='nt',unicode=True))
    assert fn(None,b'target',0)==1 and fn(b'pending',None,0)==1
   results[role]=dict(source_sha256=sha(source.read_bytes()),binary_sha256=sha(dll.read_bytes()),restart=rows,crc=checks,generation=gen)
  assert results['incumbent']['restart']==results['candidate']['restart']and results['incumbent']['crc']==results['candidate']['crc'];reports[opt]=results
 (out/'RESULT.json').write_text(json.dumps(dict(status='REAL_NATIVE_PUBLISHER_BEFORE_AFTER_AND_PRECOMMIT_FAULT_STATES_PASS',platform=os.name,results=reports,events=events,production_source_changed=False,production_admission=False,whole_scientific_admission=False),indent=2)+'\n');print('REAL_NATIVE_PUBLISHER_BEFORE_AFTER_AND_PRECOMMIT_FAULT_STATES_PASS')
if __name__=='__main__':main()
