"""Audit and compare existing complete RC3/original431 laptop evidence; no models."""
import argparse,csv,hashlib,json,math,shutil,sys,time
from decimal import Decimal,getcontext
from pathlib import Path
getcontext().prec=50
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser(description=__doc__)
for name in ('release','qualification','prior','output'):p.add_argument('--'+name,type=Path,required=True)
a=p.parse_args();a.release=a.release.resolve();a.qualification=a.qualification.resolve();a.prior=a.prior.resolve();a.output=a.output.resolve();a.output.mkdir(exist_ok=False)
started=time.perf_counter();manifest=json.loads((a.release/'RELEASE_MANIFEST.json').read_text())
assert manifest['source_commit']=='2cedd9d0eaf8be8e8cdba321e3ab836835c558a3'
for n,h in manifest['files'].items():assert sha(a.release/n)==h,n
sys.path.insert(0,str(a.release/'app/hybrid_water'))
from user_prepare import validate
from daily_coupling import validate_bundle
import daily_host as h
old=a.prior/'comparison431';audit=json.loads((a.prior/'comparison431-audit.json').read_text());previous=json.loads((old/'COMPARISON.json').read_text())
assert previous['tolerances_changed'] is False and previous['physical_input_changed'] is False
original_provider=Path(audit['provider']);original_prepared=validate(original_provider);current_prepared=validate(a.qualification/'provider')
assert original_prepared==json.loads((old/'ORIGINAL_PROVIDER_PREPARED.json').read_text())
for key in ('source_archives','toolchain','floating_point_profile','preparation_sources','inputs'):assert original_prepared[key]==current_prepared[key],key
sources={f.name:sha(f) for f in (original_provider/'build/swap-selected').iterdir() if f.is_file()}
assert sources=={f.name:sha(f) for f in (a.qualification/'provider/build/swap-selected').iterdir() if f.is_file()}
assert sha(old/'swap431-common.exe')==sha(Path(audit['original_exe']))==audit['original_exe_sha256']
salt_reference=json.loads((old/'salt-reference-RESULT.json').read_text());assert salt_reference['original_executable_sha256']==audit['original_exe_sha256']
assert salt_reference['profile']==current_prepared['floating_point_profile'] and salt_reference['toolchain']==current_prepared['toolchain']
for n,digest in salt_reference['original_objects'].items():assert sha(original_provider/'build/swap-obj'/n)==digest,n
assert sha(original_provider/'build/ttutil-obj/libttutil.a')==salt_reference['current_build']['identity']['ttutil_library']
events=json.loads((old/'EVENTS.json').read_text());salt_events=json.loads((old/'salt-reference-EVENTS.json').read_text());current_events=json.loads((a.qualification/'EVENTS.json').read_text());current_profiles=json.loads((a.qualification/'PROFILES.json').read_text())
assert json.loads((a.qualification/'RESULT.json').read_text())['source']==manifest['source_commit']
report=dict(status='RC3_ORIGINAL431_IDENTICAL_INPUT_SAME_LAPTOP_COMPARISON_COMPLETE',source_commit=manifest['source_commit'],new_model_executions=0,tolerances_changed=False,physical_input_changed=False,original_literal_input_pass_claimed=False,scientific_equivalence='NOT_QUALIFIED; descriptive differences, no new acceptance threshold',timing_scope='Reused actual laptop measurements at different times; not randomized/paired/accuracy-matched performance qualification',output_preparation='Existing public INLIST_CSV/NUM_DECIMALS/SWENDTYPE preparation is identical in both executed decks; literal original S_CONC refusals remain preserved',profiles={})
proof=dict(original_executable_sha256=audit['original_exe_sha256'],original_selected_sources=sources,toolchain=current_prepared['toolchain'],floating_point_profile=current_prepared['floating_point_profile'],source_archives=current_prepared['source_archives'],original_provider_files=original_prepared['provider_files'],current_provider_files=current_prepared['provider_files'],object_identity_note='Providers validated separately. Compilation-path-bearing object bytes may differ; original executable remains bound to its preserved original source/object/library proof, not rebound as a new binary.')
def copy(source,target):
 target=a.output/target;target.parent.mkdir(exist_ok=True,parents=True);shutil.copyfile(source,target)
