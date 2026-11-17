"""Test original restart transfer before using a common-state late comparison."""
from pathlib import Path
import argparse,contextlib,csv,json,re,shutil,subprocess,time,zipfile
from run import m,POLICY
from candidate_saturation import csvrows
def main():
 p=argparse.ArgumentParser();p.add_argument('--prior',type=Path,required=True);p.add_argument('--candidate-build',type=Path,required=True);p.add_argument('--reference-exe',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--no-current-irrigation',action='store_true');a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);build=a.candidate_build;project=m.e.load(a.prior/'inputs/water-surface-history',time_step_policy=POLICY);meta=json.loads((build/'BUILD.json').read_text());binding={**meta['binding'],'common_state_diagnostic_exe':m.sha(build/'late_cap.exe')};folder=out/'candidate';folder.mkdir();data=[]
 def trial():
  with contextlib.ExitStack() as stack:
   host=m.h.DailyHost(stack,build/'late_cap.exe',m.h.executable(build,'day_kernel'),a.prior/'inputs/water-surface-history',folder,[m.h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=binding,model=project.model,project=project)
   for d in range(1,366):data.append(host.step(1,checkpoint=d in (362,365)))
   host.close()
 _,seconds=m.bounded(30,trial);original=out/'original';shutil.copytree(a.prior/'finish-controls/water-surface-history-literal-input',original)
 with zipfile.ZipFile(folder/'accepted-column-1-day-362.zip') as z:
  (original/'restart.end').write_bytes(z.read('result.end'));(original/'macro.bin').write_bytes(z.read('macro.bin'))
 p=original/'swap.swp';s=p.read_text(encoding='cp1252').replace('TSTART = 2002-01-01','TSTART = 2002-12-29').replace('TEND = 2004-12-31','TEND = 2002-12-31');s,n=re.subn(r'(?m)^(\s*SWINCO\s*=\s*)\d+',r'\g<1>3',s);assert n==1;s,n=re.subn(r"(?m)^(\s*INIFIL\s*=\s*)'[^']*'",r"\g<1>'restart.end'",s);assert n==1
 # This diagnostic has no irrigation during its three-day interval. The original
 # reader otherwise refuses an entirely past fixed table. Make that structural
 # input change explicit, never call it literal executed-input equality.
 if a.no_current_irrigation:
  assert all(float(v['IRRIG'])==0 for v in csvrows(folder/'original/result_output.csv')[363:366])
  s,n=re.subn(r'(?m)^(\s*SWIRFIX\s*=\s*)\d+',r'\g<1>0',s);assert n==1
 s+='\nSWINITYPE = 2\n';p.write_text(s,encoding='cp1252');start=time.perf_counter()
 with (original/'stdout').open('wb') as log:r=subprocess.run([str(a.reference_exe),'./swap.swp'],cwd=original,stdout=log,stderr=subprocess.STDOUT,timeout=20)
 report=dict(kind='ORIGINAL_RESTART_TRANSFER_MUST_QUALIFY_BEFORE_COMMON_STATE_CLAIM',candidate_seconds=seconds,original_seconds=time.perf_counter()-start,returncode=r.returncode,swap_ok=(original/'swap.ok').exists(),tolerances_changed=False,reference_executable_sha256=m.sha(a.reference_exe),science='NOT_QUALIFIED',past_irrigation_table_disabled_explicitly=a.no_current_irrigation,literal_executed_input_equality=False)
 if report['swap_ok']:
  b=csvrows(original/'result_output.csv');c=csvrows(folder/'original/result_output.csv');report['initial_differences']={k:float(b[0][k])-float(c[362][k]) for k in ['GWL','WTOT','PD_VOL']};report['day364']={'candidate_GWL':float(c[364]['GWL']),'original_GWL':float(b[2]['GWL']),'difference_cm':float(c[364]['GWL'])-float(b[2]['GWL'])};report['original_daily_BALDEV_cm']=[float(x['BALDEV']) for x in b[1:]]
 (out/'RESULT.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
if __name__=='__main__':main()
