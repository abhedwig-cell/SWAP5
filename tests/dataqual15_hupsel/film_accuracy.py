"""Independent original-state film reference fixture; never a production path."""
import argparse,base64,gzip,hashlib,json,math,os,subprocess,time
from pathlib import Path
import mpmath as mp
import original_chronology_evidence as parent
ROOT=parent.ROOT;BASE=parent.BASE
sha=lambda b:hashlib.sha256(b).hexdigest()
USE='      use film_accuracy_fixture, only: fixture_enabled, certified_film\n'
SEAM='        if(fixture_enabled)waterfilm_thickness=certified_film(node)\n'
ANCHOR='! --- Calculate microbial respiration rate\n'
MODULE='''module film_accuracy_fixture
 use ieee_arithmetic,only:ieee_is_finite
 logical::fixture_enabled=.false.
 real(8)::certified_film(34)=0d0
end module
'''

def frames(raw):
 lines=raw.decode('ascii').splitlines();assert len(lines)==3206*34
 result=[]
 for offset in range(0,len(lines),34):
  group=[line.split() for line in lines[offset:offset+34]]
  assert all(len(row)==41 and all(math.isfinite(float(x)) for x in row) for row in group)
  n=int(float(group[0][10]));assert 1<=n<=34
  assert all(float(row[9])==i+1 and float(row[10])==n for i,row in enumerate(group))
  assert all(row[:2]==group[0][:2] for row in group)
  assert 583<=float(group[0][0])<float(group[0][1])<=584.00000000001
  if result:assert abs(float(result[-1][0][1])-float(group[0][0]))<1e-11
  result.append(group[:n])
 assert abs(float(result[0][0][0])-583)<1e-11 and abs(float(result[-1][0][1])-584)<1e-11
 return result

def film(fields,digits=50,quadrature=False):
 assert len(fields)==41 and all(math.isfinite(float(x)) for x in fields)
 with mp.workdps(digits):
  row=list(map(mp.mpf,fields));head=row[11];gfp=max(mp.mpf(0),row[22]-row[12])
  if head>=0 or gfp<mp.mpf('1e-4'):return mp.mpf(0)
  upper=-100*head
  if upper>mp.mpf('1e7'):return mp.mpf('1e-8')
  lo=mp.mpf('1e-10');alpha=row[24]/100;n=row[26];m=row[27]
  assert alpha>0 and n>1 and m>0 and row[22]>row[21] and upper>lo
  sigma=mp.mpf('0.07275')*(1-mp.mpf('0.002')*(row[13]+273-291));assert sigma>0
  capac=(row[22]-row[21])*alpha*n*m
  def z(x):u=(alpha*x)**n;return u/(1+u)
  integral=capac/(4*mp.pi*sigma**2*n*alpha**3)*mp.betainc(1+2/n,m-2/n,z(lo),z(upper))
  assert mp.isfinite(integral) and integral>0
  if quadrature:
   def f(t):
    x=mp.exp(t);return capac*(alpha*x)**(n-1)*(1+(alpha*x)**n)**(-m-1)*x**3/(4*mp.pi*sigma**2)
   points=[mp.log(lo)+(mp.log(upper)-mp.log(lo))*i/4 for i in range(5)]
   check=mp.quad(f,points)
   assert abs(check-integral)<mp.mpf('1e-35')*abs(integral)
  value=2*(mp.sqrt(1/(mp.pi*integral))-2*sigma/upper)
  assert mp.isfinite(value) and value>0
  return +value

def adapted_source(literal):
 literal=literal.replace('\r\n','\n')
 assert literal.count('      use MOD_arrays,            only: macp, matab\n')==1 and literal.count(ANCHOR)==1
 result=literal.replace('      use MOD_arrays,            only: macp, matab\n',USE+'      use MOD_arrays,            only: macp, matab\n').replace(ANCHOR,SEAM+ANCHOR)
 assert result.replace(USE,'').replace(SEAM,'')==literal
 return result

