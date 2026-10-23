"""Execute retained complete Andelst input on exact reconstructed B1.12."""
import argparse,csv,gzip,hashlib,json,os,runpy,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--opt',choices=['O0','O2'],default='O2');a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);fc=os.environ.get('FC','gfortran');events=[]
 def run(cmd,cwd,timeout=None):
  t=time.perf_counter()
  try:r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,input=b'',timeout=timeout)
  except subprocess.TimeoutExpired as e:r=subprocess.CompletedProcess(cmd,124,e.stdout or b'',e.stderr or b'')
  i=len(events);events.append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-t,returncode=r.returncode))
  for s in ['stdout','stderr']:(out/f'{i:03}.{s}').write_bytes(getattr(r,s))
  (out/'events.json').write_text(json.dumps(events,indent=2)+'\n');return r
 build=out/'build';r=run([sys.executable,ROOT/'tools/performance/build_swap431_perf01.py','--output',build,'--opt',a.opt],ROOT);assert r.returncode==0
 # Reconstruct all63 members with the official SWAP-019 identity verifier.
 ref=runpy.run_path(str(ROOT/'tools/vq/b1_12_reconstruct.py'))['from_authority'](out/'B112')
 (out/'reference.json').write_text(json.dumps(ref,indent=2)+'\n');assert ref['source_tree']['manifest_sha256']=='5bab54598c3519c1b1f2f313431ba0947f39c9673eb1fbc7eec719477f9f2d0e'
 sys.path.insert(0,str(ROOT/'tools/vq'));from b0_source_runner import SWAP_ORDER,select_dec_branches
 b=json.loads((build/'INPUTS.json').read_text());flags=b['flags'];bs=build/'swobj';bt=build/'ttobj';changed=[]
 for name in SWAP_ORDER:
  raw=(out/'B112'/name).read_bytes();selected=select_dec_branches(raw.decode('cp1252')).encode('cp1252');p=build/'selected'/name
  if p.read_bytes()!=selected:
   changed.append(name);p.write_bytes(selected);r=run([fc,*flags,'-cpp','-Dlinux','-ffree-line-length-none','-I',bt,'-I',bs,'-c',p],bs);assert r.returncode==0
 assert set(changed)=={'wofost.f90','wofostnut.f90'}
 obj=build/'main.o';r=run([fc,*flags,'-cpp','-Dlinux','-ffree-line-length-none','-I',bt,'-I',bs,'-c',build/'selected/swap_main.f90','-o',obj],bs);assert r.returncode==0
 exe=build/'swap_b112';r=run([fc,*flags,*sorted(bs.glob('*.o')),obj,bt/'libttutil.a','-o',exe],build);assert r.returncode==0
 data=ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006';case=out/'original';case.mkdir()
 names=['swap.swp','swap.bbc','swap.dra','wintcer1.crp','wintcer2.crp','andelst_meteo.998','andelst_meteo.999','andelst_rain.998','andelst_rain.999','soilshrinkchar.csv']
 inputs={}
 for name in names:
  p=data/('b111-'+name+'.gz');raw=gzip.decompress(p.read_bytes());(case/name).write_bytes(raw);inputs[name]=sha(raw)
 r=run([exe,'./swap.swp'],case,300)
 errors=(case/'swap.err').read_text(errors='replace')if(case/'swap.err').exists()else''
 ok=r.returncode==100 and(case/'swap.ok').exists()and not errors.strip()
 report=dict(status='B112_ORIGINAL_HISTORICAL_RUN_PASS'if ok else'B112_ORIGINAL_HISTORICAL_RUN_FAILED',reference=ref,optimization=a.opt,events=events,returncode=r.returncode,errors=errors,input_sha256=inputs,executable_sha256=sha(exe.read_bytes()),original_inputs_modified=False,swap5_parity_qualified=False)
 if(case/'result_output.csv').exists():
  raw=(case/'result_output.csv').read_bytes();old=gzip.decompress((data/'b111-result_output.csv.gz').read_bytes())
  def body(b):return '\n'.join(l for l in b.decode('cp1252').splitlines()if l and not l.startswith('*'))
  report['B111_physical_output_exact']=body(raw)==body(old)
  lines=raw.decode('cp1252').splitlines();start=next(i for i,l in enumerate(lines)if l.startswith('DATE,'));rows=list(csv.DictReader(lines[start:]));report['output_records']=len(rows);report['simulated_days']=len(rows)-1;report['initial_state_date']=rows[0]['DATE'];report['max_printed_BALDEV_cm']=max(abs(float(r['BALDEV']))for r in rows)if rows and 'BALDEV'in rows[0]else None
 (out/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items()if k not in ['events','reference','input_sha256']}))
if __name__=='__main__':main()
