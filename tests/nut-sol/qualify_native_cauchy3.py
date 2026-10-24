"""Fresh BBC481 qualification from the immutable retained original fixture."""
import argparse,base64,csv,gzip,hashlib,io,json,re,shutil,subprocess,sys,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
def rows(p):return [{k:float(v)for k,v in r.items()}for r in csv.DictReader(p.open())]
def fixture(out):
 receipt=json.loads((ROOT/'integration/mc-sol01/drainage/CAUCHY3_QUALIFICATION.json').read_text())['evidence']
 raw=base64.b64decode((ROOT/receipt['path']).read_bytes(),validate=True);assert sha(raw)==receipt['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  manifest=json.load(t.extractfile('MANIFEST.json'));prefix='native-O2/project/'
  for member in t.getmembers():
   if member.name.startswith(prefix):
    name=member.name[len(prefix):];assert member.isfile()and'..'not in Path(name).parts and not Path(name).is_absolute()
    b=t.extractfile(member).read();assert sha(b)==manifest[member.name]
    p=out/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
def main():
 p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir();case=out/'project';fixture(case)
 original=(case/'swap.bbc').read_bytes();assert sha(original)=='ed83fe31870676cef7a57a27ce2372abc53cc0755b0f4ea6b0b6248e152480ff'
 bundle=a.bundle.resolve();b=json.loads((bundle/'bundle.json').read_text());events=[]
 common=[sys.executable,str(ROOT/'tools/solute/run_project.py'),str(case/'project.swp'),'--bundle',str(bundle),'--temporal-tolerance','.01','--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero']
 report=dict(status='RUNNING',events=events,original_bbc_sha256=sha(original),temporal_tolerance=.01,full_original_Andelst=False)
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd=ROOT,valid=True):
  cmd=list(map(str,cmd));t=time.perf_counter();r=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=1200);i=len(events)
  for stream in ['stdout','stderr']:(out/f'{i:03}.{stream}').write_bytes(getattr(r,stream))
  events.append(dict(command=cmd,returncode=r.returncode,seconds=time.perf_counter()-t,expected_success=valid));save()
  assert (r.returncode==0)==valid,r.stderr.decode()[-3000:]+r.stdout.decode()[-1000:]
 for label,args in [('full',['--stop-after',481]),('split',['--stop-after',365]),('resumed',['--stop-after',481,'--restart',out/'split'])]:run(common+['--output',out/label]+args)
 for name in ['state.csv','endpoint.csv','restart.bin']:assert(out/'full'/name).read_bytes()==(out/'resumed'/name).read_bytes(),name
 data=rows(out/'full/budget.csv');assert len(data)==481 and data[365:]==rows(out/'resumed/budget.csv')
 gross=[]
 for d in data:
  assert abs(d['water_residual_cm'])<1e-10 and abs(d['solute_residual_mg_cm2'])<1e-10
  gross.append(d['water_end_cm']-d['water_start_cm']-d['rain_supplied_cm']+d['runoff_cm']+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['actual_transpiration_cm']-d['bottom_up_cm']+d['drainage_cm'])
  assert abs(gross[-1])<1e-10
 for d in rows(out/'full/state.csv'):assert min(d[k]for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0
 assert sum(d['drainage_cm']for d in data)>0
 # The unchanged first 365 rows hold the original AFGEN endpoint beyond 1998.
 assert original.count(b'1998-')==365
 changed=original.replace(b'1998-12-31',b'1998-12-30');assert changed!=original
 (case/'swap.bbc').write_bytes(changed);run(common+['--output',out/'forbidden','--restart',out/'split'],valid=False)
 assert not(out/'forbidden').exists();(case/'swap.bbc').write_bytes(original)
 stage=out/'negatives';stage.mkdir();(stage/'input.swp').write_bytes((case/'project.swp').read_bytes())
 mutations=[(r'(SWBOTB\s*=\s*)3',r'\g<1>2'),(r'(SWBOTB3IMPL\s*=\s*)1',r'\g<1>0'),(r'(SHAPE_3\s*=\s*)1\.0',r'\g<1>0.5'),(r'(SW3\s*=\s*)2',r'\g<1>1'),(r'(SW4\s*=\s*)0',r'\g<1>1')]
 for pattern,repl in mutations:
  text,n=re.subn(pattern,repl,original.decode(),count=1,flags=re.I);assert n==1
  (stage/'input.bbc').write_text(text);run([b['project_reader'],'input.swp','prepare'],stage,False)
 (stage/'input.bbc').unlink();run([b['project_reader'],'input.swp','prepare'],stage,False)
 full=gzip.decompress((ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-swap.swp.gz').read_bytes());(stage/'input.swp').write_bytes(full)
 run([b['project_reader'],'input.swp','scan'],stage,False)
 report.update(status='BOUNDED_ORIGINAL_BBC_NATIVE_RESTART_PASS',complete_days=481,restart_exact=True,original_full_swp_rejected=True,max_water_residual=max(abs(d['water_residual_cm'])for d in data),max_solute_residual=max(abs(d['solute_residual_mg_cm2'])for d in data),max_independent_gross_residual=max(map(abs,gross)))
 save();print(report['status'])
if __name__=='__main__':main()
