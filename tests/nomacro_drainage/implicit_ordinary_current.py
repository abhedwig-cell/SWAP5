"""Actual current receiver against unchanged ordinary bottom6 compiled bundles."""
import argparse,json,subprocess,sys,zipfile
from pathlib import Path
import implicit_zero_boundary_runtime as runtime
m=runtime.m;ROOT=runtime.ROOT

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();old=json.loads((a.profile/'RESULT.json').read_text());build=Path(old['build_root']);project=m.e.load(a.profile/'input',original_output=True);meta,_=m.validate_bundle(build,a.reference_work,project)
 assert meta['identity'].get('extended_drainage') is None
 command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',project.input_directory,'--original-output','--reference-work',str(a.reference_work),'--build-bundle',str(build),'--days','34','--checkpoint-at','34','--restart',str(a.profile/'trajectory/accepted-column-1-day-30.zip'),'--restart-day','30','--output',str(a.output/'public')]
 v=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=90);(a.output/'actual.stdout').write_text(v.stdout);(a.output/'actual.stderr').write_text(v.stderr);v.check_returncode()
 assert m.physical(m.rows(a.output/'public'))==m.physical(m.rows(a.profile/'trajectory')[30:34])
 with zipfile.ZipFile(a.output/'public/accepted-column-1-day-34.zip') as now,zipfile.ZipFile(a.profile/'trajectory/accepted-column-1-day-34.zip') as before:assert all(now.read(n)==before.read(n) for n in ('result.end','macro.bin'))
 q=dict(status='ACTUAL_CURRENT_PUBLIC_ORDINARY_ZERO_BOUNDARY_UNCHANGED_COMPILED_NATIVE_POSTIMAGE_PASS',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),actual_old_build_root=str(build),actual_old_build_sha256=m.sha(build/'BUILD.json'),actual_prior_source=old['source'],returncode=v.returncode,exact_physical_days=[31,32,33,34],exact_complete_native_day=34,new_compilations=0,new_full_periods=0)
 (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'])
if __name__=='__main__':main()
