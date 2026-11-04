"""Controlled standalone root-pressure experiment, never a production admission."""
import argparse,hashlib,io,json,math,os,subprocess,sys,tarfile,tempfile,copy
from pathlib import Path
from full_profile_evidence import unpack
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'integration/dataqual15_hupsel'
PROCESS='src/process/mod_root_micro_de_willigen_process.f90'
TABLE='src/process/mod_root_micro_matric_flux_table.f90'
STEM='MICRO_PRESSURE_PROBE_EVIDENCE_20261104'
sha=lambda b:hashlib.sha256(b).hexdigest()
norm=lambda p:sha(p.read_bytes().replace(b'\r\n',b'\n'))
OLD='''      if(abs(fm)<=parameters%residual_tolerance_cm_per_day.or. &
         abs(hi-lo)<=parameters%pressure_tolerance_cm) exit
'''
NEW='''      if(abs(hi-lo)<=parameters%pressure_tolerance_cm) exit
'''
TRACE='''    write(*,'(a,1x,i0,5(1x,es25.17e3))')'GLOBAL',iteration,lo,hi,mid,fm,parameters%pressure_tolerance_cm
'''
FIXTURE='''
  subroutine bind_exact_observed_table(table,m,k,dry,sat,mismatches,largest,status)
    type(micro_matric_flux_table_t),intent(inout)::table
    real(real64),intent(in)::m(MICRO_TABLE_POINTS),k(MICRO_TABLE_POINTS),dry,sat
    integer,intent(out)::mismatches,status
    real(real64),intent(out)::largest
    status=MICRO_TABLE_INVALID;mismatches=0;largest=0d0
    if(.not.table%ready)return
    if(any(.not.ieee_is_finite(m)).or.any(m<0d0))return
    if(any(m(:MICRO_TABLE_POINTS-1)<m(2:)))return
    if(any(table%k/=k).or.table%dry_k/=dry.or.table%saturated_k/=sat)return
    mismatches=count(table%m/=m);largest=maxval(abs(table%m-m))
    ! Isolated coefficient fixture only: use the exact admitted observations,
    ! never an approximate reconstruction, for BOTH experimental variants.
    table%m=m;status=MICRO_TABLE_OK
  end subroutine
'''
def sources(variant):
 original=(ROOT/PROCESS).read_text();assert original.count(OLD)==1
 s=original if variant=='incumbent' else original.replace(OLD,NEW)
 anchor='    ! Re-evaluate at the published pressure: residual evaluation owns X.\n';assert s.count(anchor)==1
 s=s.replace(anchor,TRACE+anchor)
 restored=s.replace(TRACE,'');assert restored==(original if variant=='incumbent' else original.replace(OLD,NEW))
 t=(ROOT/TABLE).read_text();anchor='  public :: build_micro_matric_flux_table, evaluate_micro_matric_flux_table\n';assert t.count(anchor)==1
 t=t.replace(anchor,anchor+'  public :: bind_exact_observed_table\n').replace('\ncontains\n','\ncontains\n'+FIXTURE)
 assert t.replace(FIXTURE,'').replace('  public :: bind_exact_observed_table\n','')==(ROOT/TABLE).read_text()
 return t,s
def parse(raw,frame,variant):
 lines=raw.decode().splitlines();get=lambda tag:[l.split()[1:] for l in lines if l.startswith(tag+' ')]
 assert get('STATUS')==[['0']]
 heads=get('HEAD');attrs=get('ATTR');nodes=get('NODE');tables=get('TABLE');trace=get('GLOBAL')
 assert len(heads)==len(attrs)==1 and len(nodes)==len(tables)==34
 h=list(map(float,heads[0]));a=list(map(float,attrs[0]));sinks=[float(r[1]) for r in nodes]
 assert all(map(math.isfinite,h+a+sinks))
 assert [int(r[0]) for r in nodes]==[int(r[0]) for r in tables]==list(range(1,35))
 assert abs(math.fsum(sinks)-h[2])<=1e-14 and h[2]<=frame[0][2]
 assert abs(frame[0][2]-h[2]-math.fsum(a[:3]))<=1e-14
 active=any(r[31]<0 and r[37]>0 for r in frame[:int(frame[0][10])])
 if active:
  assert len(trace)==1;v=list(map(float,trace[0]));assert 1<=int(v[0])<=int(frame[0][24])
  assert v[3]==h[0] and abs(v[4])<=frame[0][23] and v[5]==frame[0][21]
  if variant=='pressure':assert abs(v[2]-v[1])<=frame[0][21]
 else:assert not trace
 error=max(abs(v-r[39]) for v,r in zip(sinks,frame))
 if variant=='incumbent':
  assert error<=1e-14 and abs(h[0]-frame[0][28])<=1e-12 and abs(h[1]-frame[0][29])<=1e-12
  assert max(abs(v-frame[0][j]) for v,j in zip(a,(3,4,5,27)))<=1e-14
 leaf=None
 if active and int(frame[0][13])==1:leaf=h[2]-frame[0][2]/(1+(h[1]/frame[0][19])**frame[0][20])
 return dict(head=h,attribution=a,node_sinks=sinks,maximum_actual_sink_difference=error,
  global_trace=[list(map(float,r)) for r in trace],leaf_demand_remainder=leaf,
  coefficient_reconstruction_mismatches=sum(int(r[1]) for r in tables),
  coefficient_reconstruction_maximum_difference=max(float(r[2]) for r in tables))
