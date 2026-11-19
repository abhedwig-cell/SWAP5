"""Actual varying-groundwater AGE nonJanuary/year private-state composition."""
import argparse,json,struct,subprocess,sys,zipfile
from datetime import date,timedelta
from pathlib import Path
import age_groundwater_runtime as runtime


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir();q=dict(status='RUNNING',optimization=a.optimization,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=runtime.ROOT,text=True).strip(),cases={})
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 save()
 try:
  for hys,reset,epoch,npd in [(0,0,'2002-12-15',1),(0,1,'2003-12-15',3),(1,0,'2003-12-15',2),(1,1,'2002-12-15',1),(2,0,'2002-12-15',3),(2,1,'2003-12-15',2)]:
   key=f'hys{hys}-reset{reset}-np{npd}-{epoch}';root=a.output/key;root.mkdir()
   cmd=[sys.executable,'-B',runtime.__file__,'--reference-work',str(a.reference_work),'--output',str(root/'actual'),'--optimization',a.optimization,'--hysteresis',str(hys),'--perstep','--mode','explicit','--reset',str(reset),'--nprintday',str(npd),'--epoch',epoch,'--source','interval' if hys else 'point']
   result=subprocess.run(cmd,cwd=runtime.ROOT,capture_output=True,text=True,timeout=300);(root/'stdout').write_text(result.stdout,encoding='utf8');(root/'stderr').write_text(result.stderr,encoding='utf8');result.check_returncode()
   report=json.loads((root/'actual/RESULT.json').read_text(encoding='utf8'));assert report['status']=='ACTUAL_ORIGINAL_AGE_GROUNDWATER_SHORT_PHYSICAL_NATIVE_OUTPUT_PASS';project=runtime.m.e.load(Path(report['input_root']),original_output=True);runtime.m.validate_bundle(Path(report['build_root']),a.reference_work,project);checks=[]
   for day in (2,4,7,9,15,19,30,34,35):
    with zipfile.ZipFile(root/f'actual/trajectory/accepted-column-1-day-{day}.zip') as cp:raw=cp.read('macro.bin')
    pos,header,nr=runtime.calendar(raw,project.nodes);completed=date.fromisoformat(epoch)+timedelta(days=day-1);expected=min(day,completed.timetuple().tm_yday) if reset else day
    assert header[6]==day and header[7]==expected and header[8]==1 and header[11]==reset and header[18:20]==(1,1),(key,day,header)
    private_day=struct.unpack_from('<i',raw,len(raw)-20)[0];private_period=struct.unpack_from('<d',raw,len(raw)-16)[0];flags=struct.unpack_from('<2i',raw,len(raw)-8);period=struct.unpack_from('<d',raw,pos+160+8*(nr-1))[0]
    assert private_day==day and private_period==period and flags==header[12:14]
    checks.append(dict(day=day,completed=completed.isoformat(),global_day=header[6],period_counter=header[7],expected_counter=expected,print_counter=header[8],private_day=private_day,private_period=private_period,private_flags=list(flags)))
   q['cases'][key]=dict(root=str(root),epoch=epoch,hysteresis=hys,reset=reset,nprintday=npd,perstep=True,actual_bottom=1,report=report,actual_native_counters=checks);save();print(key,'ACTUAL_AGE_GROUNDWATER_EPOCH_NATIVE_PASS',flush=True)
  q['status']='SIX_NONJANUARY_AGE_GROUNDWATER_EPOCHS_BOTH_RESET_PRIVATE_NATIVE_COLD_PASS';print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
