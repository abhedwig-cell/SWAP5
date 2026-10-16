"""Source-exact finite decoder repair: reuse unchanged providers, fresh natives.

Only the continuation decoder finite guard moves ahead of discrimination.
Keep every flag/trap, bind all reused objects and require identical module ABI.
Replay all actual harvest/rotation native assertions and original thermal native
profiles; add CRC-valid non-finite owner fields. No full-suite PASS is invented.
"""
from pathlib import Path
import argparse,hashlib,json,struct,subprocess,time,zlib
R=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--base',type=Path,required=True);p.add_argument('--small',type=Path,required=True);p.add_argument('--thermal',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--pin',required=True);a=p.parse_args()
O=a.output.resolve();O.mkdir(exist_ok=False);sha=lambda b:hashlib.sha256(b).hexdigest()
path='src/crop/mod_crop_soil_n_day.f90';old=subprocess.check_output(['git','show',a.pin+':'+path],cwd=R).decode()
expected=old.replace('  if(size(v)==0)return\n  if(v(1)==-81002d0)then','  if(size(v)==0)return\n  if(.not.all(ieee_is_finite(v)))return\n  if(v(1)==-81002d0)then')
assert old.count('.not.all(ieee_is_finite(v)).or.any(abs(v)>1d9)')==2
expected=expected.replace('.not.all(ieee_is_finite(v)).or.any(abs(v)>1d9)','any(abs(v)>1d9)')
assert expected==(R/path).read_text()
assert subprocess.check_output(['git','diff','--name-only',a.pin,'HEAD','--','src'],cwd=R,text=True).splitlines()==[path]
events=[];bindings={};result=dict(status='RUNNING',source_pin=a.pin,before_sha256=sha(old.encode()),after_sha256=sha(expected.encode()),
 source_path=path,projection='Exactly hoist finite vector check before discriminator; remove two redundant inner finite checks; all flags/traps/assertions unchanged',
 execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),events=events,bindings=bindings,runs={})
