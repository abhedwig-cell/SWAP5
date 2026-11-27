"""Exact current initial1/2 source inverse; no model or compiler execution."""
import argparse,json
from pathlib import Path
from closed_joint_history_calendar_science import source_contract,git
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
head=git('rev-parse','HEAD').decode().strip();q=source_contract(head)
assert git('rev-parse','HEAD').decode().strip()==head
with a.output.open('x',encoding='utf8') as out:json.dump(q,out,indent=2);out.write('\n')
print('ACTUAL_INITIAL1_AND2_CLOSED_CALENDAR_COMPLETE_SOURCE_INVERSE_PASS',head,flush=True)
