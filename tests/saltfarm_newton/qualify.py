"""Real current-source SaltFarm acceptance, bounded model calls, own origins."""
from pathlib import Path
from dataclasses import replace
import argparse,contextlib,json,subprocess,sys,zipfile
root=Path(__file__).resolve().parents[2];sys.path[:0]=[str(root/'app/hybrid_water'),str(root/'tools/solute')]
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows,check,csvlines
p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--reference',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--control',action='store_true');p.add_argument('--days',type=int,default=1461);p.add_argument('--model-cap',type=float,default=25);a=p.parse_args()
project=h.SALTFARM
if a.control:
 old=project;project=replace(project,water_polish_policy=h.ALWAYS_WATER_POLISH);h.PROJECTS=tuple(project if x==old else x for x in h.PROJECTS)
meta,case=validate_bundle(a.bundle,a.reference,project);binding=meta['binding'];donor=h.executable(a.bundle,'day_donor');kernel=h.executable(a.bundle,'day_kernel');a.output.mkdir(parents=True,exist_ok=False);full=a.output/'full';full.mkdir();data=[]
cuts={109,111,365,367,453,455,1460,1461};cuts={x for x in cuts if x<=a.days};result=dict(source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),build_sha256=h.sha(a.bundle/'BUILD.json'),policy=project.water_polish_policy,argv=sys.argv,restarts=[])
def trajectory():
 with contextlib.ExitStack() as stack:
  host=h.DailyHost(stack,donor,kernel,case,full,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=binding,model=project.model,project=project)
  with (full/'daily.jsonl').open('w') as journal:
   for day in range(1,a.days+1):
    row=host.step(1,checkpoint=day in cuts);data.append(row);journal.write(json.dumps(row)+'\n');journal.flush();assert row['committed'],('refused',day,row)
  host.close()
try:
 _,elapsed=bounded(a.model_cap,trajectory);assert [r['day'] for r in data]==list(range(1,a.days+1));result.update(status='FULL_PASS',days=len(data),seconds=elapsed,budgets=check(data))
 assert len(csvlines(full/'original/result_output.csv'))==a.days+2
 windows=[(109,111),(365,367),(453,455),(1460,1461),(109,1461)]
 for start,end in windows:
  if end>a.days or a.control:continue
  checkpoint=full/f'accepted-column-1-day-{start}.zip';digest=h.sha(checkpoint);origin=a.output/f'origin{start}-{end}';receipt=h.verify_checkpoint(checkpoint,start,binding,origin);restart=a.output/f'restart{start}-{end}';restart.mkdir()
  def resume():return h.run(donor,kernel,case,restart,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=binding,model=project.model,project=project)
  resumed,seconds=bounded(a.model_cap,resume);assert resumed['first_refusal'] is None;assert physical(rows(restart))==physical(data[start:end]);check(rows(restart));assert csvlines(restart/'original/result_output.csv')[-(end-start):]==csvlines(full/'original/result_output.csv')[start+2:end+2]
  with zipfile.ZipFile(restart/f'accepted-column-1-day-{end}.zip') as x,zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
  assert h.sha(checkpoint)==digest;result['restarts'].append(dict(start=start,end=end,seconds=seconds,exact_physical=True,exact_csv=True,exact_native=True,origin_unchanged=True))
except Exception as ex:result.update(status='FAIL',error=repr(ex),completed_days=len(data))
(a.output/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2));sys.exit(result['status']!='FULL_PASS')
