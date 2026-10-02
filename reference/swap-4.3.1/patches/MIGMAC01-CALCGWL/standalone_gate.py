from pathlib import Path
import hashlib,subprocess,tempfile,shutil
root=Path(__file__).resolve().parent
source=root/'b111_calcgwl.f90'
assert hashlib.sha256(source.read_bytes()).hexdigest()=='d7649f02bf6cd629cc7eceb1c761a6c38d6f0adf0d0c072c7aaab3af4562f5eb'
raw=source.read_bytes();old=b'do i = min(nodgwl,numnod), 1, -1'
assert raw.count(old)==1
patched=raw.replace(old,b'do i = node, 1, -1')
print('PATCHED_CALCGWL_SHA256',hashlib.sha256(patched).hexdigest())
fc=shutil.which('gfortran')
assert fc
print(subprocess.check_output([fc,'--version'],text=True).splitlines()[0])
for opt in ['O0','O2']:
 for kind,text in [('baseline',raw),('corrected',patched)]:
  with tempfile.TemporaryDirectory() as tmp:
   work=Path(tmp);(work/'calcgwl.f90').write_bytes(text)
   cmd=[fc,'-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-o','test',str(root/'stubs.f90'),'calcgwl.f90',str(root/'test_calcgwl.f90')]
   subprocess.run(cmd,cwd=work,check=True)
   p=subprocess.run(['./test'],cwd=work,text=True,capture_output=True)
   print(opt,kind,p.returncode,p.stdout.strip())
   if kind=='baseline':
    assert p.returncode!=0 and 'saturated containing cell' in p.stderr
   else:
    assert p.returncode==0,p.stderr
print('TARGETED_B1_CALCGWL_CORRECTION_PASS_O0_O2_NOT_GLOBAL_REFERENCE_ADMISSION')
