"""Actual nonJanuary AGE perstep epochs with private/calendar clock identity."""
import argparse,hashlib,json,subprocess,sys,struct,zipfile
from datetime import date,timedelta
from pathlib import Path
import age_perstep_runtime as runtime
from original_output_baseline import assignment


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--resume-cadence',action='store_true');a=p.parse_args();a.output.mkdir(exist_ok=a.resume_cadence);q=dict(status='RUNNING',optimization=a.optimization,cases={})
 if a.resume_cadence:
  raw=(a.output/'RESULT.json').read_bytes();old=json.loads(raw);assert old['status']=='FAILED' and not old['cases']
  first=a.output/'hys0-reset0-np1-2002-12-15/actual';report=json.loads((first/'RESULT.json').read_text(encoding='utf8'));original=json.loads((first/'RETAINED_FAILED_RESULT.json').read_bytes())
  assert report['status']=='ACTUAL_AGE_PERSTEP_SHORT_SOURCE_NATIVE_OUTPUT_PASS' and report['post_validation_role'].startswith('Actual complete existing source-bound trajectory') and original['error'].startswith("AssertionError({'result.ageProfile.csv':") and original['trajectory']['days']==35
  backup=a.output/'RETAINED_FAILED_EPOCH_RESULT.json';assert not backup.exists();backup.write_bytes(raw);q['retained_cadence_failure']=dict(path=backup.name,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 save()
 try:
  cases=[(0,0,'2002-12-15',1),(0,1,'2003-12-15',3),(1,0,'2003-12-15',2),(1,1,'2002-12-15',1),(2,0,'2002-12-15',3),(2,1,'2003-12-15',2)]
  for hys,reset,epoch,npd in cases:
   key=f'hys{hys}-reset{reset}-np{npd}-{epoch}';root=a.output/key;existing=root.exists();root.mkdir(exist_ok=a.resume_cadence);inputs=root/'input'
   if not existing:
    runtime.fixture(inputs,'explicit',hys,3,reset,npd,'interval' if hys else 'point')
    path=inputs/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),'TSTART',epoch),encoding='cp1252')
    path=inputs/'fixed-irrigation.irg';text=path.read_text(encoding='cp1252');assert text.count('2002-01-05')==1;path.write_text(text.replace('2002-01-05',(date.fromisoformat(epoch)+timedelta(days=4)).isoformat()),encoding='cp1252')
   cmd=[sys.executable,'-B',str(Path(runtime.__file__)),'--reference-work',a.reference_work,'--output',root/'actual','--existing-input',inputs,'--mode','explicit','--hysteresis',hys,'--format',3,'--reset',reset,'--nprintday',npd,'--source','interval' if hys else 'point','--optimization',a.optimization]
   if not existing:
    result=subprocess.run(list(map(str,cmd)),cwd=runtime.ROOT,capture_output=True,text=True,timeout=300);(root/'stdout').write_text(result.stdout,encoding='utf8');(root/'stderr').write_text(result.stderr,encoding='utf8');result.check_returncode()
   report=json.loads((root/'actual/RESULT.json').read_text(encoding='utf8'));assert report['status']=='ACTUAL_AGE_PERSTEP_SHORT_SOURCE_NATIVE_OUTPUT_PASS';meta=json.loads((Path(report['build_root'])/'BUILD.json').read_text(encoding='utf8'));checks=[]
   for day in (2,4,8,19,23,30,34,35):
    with zipfile.ZipFile(root/f'actual/trajectory/accepted-column-1-day-{day}.zip') as cp:raw=cp.read('macro.bin')
    pos,header,nr=runtime.calendar(raw,meta['project']['nodes']);completed=date.fromisoformat(epoch)+timedelta(days=day-1);expected=min(day,completed.timetuple().tm_yday) if reset else day
    assert header[6]==day and header[7]==expected and header[8]==1 and header[11]==reset and header[18:20]==(1,1),(key,day,header)
    private_day=struct.unpack_from('<i',raw,len(raw)-20)[0];private_period=struct.unpack_from('<d',raw,len(raw)-16)[0];private_flags=struct.unpack_from('<2i',raw,len(raw)-8)
    calendar_period=struct.unpack_from('<d',raw,pos+160+8*(nr-1))[0]
    assert private_day==day and private_period==calendar_period and private_flags==header[12:14]
    checks.append(dict(day=day,completed=completed.isoformat(),global_day=header[6],period_counter=header[7],expected_counter=expected,print_counter=header[8],private_day=private_day,private_period=private_period,private_flags=list(private_flags)))
   q['cases'][key]=dict(root=str(root),epoch=epoch,hysteresis=hys,reset=reset,perstep=True,nprintday=npd,report=report,actual_native_counters=checks);save();print(key,'ACTUAL_EPOCH_NATIVE_PASS',flush=True)
  q['status']='SIX_NONJANUARY_AGE_PERSTEP_EPOCHS_BOTH_RESET_PRIVATE_NATIVE_COLD_PASS';print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
