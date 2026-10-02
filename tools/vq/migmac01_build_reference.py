from pathlib import Path
import sys, subprocess, shutil, hashlib, json, os
sys.path.insert(0,str(Path(__file__).resolve().parent))
from b0_source_runner import SWAP_ORDER, select_dec_branches
root=Path('reference-run').resolve(); src=Path(os.environ.get('B111_SOURCE',str(root/'source'))).resolve(); selected=root/'selected'; selected.mkdir(exist_ok=True)
tt=Path(os.environ['TTUTIL_SOURCE']).resolve()
bt=root/'ttobj'; bs=root/'swobj';bt.mkdir(exist_ok=True);bs.mkdir(exist_ok=True)
fc=os.environ.get('FC','gfortran')
log=(root/'build.log').open('w')
def run(cmd,cwd):
 r=subprocess.run(cmd,cwd=cwd,stdout=log,stderr=subprocess.STDOUT)
 if r.returncode: log.flush();raise RuntimeError('failed '+str(cmd))
first=['ttutilprefs.f90','ttutil.f90','outdat.f90','rdmodulettutil.f90']
for p in [tt/n for n in first]+[p for p in sorted(tt.glob('*.f90'))+sorted(tt.glob('*.for')) if p.name not in first]:
 run([fc,'-O2','-finit-local-zero','-fallow-argument-mismatch','-ffree-line-length-none' if p.suffix=='.f90' else '-ffixed-line-length-none','-I',str(tt),'-I',str(bt),'-c',str(p)],bt)
run(['ar','rcs','libttutil.a']+[str(p) for p in bt.glob('*.o')],bt)
for p in src.glob('*.f90'):
 s=select_dec_branches(p.read_bytes().decode('cp1252'))
 (selected/p.name).write_bytes(s.encode('cp1252'))
for n in SWAP_ORDER:
 run([fc,'-O2','-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-I',str(bt),'-I',str(bs),'-c',str(selected/n)],bs)
run([fc,'-o',str(root/'swap_b111')]+[str(p) for p in bs.glob('*.o')]+[str(bt/'libttutil.a')],bs)
print('REFERENCE_BUILD=PASS')
