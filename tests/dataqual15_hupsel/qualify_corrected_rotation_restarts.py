"""Actual final-period continuation on the corrected current native builds."""
import argparse,csv,hashlib,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--case',type=Path,required=True)
p.add_argument('--o0',type=Path,required=True);p.add_argument('--o2',type=Path,required=True)
p.add_argument('--output',type=Path,required=True);a=p.parse_args()
case=a.case.resolve();out=a.output.resolve();out.mkdir();events=[];proof=[]
fresh=json.loads((case/'RESULT.json').read_text());assert fresh['returncode']==0 and fresh['from_start']
assert fresh['executable_sha256']==sha(a.o2)

def run(name,exe,seed,end=1096,compatible=False,capture=None):
 folder=out/name
 command=[sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/run_canopy_observation.py'),
          '--exe',str(exe.resolve()),'--predecessor',str(case),'--strict-restart',str(seed.resolve()),
          '--output',str(folder),'--end',str(end),'--timeout','600']
 if compatible:command+=['--compatibility-control']
 if capture:command+=['--capture',str(capture)]
 t=time.monotonic();cp=subprocess.run(command,cwd=ROOT,capture_output=True,timeout=660)
 (out/(name+'.stdout')).write_bytes(cp.stdout);(out/(name+'.stderr')).write_bytes(cp.stderr)
 events.append(dict(command=command,returncode=cp.returncode,seconds=time.monotonic()-t))
 (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
 assert cp.returncode==0,(name,cp.stderr)
 r=json.loads((folder/'RESULT.json').read_text());assert r['returncode']==0,name
 return folder

def compare(whole,resumed,start,name):
 assert (whole/'checkpoint.bin').read_bytes()==(resumed/'checkpoint.bin').read_bytes(),name+' typed endpoint'
 count={}
 for file,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
  full=list(csv.DictReader((whole/file).open()));tail=list(csv.DictReader((resumed/file).open()))
  selected=[r for r in full if float(r[clock])>start]
  assert selected==tail,(name,file)
  assert len(tail)==1096-start,(name,file,'missing day')
  count[file]=len(tail)
 proof.append(dict(name=name,strict_own_build=True,checkpoint_exact=True,daily_output_rows_exact=count,
                   checkpoint_sha256=sha(whole/'checkpoint.bin')))

for day in (1058,1077):
 resumed=run('O2-restart-'+str(day),a.o2,case/f'checkpoint-{day}.bin')
 compare(case,resumed,day,'O2-'+str(day))
# The imported O2 seed is expressly a compatibility control. Only the following
# own-O0 checkpoint continuation earns the strict own-build restart claim.
whole=run('O0-compatible-tail',a.o0,case/'checkpoint-1058.bin',compatible=True,capture=1077)
resumed=run('O0-strict-restart-1077',a.o0,whole/'checkpoint-1077.bin')
compare(whole,resumed,1077,'O0-1077')
report=dict(status='CORRECTED_FINAL_ROTATION_OWN_BUILD_RESTART_O0_O2_PASS',fresh_executable_sha256=fresh['executable_sha256'],
            o0_executable_sha256=sha(a.o0),o2_executable_sha256=sha(a.o2),proof=proof,events=events,
            o0_seed_scope='O2-to-O0 input-bound codec compatibility, not same-build restart or full O0 trajectory',
            whole_scientific_admission=False)
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
