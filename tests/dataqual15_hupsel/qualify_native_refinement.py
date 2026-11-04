"""Registered complete native time-cap controls; never cross-variant restart."""
import argparse,concurrent.futures,csv,hashlib,json,re,shutil,subprocess,sys,time
from pathlib import Path
from inspect_profiles import profile
ROOT=Path(__file__).resolve().parents[2]
DAYS=(120,365,494,524,537,566,584,591,603,636,730,731,868,930,956,989,1033,1058,1077,1088,1096)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def qualify(cap,basecase,o0,o2,root):
 out=root/('cap-'+str(cap));out.mkdir();inputs=out/'inputs';inputs.mkdir();events=[]
 for f in basecase.iterdir():
  if f.suffix.lower() in ('.nml','.swp','.crp','.met','.dra'):shutil.copyfile(f,inputs/f.name)
 pattern=rb'(?im)^(\s*DTMAX\s*=\s*)[\d.eE+\-]+'
 raw=(inputs/'swap.swp').read_bytes();assert len(re.findall(pattern,raw))==1
 changed=re.sub(pattern,lambda m:m[1]+str(cap).encode(),raw)
 assert changed!=raw;(inputs/'swap.swp').write_bytes(changed)
 for n in ('input.nml','maize.crp','potato.crp','grass.crp','283.met','swap.dra'):assert (inputs/n).read_bytes()==(basecase/n).read_bytes()
 for opt,bundle in [('O0',o0),('O2',o2)]:
  b=json.loads((bundle/'BUILD.json').read_text());assert '-'+opt in b['flags']
  assert all(sha(Path(p))==h for p,h in b['source_sha256'].items())
  assert sha(bundle/'swap5_hupsel_germination.exe')==b['executable_sha256']
 def run(name,exe,seed=None,compatible=False,captures=()):
  folder=out/name
  cmd=[sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/run_canopy_observation.py'),
       '--exe',str(exe),'--predecessor',str(inputs),'--output',str(folder),'--end','1096','--timeout','7200']
  if seed:cmd+=['--strict-restart',str(seed)]
  else:cmd+=['--from-start']
  if compatible:cmd+=['--compatibility-control']
  if captures:cmd+=['--capture',*map(str,captures)]
  begin=time.monotonic();cp=subprocess.run(cmd,cwd=ROOT,capture_output=True,timeout=7260)
  (out/(name+'.stdout')).write_bytes(cp.stdout);(out/(name+'.stderr')).write_bytes(cp.stderr)
  events.append(dict(command=cmd,returncode=cp.returncode,seconds=time.monotonic()-begin))
  (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
  assert cp.returncode==0,(cap,name,cp.stderr)
  r=json.loads((folder/'RESULT.json').read_text());assert r['returncode']==0,(cap,name,r)
  return folder
 full=run('full-O2',o2/'swap5_hupsel_germination.exe',captures=DAYS)
 # The final checkpoint itself is authoritative even if the process exits
 # before the polling observer can retain a second copy at the last clock.
 final_fallback=False
 if not (full/'checkpoint-1096.bin').exists():
  assert profile((full/'checkpoint.bin').read_bytes())['day']==1096
  shutil.copyfile(full/'checkpoint.bin',full/'checkpoint-1096.bin');final_fallback=True
 assert all((full/f'checkpoint-{d}.bin').is_file() for d in DAYS)
 tail=run('strict-O2-1088',o2/'swap5_hupsel_germination.exe',full/'checkpoint-1088.bin')
 compatible=run('compatible-O0-1077',o0/'swap5_hupsel_germination.exe',full/'checkpoint-1077.bin',True,(1088,))
 own=run('strict-O0-1088',o0/'swap5_hupsel_germination.exe',compatible/'checkpoint-1088.bin')
 for whole,resumed in [(full,tail),(compatible,own)]:
  assert (whole/'checkpoint.bin').read_bytes()==(resumed/'checkpoint.bin').read_bytes()
  for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
   read=lambda f:list(csv.DictReader(f.open()))
   assert [r for r in read(whole/name) if float(r[clock])>1088]==read(resumed/name)
 report=dict(status='ACTUAL_FULL1096_NATIVE_REFINEMENT_AND_OWN_O0_O2_TAILS_PASS',cap_day=cap,
             from_start=True,imported_initial_checkpoint=False,full_executable_sha256=sha(o2/'swap5_hupsel_germination.exe'),
             retained_days=list(DAYS),final_checkpoint_copy_fallback=final_fallback,
             strict_O2_1088=True,strict_O0_1088=True,O0_initial_scope='Explicit input-bound O2-to-O0 compatibility at1077, not full O0 execution',
             inputs_sha256={p.name:sha(p) for p in inputs.iterdir()},events=events,whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');return report

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for n in ('case','o0','o2','output'):p.add_argument('--'+n,type=Path,required=True)
 a=p.parse_args();out=a.output.resolve();out.mkdir()
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
  jobs={str(cap):pool.submit(qualify,cap,a.case.resolve(),a.o0.resolve(),a.o2.resolve(),out) for cap in (.005,.0025)}
  results={cap:job.result() for cap,job in jobs.items()}
 (out/'RESULT.json').write_text(json.dumps(results,indent=2)+'\n');print('BOTH_REGISTERED_NATIVE_REFINEMENT_RUNS_AND_STRICT_TAILS_PASS')