def run(opt,variant,payloads,out,fc):
 out.mkdir(exist_ok=True);table,process=sources(variant);(out/'table.f90').write_text(table,encoding='utf-8',newline='\n');(out/'process.f90').write_text(process,encoding='utf-8',newline='\n')
 exe=out/'probe.exe';cmd=[str(fc),'-'+opt,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(out),'-J'+str(out),str(out/'table.f90'),str(out/'process.f90'),str(ROOT/'tests/dataqual15_hupsel/micro_pressure_probe_driver.f90'),'-o',str(exe)]
 p=subprocess.run(cmd,cwd=out,capture_output=True,timeout=180);(out/'compile.stdout').write_bytes(p.stdout);(out/'compile.stderr').write_bytes(p.stderr);assert p.returncode==0,p.stderr
 reports=[]
 for i,payload in enumerate(payloads):
  (out/f'{i}.input').write_bytes(payload);p=subprocess.run([str(exe)],input=payload,cwd=out,capture_output=True,timeout=120)
  (out/f'{i}.stdout').write_bytes(p.stdout);(out/f'{i}.stderr').write_bytes(p.stderr);assert p.returncode==0,(i,p.stdout,p.stderr)
  frame=[list(map(float,l.split())) for l in payload.splitlines()[:34]];reports.append(parse(p.stdout,frame,variant))
 record=dict(compiler=subprocess.check_output([str(fc),'--version'],text=True).splitlines()[0],command=cmd,variant=variant,optimization=opt,executable_sha256=sha(exe.read_bytes()),table_source_sha256=sha(table.encode()),process_source_sha256=sha(process.encode()),profiles=reports)
 (out/'RUN.json').write_text(json.dumps(record,indent=2)+'\n');return record
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);p.add_argument('--compiler',default=os.environ.get('FC','gfortran'));a=p.parse_args()
 subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/matched_micro_evidence.py'),'--compiler',a.compiler],cwd=ROOT,check=True)
 m=json.loads((BASE/'MATCHED_MICRO_EVIDENCE_20261104.json').read_text());path=BASE/'MATCHED_MICRO_EVIDENCE_20261104.tar.xz';assert sha(path.read_bytes())==m['archive_sha256'];old=unpack(path,m['files_sha256'])
 if a.capture:files={}
 else:
  record=json.loads((BASE/(STEM+'.json')).read_text());assert not record['production_admission']
  for n,h in record['normalized_repository_dependency_sha256'].items():assert norm(ROOT/n)==h,n
  path=BASE/(STEM+'.tar.xz');assert sha(path.read_bytes())==record['archive_sha256'];files=unpack(path,record['files_sha256'])
 results={}
 with tempfile.TemporaryDirectory(prefix='micro-pressure-probe-') as temp:
  root=a.capture.resolve() if a.capture else Path(temp);root.mkdir(exist_ok=True)
  for opt in ('O0','O2'):
   payloads=[old[f'literal-{opt}/{i}.input'] for i in range(8)];results[opt]={}
   for variant in ('incumbent','pressure'):
    out=root/(opt+'-'+variant);r=run(opt,variant,payloads,out,a.compiler);results[opt][variant]=r
    if not a.capture:
     saved=json.loads(files[opt+'-'+variant+'/RUN.json']);t,s=sources(variant)
     assert files[opt+'-'+variant+'/table.f90'].decode()==t and files[opt+'-'+variant+'/process.f90'].decode()==s
     assert sha(files[opt+'-'+variant+'/probe.exe'])==saved['executable_sha256']
     for i,payload in enumerate(payloads):
      frame=[list(map(float,l.split())) for l in payload.splitlines()[:34]]
      assert files[f'{opt}-{variant}/{i}.input']==payload
      assert parse(files[f'{opt}-{variant}/{i}.stdout'],frame,variant)==saved['profiles'][i]
  # Real-output mutation: a candidate cannot claim a converged bracket while
  # exceeding the exact unchanged configured head tolerance.
  raw=(root/'O0-pressure/0.stdout').read_text();lines=raw.splitlines();i=next(i for i,l in enumerate(lines) if l.startswith('GLOBAL '));v=lines[i].split();v[3]=str(float(v[2])+1);lines[i]=' '.join(v)
  frame=[list(map(float,l.split())) for l in old['literal-O0/0.input'].splitlines()[:34]]
  try:parse(('\n'.join(lines)+'\n').encode(),frame,'pressure')
  except AssertionError:pass
  else:raise AssertionError('accepted unconverged candidate bracket')
  for label in ('iteration_cap','tolerance_tag'):
   lines=raw.splitlines();i=next(i for i,l in enumerate(lines) if l.startswith('GLOBAL '));v=lines[i].split()
   if label=='iteration_cap':v[1]=str(int(frame[0][24])+1)
   else:v[6]=str(frame[0][21]*2)
   lines[i]=' '.join(v)
   try:parse(('\n'.join(lines)+'\n').encode(),frame,'pressure')
   except AssertionError:pass
   else:raise AssertionError('accepted forged '+label)
  lines=(root/'O0-incumbent/0.stdout').read_text().splitlines();i=next(i for i,l in enumerate(lines) if l.startswith('NODE '));v=lines[i].split();v[2]=str(float(v[2])+1e-6);lines[i]=' '.join(v)
  try:parse(('\n'.join(lines)+'\n').encode(),frame,'incumbent')
  except AssertionError:pass
  else:raise AssertionError('accepted altered incumbent sink')
  lines=old['literal-O0/0.input'].decode().splitlines();v=lines[35].split();v[4]='-1';lines[35]=' '.join(v)
  bad=subprocess.run([str(root/'O0-incumbent/probe.exe')],input=('\n'.join(lines)+'\n').encode(),capture_output=True,timeout=60)
  (root/'O0-incumbent/CONTROL_BAD_TABLE.stdout').write_bytes(bad.stdout);(root/'O0-incumbent/CONTROL_BAD_TABLE.stderr').write_bytes(bad.stderr)
  assert bad.returncode!=0,'accepted malformed observed coefficient table'
  if a.capture:
   for f in root.rglob('*'):
    if f.is_file() and f.suffix!='.mod':files[f.relative_to(root).as_posix()]=f.read_bytes()
 summary={}
 for opt,r in results.items():
  summary[opt]={v:dict(maximum_leaf_remainder=max(abs(p['leaf_demand_remainder'] or 0) for p in x['profiles']),maximum_iterations=max([int(p['global_trace'][0][0]) if p['global_trace'] else 0 for p in x['profiles']]),constructor_mismatches=sum(p['coefficient_reconstruction_mismatches'] for p in x['profiles'])) for v,x in r.items()}
  for variant,x in r.items():
   errors=[]
   for i,profile in enumerate(x['profiles']):
    expected=[float(l.split()[2]) for l in old[f'literal-{opt}/{i}.stdout'].decode().splitlines() if l.startswith('NODE ')];errors.extend(abs(a-b) for a,b in zip(profile['node_sinks'],expected))
   summary[opt][variant]['maximum_original_node_difference']=max(errors)
   assert max(errors)<=2e-5,'unchanged original-source nodal bound exceeded'
 if a.capture:
  files['AUDIT.json']=(json.dumps(dict(results=results,summary=summary,production_admission=False),indent=2)+'\n').encode();path=BASE/(STEM+'.tar.xz')
  with tarfile.open(path,'w:xz') as t:
   for n,b in sorted(files.items()):entry=tarfile.TarInfo(n);entry.size=len(b);entry.mtime=0;t.addfile(entry,io.BytesIO(b))
  deps=dict(m['normalized_repository_dependency_sha256'])
  for n in ('tests/dataqual15_hupsel/micro_pressure_probe.py','tests/dataqual15_hupsel/micro_pressure_probe_driver.f90','.github/workflows/hupsel-micro-pressure-probe.yml','integration/dataqual15_hupsel/MICRO_PRESSURE_PROBE_PREREGISTRATION_20261104.json'):deps[n]=norm(ROOT/n)
  (BASE/(STEM+'.json')).write_text(json.dumps(dict(archive_sha256=sha(path.read_bytes()),files_sha256={n:sha(b) for n,b in files.items()},normalized_repository_dependency_sha256=deps,production_admission=False),indent=2)+'\n')
 print('CONTROLLED_MICRO_PRESSURE_PROBE_COMPLETE_NOT_PRODUCTION_ADMISSION');print(json.dumps(summary))
if __name__=='__main__':main()
