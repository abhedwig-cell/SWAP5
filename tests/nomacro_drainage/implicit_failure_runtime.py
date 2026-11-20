"""Reproduce the retained history failure from its actual day530 native origin."""
import argparse,json,time
from pathlib import Path
import calendar_runtime as runtime
m=runtime.m

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=json.loads((a.profile/'RESULT.json').read_text());assert q['status']=='FAILED';build=Path(q['build_root']);project=m.e.load(a.profile/'input',original_output=True);rows=m.rows(a.profile/'trajectory');start=time.monotonic()
 try:runtime.own(build,a.reference_work,project,a.profile/'trajectory',rows,530,572,a.output)
 except RuntimeError as error:
  actual=m.rows(a.output);assert len(actual)==41 and m.physical(actual)==m.physical(rows[530:571])
  assert 'ERROR STOP Implicit original retry reached clock resolution' in (a.output/'original/donor.stderr').read_text()
  assert not (a.output/'accepted-column-1-day-572.zip').exists()
  result=dict(status='ACTUAL_NATIVE_DAY530_EXACT41DAY_PREFIX_AND_DAY572_FAILURE_REPRODUCED',error=str(error),actual_exact_accepted_days=41,failed_day=572,seconds=time.monotonic()-start,actual_build_root=str(build),actual_build_sha256=m.sha(build/'BUILD.json'),source_origin_sha256=m.sha(a.profile/'trajectory/accepted-column-1-day-530.zip'),full_period_reruns=0)
  (a.output/'REPRODUCTION.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
 else:raise AssertionError('Retained implicit/history numerical failure did not reproduce')
if __name__=='__main__':main()
