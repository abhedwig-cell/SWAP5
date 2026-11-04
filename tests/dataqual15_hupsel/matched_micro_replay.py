"""Exact accepted MICRO carrier selection and accepted original-source replay."""
import collections,hashlib,json,math,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
def source():
 helper=ROOT/'tests/physics/run_ppa_micro02_source_oracle.py'
 scope={'__file__':str(helper)}
 prefix=helper.read_text().split('FC=shlex.split',1)[0]
 exec(compile(prefix,str(helper),'exec'),scope)
 stubs=scope['STUBS']
 changes={'integer,parameter::numnod=2,numlay=1':'integer,parameter::numnod=34,numlay=34',
 'integer::layer(2)=[1,1],nod1lay(1)=[1]':'integer::layer(34)=1,nod1lay(34)=1',
 'real(8)::dz(2)=[10d0,10d0]':'real(8)::dz(34)=0d0',
 'real(8)::hroot(2),mroot(2),mflux(2)':'real(8)::hroot(34),mroot(34),mflux(34)',
 "real(8)::h(2),t1900=0d0,ksatfit(1)=[.01d0]":"real(8)::h(34),t1900=0d0,ksatfit(34)=.01d0"}
 for old,new in changes.items():assert stubs.count(old)==1;stubs=stubs.replace(old,new)
 return stubs+scope['source']+scope['TRAILER']+scope['attribution_literal'],dict(reference_sha256=scope['PIN'],attribution_reference_sha256=scope['ATTRIBUTION_PIN'],explicit_patches=scope['patches'])
def select(raw,tables,nodes,accepted,reg):
 assert len(raw)%34==0
 candidates=[raw[i:i+34] for i in range(0,len(raw),34)];selected=[]
 grouped=collections.defaultdict(lambda:collections.defaultdict(set))
 for r in tables:
  assert len(r)==6 and all(map(math.isfinite,r))
  grouped[tuple(r[:2])][(int(r[2]),int(r[3]))].add(tuple(r[4:]))
 for s in reg['selected_profiles']:
  receipt=s['receipt'];assert receipt in accepted
  expected=next(n for n in nodes if n[:2]==receipt[:2]);matches=[]
  for f in candidates:
   if f[0][:9]!=receipt:continue
   assert [int(r[9]) for r in f]==list(range(1,35)) and all(r[:9]==receipt for r in f)
   assert [r[31] for r in f]==expected[2:36] and [r[32] for r in f]==expected[36:70]
   assert [r[39] for r in f]==expected[70:104]
   matches.append(tuple(tuple(r) for r in f))
  assert matches and len(set(matches))==1,'missing/ambiguous final MICRO carrier'
  f=[list(r) for r in matches[0]];n=int(f[0][10]);assert 1<=n<=34
  assert all(len(r)==40 and all(map(math.isfinite,r)) for r in f)
  assert all(r[10:31]==f[0][10:31] for r in f)
  assert abs(math.fsum(r[39] for r in f)-receipt[6])<=1e-12
  assert abs(receipt[2]-receipt[3]-receipt[4]-receipt[5]-receipt[6])<=1e-12
  assert all(0<=r[35]<=1 and 0<=r[36]<=1 and 0<=r[37]<=1 for r in f)
  assert all(r[37]==(r[35]*r[36] if int(r[14])==1 else min(r[35],r[36])) for r in f)
  g=grouped[tuple(receipt[:2])];assert set(g)=={(j,i) for j in range(1,35) for i in range(431)}
  assert all(len(v)==1 for v in g.values()),'ambiguous hydraulic table'
  t=[[*receipt[:2],float(j),float(i),*next(iter(g[(j,i)]))] for j in range(1,35) for i in range(431)]
  selected.append((f,t))
 return selected
