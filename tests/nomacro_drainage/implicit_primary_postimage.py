"""Actual current primary35day numerical postimage over the input-only guard."""
import argparse,json,zipfile
from pathlib import Path
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
from extended_evidence import lines,physical,package,digest
from extended_forensics import require
import implicit_forensics as science

def audit(current,prior):
 current=Path(current);prior=Path(prior);cq=json.loads((current/'RESULT.json').read_text());pq=json.loads((prior/'RESULT.json').read_text());now=Path(cq['build_root']);old=Path(pq['build_root']);a=json.loads((now/'BUILD.json').read_text());b=json.loads((old/'BUILD.json').read_text())
 require(cq['parameters']['days']==35 and pq['parameters']['days']==1096,'Wrong actual current/full primary source phase')
 require({p.name:p.read_bytes() for p in now.glob('*.f90')}=={p.name:p.read_bytes() for p in old.glob('*.f90')},'Input-only primary guard changed generated Fortran')
 require(a['inputs']==b['inputs'] and a['project']==b['project'],'Input-only primary guard changed inputs')
 changed=differences(b['identity'],a['identity']);require(set(changed)<={'extended_drainage.source_sha256','restart_publisher.library_sha256'},'Input-only primary guard changed physical/compiler/provider identity')
 pe=None
 if 'restart_publisher.library_sha256' in changed:
  require(digest((old/'restart_publish.dll').read_bytes())==b['identity']['restart_publisher']['library_sha256'] and digest((now/'restart_publish.dll').read_bytes())==a['identity']['restart_publisher']['library_sha256'],'Actual compared publisher hashes differ');pe=publisher_equivalence(old/'restart_publish.dll',now/'restart_publish.dll')
 rows=lines((current/'trajectory/daily.jsonl').read_bytes());before=lines((prior/'trajectory/daily.jsonl').read_bytes());require(physical(rows)==physical(before[:35]),'Current primary physical prefix changed')
 for day in (2,4,14,17,30,35):require(package((current/f'trajectory/accepted-column-1-day-{day}.zip').read_bytes())[1]==package((prior/f'trajectory/accepted-column-1-day-{day}.zip').read_bytes())[1],'Current primary complete native changed')
 return dict(status='ACTUAL_CURRENT_PRIMARY_INPUT_FORTRAN_COMPILER_KERNEL_PHYSICAL_NATIVE_POSTIMAGE_PASS',actual_days=35,exact_native_days=[2,4,14,17,30,35],changed_source_roles=changed,publisher=pe,source_current=cq['source'],source_prior=pq['source'],current_build_sha256=digest((now/'BUILD.json').read_bytes()),prior_build_sha256=digest((old/'BUILD.json').read_bytes()),current_independent=science.audit_root(current),fresh_unchanged_CDE_full_periods=0)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('current','prior','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=audit(a.current,a.prior)
 with a.output.open('x') as stream:json.dump(q,stream,indent=2)
 print(q['status'])
