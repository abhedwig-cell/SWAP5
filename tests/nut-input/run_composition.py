#!/usr/bin/env python3
"""Generate the admitted full-assertion drivers with an additional file producer.

No physical assertion is removed. Fresh compilation/driver/native execution uses
the existing owner runner, with a deterministic bounded transformation retained
alongside all raw evidence. No cached provider object is used.
"""
from pathlib import Path
import hashlib,json,os,sys
ROOT=Path(__file__).resolve().parents[2]
selected_mode=sys.argv[1]if len(sys.argv)>1 else'joint'
assert selected_mode in ['day','joint']
OUT=Path(os.environ['N_INPUT_COMPOSITION_DIR']).resolve();OUT.mkdir(exist_ok=False)
(OUT/'drivers').mkdir()
sha=lambda b:hashlib.sha256(b).hexdigest()
fixture=ROOT/'tests/nut-input/parsed_plan_fixture.inc'
inputs={str(fixture.relative_to(ROOT)):sha(fixture.read_bytes())}
generated={}
for name in ['test_calendar_day','test_calendar_joint']:
 p=ROOT/f'tests/nut-calendar/{name}.f90';s=p.read_text();inputs[str(p.relative_to(ROOT))]=sha(p.read_bytes())
 s=s.replace(' use mod_soil_n_amendment_calendar\n',' use mod_soil_n_amendment_calendar\n use mod_soil_n_amendment_input\n')
 needle='  call create_soil_n_amendment_calendar(0d0,[0d0,0d0,1d0,1d0],dose,defs,plan,code)'
 assert s.count(needle)==1
 replacement='  call make_file_calendar(items,plan,code)'
 if name.endswith('joint'):
  replacement="  if(trim(profile)=='file')then\n"+replacement+'\n  else\n'+needle+'\n  end if'
 s=s.replace(needle,replacement)
 assert s.count(" include 'material_fixture.inc'")==1
 s=s.replace(" include 'material_fixture.inc'"," include 'material_fixture.inc'\n"+fixture.read_text())
 target=OUT/'drivers'/p.name;target.write_text(s);generated[p.name]=sha(target.read_bytes())
p=ROOT/'tests/nut-calendar/run_calendar.py';s=p.read_text();inputs[str(p.relative_to(ROOT))]=sha(p.read_bytes())
old="drivers=[ROOT/'tests/nut-calendar/test_calendar.f90']\n if mode in ['day','joint']:drivers += [ROOT/'tests/nut-calendar/test_calendar_day.f90']\n if mode=='joint':drivers += [ROOT/'tests/nut-calendar/test_calendar_joint.f90']"
new="drivers=[OUT/'drivers/test_calendar_day.f90']"+("\n if mode=='joint':drivers += [OUT/'drivers/test_calendar_joint.f90']")
assert s.count(old)==1;s=s.replace(old,new)
old="inputs[str(d.relative_to(ROOT))]=sha(d)"
assert s.count(old)==1;s=s.replace(old,"inputs['tests/nut-calendar/'+d.name]=sha(ROOT/'tests/nut-calendar'/d.name)")
assert s.count("for profile in ['manual','calendar']:")==2
s=s.replace("for profile in ['manual','calendar']:","for profile in ['manual','calendar','file']:")
old="assert (b/('manual-'+suffix)).read_bytes()==(b/('calendar-'+suffix)).read_bytes(),'manual/scheduled drift '+suffix"
assert s.count(old)==1
s=s.replace(old,old+"\n   assert (b/('manual-'+suffix)).read_bytes()==(b/('file-'+suffix)).read_bytes(),'manual/file drift '+suffix")
# Baseline runner records this script's identity via __file__; the retained
# executed text and generated driver hashes bind the exact transformations.
(OUT/'executed_runner.py').write_text(s)
(OUT/'GENERATION.json').write_text(json.dumps(dict(input_sha256=inputs,generated_driver_sha256=generated,executed_runner_sha256=sha(s.encode())),indent=2)+'\n')
os.environ['CALENDAR_RESULT_DIR']=str(OUT)
sys.argv=[str(Path(__file__)),selected_mode]
exec(compile(s,str(OUT/'executed_runner.py'),'exec'),globals())