def analyze(raw,frame):
 lines=raw.decode().splitlines();attrs=[l for l in lines if l.startswith('ATTR ')]
 assert len(attrs)==1
 a=list(map(float,attrs[0].split()[1:]));expected=[frame[0][3],frame[0][4],frame[0][5],frame[0][27]]
 assert all(map(math.isfinite,a)) and max(abs(x-y) for x,y in zip(a,expected))<=1e-14
 checks=[l for l in lines if l.startswith('CHECK ')];nodes=[l for l in lines if l.startswith('NODE ')]
 assert len(checks)==1 and len(nodes)==int(frame[0][10])
 flags=list(map(int,checks[0].split()[1:4]));errors=[];source_values=[]
 for i,l in enumerate(nodes):
  r=list(map(float,l.split()[1:]));assert int(r[0])==i+1 and r[2]==frame[i][39]
  if not all(map(math.isfinite,r)):errors.append(float('inf'));continue
  source_values.append(r[1])
  assert abs(r[3]-abs(r[1]-r[2]))<=1e-15;errors.append(r[3])
 native_leaf=None;source_leaf=None
 if int(frame[0][13])==1 and any(r[31]<0 and r[37]>0 for r in frame[:int(frame[0][10])]):
  potential=frame[0][2];half=frame[0][19];exponent=frame[0][20]
  native_leaf=frame[0][6]-potential/(1+(frame[0][29]/half)**exponent)
  source_leaf=math.fsum(source_values)-potential/(1+(float(checks[0].split()[8])/half)**exponent)
  assert abs(native_leaf)<=frame[0][23]
 return dict(attribution_maximum_error=max(abs(x-y) for x,y in zip(a,expected)),source_checks=flags,
  maximum_node_uptake_error=max(errors),inside_unchanged_node_bound=all(flags) and max(errors)<=2e-5,
  original_leaf_Tact=checks[0].split()[4],original_node_total=math.fsum(source_values),native_total=frame[0][6],native_leaf_demand_defect=native_leaf,original_leaf_demand_defect=source_leaf)
def replay(selected,opt,out,fc):
 out.mkdir(exist_ok=True);literal,metadata=source();(out/'literal.f90').write_text(literal,encoding='utf-8',newline='\n')
 exe=out/'oracle.exe';cmd=[str(fc),'-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(out),'-I'+str(out),str(out/'literal.f90'),str(ROOT/'tests/dataqual15_hupsel/matched_micro_driver.f90'),'-o',str(exe)]
 p=subprocess.run(cmd,cwd=out,capture_output=True,timeout=180);(out/'compile.stdout').write_bytes(p.stdout);(out/'compile.stderr').write_bytes(p.stderr);assert p.returncode==0,p.stderr
 record=dict(**metadata,command=cmd,compiler=subprocess.check_output([str(fc),'--version'],text=True).splitlines()[0],source_sha256=sha(literal.encode()),executable_sha256=sha(exe.read_bytes()),profiles=[])
 for i,(frame,tab) in enumerate(selected):
  payload='\n'.join(' '.join(f'{v:.17e}' for v in row) for row in frame+tab)+'\n';(out/f'{i}.input').write_bytes(payload.encode())
  p=subprocess.run([str(exe)],input=payload.encode(),cwd=out,capture_output=True,timeout=120)
  (out/f'{i}.stdout').write_bytes(p.stdout);(out/f'{i}.stderr').write_bytes(p.stderr)
  assert p.returncode==0,(i,p.stdout,p.stderr)
  result=analyze(p.stdout,frame);record['profiles'].append(dict(profile=i,input_sha256=sha(payload.encode()),output_sha256=sha(p.stdout),returncode=p.returncode,**result))
 (out/'REPLAY.json').write_text(json.dumps(record,indent=2)+'\n');return record
def require_uptake_gate(profiles):
 # Raw original outputs remain on disk if this fails. A retained discrepancy
 # is evidence to adjudicate, never an admitted original-uptake PASS.
 assert all(p['inside_unchanged_node_bound'] and all(p['source_checks']) for p in profiles)
