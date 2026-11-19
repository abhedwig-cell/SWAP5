"""Real availability interface with actual original pond and evaporation inputs."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys,time

ROOT=Path(__file__).resolve().parents[2]


def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir()
 sys.path.insert(0,str(ROOT/'app/hybrid_water'));from daily_host import NO_MACRO_FP_FLAGS,no_macro_fp_profile
 provider=ROOT/'app/hybrid_water/implicit_pond_availability.f90';driver=Path(__file__).with_name('implicit_pond_availability_driver.f90');fixture=Path(__file__).with_name('implicit_pond_event_inputs.json');inputs=json.loads(fixture.read_text(encoding='utf8'));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=a.optimization,source_sha256={str(p.relative_to(ROOT)):sha(p) for p in (provider,driver,fixture)},compile_link_closure=[str(provider.relative_to(ROOT)),str(driver.relative_to(ROOT))],floating_point_profile=no_macro_fp_profile(),cases=[])
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 save()
 try:
  exe=a.output/('availability.exe' if os.name=='nt' else 'availability');cmd=['gfortran','-'+a.optimization,'-ffree-line-length-none','-fcheck=all','-fimplicit-none',*NO_MACRO_FP_FLAGS,str(provider),str(driver),'-o',str(exe)]
  t=time.perf_counter();r=subprocess.run(cmd,cwd=a.output,capture_output=True,text=True,timeout=30);q['compile_link_seconds']=time.perf_counter()-t;(a.output/'compile.log').write_text(r.stdout+r.stderr,encoding='utf8');r.check_returncode()
  cases=[]
  for item in inputs['cases']:
   values=[item['inputs'][1],item['inputs'][2],item['inputs'][3],item['actual_exported_row'][29],item['inputs'][6]]
   assert values[3]-values[4]/values[0]>=0
   cases.append((item['name'],'valid',values,None));q.setdefault('actual_original_inputs',[]).append(dict(name=item['name'],source=item['producer_source'],raw_member=item['raw_member'],raw_sha256=item['raw_sha256'],values=values))
  values=cases[0][2]
  cases += [(mode,mode,values,None) for mode in ('dry','filled','no-deficit','no-evaporation','unavailable')]
  cases += [(mode,mode,values,message) for mode,message in [('nan-stop','Nonfinite original implicit pond availability'),('zero-stop','Invalid original implicit pond availability'),('negative-stop','Invalid original implicit pond availability'),('cap-stop','Invalid original implicit pond availability')]]
  for name,mode,values,expected in cases:
   t=time.perf_counter();r=subprocess.run([str(exe),mode,*map(repr,values)],cwd=a.output,capture_output=True,text=True,timeout=10)
   if expected:assert r.returncode!=0 and expected in r.stderr,(mode,r.returncode,r.stderr)
   else:assert r.returncode==0 and ('REAL_ORIGINAL_POND_AVAILABILITY_PASS' if mode=='valid' else 'REAL_ORIGINAL_POND_AVAILABILITY_INACTIVE_PASS') in r.stdout,(mode,r.stdout,r.stderr)
   q['cases'].append(dict(name=name,mode=mode,status='REFUSED' if expected else 'PASS',seconds=time.perf_counter()-t,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));save()
  q['status']='REAL_POND_AVAILABILITY_TWO_ACTUAL_FIVE_INACTIVE_FOUR_REFUSALS_PASS';print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
