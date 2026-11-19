"""Independent censored implicit/history failure observations; no admission."""
import argparse,json,math
from pathlib import Path
import implicit_forensics as science
from extended_evidence import digest,lines
from extended_forensics import require

def audit(root,compiled_root=None):
 root=Path(root);q=json.loads((root/'RESULT.json').read_text());buildroot=Path(compiled_root or q['build_root']);raw=(buildroot/'BUILD.json').read_bytes();build=json.loads(raw)
 require(q['status']=='FAILED' and q['parameters']['days']==1096 and q['parameters']['hysteresis'] in (0,2) and q['parameters']['implicit'] is True,'Foreign censored implicit configuration')
 require(json.loads((root/'trajectory/BUILD.json').read_text())==build,'Censored implicit actual compiler bundle differs')
 for name,value in build['inputs'].items():require(digest((root/'input'/name).read_bytes())==value,'Censored implicit actual input changed')
 key=(q['parameters']['case'],q['parameters']['hysteresis'],'continuous_saturation_renderer_sha256' in build['identity']['extended_drainage'])
 require(key in {('automatic',2,False),('automatic',0,False),('water',0,True)},'Foreign censored numerical failure scope')
 expected_days={('automatic',2,False):571,('automatic',0,False):566,('water',0,True):288}[key]
 rows=lines((root/'trajectory/daily.jsonl').read_bytes());require(len(rows)==expected_days and [row['day'] for row in rows]==list(range(1,expected_days+1)),'Censored implicit accepted prefix changed')
 result=science.inventory(rows);stdout=(root/'trajectory/original/donor.stdout').read_text();stderr=(root/'trajectory/original/donor.stderr').read_text()
 science.observed(stdout.encode(),rows,build)
 selected=science.selected_input(root/'input/swap.swp');dz=science.geometry((root/'input/swap.swp').read_text(encoding='cp1252'))
 for path in (root/'trajectory').glob('accepted-column-1-day-*.zip'):
  day=int(path.stem.rsplit('-',1)[1]);science.checkpoint(path,build,rows[day-1],selected,dz)
 require('ERROR STOP Implicit original retry reached clock resolution' in stderr,'Censored implicit stop differs')
 flags=[line.split()[1:] for line in stdout.splitlines() if line.startswith('EXTENDED_DRAIN_NONCONVERGED_FLAGS ')]
 values=[[float(v) for v in line.split()[1:]] for line in stdout.splitlines() if line.startswith('EXTENDED_DRAIN_NONCONVERGED ')]
 require(len(flags)==len(values)>=10 and (all(v==['F','F','T','T','F','F'] for v in flags) if key[0]=='automatic' else all(v[2:4]==['T','T'] and v[5]=='F' for v in flags)),'Censored original nodal convergence/uncoupled boundary witness changed')
 require(all(len(v)==14 and all(math.isfinite(x) for x in v) for v in values),'Censored actual iteration diagnostics incomplete')
 last=values[-1];require(last[1]>8*math.ulp(last[0]) and last[1]/3<=8*math.ulp(last[0]),'Actual clock-floor failure not reproduced from original reduction')
 require(not (root/f'trajectory/accepted-column-1-day-{expected_days+1}.zip').exists(),'Failed day published accepted native state')
 return dict(status='INDEPENDENT_CENSORED_IMPLICIT_AUTOMATIC_DRAINAGE_NUMERICAL_FAILURE_CONFIRMED',actual_accepted_days=expected_days,failed_day=expected_days+1,actual_nodal_nonconvergence_observations=len(values),new_pond_tangent_active=any(v[0:2]==['T','T'] for v in flags),last_trial_duration_days=last[1],actual_clock_floor_days=8*math.ulp(last[0]),warm_prefix=result,build_sha256=digest(raw),source=q['source'],full_period_qualified=False)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit(a.directory)
 with a.output.open('x') as stream:json.dump(q,stream,indent=2)
 print(q['status'],q['actual_accepted_days'])
