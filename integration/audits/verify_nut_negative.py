"""Finite-donor source/physics/restart admission; frozen incumbent stays immutable."""
from pathlib import Path
import base64,csv,hashlib,io,json,math,re,runpy,struct,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='437d96ff51ac8a5825b605caf788661848c88be5'
CONCURRENT='fb00736e320498f2e610b0671af9c7dc5a381921'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
KEY='negative_reference_candidate_20261021'
SCIENCE=['src','tests','tools','reference','.github','app','examples','integration/audits','integration/performance/authority.py']
PRODUCTION={
 'src/process/mod_b111_soil_n_transport.f90','src/process/mod_b111_soil_n_mineral_owner.f90',
 'src/process/mod_b111_soil_n_reactive_owner.f90','src/process/mod_b111_soil_n_daily_exchange.f90',
 'src/crop/mod_crop_soil_n_day.f90','src/runtime/mod_fmr_crop_soil_n_joint_application.f90'}
OWNED=PRODUCTION|{
 'tests/nut-mineral/test_negative_boundary.f90','tests/nut-reactive/test_finite_donor_invalid.f90',
 'tests/nut-crop/negative_joint.inc','integration/audits/run_nut_negative.py',
 'integration/audits/resume_nut_retained.py','integration/audits/resume_nut_hist.py','integration/audits/package_nut_negative.py',
 'integration/audits/verify_nut_negative.py','integration/performance/authority.py'}|{
 'reference/swap-4.3.1/patches/SWAP-020/'+n for n in ['CONTRACT.md','apply.py','negative_boundary.f90','test_negative.f90','run.py']}
sha=lambda b:hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())[KEY]
def hook(name):
 return ("    finite=json.loads((ROOT/'"+STATUS+"').read_text()).get('"+KEY+"',{})\n"
         "    if 'evidence' in finite:\n"
         "        return runpy.run_path(str(ROOT/'integration/audits/verify_nut_negative.py'),run_name='finite_donor_"+name+"')['"+name+"']()\n")
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if 'evidence' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text()).get('swp_reader_successor', {}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_reader.py'))['source'](reader,changed)
 s=record();require(s['baseline']==BASE,'finite donor baseline')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty finite donor science')
 if changed is None:changed={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 git('merge-base','--is-ancestor',CONCURRENT,'HEAD')
 concurrent={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,CONCURRENT,'--',*SCIENCE).splitlines()}
 require(not(OWNED&concurrent.keys()),'concurrent owner overlap')
 for p,v in concurrent.items():
  require(changed.get(p)==v and reader(p)==subprocess.check_output(['git','show',CONCURRENT+':'+p],cwd=ROOT),'concurrent postimage drift '+p)
 changed={p:v for p,v in changed.items()if p not in concurrent}
 if 'evidence'in s:
  index=ROOT/s['evidence']['index'];idx=json.loads(index.read_text())
  allowed={str(index.relative_to(ROOT)),*[str((index.parent/p).relative_to(ROOT))for p in idx['parts']]}
  require(all(changed.get(p)=='A'for p in allowed),'evidence additions not exact')
  changed={p:v for p,v in changed.items()if p not in allowed}
 require(set(s['postimages'])==OWNED,'finite donor owning file set')
 require(changed=={p:v['status']for p,v in s['postimages'].items()},'foreign finite donor delta')
 for p,v in s['postimages'].items():require(sha(reader(p))==v['sha256'],'finite donor source drift '+p)
 require({p for p in changed if p.startswith('src/')}==PRODUCTION,'foreign production owner')
 p='integration/performance/authority.py'
 original=subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT,text=True)
 expected=original.replace('def verify_qualification():\n','def verify_qualification():\n'+hook('verify_qualification'),1)
 expected=expected.replace('def self_test():\n','def self_test():\n'+hook('self_test'),1)
 fsi=("    finite=json.loads((ROOT/'"+STATUS+"').read_text()).get('"+KEY+"',{})\n"
      "    if 'evidence' in finite:\n"
      "        runpy.run_path(str(ROOT/'integration/audits/verify_nut_negative.py'),run_name='finite_donor_fsi35')['source']()\n"
      "        path='src/legacy/b1_10_port/headcalc.f90'\n"
      "        return {path: {'historical_blob': '7ff36cbadf8acfaa09e129ff54aa54a933c3f1ac', 'canonical_blob': git('rev-parse','HEAD:'+path)}}\n")
 expected=expected.replace('def fsi35_successors():\n','def fsi35_successors():\n'+fsi,1)
 require(reader(p).decode()==expected,'changed incumbent authority handoff')
 return s