(O/'before.f90').write_text(old);(O/'after.f90').write_text(expected)
def save():(O/'result.json').write_text(json.dumps(result,indent=2)+'\n')
def run(cmd,cwd,kind):
 cmd=list(map(str,cmd));t=time.perf_counter()
 if kind=='native':Path(cmd[0]).chmod(Path(cmd[0]).stat().st_mode|0o111)
 r=subprocess.run(cmd,cwd=cwd,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(O/f'{i}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=cmd,category=kind,exit=r.returncode,seconds=time.perf_counter()-t,stdout=f'{i}.stdout',stderr=f'{i}.stderr'));save()
 if r.returncode:raise RuntimeError('retained repair failure '+str(i))
 return r.stdout

def bind(cmd):
 for word in cmd:
  q=Path(word)
  if q.is_file()and(q.suffix in ['.o','.mod','.f90']or q.name=='gfortran'):bindings[str(q)]=sha(q.read_bytes())

def recompile(base,opt,source_events):
 work=O/(base.name+'-'+opt);work.mkdir()
 e=next(e for e in source_events if e['category']in ['compile','provider_compile']and '-'+opt in e['command']and str(R/path)in e['command'])
 cmd=e['command'];oldobj=Path(cmd[cmd.index('-o')+1]);newobj=work/'finite-owner.o'
 original=base/opt/'mod_crop_soil_n_day.mod';bindings[str(original)]=sha(original.read_bytes());bind(cmd)
 cmd=[('-J'+str(work)if x.startswith('-J')else x)for x in cmd];cmd[cmd.index('-o')+1]=str(newobj)
 run(cmd,work,'changed_provider_compile')
 assert (work/original.name).read_bytes()==original.read_bytes(),'module ABI changed'
 return work,oldobj,newobj
try:
 # Bound source bytes from the original physical compile to its pinned Git state.
 pe=json.loads((a.base/'events.json').read_text())
 for e in pe:
  if e['category']=='compile':
   source=Path(e['command'][e['command'].index('-c')+1])
   if source.is_relative_to(R)and str(source.relative_to(R))!=path:
    assert source.read_bytes()==subprocess.check_output(['git','show',a.pin+':'+str(source.relative_to(R))],cwd=R)
 for opt in ['O0','O2']:
  work,oldobj,newobj=recompile(a.base,opt,pe);row={};result['runs'][opt]=row
  for name in ['test_harvest_joint','test_rotation_joint']:
   link=next(e['command']for e in pe if e['category']=='link'and '-'+opt in e['command']and Path(e['command'][-1]).name==name)
   bind(link);exe=work/name;link=[str(newobj)if x==str(oldobj)else x for x in link];link[link.index('-o')+1]=str(exe)
   run(link,work,'link')
   native=[e for e in pe if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name==name]
   for e in native:
    cmd=[str(exe)]+[str(work/Path(x).name)if str(a.base/opt)in x else x for x in e['command'][1:]]
    if cmd[1]=='reject':Path(cmd[2]).write_bytes(Path(e['command'][2]).read_bytes())
    raw=run(cmd,work,'native');assert b'PASS'in raw
   prefix='harvest-'if name=='test_harvest_joint'else'rotation-'
   for suffix in ['restart.bin','expected.bin','fresh.bin','expected.bin.opaque']:
    assert (work/(prefix+suffix)).read_bytes()==(a.base/opt/(prefix+suffix)).read_bytes()
   row[name]={'fresh_native_events':len(native),'endpoint_sha256':sha((work/(prefix+'expected.bin')).read_bytes())}
  count=0
  for origin,indices in [(work/'rotation-expected.bin.retired',range(9)),(work/'harvest-restart.bin',[0,1,2,4,11,27,28,30])]:
   data=origin.read_bytes();nn=struct.unpack_from('<i',data,152)[0];hh=struct.unpack_from('<i',data,156)[0]
   chemical=160+16*nn+16+(8*nn if hh else 0);pc=struct.unpack_from('<i',data,chemical+24)[0];crop=chemical+28+8*pc+104
   cc=struct.unpack_from('<i',data,crop+8)[0];owner=crop+12+8*cc+4
   for index in indices:
    for label,value in [('nan',float('nan')),('posinf',float('inf')),('neginf',-float('inf'))]:
     mutant=bytearray(data);struct.pack_into('<d',mutant,owner+8*index,value);struct.pack_into('<I',mutant,len(mutant)-4,zlib.crc32(mutant[:-4]))
     bad=work/(origin.stem+f'-{index}-{label}.bin');bad.write_bytes(mutant)
     raw=run([work/'test_rotation_joint','reject',bad],work,'native');assert b'INVALID_DISK=PASS'in raw;count+=1
  row['nonfinite_decoder_negatives']=count
  # Exact original thermal driver, fresh manual/calendar science after relink.
  heat=json.loads((a.thermal/'result.json').read_text());link=next(e['command']for e in heat['events']if e['category']=='link'and '-'+opt in e['command'])
  bind(link);exe=work/'thermal';link=[str(newobj)if x==str(oldobj)else x for x in link];link[link.index('-o')+1]=str(exe)
  run(link,work,'link')
  for e in heat['events']:
   if e['category']!='native'or'/'+opt+'/'not in e['command'][0]:continue
   cmd=[str(exe)]+[str(work/Path(x).name)if str(a.thermal/opt)in x else x for x in e['command'][1:]]
   run(cmd,work,'native')
  for profile in ['manual','calendar']:
   for suffix in ['restart.bin','expected.bin','fresh.bin','expected.bin.opaque']:
    name=profile+'-'+suffix;assert (work/name).read_bytes()==(a.thermal/opt/name).read_bytes()
  row['original_thermal_native_bytes']='IDENTICAL_FRESH_EXECUTION'
  # Small real owner/chemical drivers reuse only unchanged source-bound providers.
  small=json.loads((a.small/'result.json').read_text());sw,so,sn=recompile(a.small,opt,small['events'])
  for name in ['chemical','harvest','incumbent_day']:
   link=next(e['command']for e in small['events']if e['category']=='link'and '-'+opt in e['command']and Path(e['command'][-1]).name==name)
   bind(link);exe=sw/name;link=[str(sn)if x==str(so)else x for x in link];link[link.index('-o')+1]=str(exe);run(link,sw,'link')
   raw=run([exe],sw,'native');expected_raw=next((a.small/e['stdout']).read_bytes()for e in small['events']if e['category']=='native'and e['command'][0]==str(a.small/opt/name))
   assert raw==expected_raw
  row['small_fresh_byte_identity']=True
 for q,digest in bindings.items():assert sha(Path(q).read_bytes())==digest,q
 result['status']='FINITE_GUARD_CURRENT_SOURCE_NATIVE_REPAIRED_AND_BYTE_PRESERVED'
 result['cost_seconds']={kind:sum(e['seconds']for e in events if e['category']==kind)for kind in {e['category']for e in events}}
except Exception:
 result['status']='FAILED';save();raise
save();print(json.dumps({k:v for k,v in result.items()if k not in ['events','bindings']},indent=2))
