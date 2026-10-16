#!/usr/bin/env python3
"""Exact classic annual owner successor, not full moving numerical qualification."""
from pathlib import Path
import base64,hashlib,io,json,math,re,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[3]
BASE='c62a2e69a0e604d92dcdba625c525835c2bd5224'
STATUS='integration/audits/MC_CROP01_ANNUAL_QUALIFICATION_STATUS.json'
SURFACE=['src','tests','tools','reference','.github']
PRODUCTION={'src/crop/mod_wofost_actual_biomass_state.f90','src/crop/mod_wofost_finalize_rates.f90','src/crop/mod_wofost_one_day_structural_evolution.f90'}
MOVING='tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'
PREDECESSOR='tests/fmig431/verify_signed_divdra_successor.py'
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['repair_admission']
OPTION='''# Classic annual source/state owner only; never a full moving PASS.
if [[ "${1:-}" == --crop-annual-owner-only ]]; then
  cd "$(cd "$(dirname "$0")/../.." && pwd)"
  python3 -B tests/fmig431/annual/verify_annual_successor.py
  echo 'FCI_CLASSIC_ANNUAL_OWNER_RECONCILIATION=PASS'
  exit 0
fi

'''
CASE='''      src/crop/mod_wofost_actual_biomass_state.f90 )
        python3 -B tests/fmig431/annual/verify_annual_successor.py || fail 'unqualified classic mortality state successor'
        ;;
'''
def delegation(function,arguments):
 return f'''    if (ROOT/'tests/fmig431/annual/verify_annual_successor.py').exists():
        sys.path.insert(0,str(ROOT/'tests/fmig431/annual'));import verify_annual_successor as annual
        return annual.{function}({arguments})
'''
ENTRY="""if __name__=='__main__':
    if (ROOT/'tests/fmig431/annual/verify_annual_successor.py').exists():
        sys.path.insert(0,str(ROOT/'tests/fmig431/annual'));import verify_annual_successor as annual
        result=annual.verify_qualification()
        if sys.argv[1:]==['--self-test']:
            annual.run_predecessor_controls()
        elif sys.argv[1:]:
            raise SystemExit('unknown annual successor owner option')
        print(json.dumps(result,indent=2))
    else:
        main()
"""
def run_predecessor_controls():
 # Keep the original six signed-owner assertions executable at their exact
 # admitted source; current annual evidence has already passed above.
 base=ROOT.parent/('annual-signed-controls-'+BASE[:12])
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'signed control source moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=base,text=True).strip(),'dirty signed control source')
 p=subprocess.run([sys.executable,'-B',PREDECESSOR,'--self-test'],cwd=base,capture_output=True,text=True)
 check(p.returncode==0 and 'MC_DRAIN01_EVIDENCE_CORRUPTION_CONTROLS=6'in p.stdout,'original signed controls failed')
 print(p.stdout,end='')
def verify_source(git_reader=None):
 if (ROOT/'tests/fmig431/verify_multilevel_divdra_successor.py').exists():
  sys.path.insert(0,str(ROOT/'tests/fmig431'));import verify_multilevel_divdra_successor as drain
  return drain.verify_source(git_reader)
 g=git if git_reader is None else git_reader;r=record()
 check(r['baseline']==BASE,'annual baseline drift');g('merge-base','--is-ancestor',BASE,'HEAD')
 dirty=g('status','--porcelain','--untracked-files=all','--',*SURFACE).splitlines()
 check(not [p for p in dirty if not re.fullmatch(r'\?\? .*/__pycache__/[^/]+\.pyc',p)],'dirty annual science')
 rows={s.split('\t')[1]:s.split('\t')[0]for s in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign annual source delta')
 check({p for p in rows if p.startswith('src/')}==PRODUCTION,'annual production scope changed')
 for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'annual postimage '+p)
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'annual reference mutation')
 current=(ROOT/MOVING).read_text();check(current.count(OPTION)==1 and current.count(CASE)==1,'annual moving recipe missing')
 check(current.replace(OPTION,'',1).replace(CASE,'',1)==subprocess.check_output(['git','show',BASE+':'+MOVING],cwd=ROOT,text=True),'unreviewed moving numerical body change')
 pred=(ROOT/PREDECESSOR).read_text()
 for f,args in [('verify_source','git_reader'),('verify_qualification','')]:
  d=delegation(f,args);check(pred.count(d)==1,'annual predecessor delegation drift');pred=pred.replace(d,'',1)
 check(pred.count(ENTRY)==1,'annual predecessor entry drift')
 pred=pred.replace(ENTRY,"if __name__=='__main__':main()\n",1)
 check(pred==subprocess.check_output(['git','show',BASE+':'+PREDECESSOR],cwd=ROOT,text=True),'predecessor science/evidence guard altered')
 check(g('rev-parse','HEAD:src')==r['source_tree'],'annual source tree drift')
 return {'baseline':BASE,'source_tree':r['source_tree'],'current_source_tree':r['source_tree'],'classic_annual_successor':True,'qualified':False,'admitted':False}
