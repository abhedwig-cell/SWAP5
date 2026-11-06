"""Actual full-reader logical tokens, complete valid reexports and empty-owner refusal."""
import argparse,json,os,re,struct,subprocess,zlib
from pathlib import Path
import matrix_thermal_native_policy as policy
sha=policy.sha
BRANCH=''' if(trim(mode)=='probe-read'.or.trim(mode)=='probe-export')then
  call read_matrix_thermal_restart(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
   cfg%tiles(1)%parameters,p,water,chemical,status)
  print '(A,I0)','PROBE_STATUS=',status
  print '(A,L1)','WATER_READY=',water%ready()
  print '(A,L1)','CHEMICAL_READY=',chemical%ready()
  print '(A,I0)','LOGICAL_STORAGE_BITS=',storage_size(.true.)
  if(status==0)then
   call summary(water,chemical)
   if(trim(mode)=='probe-export')then
    call write_matrix_thermal_restart(trim(endpoint),column,cfg%tiles(1)%template,670001_int64, &
     cfg%tiles(1)%parameters,water,chemical,status)
    call require(status==0,'proper public reader reexport')
   end if
  end if
  stop
 end if
'''

def build(base,opt,out,compiler,publication_only=False):
 r=json.loads((base/'physical/result.json').read_text());ledger=json.loads((base/'COMPILER.json').read_text());link=next(e['effective']for e in ledger if '-c'not in e['effective'] and '-o'in e['effective'] and e['returncode']==0 and '-'+opt in e['effective'])
 event=next(e for e in r['events']if e['category']=='compile' and e['command'][-3].replace('\\','/').endswith('/tests/nut-sol/test_matrix_thermal.f90') and '-'+opt in e['command']);old_object=event['command'][-1]
 source=policy.before('tests/nut-sol/test_matrix_thermal.f90');anchor=" if(index(trim(mode),'reject')==1)then";assert source.count(anchor)==1;source=source.replace(anchor,BRANCH+anchor,1);f=out/'probe.f90';f.write_text(source,encoding='utf-8',newline='\n')
 flags=event['command'][1:event['command'].index('-c')];flags=[x for x in flags if not x.startswith('-J')];flags+=['-J'+str(out),'-I'+str(base/'physical'/opt),'-I'+str(base/'physical')]
 obj=out/'probe.o';exe=out/('probe.exe'if os.name=='nt'else'probe');commands=[]
 def run(cmd):
  cp=subprocess.run(list(map(str,cmd)),capture_output=True,cwd=out);i=len(commands)
  for stream in ('stdout','stderr'):(out/(str(i)+'.'+stream)).write_bytes(getattr(cp,stream))
  commands.append(dict(command=list(map(str,cmd)),returncode=cp.returncode));(out/'BUILD_EVENTS.json').write_text(json.dumps(commands,indent=2)+'\n');assert cp.returncode==0,cp.stderr[-4000:]
 replacement=None
 if publication_only:
  module=out/'publication-only.f90';module.write_text(policy.candidate(False),encoding='utf-8',newline='\n');replacement=out/'publication-only.o';run([compiler,*flags,'-c',module,'-o',replacement])
 run([compiler,*flags,'-c',f,'-o',obj]);args=link[1:].copy();assert args.count(old_object)==1;args[args.index(old_object)]=str(obj);args[-1]=str(exe)
 if replacement:
  event=next(e for e in r['events']if e['category']=='compile' and e['command'][-3].replace('\\','/').endswith('/'+policy.SOURCE) and '-'+opt in e['command']);old_module=event['command'][-1];assert args.count(old_module)==1;args[args.index(old_module)]=str(replacement)
 if os.name=='nt':
  response=out/'link.args';response.write_text('\n'.join('"'+x.replace('\\','/')+'"'for x in args)+'\n',encoding='utf-8',newline='\n');run([compiler,'@'+str(response)])
 else:run([compiler,*args])
 return exe

