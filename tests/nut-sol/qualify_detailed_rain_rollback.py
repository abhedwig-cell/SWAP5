"""Actual wet native failure: a later rain segment must not publish a day."""
import argparse,csv,json,re,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--fixture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir();src=a.fixture.resolve();events=[]
 for folder in ['weather data','crop data']:shutil.copytree(src/folder,out/folder)
 swp=out/'project.swp';swp.write_bytes((src/'project.swp').read_bytes())
 for rain in (out/'weather data').glob('andelst_rain.*'):
  lines=[]
  for line in rain.read_text().splitlines():
   fields=line.split()
   if len(fields)==6 and fields[1].isdigit():fields[-1]=str(float(fields[-1])*4);line=' '.join(fields)
   lines.append(line)
  rain.write_text('\n'.join(lines)+'\n')
 common=[sys.executable,ROOT/'tools/solute/run_project.py',swp,'--bundle',a.bundle.resolve(),'--temporal-tolerance','.001','--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero']
 def run(label,days):
  t=time.perf_counter();cmd=common+['--output',out/label,'--stop-after',str(days)];r=subprocess.run(list(map(str,cmd)),cwd=ROOT,capture_output=True,timeout=300)
  for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(r,stream))
  events.append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-t,returncode=r.returncode));return r
 r=run('wet',97)
 if r.returncode==0:
  result=dict(status='WET_97_DAY_COMPLETED_NO_REJECTION_WITNESS',events=events)
 else:
  assert not(out/'wet').exists(),'failed day published complete output'
  pending=list(out.glob('wet.pending-*'));assert len(pending)==1;pending=pending[0]
  stream=(pending/'stdout').read_text();counts=re.findall(r'detailed rain completed intervals:\s+(\d+)',stream);assert counts and int(counts[-1])>0,'no later-segment rejection'
  budget=list(csv.DictReader((pending/'budget.csv').open()));days=len(budget);assert days>0
  assert run('prefix',days).returncode==0
  before=(out/'prefix/restart.bin').read_bytes();assert before==(pending/'diagnostic-rejected.bin').read_bytes(),'failed day leaked owners'
  assert before!=(pending/'diagnostic-partial-candidate.bin').read_bytes(),'candidate never progressed'
  result=dict(status='ACTUAL_LATER_RAIN_SEGMENT_FAILURE_DAY_ATOMIC_PASS',complete_days=days,completed_segments_before_rejection=int(counts[-1]),committed_restart_exact=True,events=events)
 (out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()
