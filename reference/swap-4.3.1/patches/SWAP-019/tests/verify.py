"""Validate sealed actual-source science; never infer full crop or SWAP5 admission."""
from pathlib import Path
import base64,copy,hashlib,io,json,re,tarfile
ROOT=Path(__file__).resolve().parents[5]
STATUS='integration/audits/MC_NUT_SOL_STATUS.json'
def require(ok,label):
 if not ok:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def unpack():
 rec=json.loads((ROOT/STATUS).read_text())['leaf_reference_admission_20261016']['science_archive'];raw=base64.b64decode((ROOT/rec['path']).read_bytes())
 require(sha(raw)==rec['decoded_sha256'] and len(raw)==rec['decoded_bytes'],'capsule identity')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  ms=t.getmembers();require(len(ms)==rec['members'] and len({m.name for m in ms})==len(ms),'capsule members')
  require(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe capsule')
  data={m.name:t.extractfile(m).read()for m in ms}
 manifest=json.loads(data.pop('MANIFEST.json'));require(set(data)==set(manifest),'capsule completeness')
 for k,h in manifest.items():require(sha(data[k])==h,'capsule corruption '+k)
 return data
def values(raw,prefix='ACTUAL_SOURCE_DAY_HARVEST='):
 return list(map(float,next(l for l in raw.splitlines()if l.startswith(prefix)).split('=')[1].split()))
def procedures(text):
 lines=text.splitlines();out={};start=None;name=None
 for i,line in enumerate(lines):
  m=re.match(r'^\s*(?:(?:real\(8\)|integer|logical)\s+)?(?:subroutine|function)\s+(\w+)\s*\(',line,re.I)
  if start is None and m:start=i;name=m[1].lower()
  elif start is not None and re.match(r'^\s*end(?:\s+(?:subroutine|function)(?:\s+\w+)?)?\s*$',line,re.I):out[name]='\n'.join(lines[start:i+1]);start=None
 return out
def verify_literals(data):
 for variant in ('original','candidate'):
  whole=data['inputs/'+('original-'if variant=='original'else'candidate-')+'wofost.f90'].decode('latin1').replace('\r\n','\n')
  extracted=data['inputs/growth-'+variant+'.f90'].decode('latin1').replace('\r\n','\n')
  full=procedures(whole);selected=procedures(extracted)
  require('daily_task'in selected and len(selected)==23,'growth/reset closure drift')
  for n,body in selected.items():
   if n!='daily_task':require(n in full and body==full[n],'copied or changed scientific helper '+n)
  require('\n'.join(whole.splitlines()[344:416])in selected['daily_task'],'task3/4 source order changed')
  whole=data['inputs/'+('original-'if variant=='original'else'candidate-')+'wofostnut.f90'].decode('latin1').replace('\r\n','\n')
  staged=data['inputs/nutrient-'+variant+'.f90'].decode('latin1').replace('\r\n','\n')
  prefix,suffix=whole.split('   contains',1)
  require(staged.endswith(suffix),'original N scientific bodies changed')
  require(staged.startswith(prefix),'original N parameter declarations changed')
 return True
def validate(data,result=None,events=None):
 r=json.loads(data['final/result.json'])if result is None else result
 es=json.loads(data['final/events.json'])if events is None else events
 verify_literals(data)
 require(r['status']=='SWAP019_REFERENCE_SCIENCE_PASS_NOT_ADMITTED','incomplete science')
 for n,h in r['input_sha256'].items():require(sha(data['inputs/'+n])==h,'scientific input '+n)
 require(data['inputs/candidate.patch']==(ROOT/'reference/swap-4.3.1/patches/SWAP-019/fix.patch').read_bytes(),'tested patch differs')
 targets={'wofost.f90':('3f7daf222835c9b4b395feaa665614e8aef88a03125cdec9e0776ca793c6271b','2d1f9962f2423f94209784cf92e295ddbd18d103a052312be0f3da3e330bac38'),'wofostnut.f90':('071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2','f64dbc7a58bc7508fd25aa277fa09f70a9ed9206aab684ad094ef1dc61d3e346')}
 for n,(a,b)in targets.items():require(sha(data['inputs/original-'+n])==a and sha(data['inputs/candidate-'+n])==b,'full source identity '+n)
 runs=r['runs'];require(set(runs)=={o+'-'+v+c for o in ('O0','O2')for v in ('original','candidate')for c in ('','-controls')},'missing optimization or source variant')
 native=[]
 for e in es:
  require(e['returncode']==0 and e['seconds']>=0,'failed measured command')
  require('final/'+e['stdout']in data and 'final/'+e['stderr']in data,'raw command missing')
  if e['category']=='native':native.append(e)
  elif e['category']=='compile':require('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked compilation')
 require(len(es)==1412 and len(native)==1368,'missing commands')
 seen=set()
 for e in native:
  cmd=e['command'];exe=Path(cmd[0]);variant=exe.parent.name
  if exe.name=='chain':
   mode,f,h,pg,hs,hmode=cmd[1:];key=f'{int(mode)}/{float(f):g}/{float(h):g}/{float(hs):g}/{int(hmode)}/{int(pg)}'
   # Runner keys retain Python formatting, including integral floats.
   def normalized(k):return tuple(map(float,k.split('/')))
   matching=[k for k in runs[variant]if normalized(k)==normalized(key)]
   require(len(matching)==1,'unknown daily command');k=matching[0];expected=runs[variant][k]
  elif exe.name=='control':
   mode,f,h,pg,hs,hmode,selector=cmd[1:];key=tuple(map(float,[selector,mode,f]));matching=[k for k in runs[variant+'-controls']if tuple(map(float,k.split('/')))==key]
   require(len(matching)==1,'unknown selector command');k=matching[0];expected=runs[variant+'-controls'][k];variant+='-controls'
  else:raise ValueError('unknown native program')
  require((variant,k)not in seen,'duplicate native command');seen.add((variant,k))
  require(data['final/'+e['stdout']].decode()==expected,'forged output')
 for opt in ('O0','O2'):
  for variant in ('original','candidate'):
   require(len(runs[opt+'-'+variant])==324 and len(runs[opt+'-'+variant+'-controls'])==18,'incomplete grid')
 for v in ('original','candidate'):
  for c in ('','-controls'):require(runs['O0-'+v+c]==runs['O2-'+v+c],'optimization drift')
 for k,old in runs['O0-original'].items():
  mode,f,h,hs,hmode,pg=map(float,k.split('/'));new=runs['O0-candidate'][k]
  if mode==0 or f==0:require(old==new,'N-OFF or f0 changed')
  else:
   a=values(old);b=values(new)
   require([l for l in old.splitlines()if l.startswith('SOURCE_N_DAY=')]==[l for l in new.splitlines()if l.startswith('SOURCE_N_DAY=')],'daily N changed')
   require(a[1]==b[1]and a[2]==b[2]and a[4]==b[4]and a[8]==b[8],'source scientific control changed')
   require(abs(a[0]-b[0]-f*h*a[2])<1e-11,'unexpected soil DM correction')
   require(abs(b[0]+b[9]-300-b[8])<1e-10 and abs(b[1]+b[10]-3)<1e-12,'whole DM/N balance')
 for k,old in runs['O0-original-controls'].items():
  selector,mode,f=map(float,k.split('/'));new=runs['O0-candidate-controls'][k]
  if selector!=1 or mode==0 or f==0:require(old==new,'unaffected selector changed')
  else:
   a=values(old,'SHARED_UPDATE_CONTROL=');b=values(new,'SHARED_UPDATE_CONTROL=')
   require(a[1:]==b[1:]and a[1]>0 and abs(b[0]-(1-f)*a[0])<1e-12,'shared potential/live/retained control')
 return {'native_programs':1368,'daily_cases_per_variant_per_opt':324,'selector_controls_per_variant_per_opt':18,'ordinary_DM_N':True,'daily_N_unchanged':True,'reset_preserves_pending':True,'soybean_grass_N_off_potential_preserved':True}
def self_test(data):
 r=json.loads(data['final/result.json']);es=json.loads(data['final/events.json']);count=0
 def reject(rr=None,ee=None,dd=None):
  nonlocal count
  try:validate(data if dd is None else dd,rr,ee)
  except (ValueError,KeyError,StopIteration,IndexError):count+=1;return
  raise AssertionError('corruption accepted')
 bad=copy.deepcopy(r);bad['runs'].pop('O2-original');reject(rr=bad)
 bad=copy.deepcopy(r);bad['runs']['O0-candidate'].pop(next(iter(bad['runs']['O0-candidate'])));reject(rr=bad)
 bad=copy.deepcopy(es);bad[0]['returncode']=1;reject(ee=bad)
 reject(ee=es[:-1])
 bad=dict(data);bad['inputs/candidate-wofost.f90']+=b'!corrupt';reject(dd=bad)
 bad=dict(data);bad['inputs/candidate.patch']+=b' ';reject(dd=bad)
 e=next(e for e in es if e['category']=='native');bad=dict(data);bad['final/'+e['stdout']]=b'forged PASS';reject(dd=bad)
 bad=copy.deepcopy(es);bad[0]['command']=[x for x in bad[0]['command']if x!='-fcheck=all'];reject(ee=bad)
 bad=dict(data);bad['inputs/growth-original.f90']=bad['inputs/growth-original.f90'].replace(b'r%gass = r%pgass * reltr',b'r%gass = r%pgass * reltr + 1d0',1);rr=copy.deepcopy(r);rr['input_sha256']['growth-original.f90']=sha(bad['inputs/growth-original.f90']);reject(rr=rr,dd=bad)
 return count
if __name__=='__main__':
 d=unpack();print(json.dumps({'science':validate(d),'corruption_controls':self_test(d)},indent=2))
