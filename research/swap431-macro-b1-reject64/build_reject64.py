from pathlib import Path
import json,hashlib,zipfile,subprocess,time,shutil
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-combined63';RES=json.loads((R/'RESOURCE_PATHS.json').read_text())
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(n,q):(R/n).write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
e=json.loads((P/'EVIDENCE.json').read_text());arc=P/e['file'];assert sha(arc)==e['sha256']
for opt in ['O0','O2']:
 out=Path(RES[opt]['path']);assert not (out/'native09.exe').exists()
 prefix='native/'+opt+'/'
 with zipfile.ZipFile(arc) as z:
  selected=[x for x in json.loads(z.read('manifest.json')) if x['path'].startswith(prefix)]
  for x in selected:
   target=out/x['path'][len(prefix):];target.parent.mkdir(parents=True,exist_ok=True)
   with z.open(x['path']) as src,target.open('wb') as dst:shutil.copyfileobj(src,dst)
   assert sha(target)==x['sha256']
 obj=out/'obj';logs=[]
 commands=[['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch','-cpp','-Dlinux','-ffree-line-length-none','-I',str(obj),'-c',str(R/'soilwater_native.f90'),'-o',str(obj/'soilwater.o')],['gfortran','-o',str(out/'native09.exe'),*map(str,sorted(obj.glob('*.o'))),str(out/'libttutil.a')]]
 for cmd in commands:
  t=time.perf_counter();q=subprocess.run(cmd,cwd=obj,capture_output=True,text=True,timeout=60);logs.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=q.returncode,output=q.stdout+q.stderr));save(opt+'_BUILD.json',logs);assert q.returncode==0,q.stderr
 save(opt+'_IDENTITY.json',dict(exe_sha256=sha(out/'native09.exe'),sources={p.name:sha(p) for p in R.glob('*.f90')},compiler=subprocess.check_output(['gfortran','--version'],text=True),inherited_combined63_sha256=e['sha256'],rebuilt_objects=['soilwater.o'],numerical_Jacobian_and_physics_unchanged=True,only_harness_change='initialproposalwithinoriginalfloor/proposallimits'))
 print(opt,'built')