def capsule():
 e=record()['evidence'];path=ROOT/e['index'];idx=json.loads(path.read_text())
 raw=base64.b64decode(b''.join((path.parent/p).read_bytes()for p in idx['parts']),validate=True)
 require(sha(raw)==e['sha256']==idx['decoded_sha256'],'finite donor capsule identity')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  mm=a.getmembers();require(all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in mm),'unsafe evidence')
  require(len(mm)==len({m.name for m in mm}),'duplicate evidence')
  f={m.name:a.extractfile(m).read()for m in mm}
 manifest=f.pop('MEMBERS.json');require(sha(manifest)==idx['members_sha256'],'member manifest')
 inventory=json.loads(manifest);require(f.keys()==inventory.keys()and len(f)==idx['members'],'member inventory')
 require(all(sha(f[p])==h for p,h in inventory.items()),'member bytes changed')
 return f
def jsonfile(f,p):return json.loads(f[p])
def budgets(values):
 v=values
 nh4=v['nh4_old']+v['nh4_sources']+v['nh4_top_actual']+v['mineralisation']-v['nh4_uptake']-v['nh4_out']-v['nitrification']-v['nh4_end']
 no3=v['no3_old']+v['no3_sources']+v['no3_top_actual']+v['nitrification']-v['no3_uptake']-v['no3_out']-v['denitrification']-v['no3_end']
 org=v['organic_old']+v['organic_sources']-v['mineralisation']-v['organic_end']
 initial=sum(v[k+'_old']for k in ['nh4','no3','organic']);final=sum(v[k+'_end']for k in ['nh4','no3','organic'])
 incoming=sum(v[k+'_sources']for k in ['nh4','no3','organic'])+sum(max(0.,v[k+'_top_actual'])for k in ['nh4','no3'])
 outgoing=sum(v[k]for k in ['nh4_out','no3_out','denitrification','volatilisation'])+sum(max(0.,-v[k+'_top_actual'])for k in ['nh4','no3'])
 residual=initial+incoming-outgoing-final
 require(max(abs(nh4),abs(no3),abs(org),abs(residual))<=1e-10,'reference form/whole nitrogen imbalance')
 require(abs(nh4+no3+org-residual+v['nh4_uptake']+v['no3_uptake'])<=1e-12,'internal N transformations not cancelling')
 require(min(v[k+'_end']for k in ['nh4','no3','organic'])>=0,'negative reference inventory')
 for form in ['nh4','no3']:
  require(v[form+'_top_actual']>=v[form+'_top_requested']-1e-14 and v[form+'_unmet']>=0,'unbounded boundary extraction')
  require(abs(v[form+'_top_actual']-v[form+'_top_requested']-v[form+'_unmet'])<=1e-13,'requested/actual/unmet mismatch')
 return residual,abs(residual)/max(initial+incoming,outgoing+final,1e-30)