def read(path):
 text=path.read_text();lines=text.splitlines();units=next(s[2:] for s in lines if s.startswith('* (yyyy-mm-dd)')).split(',');rows=list(csv.DictReader(s for s in lines if s.strip() and not s.startswith('*')))
 assert len(units)==len(rows[0]);return rows,dict(zip(rows[0],units))
flows={'RAIN','IRRIG','RUNOFF','EIC','EPD','EPOT','EACT','TPOT','TACT','TREDDRY','TREDWET','TREDSOL','DRN','SSDI','BOT','S_RAIN','S_IRRIG','S_BOT','S_DRN','S_UPT'}
sentinels={Decimal('-999'),Decimal('-999.999')}
for name,project,last in [('grass',h.GRASSGROWTH,1827),('hupsel',h.HUPSEL,1096),('saltfarm',h.SALTFARM,1461)]:
 key='salt' if name=='saltfarm' else name;prior=previous['profiles'][key];bundle=a.qualification/(name+'-O2-candidate-build');full=a.qualification/(name+'-O2-candidate-full');meta,_=validate_bundle(bundle,a.qualification/'provider',project)
 event=next(e for e in (salt_events if name=='saltfarm' else events) if (e.get('label')=='original-model' and e.get('returncode')==100) or e.get('project')==name)
 original_case=Path(event['cwd']);assert event.get('returncode',event.get('exit_code'))==100 and (original_case/'swap.ok').exists()
 assert sha(Path(event['command'][0]))==audit['original_exe_sha256']
 inventory={n:sha(full/'original'/n) for n in meta['inputs']};assert inventory==prior['input_sha256']
 for n,digest in inventory.items():assert sha(original_case/n)==digest,n;copy(full/'original'/n,name+'/input/'+n)
 oldcsv=old/(name+'-original431/result_output.csv') if name!='saltfarm' else old/'salt-original431-reused.csv'
 assert sha(oldcsv)==prior['original_csv_sha256']==sha(original_case/'result_output.csv')
 currentcsv=full/'original/result_output.csv';left,units=read(oldcsv);right,current_units=read(currentcsv);assert units==current_units
 assert len(left)==len(right)==last+1 and list(left[0])==list(right[0]);assert [r['DATE'] for r in left]==[r['DATE'] for r in right]
 oldrc2,_=read(a.prior/(key+'-full/original/result_output.csv'));assert oldrc2==right
 journal=[json.loads(s) for s in (full/'daily.jsonl').read_text().splitlines()];assert [r['day'] for r in journal]==list(range(1,last+1))
 assert all(r['committed'] and abs(r['independent_residual_cm'])<=1e-10 and abs(r['kernel_residual_cm'])<=1e-10 and abs(r.get('solute_independent_residual_mg_cm2',0))<=1e-10 for r in journal)
 fields={}
 for column in left[0]:
  if column=='DATE':continue
  values=[];missing=[];both_missing=0
  for day,(x,y) in enumerate(zip(left[1:],right[1:]),1):
   u,v=Decimal(x[column]),Decimal(y[column]);assert u.is_finite() and v.is_finite()
   if (u in sentinels)!=(v in sentinels):missing.append(dict(day=day,date=x['DATE'],original=str(u),rc3=str(v)));continue
   if u in sentinels and v in sentinels:both_missing+=1;continue
   values.append((abs(v-u),day,x['DATE'],u,v))
  f=dict(unit=units[column],comparable_days=len(values),both_missing_days=both_missing,sentinel_mismatches=missing,initial_original=left[0][column],initial_rc3=right[0][column])
  if values:
   difference,day,date,u,v=max(values,key=lambda x:(x[0],x[1]));f.update(max_abs_difference=str(difference),worst_day=day,worst_date=date,original=str(u),rc3=str(v),rc3_minus_original=str(v-u),mean_abs_difference=str(sum(t[0] for t in values)/len(values)))
   if column in flows:f['period_signed_flux_difference']=str(sum(t[4]-t[3] for t in values))
   assert difference==Decimal(prior['fields'][column]['max_abs_difference']),column
  else:f.update(max_abs_difference=None,assessment='NOT_DEFINED_IN_BOTH_OUTPUTS')
  fields[column]=f
 wall=event.get('wall_seconds',event.get('seconds'));assert wall==prior['original_wall_seconds']
 public=next(e for e in current_events if e['label']==name+'-O2-full');profile=next(p for p in current_profiles if p['project']==name and p['opt']=='O2');assert public['returncode']==0
 controller=json.loads((full/'RESULT.json').read_text())['model_and_controller_seconds'];assert controller==profile['model_seconds']
 report['profiles'][name]=dict(days=last,original_results_reused=True,rc3_results_reused=True,execution_input_bytes_identical=True,input_sha256=inventory,rc3_printed_data_exact_to_RC2=True,original_csv_sha256=sha(oldcsv),rc3_csv_sha256=sha(currentcsv),rc3_journal_sha256=sha(full/'daily.jsonl'),rc3_build_sha256=sha(bundle/'BUILD.json'),original_wall_seconds=wall,rc3_public_wall_seconds=public['seconds'],rc3_model_controller_seconds=controller,observed_public_wall_ratio=public['seconds']/wall,observed_controller_to_original_wall_ratio=controller/wall,rc3_water_max_cm=max(abs(r['independent_residual_cm']) for r in journal),rc3_solute_max_mg_cm2=max(abs(r.get('solute_independent_residual_mg_cm2',0)) for r in journal),fields=fields)
 for src,dst in [(oldcsv,'original431.csv'),(currentcsv,'rc3.csv'),(bundle/'BUILD.json','BUILD.json'),(full/'RESULT.json','RC3_RESULT.json')]:copy(src,name+'/'+dst)
