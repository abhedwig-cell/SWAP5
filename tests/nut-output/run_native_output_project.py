"""Native TRUE startup composed with the actual Richards/crop/N output day.

All incumbent default driver assertions remain; only the extra source route is
bounded to two days. No numerical provider or tolerance is replaced.
"""
from pathlib import Path
import argparse,hashlib,json,os,resource,sys
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
recipe=ROOT/'tests/nut-crop/run_reproductive_process.py'
text=recipe.read_text().split("for opt in ('O0','O2'):")[0]
os.environ['REPRODUCTIVE_PROCESS_RESULT_DIR']=str(OUT/'literal')
exec(compile(text,str(recipe),'exec'),{'__file__':str(recipe),'__name__':'literal_preparation'})
original=ROOT/'tests/nut-crop/test_b112_retained_joint.f90'
s=original.read_text().replace(' implicit none',' use mod_crop_soil_n_native_output_start\n use mod_crop_soil_n_output_day\n use mod_crop_n_output_generation\n use mod_crop_soil_n_calendar_day,only:select_calendar_material_batch\n use mod_soil_n_crop_extended_output\n implicit none',1)
s=s.replace('\ncontains\n',"\ncontains\n include 'native_output_project.inc'\n",1)
anchor="   call require(all(startup_policy%application_age==[1.27d0,.99d0,1.27d0]),'source crop ages')"
assert s.count(anchor)==1
s=s.replace(anchor,anchor+"\n   if(index(trim(mode),'native-output')==1)then\n    call native_output_source_proof(startup_plan,startup_policy,base_day,source_water)\n    return\n   end if",1)
(OUT/'driver.f90').write_text(s)
recipe=ROOT/'tests/nut-crop/run_hist_complete.py'
text=recipe.read_text().split(' # Original composition and its fresh-process endpoint stay selected.')[0]
text=text.replace('OUT.mkdir(exist_ok=False)','OUT.mkdir(exist_ok=True)',1)
text=text.replace("driver=ROOT/'tests/nut-crop/test_b112_retained_joint.f90';visit(driver)","driver=OUT/'driver.f90';visit(driver)",1)
text=text.replace("'-I'+str(b)]","'-I'+str(b),'-I'+str(ROOT/'tests/nut-output')]",1)
text=text.replace("['gfortran',","[os.environ.get('FC','gfortran'),")
text+='''
 native_restart=b/'native.restart';native_end=b/'native.endpoint';native_fresh=b/'native.fresh'
 run([exe,'native-output',native_restart,native_end,'source-profile'],b,'native_output')
 run([exe,'native-output-resume',str(native_restart)+'.day1',native_fresh,'source-profile'],b,'native_output_restart')
 for value in [native_end,native_fresh]:
  assert Path(str(value)+'.true').read_bytes()==Path(str(value)+'.false').read_bytes(),'TRUE changes physics'
  assert Path(str(value)+'.initial-true').read_bytes()==Path(str(value)+'.initial-false').read_bytes(),'TRUE changes startup physics'
  assert value.read_bytes()==Path(str(value)+'.after-rejected-start').read_bytes(),'rejected startup changes live run'
 for suffix in ['', '.csv','.true','.false']:
  assert Path(str(native_end)+suffix).read_bytes()==Path(str(native_fresh)+suffix).read_bytes(),'native fresh drift '+suffix
 results[opt]=dict(default_endpoint=sha(default_endpoint),native_endpoint=sha(native_end),native_csv=sha(Path(str(native_end)+'.csv')),providers=len(ordered)-1)
assert results['O0']==results['O2'],'native output optimization drift'
for p in ['tests/nut-output/native_output_project.inc','tests/nut-output/run_native_output_project.py','tests/nut-crop/run_hist_complete.py','tests/nut-crop/test_b112_retained_joint.f90']:
 inputs[p]=sha(ROOT/p)
r=dict(status='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),results=results,input_sha256=inputs,generated_driver_sha256=sha(OUT/'driver.f90'),cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\\n');print(r['status'])
'''
os.environ['N_HIST_RESULT_DIR']=str(OUT);os.environ['REPRODUCTIVE_LITERAL_FILE']=str(OUT/'literal/literal.f90')
sys.path.insert(0,str(ROOT/'tests/nut-crop'))
exec(compile(text,str(recipe),'exec'),{'__file__':str(recipe),'__name__':'native_project_qualification'})