def validate(f,reader=lambda p:(ROOT/p).read_bytes()):
 g=runpy.run_path(str(ROOT/'tests/nut-crop/verify_historical_gross.py'),run_name='finite_helpers')
 r=jsonfile(f,'reference/result.json');p=jsonfile(f,'production/result.json');q=jsonfile(f,'retained/result.json')
 for report in [r,p,q]:g['inputs'](report,reader)
 require(r['native_models']==14 and r['native_N_steps']==120,'missing actual complete corrected-reference models')
 require(p['status']=='FINITE_DONOR_PRODUCTION_LOCAL_PASS_NOT_ADMITTED','current production incomplete')
 require(q['status']=='B112_RETAINED_JOINT_PHYSICAL_PASS_NOT_ADMITTED'and q['b112_retained']['O0']==q['b112_retained']['O2'],'retained owner incomplete')
 require(p['direct']['O0']==p['direct']['O2']and'OWNER_ATOMIC_OPAQUE=PASS'in p['direct']['O0'],'direct corrected comparison')
 require(r['valid_direct_cases']==80 and r['direct_cases']==84,'reference coefficient/stock matrix')
 require(r['direct_max_abs_residual']<=1e-12 and r['direct_max_oracle_error']<2e-11,'independent numerical reference')
 refmod=runpy.run_path(str(ROOT/'reference/swap-4.3.1/patches/SWAP-020/apply.py'))
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(reader('integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'))))as a:
  raw={Path(n).name:a.extractfile(n).read()for n in a.getnames()if n.endswith('.f90')}
 require(len(raw)==63,'original full source closure')
 corrected=refmod['transform'](raw)
 for n,b in raw.items():
  require(f['reference/original/'+n]==b,'original source changed '+n)
  require(f['reference/corrected/'+n]==corrected[n],'reference source transform '+n)
 ev=jsonfile(f,'reference/events.json');require(sum(e['category']=='corrected_native'for e in ev)==14,'reference native matrix')
 require(all(e['returncode']==(100 if e['category']=='corrected_native'else 0)for e in ev),'reference build/native failure')
 for e in ev:
  for stream in ['stdout','stderr']:require(sha(f['reference/'+e[stream]])==e[stream+'_sha256'],'reference raw event changed')
 sys.path.insert(0,str(ROOT/'tools/vq'))
 from b0_source_runner import SWAP_ORDER,select_dec_branches
 rr=jsonfile(f,'reference/RUNS.json');max_abs=max_rel=0.;unmet=0.
 old=runpy.run_path(str(ROOT/'integration/audits/verify_nut_original_full.py'))
 prior=old['helper']()['capsule'](old['record']()['evidence'])
 for opt in ['O0','O2']:
  prefix='reference/build-'+opt+'/'
  for n in SWAP_ORDER:require(f[prefix+'selected/'+n]==select_dec_branches(corrected[n].decode('cp1252')).encode('cp1252'),'selected complete reference member '+n)
  links=[e['command']for e in ev if e['category']=='main_link'and '/build-'+opt+'/'in' '.join(e['command'])]
  require(len(links)==1,'reference complete-main link')
  require(sorted(Path(o).name for o in links[0]if o.endswith('.o'))==sorted(Path(n).stem+'.o'for n in SWAP_ORDER),'reference missing provider or linked stub')
  for name in old['NAMES']+['fallow-both-low','fallow-both-high']:
   prefix='reference/'+opt+'/'+name+'/'
   require(b'simulation succesfully terminated'in f[prefix+'swap.ok'],'original completion marker')
   if prefix+'swap.err'in f:require(not f[prefix+'swap.err'].strip(),'original model error')
   for filename,h in rr[opt+'/'+name]['input_sha256'].items():require(sha(f[prefix+filename])==h,'original case input drift')
   origin=name if name in old['NAMES']else'fallow-no-denitr'
   require(old['csvbody'](f[prefix+'result_output.csv'])==old['csvbody'](prior['actual/'+opt+'/'+origin+'/result_output.csv']),'corrected reference hydraulic drift')
   if name=='original-control-prefix':continue
   rows=list(csv.reader(io.StringIO(f[prefix+'bounded_n_book.csv'].decode())))
   require(len(rows)==10,'missing unrounded actual reference N steps')
   for row in rows:
    v=dict(zip(refmod['FIELDS'],map(float,row[1:])));require(len(v)==25 and all(math.isfinite(x)for x in v.values()),'invalid unrounded N book')
    absres,relres=budgets(v);max_abs=max(max_abs,abs(absres));max_rel=max(max_rel,relres);unmet+=v['nh4_unmet']+v['no3_unmet']
   require(f[prefix+'bounded_n_book.csv']==f['reference/O0/'+name+'/bounded_n_book.csv'],'reference O0/O2 nitrogen drift')
 require(unmet>0,'reference donor exhaustion not exercised')
 for prefix in ['physical','retained']:
  report=jsonfile(f,('production/'if prefix=='physical'else'')+prefix+'/result.json')
  g['inputs'](report,reader)
  g['executions'](f,('production/'if prefix=='physical'else'')+prefix,jsonfile(f,('production/'if prefix=='physical'else'')+prefix+'/events.json'))
 objects=g['executions'](f,'production/physical',jsonfile(f,'production/physical/events.json'))
 objects=set(objects);linked=set();pe=jsonfile(f,'production/events.json')
 require(sum(e['category']=='joint_native'for e in pe)==4 and sum(e['category']=='restart_native'for e in pe)==8,'new current native inventory')
 require(sum(e['category']=='invalid_native'for e in pe)==2,'missing nonfinite forcing tests')
 for e in pe:
  c=e['command'];require(e['returncode']==0,'current finite-donor native/build failure')
  for stream in ['stdout','stderr']:require(sha(f['production/'+e[stream]])==e[stream+'_sha256'],'current raw event drift')
  if e['category']=='incumbent_physical':
   require(c[-1].endswith('/tests/nut-crop/run_hist_complete.py'),'wrong incumbent scientific runner');continue
  if '-c'in c:
   require(('-O0'in c or'-O2'in c)and'-fcheck=all'in c and'-ffpe-trap=invalid,zero,overflow'in c,'current unchecked compilation')
   objects.add(c[c.index('-o')+1])
  elif '-o'in c:
   require(all(o in objects for o in c if o.endswith('.o')),'current link has unqualified object')
   linked.add(c[c.index('-o')+1])
  else:require(c[0]in linked,'current native lacks its checked executable')
 physical=jsonfile(f,'production/physical/result.json');require(physical['results']['O0']==physical['results']['O2'],'incumbent optimization drift')
 ga=runpy.run_path(str(ROOT/'integration/audits/verify_nut_gash_successor.py'))
 frozen=g['capsule'](ga['record']()['evidence'])
 for opt in ['O0','O2']:
  for name in ['default',*physical['results'][opt]['endpoint']]:
   end=f['production/physical/'+opt+'/'+name+'.endpoint']
   require(end==frozen['physical/'+opt+'/'+name+'.endpoint'],'incumbent physical endpoint changed '+name)
  for name in ['negative-low','negative-high']:
   root='production/joint-'+opt+'/';end=f[root+name+'.endpoint'];ledger=f[root+name+'.endpoint.ledger']
   require(len(ledger)==120,'missing cumulative boundary/process journal')
   vv=struct.unpack('15d',ledger);require(vv[3]==0 and sum(vv[11:13])>0,'fallow uptake or no exhaustion')
   require(abs(sum(vv[9:11])-sum(vv[7:9])-sum(vv[11:13]))<=1e-12,'cumulative requested/actual/unmet')
   for day in [1,6]:
    require(end==f[root+name+'.fresh-'+str(day)]and ledger==f[root+name+'.fresh-'+str(day)+'.ledger'],'fresh-process state/flux continuation mismatch')
   for day in [3,7]:
    before=f[root+name+'.restart.before-'+str(day)]
    require(before==f[root+name+'.restart.water-reject-'+str(day)]==f[root+name+'.restart.chemical-reject-'+str(day)],'joint rejection published candidate')
   require(end==f['production/joint-O0/'+name+'.endpoint']and ledger==f['production/joint-O0/'+name+'.endpoint.ledger'],'production physical O0/O2 drift')
   text=p['joint'][opt+'/'+name]['stdout'];lines=[l.split()for l in text.splitlines()if l.strip().startswith('NEGATIVE_DAY')]
   current=[e for e in pe if e['category']=='joint_native'and'/joint-'+opt+'/'in e['command'][0]and e['command'][-1]==name]
   require(len(current)==1 and f['production/'+current[0]['stdout']].decode()==text,'current case/raw stdout mismatch')
   require(len(lines)==12 and'FINITE_DONOR_ACTUAL_RICHARDS_RETIRED_CROP_N_RESTART=PASS'in text,'actual current coupled daily model missing')
   for row in lines:
    vals=list(map(float,row[2:]));before,external_in,external_out,final,residual=vals[:5]
    require(abs(before+external_in-external_out-final-residual)<=1e-13 and abs(residual)<=1e-12,'joint daily whole nitrogen')
    require(int(vals[-1])>0,'no accepted Richards substeps')
   budget=list(map(float,next(l for l in text.splitlines()if l.strip().startswith('NEGATIVE_BUDGET')).split()[1:]))
   require(abs(budget[0]+budget[1]-budget[2]-budget[3])<=1e-10 and abs(budget[4])<=1e-10,'joint cumulative N balance')
 predecessor=jsonfile(f,'preservation/PREDECESSOR.json')
 require(predecessor['baseline']==BASE and predecessor['returncode']==0 and predecessor['owner']['qualified'],'predecessor not qualified')
 perf=runpy.run_path(str(ROOT/'integration/performance/verify_proposal.py'));pf=perf['capsule']()
 for path in ['build-O0/build-complete.json','build-O2/build-complete.json','composition/thermal/0.5/physical/result.json']:
  pp=json.loads(pf[path]);values=pp.get('input_sha256',pp.get('inputs',{}))
  require(values and not(PRODUCTION&values.keys()),'affected SOL/PERF scientific footprint')
  for path,h in values.items():
   if sha(reader(path))!=h:
    require(reader(path)==subprocess.check_output(['git','show',CONCURRENT+':'+path],cwd=ROOT),'unqualified concurrent provider '+path)
 # The complete current SOL application/refinement proof, not an old column
 # hash waiver, qualifies the concurrently changed file application/providers.
 sol=runpy.run_path(str(ROOT/'integration/audits/verify_pond_thermal.py'))
 sol_files=sol['capsule']()
 for path,raw in sol_files.items():
  if path.endswith('result.json')or path.endswith('build-complete.json'):
   report=json.loads(raw);values=report.get('inputs',report.get('input_sha256',{}))
   if isinstance(values,dict):require(not(PRODUCTION&values.keys()),'SOL execution consumes changed NUT provider')
 require(sol['validate'](sol_files,reader)['qualified'],'concurrent SOL qualification')
 require(g['unchanged_ci_closure']()==3,'changed integrated core-CI footprint')
 return dict(status='FINITE_DONOR_FALLOW_REFERENCE_AND_CURRENT_COUPLED_QUALIFIED',qualified=True,
     full_capability=False,full_migration_qualified=False,old_endpoints_exact=16,
     fresh_transition_processes=64,reference_native_models=14,reference_daily_N_steps=120,
     reference_max_abs_N_residual=max_abs,reference_max_relative_N_residual=max_rel,
     current_finite_donor_cases=4,current_fresh_restarts=8,retained_owner_pass=True,
     concurrent_sol_current_providers_qualified=True,predecessor_qualified=True,
     unchanged_core_ci_compile_footprints=3,concurrent_canonical=CONCURRENT,
     source_tree=git('rev-parse','HEAD:src'),full_fci='NOT_SELECTED_IMPACT_NUT_SEAM',
     highest_low_air='NOT_SELECTED_POLICY',mastercoverage_promotion=False)
