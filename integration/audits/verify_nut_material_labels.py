"""Exact registered parser-only successor; no general source waiver."""
from pathlib import Path
import hashlib,json
SOURCE='src/process/mod_soil_n_unified_input.f90'
OLD="""  do k=1,nmat
   rows(k+1)=trim(values(1,k))//' '//trim(values(2,k))//' '//trim(values(3,k))// &
"""
NEW="""  do k=1,nmat
   ! Original rdainr validates definition labels in 1..maxmat, then rdfinr
   ! overwrites MatNum with event row positions. Definition labels are not keys.
   error_line=value_line(1,k)
   read(values(1,k),*,iostat=code)idx
   if(code/=0)return
   if(idx<1.or.idx>20)return
   write(word,'(I0)')k
   rows(k+1)=trim(word)//' '//trim(values(2,k))//' '//trim(values(3,k))// &
"""
def verify(root,record,files,oldfiles,require):
 sha=lambda b:hashlib.sha256(b).hexdigest()
 require(sha(Path(__file__).read_bytes())==record['validator_sha256'],'label validator identity')
 old=files['predecessor/unified.f90'];require(sha(old)==record['predecessor_sha256'],'label predecessor identity')
 text=old.decode();require(text.count(OLD)==1,'label predecessor normalization seam')
 require((root/SOURCE).read_bytes()==text.replace(OLD,NEW).encode(),'unregistered native parser delta')
 def inputs(r):
  for q,h in r['input_sha256'].items():require(sha((root/q).read_bytes())==h,'label current input '+q)
 result=lambda prefix:json.loads(files[prefix+'/result.json'])
 direct=result('labels');inputs(direct)
 require(direct['status']=='NATIVE_POSITION_LABEL_SUPPLEMENT_PASS' and len(direct['fixtures'])==9,'label direct matrix')
 require(direct['outputs']['O0']==direct['outputs']['O2'],'label optimization')
 ev=json.loads(files['labels/events.json']);require(all(e['returncode']==0 for e in ev),'label failed event')
 require(sum(e['category']=='native' for e in ev)==18 and sum(e['category']=='original_native' for e in ev)==8,'label execution counts')
 for i,e in enumerate(ev):
  require(f'labels/{i:03d}.stdout' in files and f'labels/{i:03d}.stderr' in files,'label raw logs')
  if e['category'] in ['native','original_native']:
   name=Path(e['command'][1]).stem;opt=Path(e['command'][0]).parent.name
   key=('original_' if e['category']=='original_native' else '')+name
   require(files[f'labels/{i:03d}.stdout'].decode()==direct['outputs'][opt][key],'label raw execution output')
 for prefix,status in [('labels/native','PASS'),('labels/export','PASS'),('labels/ttutil','ORIGINAL_TTUTIL_O0_O2_PASS')]:
  r=result(prefix);require(r['status']==status,'label predecessor suite '+prefix)
  if 'input_sha256' in r:inputs(r)
  else:require(r['runner_sha256']==sha((root/'tests/nut-input/run_ttutil_native_oracle.py').read_bytes()),'label original runner')
  ee=json.loads(files[prefix+'/events.json']);require(all(e['returncode']==0 or e['category']=='negative_native' for e in ee),'label suite event')
  if prefix.endswith('/native'):require(len(r['fixtures'])==38 and r['outputs']['O0']==r['outputs']['O2'] and sum(e['category']=='native' for e in ee)==76,'old38 native preservation')
  if prefix.endswith('/export'):require(r['runs']['O0']==r['runs']['O2'],'modern export preservation')
  if prefix.endswith('/ttutil'):require(r['results']['O0']==r['results']['O2'] and sum(e['category']=='native' for e in ee)==20 and sum(e['category']=='negative_native' for e in ee)==2,'original TTUTIL preservation')
 main=result('physical');inputs(main);prior=json.loads(oldfiles['nut-hist-capacity-qualified/result.json'])
 require(main['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION','label physical status')
 require(main['results']==prior['results'],'label original physical outputs')
 require(main['literal_sha256']==prior['literal_sha256'] and main['authority_sha256']==prior['authority_sha256'],'label original science source identity')
 require(set(main['input_sha256'])==set(prior['input_sha256']),'label changed production closure')
 for q,h in prior['input_sha256'].items():
  require(h==(sha(old) if q==SOURCE else sha((root/q).read_bytes())),'label old physical dependency '+q)
 events=json.loads(files['physical/events.json']);objects={};links={}
 for e in events:
  require(e['returncode']==0,'label physical failed event');c=e['command'];cat=e['category']
  for stream in ['stdout','stderr']:require('physical/'+e[stream] in files,'label physical raw log')
  if cat=='compiler':continue
  if cat in ['native','restart_native']:require(c[0] in links,'label unlinked physical execution');continue
  require(('-O0' in c or '-O2' in c) and '-fcheck=all' in c and '-ffpe-trap=invalid,zero,overflow' in c,'label physical flags')
  out=c[c.index('-o')+1]
  if cat=='compile':require(out not in objects,'label duplicate object');objects[out]=c
  elif cat=='link':
   oo=[v for v in c if v.endswith('.o')];require(oo and all(v in objects for v in oo) and len(oo)==len(set(oo)),'label compiled closure');links[out]=c
  else:require(False,'label physical category')
 for opt in ['O0','O2']:
  for q in main['input_sha256']:
   if q.startswith('src/') and q.endswith('.f90'):require(sum('-'+opt in c and c[c.index('-c')+1].endswith('/'+q) for c in objects.values())==1,'label missing provider '+q)
  for profile in ['source-profile','rotation-profile','atmospheric-profile','humus-profile']:
   prefix=opt+'/'+profile;endpoint=files['physical/'+prefix+'.endpoint']
   require(endpoint==oldfiles['nut-hist-capacity-qualified/'+prefix+'.endpoint'],'label endpoint drift')
   if profile=='source-profile':require(endpoint==files['physical/'+prefix+'.fresh'],'label source restart')
   else:
    for day in [1,120,121,365,366,500]:
     require(endpoint==files[f'physical/{opt}/{profile}-fresh-{day}'],'label fresh transition')
     require(sum(e['category']=='restart_native' and '/'+opt+'/' in e['command'][0] and e['command'][-2:]==[profile,str(day)] for e in events)==1,'label missing fresh process')
    for day in [120,366]:
     before=files[f'physical/{prefix}.restart.reject-before-{day}']
     require(before==files[f'physical/{prefix}.restart.reject-after-{day}'],'label rollback')
     if profile in ['atmospheric-profile','humus-profile']:require(before==files[f'physical/{prefix}.restart.clean-reject-{day}'],'label clean-only rollback')
  require(files[f'physical/{opt}/default.endpoint']==files[f'physical/{opt}/default.fresh']==files[f'physical/{opt}/default.endpoint.opaque'],'label default native')
 return lambda q:old if q==SOURCE else (root/q).read_bytes()

def self_test(root,record,files,oldfiles,require):
 import copy
 verify(root,record,files,oldfiles,require);passed=[]
 def reject(name,mutate,metadata=False):
  f=dict(files);r=copy.deepcopy(record)
  mutate(r if metadata else f)
  try:verify(root,r,f,oldfiles,require)
  except (ValueError,KeyError,IndexError):passed.append(name);return
  raise AssertionError('accepted label corruption '+name)
 def edit(f,path,fn):
  obj=json.loads(f[path]);fn(obj);f[path]=json.dumps(obj).encode()
 reject('predecessor drift',lambda f:f.__setitem__('predecessor/unified.f90',f['predecessor/unified.f90']+b'!'))
 reject('unregistered validator',lambda r:r.__setitem__('validator_sha256','0'*64),True)
 reject('missing original labels',lambda f:edit(f,'labels/events.json',lambda es:es.__setitem__(slice(None),[e for e in es if e['category']!='original_native'])))
 reject('missing old parser native',lambda f:edit(f,'labels/native/events.json',lambda es:es.__setitem__(slice(None),[e for e in es if e['category']!='native'])))
 reject('transition state drift',lambda f:f.__setitem__('physical/O2/humus-profile-fresh-366',f['physical/O2/humus-profile-fresh-366']+b'x'))
 reject('rollback drift',lambda f:f.__setitem__('physical/O0/rotation-profile.restart.reject-after-120',f['physical/O0/rotation-profile.restart.reject-after-120']+b'x'))
 reject('unchecked provider',lambda f:edit(f,'physical/events.json',lambda es:es[0]['command'].remove('-fcheck=all')))
 reject('missing fresh process',lambda f:edit(f,'physical/events.json',lambda es:es.__setitem__(slice(None),[e for e in es if e['category']!='restart_native'])))
 e=json.loads(files['labels/events.json']);i=next(i for i,e in enumerate(e) if e['category']=='original_native')
 reject('original output drift',lambda f:f.__setitem__(f'labels/{i:03d}.stdout',b'PASS'))
 return passed