def capsule():
 e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes());check(sha(raw)==e['decoded_sha256'],'annual capsule corrupted')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(len(ms)==len({m.name for m in ms})==e['members'],'annual member set')
  check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe annual archive')
  d={m.name:a.extractfile(m).read()for m in ms}
 manifest=json.loads(d.pop('MANIFEST.json'));check(set(d)==set(manifest),'incomplete annual manifest')
 for p,h in manifest.items():check(sha(d[p])==h,'annual member corruption '+p)
 return d
def validate(data,check_inputs=True):
 j=lambda p:json.loads(data[p])
 s=j('source/result.json');check(s['living_source_probe_pass']and s['O0_O2_stdout_identity'],'annual source not complete')
 check(s['source_member_sha256']=='3f7daf222835c9b4b395feaa665614e8aef88a03125cdec9e0776ca793c6271b','foreign B111 source')
 check(s['source_functions_sha256']=='b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527','foreign AFGEN')
 check(s['source_state_completeness']['mapping_complete_for_tested_trajectories'],'missing mortality mapping')
 check({r['optimization']for r in s['runs']}=={0,2}and len(s['runs'])==2,'missing optimization')
 for r in s['runs']:
  check(r['compile_exit']==0 and r['native_exit']==0,'failed annual compile/native')
  check(all(math.isfinite(r[k])and r[k]>=0 for k in ['compile_link_seconds','native_seconds']),'invalid annual costs')
  out=data[f"source/o{r['optimization']}/native.stdout"]
  check(sha(out)==r['stdout_sha256']and out.count(b'SOURCE_DEAD_ORGANS')==3,'missing source trajectories/raw')
  check(b'CLASSIC_COMPLETE_ORGAN_OPAQUE_AND_EXISTING_DISK_CODEC_CONTINUATION=PASS'in out,'source restart absent')
 for p,h in j('compiled-inputs.json').items():
  if check_inputs:check(sha((ROOT/p).read_bytes())==h,'stale annual compiled input '+p)
 for name,marker in [('owners',b'F_WOF_PP03_FWO38_FWO39_CURRENT_CONTRACT_PRESERVATION_GATE PASS'),('restart',b'FWOF40_TRUE_PROCESS_RESTART_QUALIFICATION_GATE PASS'),('wof81',b'F_WOF_PP02_CASE001_FULLSEASON_GATE PASS'),('weather',b'CROP_FILE_WEATHER_HYDRAULIC_CONTINUOUS_RESTORED_O0_O2=PASS')]:
  r=j(name+'/result.json');check(r['exit']==0 and math.isfinite(r['seconds'])and r['seconds']>=0,'failed '+name)
  check(marker in data[name+'/stdout'],'incomplete '+name+' raw assertions')
 for opt in [0,2]:
  c=j(f'codec-o{opt}/result.json');check(c['all_pass']and len(c['controls'])==7,'missing codec controls')
  check(all(r['pass']and r['exit']==0 for r in c['controls']),'failed codec control')
  check(data[f'restart/o{opt}/reference.artifact']==data[f'restart/o{opt}/restarted_end.artifact'],'fresh restart endpoint differs')
  check(b'codec 2\n'in data[f'restart/o{opt}/reference.artifact'],'mortality codec not active')
  for moisture in ['neutral','dry','hydraulic']:
   check(data[f'weather/o{opt}/{moisture}-continuous.txt']==data[f'weather/o{opt}/{moisture}-restart.txt'],'actual weather restart differs')
   for mode in ['continuous','restart']:check(b'CROP_FILE_WEATHER_PRODUCTION=PASS'in data[f'weather/o{opt}/{moisture}-{mode}.txt'],'missing actual weather native assertions')
 for moisture in ['neutral','dry','hydraulic']:
  check(data[f'weather/o0/{moisture}-restart.txt']==data[f'weather/o2/{moisture}-restart.txt'],'weather optimization differs')
 z=j('zero/result.json');check(z['zero_counter_codec1_bytes_identical']and len(z['runs'])==4,'legacy codec identity missing')
 check(all(r['compile_exit']==0 and r['native_exit']==0 for r in z['runs']),'zero compatibility run failed')
 check(data['zero/o0-baseline/zero.restart']==data['zero/o0-current/zero.restart']==data['zero/o2-current/zero.restart'],'legacy bytes differ')
 old=j('incumbent/qualification.stdout');check(j('incumbent/result.json')['exit']==0 and old['qualified']and old['reproductive_successor'],'actual admitted predecessor rejected')
 return old
def verify_qualification():
 if (ROOT/'tests/fmig431/verify_multilevel_divdra_successor.py').exists():
  sys.path.insert(0,str(ROOT/'tests/fmig431'));import verify_multilevel_divdra_successor as drain
  return drain.verify_qualification()
 s=verify_source();r=record();check(r['stage']in ['QUALIFIED_ADMISSION_PENDING','CANONICALLY_ADMITTED'],'annual not ready')
 old=validate(capsule())
 return {**{k:v for k,v in old.items()if isinstance(v,bool)},**s,'qualified':True,'scope':'Classic B1.11 IDSL0/SWCROPSNM0 actual-crop source, gross mortality and FMR accepted-event/restart; existing typed valid domain. No Soil-N, automatic sowing/rotation or new numerical policy.','full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS','highest_low_air':'NOT_SELECTED_UNCHANGED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if '--source-only'in sys.argv else verify_qualification(),indent=2))
