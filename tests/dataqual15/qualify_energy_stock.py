"""Observe endpoint energy stocks through the unchanged real heat owner.

These are explicit same-state probes, never continuations of a bound checkpoint.
The independent stock oracle is not a replacement heat solver.
"""
import argparse,csv,hashlib,io,json,math,os,struct,subprocess,sys,tarfile,time
from pathlib import Path
from checkpoint_layout import layout
from sprint03_evidence import verify as verify_predecessor
ROOT=Path(__file__).resolve().parents[2]
CAP=ROOT/'integration/dataqual15/SPRINT03_EVIDENCE.tar.xz'
SOURCES=[ROOT/p for p in ['src/transaction/mod_transaction_reference.f90',
 'src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_process_hydraulic_view.f90',
 'src/process/mod_soil_temperature_contract.f90','src/process/mod_restricted_soil_temperature.f90',
 'tests/dataqual15/energy_stock_driver.f90']]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()

def read_cases(path):
 lines=iter(path.read_text().splitlines());n,count=map(int,next(lines).split())
 geometry=[list(map(float,next(lines).split()))for _ in range(8)];cases=[]
 assert n==113 and all(len(x)==n for x in geometry)
 for _ in range(count):
  day,kind,dt,air=map(float,next(lines).split());arrays=[list(map(float,next(lines).split()))for _ in range(4)]
  assert all(len(x)==n for x in arrays);cases.append(dict(day=int(day),kind=int(kind),dt=dt,air=air,head=arrays[0],theta0=arrays[1],theta1=arrays[2],old=arrays[3]))
 assert next(lines,None)is None
 return geometry,cases

def observe(path,inputs):
 geometry,cases=read_cases(inputs);params={};energy={};nodes={}
 for line in path.read_text().splitlines():
  fields=line.split(',');kind=fields[0]
  if kind=='PARAM':
   node=int(fields[1]);assert node not in params;params[node]=list(map(float,fields[2:]))
  elif kind=='ENERGY':
   case=int(fields[1]);assert case not in energy;energy[case]=list(map(float,fields[2:]))
  elif kind=='NODE':
   key=tuple(map(int,fields[1:3]));assert key not in nodes;nodes[key]=list(map(float,fields[3:]))
 assert 'REAL_HEAT_ENERGY_STOCK_OBSERVATIONS_COMPLETE'in path.read_text()
 assert set(params)==set(range(1,114))and set(energy)==set(range(1,len(cases)+1))and len(nodes)==113*len(cases)
 # J cm-3 K-1, independently transcribed source constants (including air).
 def capacity(p,theta):
  dz,porosity,fq,fc,fo,dist=p
  return (fq*2660*800+fc*2650*900+fo*1300*1920+theta*1000*4180+max(0.,porosity-theta)*1.2*1010)*1e-6
 rows=[]
 for index,case in enumerate(cases,1):
  dt,air,reported_storage,boundary,residual,top,bottom=energy[index]
  assert dt==case['dt']and air==case['air'];a=case['theta0'];b=case['theta1'];old=case['old']
  output=[nodes[index,j]for j in range(1,114)];new=[v[0]for v in output]
  c0=[capacity(params[j+1],a[j])for j in range(113)];c1=[capacity(params[j+1],b[j])for j in range(113)]
  cm=[capacity(params[j+1],.5*(a[j]+b[j]))for j in range(113)];dz=geometry[1]
  for j in range(113):assert params[j+1][0]==dz[j]and params[j+1][1]==geometry[3][j]and params[j+1][5]==geometry[2][j]
  stock0=math.fsum(c*t*d for c,t,d in zip(c0,old,dz));stock1=math.fsum(c*t*d for c,t,d in zip(c1,new,dz))
  equation=math.fsum(c*d*(v-u)for c,d,u,v in zip(cm,dz,old,new))
  capacity_term=math.fsum((v-u)*.5*(x+y)*d for u,v,x,y,d in zip(c0,c1,old,new,dz))
  independent_top=output[0][2]*(air-new[0])/geometry[2][0]
  row=dict(case=index,day=case['day'],kind=case['kind'],dt=dt,equation_storage=equation,
   reported_storage=reported_storage,boundary_energy=boundary,reported_residual=residual,
   endpoint_stock_change=stock1-stock0,capacity_exchange=capacity_term,
   stock_identity_residual=stock1-stock0-equation-capacity_term,
   endpoint_stock_minus_boundary=stock1-stock0-boundary,
   independent_boundary_residual=equation-dt*independent_top,
   maximum_capacity_difference=max(abs(c-v[1])for c,v in zip(cm,output)),
   maximum_temperature_change=max(abs(x-y)for x,y in zip(old,new)),
   maximum_water_change=max(abs(x-y)for x,y in zip(a,b)))
  assert all(math.isfinite(v)for v in row.values())
  assert abs(equation-reported_storage)<=5e-9 and abs(boundary-dt*(top+bottom))<=5e-9
  assert abs(top-independent_top)*dt<=5e-9 and bottom==0.
  assert abs(row['independent_boundary_residual'])<=5e-9
  assert abs(row['stock_identity_residual'])<=5e-9 and row['maximum_capacity_difference']<=5e-12
  if case['kind']==0:assert abs(row['endpoint_stock_minus_boundary'])<=5e-9
  if case['kind']in [2,3]:assert row['maximum_temperature_change']<=5e-10
  if case['kind']==3:assert abs(row['endpoint_stock_minus_boundary'])<=5e-9
  rows.append(row)
 return rows