def adapted_driver(original):
 pairs=[(' use iso_fortran_env,only:real64\n',' use iso_fortran_env,only:real64\n use film_accuracy_fixture\n'),
 (' integer::i,n,io,record,u,status\n',' integer::i,n,io,record,u,status,w,seq,wn\n'),
 (' record=0\n'," call get_command_argument(2,name)\n fixture_enabled=len_trim(name)>0\n if(fixture_enabled)open(newunit=w,file=trim(name),status='old')\n record=0\n"),
 ('  c_top=0d0\n',"  if(fixture_enabled)then\n   read(w,*,iostat=io)seq,wn,certified_film(1:n)\n   if(io/=0.or.seq/=record.or.wn/=n)error stop 'witness coverage'\n   if(any(.not.ieee_is_finite(certified_film(1:n))).or.any(certified_film(1:n)<0d0))error stop 'witness finite'\n  end if\n  c_top=0d0\n"),
 (' if(record==0)error stop \'empty original forcing\'\n'," if(record==0)error stop 'empty original forcing'\n if(fixture_enabled)then\n  read(w,*,iostat=io)seq\n  if(io>=0)error stop 'extra witness'\n end if\n")]
 result=original
 for a,b in pairs:assert result.count(a)==1;result=result.replace(a,b)
 for a,b in reversed(pairs):result=result.replace(b,a)
 assert result==original
 result=original
 for a,b in pairs:result=result.replace(a,b)
 return result

