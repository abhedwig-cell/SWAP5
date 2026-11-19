from pathlib import Path
import json,hashlib,zipfile,subprocess,time,shutil
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-combined62';W=Path('C:/Users/Veldh012/swap431-combined63-final-work')
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(n,q):(R/n).write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
e=json.loads((P/'EVIDENCE.json').read_text());arc=P/e['file'];assert sha(arc)==e['sha256']
for opt in ['O0','O2']:
 out=W/'native'/opt;assert not out.exists()
 with zipfile.ZipFile(arc) as z:
  selected=[x for x in json.loads(z.read('manifest.json')) if x['path'].startswith('native/'+opt+'/')]
  for x in selected:
   target=W/x['path'];target.parent.mkdir(parents=True,exist_ok=True)
   with z.open(x['path']) as src,target.open('wb') as dst:shutil.copyfileobj(src,dst)
   assert sha(target)==x['sha256']
 obj=out/'obj';log=[]
 commands=[['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch','-cpp','-Dlinux','-ffree-line-length-none','-I',str(obj),'-c',str(R/'macrorate_node.f90'),'-o',str(obj/'macrorate.o')],['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch','-cpp','-Dlinux','-ffree-line-length-none','-I',str(obj),'-c',str(R/'jac63_update.f90'),'-o',str(obj/'jac63.o')],['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch','-cpp','-Dlinux','-ffree-line-length-none','-I',str(obj),'-c',str(R/'jac_update.f90'),'-o',str(obj/'jac24.o')],['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch','-cpp','-Dlinux','-ffree-line-length-none','-I',str(obj),'-c',str(R/'head_diag.f90'),'-o',str(obj/'headcalc.o')],['gfortran','-o',str(out/'native09.exe'),*[str(p) for p in sorted(obj.glob('*.o')) if p.name!='jac63.o'],str(obj/'jac63.o'),str(out/'libttutil.a')]]
 for cmd in commands:
  t=time.perf_counter();p=subprocess.run(cmd,cwd=obj,capture_output=True,text=True,timeout=60);log.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=p.returncode,output=p.stdout+p.stderr));save(opt+'_BUILD.json',log);assert p.returncode==0,p.stderr
 save(opt+'_IDENTITY.json',dict(exe_sha256=sha(out/'native09.exe'),sources={p.name:sha(p) for p in R.glob('*.f90')},compiler=subprocess.check_output(['gfortran','--version'],text=True),inherited_combined62_archive_sha256=e['sha256'],inherited_native_members=len(selected),rebuilt_objects=['macrorate.o','jac63.o','jac24.o','headcalc.o'],new_observer_only=False,numerical_change="COMBINED62 guardedrank2 D3only",qualification_probes="none; actualoriginalD2convergencetest"))
 print(opt,'built')