def verify(out):
 r=json.loads((out/'RESULT.json').read_text());assert r['status']=='REAL_HEAT_ENDPOINT_STOCK_AUDIT_COMPLETE'
 for name,digest in r['source_sha256'].items():assert sha(ROOT/name)==digest,name
 assert sha(CAP)==r['predecessor_archive_sha256']
 for name,digest in r['file_sha256'].items():assert sha(out/name)==digest,name
 observations={opt:observe(out/opt/'native.stdout',out/'inputs.dat')for opt in ['O0','O2']}
 assert observations['O0']==observations['O2']==r['observations']
 assert all(e['returncode']==0 and not e['censored']for e in r['events'])
 with tarfile.open(CAP)as t:assert(out/'input.swp').read_bytes()==t.extractfile('adaptive-O2/input.swp').read()
 print(json.dumps(dict(status='SOURCE_BOUND_ENERGY_STOCK_RAW_AUDIT_PASS',cases_per_optimization=len(r['observations']),whole_project_energy_qualified=False),indent=2))
 return observations

def make_inputs(out):
 meta=json.loads(CAP.with_name('SPRINT03_EVIDENCE_MANIFEST.json').read_text());assert sha(CAP)==meta['archive_sha256']
 with tarfile.open(CAP)as t:
  snapshots={}
  for member in t.getnames():
   if member.startswith('adaptive-O2/checkpoint')and member.endswith('.bin'):
    raw=t.extractfile(member).read();snapshots[int(layout(raw)['clock'])]=raw
  swp=t.extractfile('adaptive-O2/input.swp').read();weather=t.extractfile('adaptive-O2/input.met').read()
 (out/'input.swp').write_bytes(swp)
 def table(first):
  lines=iter(swp.decode().splitlines())
  for line in lines:
   if line.split()[:len(first)]==first:break
  values=[]
  for line in lines:
   if line.strip().startswith('* End of table'):break
   if line.strip()and not line.lstrip().startswith('*'):values.append(list(map(float,line.split())))
  assert values;return values
 layers=[int(row[1])-1 for row in table(['ISUBLAY','ISOILLAY'])for _ in range(int(row[3]))]
 porosities=[row[1]for row in table(['ORES','OSAT'])];porosity=[porosities[i]for i in layers];assert len(layers)==113
 texture=table(['PSAND','PSILT','PCLAY','ORGMAT']);textures=[[texture[i][j]for i in layers]for j in range(4)]
 met=list(csv.DictReader(line for line in weather.decode().splitlines()if line.strip()and not line.lstrip().startswith('*')))
 first=next(iter(snapshots.values()));state=layout(first);n=state['nodes'];z=struct.unpack_from('='+str(n)+'d',first,state['header']+48);dz=struct.unpack_from('='+str(n)+'d',first,state['header']+48+8*n);dist=[.5*dz[0]]+[.5*(dz[i-1]+dz[i])for i in range(1,n)];cases=[]
 for day,raw in sorted(snapshots.items()):
  state=layout(raw);head=list(struct.unpack_from('=113d',raw,state['physical']));theta=list(struct.unpack_from('=113d',raw,state['physical']+8*n));temp=list(struct.unpack_from('=113d',raw,state['physical']+16*n+16));w=met[min(day,len(met)-1)];air=.5*(float(w['Tmin'])+float(w['Tmax']))
  for dt in [.04,.02,.01]:
   cases.append([day,0,dt,air,head,theta,theta,temp])
   if day+1 not in snapshots:continue
   following=snapshots[day+1];right=struct.unpack_from('=113d',following,layout(following)['physical']+8*n);end=[a+dt*(b-a)for a,b in zip(theta,right)]
   cases.append([day,1,dt,air,head,theta,end,temp])
   for kind,value in [(2,5.),(3,0.)]:cases.append([day,kind,dt,value,head,theta,end,[value]*n])
 with(out/'inputs.dat').open('w',newline='\n')as f:
  emit=lambda values:f.write(' '.join(format(v,'.17e')for v in values)+'\n')
  f.write(f'{n} {len(cases)}\n')
  for values in [z,dz,dist,porosity,*textures]:emit(values)
  for day,kind,dt,air,*arrays in cases:
   f.write(f'{day} {kind} {dt:.17e} {air:.17e}\n')
   for values in arrays:emit(values)
 return dict(checkpoint_sha256={str(k):hashlib.sha256(v).hexdigest()for k,v in snapshots.items()},cases=len(cases),predecessor_archive_sha256=sha(CAP))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path);p.add_argument('--output',type=Path);p.add_argument('--verify',type=Path);a=p.parse_args()
 if a.verify:verify(a.verify.resolve());return
 verify_predecessor();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);fc=str(a.compiler.resolve());events=[]
 r=dict(status='IN_PROGRESS',scope=__doc__,criteria=json.loads((ROOT/'integration/dataqual15/STATUS.json').read_text())['sprint04']['criteria'],events=events,whole_project_energy_qualified=False,canonical_modified=False,production_changed=False)
 def save():(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n',newline='\n')
 r.update(make_inputs(out));r['source_sha256']={p.relative_to(ROOT).as_posix():sha(p)for p in SOURCES+[Path(__file__),ROOT/'tests/dataqual15/checkpoint_layout.py']};save()
 def run(command,label,cwd,timeout=120):
  begin=time.monotonic();index=len(events)
  with(out/f'{index}.stdout').open('wb')as so,(out/f'{index}.stderr').open('wb')as se:
   try:proc=subprocess.run(list(map(str,command)),cwd=cwd,stdout=so,stderr=se,timeout=timeout);code=proc.returncode;censored=False
   except subprocess.TimeoutExpired:code=None;censored=True
  events.append(dict(label=label,command=list(map(str,command)),returncode=code,censored=censored,seconds=time.monotonic()-begin,stdout=f'{index}.stdout',stderr=f'{index}.stderr'));save();assert code==0 and not censored,(label,out/f'{index}.stderr')
  return out/f'{index}.stdout'
 observations={}
 for opt in ['O0','O2']:
  folder=out/opt;folder.mkdir();flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(folder),'-J'+str(folder)];objects=[]
  for i,source in enumerate(SOURCES):
   obj=folder/f'{i}.o';run([fc,*flags,'-c',source,'-o',obj],'compile-'+opt,folder);objects.append(obj)
  exe=folder/('energy.exe'if os.name=='nt'else'energy');args=folder/'link.args';args.write_text('\n'.join('"'+str(v).replace('\\','/')+'"'for v in [*objects,'-o',exe]),newline='\n');run([fc,'@'+str(args)],'link-'+opt,folder)
  raw=run([exe,out/'inputs.dat'],'native-'+opt,out);(folder/'native.stdout').write_bytes(raw.read_bytes());observations[opt]=observe(folder/'native.stdout',out/'inputs.dat')
 assert observations['O0']==observations['O2'];r['observations']=observations['O2'];r['compiler']=subprocess.check_output([fc,'--version'],text=True).splitlines()[0];r['status']='REAL_HEAT_ENDPOINT_STOCK_AUDIT_COMPLETE'
 r['file_sha256']={p.relative_to(out).as_posix():sha(p)for p in out.rglob('*')if p.is_file()and p.name!='RESULT.json'and(p.suffix in ['.dat','.stdout','.stderr','.swp','.args','.exe']or p.name=='energy')}
 save();verify(out)
if __name__=='__main__':main()
