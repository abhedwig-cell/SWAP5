#!/usr/bin/env python3
"""Exact bounded producer delta and complete fresh native/physical proof."""
from pathlib import Path
import argparse,ast,base64,hashlib,io,json,os,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='7c774455bf1d5918b76d6147a23cc159ba427e8b'
STATUS='integration/audits/MC_NUT01_AMENDMENT_INPUT_STATUS.json'
PRODUCTION={'src/process/mod_soil_n_amendment_input.f90'}
CHANGED={'tests/nut-calendar/verify_calendar_successor.py','tests/nut-calendar/check_calendar_controls.py','tests/crop-co2/verify_co2_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'}
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def baseline_command(path):
 root=ROOT.parent/('input-baseline-'+BASE[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,capture_output=True,check=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'baseline moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root,text=True).strip(),'dirty baseline')
 p=subprocess.run([sys.executable,'-B',str(root/path)],cwd=root,capture_output=True,check=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 return json.loads(p.stdout)
def verify_source(git_reader=None):
 if (ROOT/'integration/audits/MC_NUT01_ACCEPTED_THERMAL_STATUS.json').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-thermal'));import verify_thermal_successor as successor
  return successor.verify_source(git_reader=git_reader)
 g=git if git_reader is None else git_reader;s=json.loads((ROOT/STATUS).read_text())
 check(s['baseline']==BASE,'baseline drift');g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--','src','tests','tools','reference'),'dirty scientific surface')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in g('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 expected={p:'A'for p in s['added_blobs']};expected.update({p:'M'for p in CHANGED})
 check(rows==expected and set(s['changed_blobs'])==CHANGED,'foreign/incomplete input delta')
 check({p for p in s['added_blobs']if p.startswith('src/')}==PRODUCTION,'foreign producer')
 for p,h in {**s['added_blobs'],**s['changed_blobs']}.items():check(g('rev-parse','HEAD:'+p)==h==blob((ROOT/p).read_bytes()),'unbound postimage '+p)
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'reference changed')
 return dict(baseline=BASE,source_tree=g('rev-parse','HEAD:src'),current_source_tree=g('rev-parse','HEAD:src'),input_successor=True,calendar_successor=True,senescence_successor=True,qualified=False,admitted=False)
def read_evidence():
 s=json.loads((ROOT/STATUS).read_text());e=s['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes())
 check(len(raw)==e['decoded_bytes']and sha(raw)==e['sha256'],'capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(len(ms)==e['members']and all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe capsule')
  d={m.name:a.extractfile(m).read()for m in ms};check(len(d)==len(ms),'duplicate raw member')
 manifest=json.loads(d.pop('MANIFEST.json'));check(set(manifest)==set(d),'manifest coverage')
 for p,h in manifest.items():check(sha(d[p])==h,'raw drift '+p)
 return d
def inputs_valid(r):
 for p,h in r['input_sha256'].items():
  check(not Path(p).is_absolute()and '..'not in Path(p).parts,'unsafe input');check(sha((ROOT/p).read_bytes())==h,'stale input '+p)
def events_valid(d,prefix,events):
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed native/build')
  if e['category']in ['compile','driver_compile']:
   check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked build')
  for stream in ['stdout','stderr']:check(sha(d[prefix+e[stream+'_file']])==e[stream+'_sha256'],'raw event binding')
def validate_process(d,source):
 r=json.loads(d['process/result.json']);ev=json.loads(d['process/events.json'])
 check(r['status']=='PASS'and r['source_tree']==source['source_tree'],'unfinished/stale process')
 inputs_valid(r);events_valid(d,'process/',ev)
 check(r['production_providers']==4 and r['fixture_count']==53 and r['invalid_count']==45 and r['date_cases']==3075,'small contract coverage')
 check(PRODUCTION<=r['input_sha256'].keys(),'untested reader')
 for p,h in r['fixture_sha256'].items():check(sha(d['process/'+p])==h,'fixture drift')
 check(len(r['fixture_sha256'])==54,'incomplete fixtures')
 check(r['runs']['O0']==r['runs']['O2'],'process optimization drift')
 for opt in ['O0','O2']:
  row=r['runs'][opt];check(row['dates']=='INDEPENDENT_GREGORIAN_CASES=3075\n','date oracle absent')
  check(len(row['fixtures'])==55,'missing file paths')
  es=[e for e in ev if e['category']=='native'and '/'+opt+'/'in e['command'][0]]
  check(len(es)==56,'missing process execution')
  check(row['dates']in [d['process/'+e['stdout_file']].decode()for e in es],'date raw absent')
  for name,out in row['fixtures'].items():
   check(out.strip()in ['INVALID_INPUT_NO_PUBLISHED_PLAN=PASS','INPUT_ACTUAL_CALENDAR_UNITS_POSITIONS_EMPTY_ABA_RESET=PASS'],'missing process assertion')
   check(out in [d['process/'+e['stdout_file']].decode()for e in es],'process raw mismatch')
  check(len([e for e in ev if e['category']=='compile'and '-'+opt in e['command']])==4,'fresh small providers absent')
  for kind in ['driver_compile','link']:check(len([e for e in ev if e['category']==kind and '-'+opt in e['command']])==1,'small fresh driver/link absent')
 return r
def generated_driver(name):
 s=(ROOT/f'tests/nut-calendar/{name}.f90').read_text()
 s=s.replace(' use mod_soil_n_amendment_calendar\n',' use mod_soil_n_amendment_calendar\n use mod_soil_n_amendment_input\n')
 needle='  call create_soil_n_amendment_calendar(0d0,[0d0,0d0,1d0,1d0],dose,defs,plan,code)'
 replacement='  call make_file_calendar(items,plan,code)'
 if name.endswith('joint'):replacement="  if(trim(profile)=='file')then\n"+replacement+'\n  else\n'+needle+'\n  end if'
 check(s.count(needle)==1,'baseline generator mismatch');s=s.replace(needle,replacement)
 return s.replace(" include 'material_fixture.inc'"," include 'material_fixture.inc'\n"+(ROOT/'tests/nut-input/parsed_plan_fixture.inc').read_text()).encode()
def validate_composition(d,prefix,source,mode,process):
 r=json.loads(d[prefix+'result.json']);ev=json.loads(d[prefix+'events.json']);gen=json.loads(d[prefix+'GENERATION.json'])
 check(r['status']=='PASS'and r['mode']==mode and r['source_tree']==source['source_tree'],'unfinished/stale composition')
 inputs_valid(r);inputs_valid(gen);events_valid(d,prefix,ev)
 check(r['compiler']==process['compiler'],'compiler drift')
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as a:
  original={name:a.extractfile('SWAP/'+name).read()for name in r['authority']}
 check(set(original)=={'wofost_soil_declarations.f90','wofost_soil_amendments.f90','wofost_soil_cropresidues.f90','wofost_soil_parameters.f90','management_soil.f90','wofost_soil_orgmatn.f90','wofost_soil_rateconstants.f90','wofost_soil_watern.f90'},'incomplete original oracle')
 check(r['authority']=={p:sha(b)for p,b in original.items()},'original authority drift')
 tree=ast.parse((ROOT/'tests/nut-calendar/run_calendar.py').read_text())
 wrapper=next(ast.literal_eval(n.value)for n in tree.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='oracle'for t in n.targets))
 check(sha(d[prefix+'executed_runner.py'])==gen['executed_runner_sha256'],'executed runner drift')
 for name,h in gen['generated_driver_sha256'].items():
  body=d[prefix+'drivers/'+name];check(sha(body)==h and body==generated_driver(Path(name).stem),'physical assertions/source changed')
 expected={'test_calendar_day','test_calendar_joint'}if mode=='joint'else {'test_calendar_day'}
 check(PRODUCTION<=r['input_sha256'].keys(),'composition missing new reader')
 for opt in ['O0','O2']:
  for name,body in original.items():
   if name=='wofost_soil_orgmatn.f90':
    old=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Bio(fn) * NFracBio'
    new=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Hum(fn) * NFracHum'
    check(body.count(old)==1,'original correction changed');body=body.replace(old,new)
   check(d[prefix+opt+'/'+name]==body,'literal source drift '+name)
  body=original['management_soil.f90'];a=body.index(b'! Mineralisation, but Nminer is negative in case of immobilisation');b=body.index(b'      Call Wofost_SoilBalanceCheck',a)
  check(body[a:b]in d[prefix+opt+'/literal_crop_exchange.f90'],'literal uptake changed')
  check(d[prefix+opt+'/material_oracle.inc']==wrapper.encode(),'literal wrapper changed')
  row=r['runs'][opt];check(row['production_providers']==(267 if mode=='joint'else 47),'actual closure drift');check(set(row['drivers'])==expected,'driver coverage')
  es=[e for e in ev if e['category']=='compile'and '-'+opt in e['command']]
  compiled={'src/'+e['command'][e['command'].index('-c')+1].split('/src/',1)[1]for e in es if '/src/'in e['command'][e['command'].index('-c')+1]}
  check(compiled=={p for p in r['input_sha256']if p.startswith('src/')}and len(compiled)==row['production_providers'],'fresh exact provider closure absent')
  for name,value in row['drivers'].items():
   for kind in ['driver_compile','link']:
    check(len([e for e in ev if e['category']==kind and '-'+opt in e['command']and any(Path(x).name==name+('.f90'if kind=='driver_compile'else'')for x in e['command'])])==1,'fresh driver/link absent')
   natives=[e for e in ev if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name==name]
   if name=='test_calendar_day':
    check(len(natives)==1 and 'CALENDAR_REAL_DAY_DELAYED_LITERAL_WHOLE_N_ROLLBACK_REPLAY=PASS'in value['stdout'],'actual file day missing')
    check(d[prefix+natives[0]['stdout_file']].decode()==value['stdout'],'day raw mismatch');continue
   check(set(value)=={'manual','calendar','file'}and len(natives)==6,'three real physical profiles absent')
   for profile,entry in value.items():
    subset=[e for e in natives if e['command'][-1]==profile]
    check(len(subset)==2 and subset[0]['command'][1]=='write'and subset[1]['command'][1]=='resume','fresh restart absent')
    check('CALENDAR_ACTUAL_RICHARDS_DELAYED_LITERAL_ATOMIC_PENDING_OPAQUE_DISK=PASS'in entry['stdout']and 'FRESH_PROCESS_CONTINUATION=PASS'in entry['fresh_stdout'],'whole-N/rollback/restart assertion absent')
    check(d[prefix+subset[0]['stdout_file']].decode()==entry['stdout']and d[prefix+subset[1]['stdout_file']].decode()==entry['fresh_stdout'],'joint raw mismatch')
    for suffix,key in [('restart.bin','restart_sha256'),('expected.bin','endpoint_sha256'),('fresh.bin','endpoint_sha256'),('expected.bin.opaque','endpoint_sha256')]:
     b=d[prefix+opt+'/'+profile+'-'+suffix];check(sha(b)==entry[key],'complete native endpoint drift')
     check(b==d[prefix+opt+'/manual-'+suffix],'manual/typed/file physical mismatch')
    check(entry['endpoint_sha256']==r['runs']['O0']['drivers'][name][profile]['endpoint_sha256'],'optimization endpoint drift')
   check(d[prefix+opt+'/file-restart.bin'][:8]==b'S5NC0002','pending full restart profile absent')
 return r
def validate(d,source):
 p=validate_process(d,source)
 validate_composition(d,'day/',source,'day',p);validate_composition(d,'joint/',source,'joint',p)
 return p
def verify_qualification():
 if (ROOT/'integration/audits/MC_NUT01_ACCEPTED_THERMAL_STATUS.json').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-thermal'));import verify_thermal_successor as successor
  return successor.verify_qualification()
 source=verify_source();validate(read_evidence(),source)
 prior=baseline_command('tests/nut-calendar/verify_calendar_successor.py');check(prior['qualified'],'baseline owner failed')
 return {**source,'qualified':True,'highest':'NOT_SELECTED_POLICY'}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');a=p.parse_args()
 print(json.dumps(verify_source()if a.source_only else verify_qualification(),indent=2))
