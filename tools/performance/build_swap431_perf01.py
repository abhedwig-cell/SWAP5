#!/usr/bin/env python3
"""Build original B1.11 SWAP431/TTUTIL and the matched physical kernel driver.

All historical model procedures are original source, without physics stubs.
The driver initializes prescribed forcing/sinks and directly calls HeadCalc.
"""
import argparse,base64,hashlib,io,json,os,subprocess,sys,tarfile,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/vq'))
from b0_source_runner import SWAP_ORDER,select_dec_branches

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--opt',choices=['O0','O2','O3'],default='O2');a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 source=out/'source';source.mkdir();raw=base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes());tarfile.open(fileobj=io.BytesIO(raw)).extractall(source,filter='data')
 tt=out/'tt';tt.mkdir();zipfile.ZipFile(io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64').read_bytes()))).extractall(tt)
 src=source/'SWAP';tt=tt/'TTUTIL'
 manifest={}
 for fname,folder,flat in [('B1.11-source-manifest.sha256',src,True),('TTUTIL-source-manifest.sha256',tt,False)]:
  for row in (ROOT/'tests/data/ppa_wu05_migmac01'/fname).read_text().splitlines():
   digest,size,name=row.split();p=folder/(Path(name).name if flat else name)
   if len(p.read_bytes())!=int(size)or hashlib.sha256(p.read_bytes()).hexdigest()!=digest:raise ValueError('source identity '+str(p))
   manifest[str(p.relative_to(out))]=digest
 selected=out/'selected';selected.mkdir();bt=out/'ttobj';bt.mkdir();bs=out/'swobj';bs.mkdir()
 for p in src.glob('*.f90'):(selected/p.name).write_bytes(select_dec_branches(p.read_bytes().decode('cp1252')).encode('cp1252'))
 flags=['-'+a.opt,'-finit-local-zero','-fallow-argument-mismatch']
 if a.opt=='O0':flags+=['-fcheck=all','-ffpe-trap=invalid,zero,overflow']
 fc=os.environ.get('FC','gfortran');log=(out/'build.log').open('w');commands=[]
 def run(cmd,cwd):
  commands.append(list(map(str,cmd)));subprocess.run(cmd,cwd=cwd,stdout=log,stderr=subprocess.STDOUT,check=True)
 first=['ttutilprefs.f90','ttutil.f90','outdat.f90','rdmodulettutil.f90']
 for p in [tt/n for n in first]+[p for p in sorted(tt.glob('*.f90'))+sorted(tt.glob('*.for')) if p.name not in first]:
  run([fc,*flags,'-ffree-line-length-none' if p.suffix=='.f90' else '-ffixed-line-length-none','-I',str(tt),'-I',str(bt),'-c',str(p)],bt)
 run(['ar','rcs','libttutil.a',*map(str,bt.glob('*.o'))],bt)
 for name in SWAP_ORDER:
  if name=='swap_main.f90':continue
  run([fc,*flags,'-cpp','-Dlinux','-ffree-line-length-none','-I',str(bt),'-I',str(bs),'-c',str(selected/name)],bs)
 driver=ROOT/'tests/performance/swap431_perf01_column.f90'
 run([fc,*flags,'-ffree-line-length-none','-I',str(bt),'-I',str(bs),'-c',str(driver),'-o',str(out/'driver.o')],bs)
 run([fc,*flags,*map(str,bs.glob('*.o')),str(out/'driver.o'),str(bt/'libttutil.a'),'-o',str(out/'trajectory')],out)
 (out/'INPUTS.json').write_text(json.dumps(dict(source_sha256=manifest,driver_sha256=hashlib.sha256(driver.read_bytes()).hexdigest(),flags=flags,commands=commands,executable_sha256=hashlib.sha256((out/'trajectory').read_bytes()).hexdigest()),indent=2))
 print('SWAP431_PERF01_BUILD=PASS')
if __name__=='__main__':main()
