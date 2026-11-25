"""Actual bounded Frost/hysteresis inputs and retained numerical refusals."""
import argparse,itertools,json,re,shutil,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from experimental_project import load,inventory,auxiliary_magic
from frost_hysteresis_composition import selection
from original_output_baseline import assignment

def main():
 p=argparse.ArgumentParser()
 for name in ('evidence','output'):p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip(),checks=[],compiler_executions=0,model_executions=0)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def read(folder):return load(folder,original_output=True,time_step_policy='original-adaptive-event-closure-v1')
 def record(folder,label,status,**extra):q['checks'].append(dict(label=label,status=status,input_root=str(folder),input_inventory=inventory(folder),**extra));save()
 try:
  for implicit,kind,hys,initial in itertools.product((0,1),('water','cde'),(0,1),(1,2)):
   label=('implicit' if implicit else 'explicit')+'-'+kind+'-hys'+str(hys)+'-initial'+str(initial)
   folder=a.evidence/('frost-history-state01-'+label+'-input-v1');selected=selection(folder);assert selected is not None and selected['implicit']==implicit and selected['hysteresis']==hys and selected['initial']==initial
   project=read(folder);expected=('S5FI' if implicit else 'S5FD')+('C' if kind=='cde' else 'W')+('002' if implicit else '001');assert auxiliary_magic(project).decode()==expected;record(folder,label,'CURRENT_NEW_ROUTE_SELECTED',codec=expected)
  for implicit,kind,hys,initial in [(0,'water',0,1),(1,'cde',1,2)]:
   stem=('implicit' if implicit else 'explicit')+'-'+kind;original=a.evidence/('frost-history-state01-'+stem+'-hys'+str(hys)+'-initial'+str(initial)+'-input-v1')
   edits=[('SWMACRO',1),('SWSOLU',2),('SWKIMPL',2),('SWSNOW',0),('SWHEA',0),('SWCALT',1),('SWSOPHY',1),('SWDRA',0),('SWBOTB',5),('SWBR',1),('SWMETDETAIL',1),('IHWCKMODEL',8),('NPRINTDAY',2),('PERIOD',2),('SWMONTH',1),('FLPRINTDT','.TRUE.'),('SWINCO',3),('SWRES',0),('DRAIN',0),('DUPLICATE','SWHYST'),('SWKMEAN',7),('SWTOPBHEA',1),('SWCSV',4)]
   for index,(key,value) in enumerate(edits):
    folder=a.output/(stem+'-refusal-'+str(index));shutil.copytree(original,folder);p=folder/'swap.swp';s=p.read_text(encoding='cp1252')
    if key=='DRAIN':p=folder/'swap.dra';s=assignment(p.read_text(encoding='cp1252'),'SWDIVD',value)
    elif key=='DUPLICATE':s+='\nSWHYST = '+str(hys)+'\n'
    elif key in ('IHWCKMODEL','FLPRINTDT') and not re.search(r'(?mi)^\s*'+key+r'\s*=',s):s+='\n'+key+' = '+str(value)+'\n'
    else:s=assignment(s,key,value)
    p.write_text(s,encoding='cp1252')
    try:read(folder)
    except ValueError as error:record(folder,key+'='+str(value),'ACTUAL_PUBLIC_FRONTEND_REFUSED_NO_BUILD',diagnostic=str(error))
    else:raise AssertionError('Unexpected public admission '+folder.name)
   folder=a.output/(stem+'-retained-hys2');shutil.copytree(original,folder);p=folder/'swap.swp';p.write_text(assignment(p.read_text(encoding='cp1252'),'SWHYST',2),encoding='cp1252');assert selection(folder) is None;read(folder);record(folder,folder.name,'EXISTING_HYS2_ROUTE_RETAINED')
   if implicit:
    folder=a.output/'implicit-examined-Ksat';shutil.copytree(original,folder);p=folder/'swap.swp';s=p.read_text(encoding='cp1252')
    def examined(match):
     names=match[1].split();rows=match[2].splitlines();fields=rows[0].split();assert len(fields)==len(names);fields[names.index('KSATEXM')]=str(float(fields[names.index('KSATFIT')])+1);rows[0]=' '.join(fields);return match[1]+'\n'.join(rows)+'\n* End of table'
    s,count=re.subn(r'(?mi)^([ \t]*ORES[ \t]+OSAT[^\r\n]*\n)(.*?)^\* End of table',examined,s,count=1,flags=re.S);assert count==1;p.write_text(s,encoding='cp1252')
    try:read(folder)
    except ValueError as error:assert 'examined-Ksat interpolation' in str(error);record(folder,folder.name,'ORIGINAL_UNIMPLEMENTED_EXAMINED_KSAT_REFUSED',diagnostic=str(error))
    else:raise AssertionError('Unimplemented examinedKsat admitted')
  assert len(q['checks'])==65
  q['status']='ACTUAL_CURRENT16_POSITIVES46_SCOPE_REFUSALS_TWO_OLD_HYS2_AND_EXAMINED_KSAT_REFUSAL_PASS'
 except Exception as error:q.update(status='FAILED_ACTUAL_FRONTEND',error=repr(error));raise
 finally:save()
 print(q['status'])

if __name__=='__main__':main()