def native_refusals(exe,frame,table,out):
 lines=table.read_text().splitlines();first=lines[0].split();trials={}
 for name,index,value in [('wrong-record',0,'0'),('wrong-node-count',1,'35'),('nonfinite',2,'NaN'),('negative',2,'-1')]:
  row=first.copy();row[index]=value;trials[name]=' '.join(row)+'\n'+'\n'.join(lines[1:])+'\n'
 trials['truncated']='\n'.join(lines[:-1])+'\n';trials['extra']='\n'.join(lines)+'\n1\n'
 results=[]
 for name,raw in trials.items():
  bad=out/(name+'.dat');bad.write_text(raw,encoding='ascii')
  run=subprocess.run([str(exe),str(frame),str(bad)],cwd=out,capture_output=True,timeout=300)
  (out/(name+'.stderr')).write_bytes(run.stderr)
  assert run.returncode!=0,(name,'invalid reference fixture accepted')
  assert b'witness' in run.stderr or b'floating-point exception' in run.stderr.lower(),(name,run.stderr[-1000:])
  results.append(dict(name=name,returncode=run.returncode,stderr_sha256=sha(run.stderr)))
  bad.unlink() # only this freshly written corrupt fixture, never model state
 return results

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',default=os.environ.get('FC','gfortran'));a=p.parse_args()
 out=a.output.resolve();out.mkdir();start=time.monotonic()
 record=json.loads((BASE/'ORIGINAL_CHRONOLOGY_EVIDENCE_20261104.json').read_text())
 assert record['archive_sha256']=='99adab40cc703f4533abc89befa5d16d76d6a36d1b7a09ef3e463becf997c1db'
 # The app envelope successor is not compiled in this component fixture. Its
 # sole allowed delta still requires the exact registered current guard; the
 # immutable older dependency is checked from its committed predecessor bytes.
 import production_diagnostic_admission as admission
 scope=json.loads((ROOT/admission.SCOPE).read_text());admission.current_guard(scope)
 for path,pin in record['normalized_repository_dependency_sha256'].items():
  if path==admission.APP:
   old_source=subprocess.check_output(['git','show',scope['predecessor']+':'+path],cwd=ROOT)
   assert sha(old_source.replace(b'\r\n',b'\n'))==pin,path
  else:assert parent.norm(ROOT/path)==pin,path
 files=parent.unpack(record)
 raw=files['micro/case/original_factor_inputs.dat'];groups=frames(raw)
 carrier=json.loads((ROOT/'integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json').read_text());literal=gzip.decompress(base64.b64decode(carrier['gzip_base64']));assert sha(literal)==carrier['sha256']=='8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87'
 old=[list(map(float,l.split()))for l in files['cold-factor-O2/comparison.stdout'].decode().splitlines()]
 assert len(old)==sum(map(len,groups))
 cases=[(i,j,row)for i,g in enumerate(groups)for j,row in enumerate(g)]
 assert [(int(r[0])-1,int(r[1])-1)for r in old]==[(i,j)for i,j,_ in cases]
 # Selection uses independent physical extrema and the retained failure, before treatment.
 keys=[lambda k:abs(old[k][4]-old[k][5]),lambda k:float(cases[k][2][11]),lambda k:-float(cases[k][2][11]),lambda k:float(cases[k][2][13]),lambda k:-float(cases[k][2][13])]
 selected=sorted(set([0,len(cases)-1]+[max(range(len(cases)),key=key)for key in keys]))
 values=[];witnesses=[]
 for k,(i,j,row)in enumerate(cases):
  value=film(row)
  values.append(mp.nstr(value,45))
  if k in selected:
   high=film(row,80,True)
   with mp.workdps(80):assert abs(value-high)<mp.mpf('1e-35')*max(1,abs(high))
   witnesses.append(dict(record=i+1,node=j+1,film50_m=mp.nstr(value,45),film80_log_checked_m=mp.nstr(high,45)))
 table=out/'certified-film.dat';lines=[];k=0
 for i,g in enumerate(groups):lines.append(' '.join([str(i+1),str(len(g)),*values[k:k+len(g)]]));k+=len(g)
 table.write_text('\n'.join(lines)+'\n',encoding='ascii');(out/'original_factor_inputs.dat').write_bytes(raw)
 (out/'WITNESSES.json').write_text(json.dumps(dict(selected=selected,records=witnesses,mpmath=mp.__version__),indent=2)+'\n')
 result=dict(status='MEASURED_NOT_ADMITTED',profiles=len(groups),rooted_nodes=len(cases),input_sha256=sha(raw),source_sha256=sha(literal),fixture_sha256=sha(table.read_bytes()),selected_independent_witnesses=len(witnesses),builds={},production_admission=False,whole_scientific_admission=False,reference_trajectory_accuracy_qualified=False)
 for opt in ('O0','O2'):
  build=out/opt;build.mkdir();(build/'fixture.f90').write_text(MODULE,encoding='ascii');(build/'oxygen.f90').write_text(adapted_source(literal.decode()),encoding='utf-8');(build/'driver.f90').write_text(adapted_driver((ROOT/'tests/dataqual15_hupsel/original_factor_comparison.f90').read_text()),encoding='utf-8')
  inputs=[build/'fixture.f90',ROOT/'tests/dataqual15_hupsel/matched_oxygen_owners.f90',build/'oxygen.f90',*[ROOT/n for n in record['factor_repository_order']],build/'driver.f90'];exe=build/'compare.exe'
  command=[a.compiler,'-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-I'+str(build),'-J'+str(build),*map(str,inputs),'-o',str(exe)]
  run=subprocess.run(command,cwd=build,capture_output=True,timeout=180);(build/'compile.stderr').write_bytes(run.stderr);assert run.returncode==0,run.stderr.decode(errors='replace')[-2000:]
  outputs=[]
  for mode,args in [('baseline',[]),('certified',[str(table)])]:
   run=subprocess.run([str(exe),str(out/'original_factor_inputs.dat'),*args],cwd=build,capture_output=True,timeout=300);(build/(mode+'.stdout')).write_bytes(run.stdout);(build/(mode+'.stderr')).write_bytes(run.stderr);assert run.returncode==0
   rows=[list(map(float,l.split()))for l in run.stdout.decode().splitlines()];assert len(rows)==len(cases) and all(len(r)==9 and all(math.isfinite(x)for x in r)for r in rows)
   assert [(int(r[0])-1,int(r[1])-1)for r in rows]==[(i,j)for i,j,_ in cases];outputs.append(rows)
  base,cert=outputs
  binding=max(abs(r[4]-r[6])for r in base);assert binding<1e-9
  assert all(x[:4]==y[:4] and x[5:7]==y[5:7] and x[8]==y[8]for x,y in zip(base,cert))
  before=max(abs(r[4]-r[5])for r in base);after=max(abs(r[4]-r[5])for r in cert)
  refusals=native_refusals(exe,out/'original_factor_inputs.dat',table,build)
  result['builds'][opt]=dict(original_binding_max=binding,unchanged_original_typed_max=before,certified_original_typed_max=after,inside_unchanged_assembled_bound=after<=1e-4,native_refusals=refusals,executable_sha256=sha(exe.read_bytes()),source_sha256={str(x.relative_to(ROOT))if x.is_relative_to(ROOT)else x.name:sha(x.read_bytes())for x in inputs})
  (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 result['status']='COMPONENT_REFERENCE_ACCURACY_MEASURED_NOT_TRAJECTORY_ADMISSION';result['seconds']=time.monotonic()-start
 (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