for src,dst in [(old/'COMPARISON.json','prior/COMPARISON.json'),(old/'EVENTS.json','prior/EVENTS.json'),(old/'salt-reference-RESULT.json','prior/salt-reference-RESULT.json'),(old/'salt-reference-EVENTS.json','prior/salt-reference-EVENTS.json'),(a.prior/'comparison431-audit.json','prior/AUDIT.json'),(old/'ORIGINAL_PROVIDER_PREPARED.json','prior/ORIGINAL_PROVIDER_PREPARED.json'),(a.qualification/'provider/PREPARED.json','RC3_PROVIDER_PREPARED.json'),(a.qualification/'EVENTS.json','RC3_EVENTS.json')]:copy(src,dst)
for name in ('grass','hupsel'):
 for ext in ('stdout','stderr'):copy(old/(name+'-original.'+ext),'prior/'+name+'-original.'+ext)
proof['verification_and_analysis_seconds']=time.perf_counter()-started
(a.output/'AUDIT.json').write_text(json.dumps(proof,indent=2));(a.output/'COMPARISON.json').write_text(json.dumps(report,indent=2))
(a.output/'FILES.json').write_text(json.dumps({p.relative_to(a.output).as_posix():sha(p) for p in sorted(a.output.rglob('*')) if p.is_file()},indent=2))
print(json.dumps({name:{k:r[k] for k in ('days','original_wall_seconds','rc3_public_wall_seconds','rc3_model_controller_seconds','observed_public_wall_ratio')} for name,r in report['profiles'].items()},indent=2));print('NO_NEW_MODEL_EXECUTIONS; ALL_REUSE_CONTRACTS_VERIFIED')