def main():
 p=argparse.ArgumentParser();p.add_argument('--models',type=Path,required=True);p.add_argument('--candidate',default='candidate-v2');p.add_argument('--incumbent',default='incumbent-v2');p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();policy.guard();base=a.models.resolve();out=a.output.resolve();out.mkdir(parents=True);events=[];reports=[]
 for role,name in (('candidate',a.candidate),('publication-only',a.candidate),('incumbent',a.incumbent)):
  for opt in ('O0','O2'):
   origin=base/name;report_path=origin/'physical/result.json'
   if not report_path.exists():assert role=='incumbent';continue
   available=json.loads(report_path.read_text()).get('executables',{})
   if opt not in available:assert role=='incumbent';reports.append(dict(role=role,optimization=opt,status='NO_ORIGINAL_COMPLETE_LINK_NOT_CLAIMED'));continue
   case=out/(role+'-'+opt);case.mkdir();exe=build(origin,opt,case,a.compiler.resolve(),role=='publication-only');observations=[]
   seeds=[base/a.candidate/'physical'/opt/'2/restart.bin',base/a.candidate/'physical'/opt/'16/full.bin',base/a.candidate/'physical'/opt/'controls/control.initial']
   for seed_index,seed in enumerate(seeds):
    raw=seed.read_bytes();assert raw[:8]==b'S5MT0001' and struct.unpack('<I',raw[-4:])[0]==zlib.crc32(raw[:-4]);assert struct.unpack_from('<i',raw,148)[0]==4
    corpus=[('valid',raw,None,None)]
    for offset,site in ((144,'time_bound'),(152,'history')):
     for token in (2,3,127,-1,-2147483648):
      mutant=bytearray(raw[:-4]);struct.pack_into('<i',mutant,offset,token);corpus.append((site+'-'+str(token),bytes(mutant)+struct.pack('<I',zlib.crc32(mutant)),site,token))
    for label,data,site,token in corpus:
     path=case/(str(seed_index)+'-'+label+'.bin');path.write_bytes(data);target=case/(str(seed_index)+'-'+label+'.reexport');mode='probe-export'if label=='valid'and role=='candidate'else'probe-read';cmd=[str(exe),mode,str(path),str(target),'2','1.0'];cp=subprocess.run(cmd,cwd=case,capture_output=True,env=dict(os.environ,OMP_NUM_THREADS='1'),timeout=180)
     index=len(events)
     for stream in ('stdout','stderr'):(out/(str(index)+'.'+stream)).write_bytes(getattr(cp,stream))
     text=cp.stdout.decode(errors='replace');assert cp.returncode==0,(cmd,text,cp.stderr)
     status=int(re.search(r'PROBE_STATUS=(\d+)',text)[1]);w=re.search(r'WATER_READY=([TF])',text)[1];c=re.search(r'CHEMICAL_READY=([TF])',text)[1];assert 'LOGICAL_STORAGE_BITS=32'in text
     if label=='valid':assert status==0 and w==c=='T';assert role!='candidate'or target.read_bytes()==raw
     elif role=='candidate':assert status!=0 and w==c=='F',(site,token,text)
     observations.append(dict(seed_sha256=sha(raw),site=site,token=token,status=status,water_ready=w,chemical_ready=c,input_sha256=sha(data)));events.append(dict(command=cmd,returncode=cp.returncode,stdout=str(index)+'.stdout',stderr=str(index)+'.stderr'));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
   reports.append(dict(role=role,optimization=opt,observations=observations))
 (out/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_FULL_MATRIX_THERMAL_LOGICAL_READERS_AND_COMPLETE_REEXPORTS_PASS',reports=reports,events=events,production_admission=False,whole_scientific_admission=False),indent=2)+'\n');print('ACTUAL_FULL_MATRIX_THERMAL_LOGICAL_READERS_AND_COMPLETE_REEXPORTS_PASS')
if __name__=='__main__':main()