def verify_qualification():
 if 'evidence' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text()).get('swp_reader_successor', {}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_reader.py'))['verify_qualification']()
 source();return validate(capsule())
def self_test():
 if 'evidence' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text()).get('swp_reader_successor', {}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_reader.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(name,broken=None,reader=lambda p:(ROOT/p).read_bytes()):
  try:validate(f if broken is None else broken,reader)
  except (ValueError,KeyError,IndexError,StopIteration):passed.append(name);return
  raise AssertionError('accepted corrupted finite-donor evidence '+name)
 for p in ['reference/corrected/management_soil.f90','reference/build-O2/selected/swap_main.f90',
           'reference/O0/fallow-low/bounded_n_book.csv','production/joint-O2/negative-high.fresh-6',
           'production/joint-O0/negative-low.endpoint.ledger','production/physical/O0/gash-profile.endpoint',
           'retained/result.json','preservation/PREDECESSOR.json']:
  broken=dict(f);broken.pop(p);reject('missing '+p,broken)
 for p in PRODUCTION:
  reject('changed '+p,reader=lambda q,p=p:(ROOT/q).read_bytes()+(b'!'if q==p else b''))
 broken=dict(f);key='reference/O0/fallow-low/bounded_n_book.csv';rows=broken[key].decode().splitlines();tokens=rows[1].split(',');tokens[2]='-1';rows[1]=','.join(tokens);broken[key]='\n'.join(rows).encode();reject('negative stock',broken)
 return dict(count=len(passed),negative_controls=passed)
if __name__=='__main__':print(json.dumps(self_test()if'--self-test'in sys.argv else verify_qualification(),indent=2))
