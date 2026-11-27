"""Independent immutable audit: normal process exit is not finite science."""
from pathlib import Path
from contextlib import ExitStack
import argparse,hashlib,json,math,re,struct,subprocess,sys
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from explicit_bottom9_archive_science import ReadView

R=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(R/'tests/nomacro_scheduled_subsurface'))
from original_output_files import records
M='bd9b3b2e74e93fccb8bbcc8b06822efcd740f349'
SHA=lambda b:hashlib.sha256(b).hexdigest()
CASES=['original-model3-snow9-control-stack64-v1','gardner-snow-paired9-explicit-water','gardner-mixed2-1-snow-paired9-explicit-cde']


def audit(revision):
 with ExitStack() as stack:
  data=GitArchiveSource(R,revision);olddata=GitArchiveSource(R,M)
  store=Archive(data,'CLOSED_REFERENCE_STATE17_ORIGINAL_CSV_AND_FULL_CAUSAL_RAW_V1',stack)
  assert store.record['sha256']=='0f77f87d43a95720a034a02e70a1e4287c874a224a23ee07537b09a8becc9b7d'
  original=Archive(olddata,'CLOSED_GARDNER_STATE12_REPAIRED_LOCAL_AND_POSTIMAGES_RAW_V1',stack)
  failures=Archive(olddata,'CLOSED_GARDNER_STATE12_FIRST_LOCAL_SUCCESSES_FAILURES_RAW_V1',stack)
  sdk=Archive(olddata,'CLOSED_DEFAULT_CALENDAR_STATE14_ORIGINAL_MIXED_J_SDK_RAW_V5',stack)
  refs=json.loads(store.get('inherited-input-member-references.json'));assert len(refs)==261
  for n,v in refs.items():
   assert v['git_source']==M and v['archive_sha256']==original.record['sha256'] and n not in store.names
   raw=original.get(v['member']);assert len(raw)==v['bytes'] and SHA(raw)==v['sha256']
  prepared=json.loads(sdk.get('original-PREPARED.json'))
  assert SHA(sdk.get('original-PREPARED.json'))=='a2f529bc5d69c9e15bdda4c7aeb643a48685b50e10c2c1fce9eb639faf8a2da5'
  for n,d in prepared['provider_files'].items():
   if n.startswith('build/'):assert SHA(sdk.get('original-provider-build/'+n[len('build/'):]))==d
  original_csv=sdk.get('original-provider-build/swap-selected/swap_csv_output.f90')
  anchor=b'      else if (swcsv == 3) then ! binary\r\n         ! datetime'
  corrected=original_csv.replace(anchor,anchor.replace(b'         ! datetime',b'         allocate(buffer(parlen-1))\r\n         ! datetime'))
  assert original_csv.count(anchor)==1 and SHA(corrected.replace(b'\r\n',b'\n'))=='94a50f29f199a441942ed8c719b77480e4fcab3d0886c3021fab764f1d51a3bb'
  zero=json.loads(store.get('observations/closure17-reference-accepted-v1/zero-day-RESULT.json'))
  full=json.loads(store.get('observations/closure17-reference-accepted-v1/full-period-RESULT.json'))
  assert zero['status']=='SIX_EXACT_EXISTING_BINARY_COMPONENT_ZERO_DAY_LIFECYCLE_CONTROLS_PASS'
  assert len(zero['observations'])==len(full['observations'])==6 and zero['compiler_executions']==2 and full['compiler_executions']==full['link_executions']==0
  for v in zero['observations']:
   prefix='observations/closure17-reference-accepted-v1/zero-day-'+v['optimization']+'-'+v['case']
   assert v['returncode']==0 and not v['censored'] and b'REFERENCE_BINARY_LIFECYCLE_ZERO_DYNAMIC_DAYS_COMPLETE' in store.get(prefix+'/stdout.txt')
   first=store.get(prefix+'/first-output.bin');second=store.get(prefix+'/second-output.bin');length=19+4*(struct.unpack_from('<4i',second,400)[3]-1)
   assert len(first)-len(second)==length and first[-2*length:]==second[-2*length:] and second[-2*length:-length]==second[-length:]
  for opt in ['O0','O2']:
   prefix='builds/closure17-reference-accepted-'+opt+'-v1/'
   assert store.get(prefix+'swap_csv_output.f90')==corrected
   for n,d in next(v for v in zero['builds'] if v['optimization']==opt)['build_files'].items():assert SHA(store.get(prefix+n))==d
   links=[v for v in zero['commands'] if v['kind']=='link' and v['command'][2].endswith(opt+'-v1\\full-period.exe')]
   assert len(links)==1
   names=[Path(n).name for n in links[0]['command'] if n.endswith('.o')]
   sdkobjects=[Path(n).name for n in sdk.names if n.startswith('original-provider-build/swap-obj/') and n.endswith('.o')]
   assert sorted(names)==sorted(sdkobjects) and len(names)==63 and 'swap_main.o' in names
  baseline=json.loads(store.get('observations/closure17-reference-csv-lifecycle-v3/RESULT.json'))
  assert len(baseline['observations'])==12
  for v in baseline['observations']:
   if v['mode']=='original':
    assert v['returncode']==3 and not v['task1_completed'] and not v['lifecycle_completed']
    root=Path(v['actual_observation_root']);assert b'SIGSEGV' in store.get('observations/'+root.parent.name+'/'+root.name+'/stderr.txt')
  results=[];by_case={}
  for v in full['observations']:
   case=v['case'];opt=v['optimization'];prefix='observations/closure17-reference-accepted-v1/full-period-'+opt+'-'+case
   assert v['returncode']==100 and not v['censored'] and v['original_normal_completion_marker']
   assert SHA(store.get('builds/closure17-reference-accepted-'+opt+'-v1/full-period.exe'))==v['executable_sha256']
   for n,d in v['input_inventory'].items():assert refs[prefix+'/'+n]['sha256']==d
   root=ReadView(store,prefix);raw=(root/'result_output.bin').read_bytes();rows=records(root/'result_output.bin')
   columns=(len(rows[0])-19)//4;labels_at=raw.find(b'DATE                    ')
   if labels_at<0:labels_at=raw.find(b'DATETIME                ')
   labels=[raw[labels_at+24*i:labels_at+24*(i+1)].decode('ascii').strip() for i in range(columns+1)]
   bad=[]
   for i,row in enumerate(rows):
    fields=[labels[j+1] for j,x in enumerate(struct.unpack('<'+'f'*columns,row[19:])) if not math.isfinite(x)]
    if fields:bad.append(dict(original_record_index=i,original_date=row[:19].decode('ascii'),original_nonfinite_fields=fields))
   bal=(root/'result.bal').read_bytes();blc=(root/'result.blc').read_bytes()
   if case==CASES[0]:assert len(rows)==36 and not bad and not re.search(rb'(?i)\bnan\b',bal+blc)
   else:
    assert bad and re.search(rb'(?i)\bnan\b',bal) and re.search(rb'(?i)\bnan\b',blc)
    if case==CASES[1]:assert len(rows)==36 and len(bad)==29 and bad[0]['original_date'].strip()=='2002-01-07' and 'PD_VOL' in bad[0]['original_nonfinite_fields']
    else:assert len(rows)==2 and len(bad)==1
    oldprefix='actual/closure12-feedback-v1/finite-'+opt+'-v1/'+case+'/'
    old=json.loads(failures.get(oldprefix+'RESULT.json'));assert old['status']=='FAILED_ACTUAL_CLOSED_GARDNER_FEEDBACK_NOT_QUALIFIED' and old['actual_source']=='3be78ad24d2bce348f38a26e289af0f4846c5883'
    assert dict(old['input_inventory'])==v['input_inventory']
    assert b'ERROR STOP Nonfinite original implicit pond availability' in failures.get(oldprefix+'trajectory/original/donor.stderr')
   if case in by_case:assert by_case[case]==rows
   else:by_case[case]=rows
   results.append(dict(case=case,output_compiler_profile_only=opt,original_physical_SDK_profile='MIXED_UNCHANGED',records=len(rows),first_original_date=rows[0][:19].decode('ascii'),last_original_date=rows[-1][:19].decode('ascii'),nonfinite_records=bad,actual_binary_sha256=SHA(raw),actual_BAL_sha256=SHA(bal),actual_BLC_sha256=SHA(blc),finite_original_control=case==CASES[0],new_scientific_qualification=False))
  return dict(status='ORIGINAL_MIXED_SDK_GARDNER_SNOW_NONFINITE_REPRODUCED_WITH_VALID_MODEL3_CONTROLS',actual_archive_reader=revision,actual_canonical=M,raw_sha256=store.record['sha256'],classification='LEGACY_DEFECT',classification_scope='Only two exact original-reader-accepted dry Gardner/Snow paired9 input sets and unchanged mixed original physical SDK; no blanket exclusion of Gardner or Snow.',original_CSV_crash_is_separate_known_output_lifetime_defect=True,existing_output_correction='NOMACRO-BINARY-OUTPUT-01',original_physical_objects_unchanged=62,full_original_main_object_retained=True,output_O0_O2_profiles_are_not_two_independent_physical_builds=True,source_level_first_invalid_operation='UNKNOWN',intended_physical_resolution='SCIENTIFIC_DECISION_PENDING_SOURCE_CAUSAL_ANALYSIS',current_failures_relabelled_as_PASS=False,original_period_normal_completion_not_scientific_PASS=True,new_scientific_contexts_admitted=0,unchanged_prior_periods_replayed=False,observations=results,global_functional_completion='PARTIAL',global_scientific_equivalence='NOT_QUALIFIED',global_counts='UNKNOWN',RC3_changed=False,compiler_executions=0,model_executions=0)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--revision',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit(a.revision)
 with a.output.open('x',encoding='utf8') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],len(q['observations']),flush=True)
