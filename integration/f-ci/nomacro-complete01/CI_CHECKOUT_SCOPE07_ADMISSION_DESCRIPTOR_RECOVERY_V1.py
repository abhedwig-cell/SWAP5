"""Complete descriptors around the already immutable, fully verified raw archive."""
from pathlib import Path
import hashlib,json,shutil,subprocess,zipfile
E=Path(__file__).resolve().parent;R=Path('C:/Users/Veldh012/swap5-nomacro-scheduled-chemical01');P=R/'integration/f-ci/nomacro-complete01'
M='0b482de01847dd8ba5f93c63881b9aeff468d3e3';C='082f3d4b8e027d7aa8fcfbb9e3dde603aea85a66';B='df00f9393ac552b0a6cab8ee84f8b8d8c06ac26c';S='e2ad1538dae3fc1eefdfd9a5f4507043bdc0a9f3';A='debb72039c28e136012c1cfa6cda157d25eecaee';TREE='ca63abf1777deac78cc899fcef9f02eb5fa24cee'
SHA=lambda b:hashlib.sha256(b).hexdigest();git=lambda *a:subprocess.check_output(['git',*a],cwd=R).decode().strip();read=lambda n:json.loads((E/n).read_text())
assert git('rev-parse','HEAD')==M and not git('diff','--name-only','HEAD')
name='CI_CHECKOUT_SCOPE07_ADMISSION_RAW_V1';archive=(E/(name+'.zip')).read_bytes();assert archive==(P/(name+'.zip')).read_bytes()
partial=(P/(name+'.json')).read_bytes();assert partial.rstrip().endswith(b'"coadmission":')
partial_name='CI_CHECKOUT_SCOPE07_ADMISSION_DESCRIPTOR_PARTIAL_V1.json.txt'
for root in (E,P):
    with (root/partial_name).open('xb') as f:f.write(partial)
members={}
with zipfile.ZipFile(E/(name+'.zip')) as z:
    assert len(z.namelist())==len(set(z.namelist()))
    for member in z.namelist():
        raw=z.read(member);assert raw==(E/member).read_bytes(),member
        members[member]=dict(bytes=len(raw),sha256=SHA(raw))
for head in (C,S,M):assert git('rev-parse',head+'^{tree}')==TREE
for head in (S,M):
    raw=(E/('CI_CHECKOUT_SCOPE07_PR1806_GENUINE_GIT_OBJECT_'+head+'.bin')).read_bytes();assert raw==subprocess.check_output(['git','cat-file','commit',head],cwd=R)
    assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==head
    assert git('show','-s','--format=%P',head)==B+' '+C
api=read('CI_CHECKOUT_SCOPE07_PR1806_ACTUAL_GIT_API_V1.json');assert api['sha']==M and api['verification']['verified'] and api['verification']['reason']=='valid'
coadmission=json.loads((E/'CI_CHECKOUT_SCOPE07_CANDIDATE_PUBLIC_V5.stdout.txt').read_text())['coadmission']
assert (coadmission['contexts'],coadmission['short35_contexts'],coadmission['native_calendar_samples'],coadmission['exact_cold_windows'])==(648,602,4326,1864)
observations={};fixtures=None
for role,version,head in [('CANDIDATE','V5',C),('ACTUAL_MERGE','V1',M)]:
    for scope in ('PUBLIC','PUBLICATION'):
        stem=f'CI_CHECKOUT_SCOPE07_{role}_{scope}_{version}';q=read(stem+'.json');out=(E/(stem+'.stdout.txt')).read_bytes()
        assert q['returncode']==0 and q['error'] is None and q['before']==q['after']
        before=q['before'];assert before['head']==head and before['tree']==TREE and not before['status'] and len(before['sparse'])==14 and len(before['original_project_files'])==56
        assert not (E/(stem+'.stderr.txt')).read_bytes()
        if fixtures is None:fixtures=before['original_project_files']
        assert fixtures==before['original_project_files']
        if scope=='PUBLIC':assert json.loads(out)['coadmission']==coadmission
        else:assert b'PUBLICATION_REPLAY_SELECTED=false' in out and q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent']
        observations[stem]=q['seconds']
negative=read('CI_CHECKOUT_SCOPE07_FINAL2_NEGATIVES_V1.json');assert negative['candidate']==C and negative['status']=='FOUR_ACTUAL_COMMITTED_PUSHED_CLEAN14_PUBLIC_NEGATIVES_REFUSED'
assert len(negative['controls'])==4 and {q['role'] for q in negative['controls']}=={'SOURCE','RAW','INHERITED','PUBLICATION'}
for control in negative['controls']:
    assert control['actual_refusal'] and control['actual_one_file_delta'] and git('show','-s','--format=%P',control['head'])==C and git('diff','--name-only',C,control['head'])==control['path']
ci=read('CI_CHECKOUT_SCOPE07_PR1806_FINAL_ALL_CI_API_V2.json');runs=ci['runs']['workflow_runs'];checks=ci['checks']['check_runs']
assert ci['runs']['total_count']==len(runs)==len({x['workflow_id'] for x in runs})==16
assert all(x['head_sha']==C and x['status']=='completed' and x['conclusion']=='success' for x in runs)
assert ci['checks']['total_count']==len(checks)==48 and all(x['head_sha']==C and x['status']=='completed' and x['conclusion'] in ('success','skipped') for x in checks)
assert sum(x['conclusion']=='success' for x in checks)==30 and sum(x['conclusion']=='skipped' for x in checks)==18
for role in ('CO2','DVS','LRV','TIMEINT_STARTUP','TIMEINT_INVERSE','FCI_MODULAR'):
    log=f'CI_CHECKOUT_SCOPE07_PR1806_{role}_ORIGINAL_CI_V2.log';raw=(E/log).read_bytes();q=read(log+'.json');assert len(raw)==q['bytes'] and SHA(raw)==q['sha256'] and q['actual_source']==C and C.encode() in raw and S.encode() in raw
selection=read('CI_CHECKOUT_SCOPE07_MCSOL_UNCHANGED_DEPENDENCY_SELECTION_V2.json');assert selection['actual_current_head']==C and selection['actual_parent']==B and selection['unchanged_tracked_files']==1063 and not git('diff',B,M,'--',*selection['unchanged_dependency_paths'])
hupsel=read('CI_CHECKOUT_SCOPE07_PR1806_HUPSEL_IMPACT_ORIGINAL_JOBS_V1.json');assert {(x['name'],x['conclusion']) for x in hupsel['jobs']}=={('dependency-impact','success'),('qualification','skipped')}
hupsel_log=(E/'CI_CHECKOUT_SCOPE07_PR1806_HUPSEL_IMPACT_ORIGINAL_CI_V1.log').read_bytes()
for token in [S.encode(),b'"unchanged_scientific_tracked_files": 1883',b'"original_model_job_body_identical": true',b'"run_models": false']:assert token in hupsel_log
digest=SHA(archive)
common=dict(canonical_admission=True,actual_merge=M,qualified_candidate=C,source_anchor=A,whole_tree=TREE,coadmission=coadmission,scientific_change_class='D_READ_ONLY_BUILD_AND_EVIDENCE_TRANSPORT',new_scientific_contexts=0,original_scientific_producer='a4f24f74f3b5b82b2673f2695d15fe7ba3990fd6',original_scientific_producer_rebound=False,whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
manifest=dict(status='ACTUAL_CANONICAL648_ORIGINAL_PUBLIC_ORDINARY_PUB_CI_NEGATIVES_AND_SIGNED_OBJECTS_PRESERVED',archive=name+'.zip',bytes=len(archive),sha256=digest,parts=[dict(file=name+'.zip',bytes=len(archive),sha256=digest)],members=members,actual_public_observations=observations,successful_workflows=16,successful_checks=30,skipped_checks=18,full_model_periods_replayed_for_CI_or_observer_repairs=0,unchanged_MCSOL_model_replay='NOT_SELECTED_IMPACT_1063_EXACT_DEPENDENCY_FILES',HUPSEL_current_model_replay='NOT_SELECTED_EXACT1883_SCIENTIFIC_DEPENDENCIES_AND_ORIGINAL_MODEL_JOB_UNCHANGED',POND_current_model_replay='NOT_SELECTED_EXISTING_PRIVATE_FROST_PATH_SELECTION_PARENT_SUCCESS_RETAINED',**common)
receipt=dict(status='ACTUAL_CANONICAL648_CHECKOUT_TRANSPORT_ADMISSION_VERIFIED',PR=1806,previous_canonical=B,ordered_parents=[B,C],synthetic_merge=S,admission_archive_sha256=digest,**common)
recovery=dict(status='EXISTING_IMMUTABLE_RAW_ARCHIVE_VERIFIED_DESCRIPTOR_RECOVERED_WITHOUT_REBUILD_OR_REPLAY',actual_merge=M,original_archive_sha256=digest,original_archive_bytes_rewritten=False,original_partial_descriptor=partial_name,original_partial_descriptor_sha256=SHA(partial),original_partial_descriptor_bytes=len(partial),original_controller='ci-checkout-scope07-admission-seal-v3.py',cause='The appended Hupsel guard loop reused the coadmission variable name expected and left a bytes token there; original archive generation and all actual scientific/admission guards had already passed. Only JSON descriptor serialization failed.',correct_coadmission_type='dict',recovery_controller=Path(__file__).name,recovery_controller_sha256=SHA(Path(__file__).read_bytes()),full_model_periods_replayed=0,actual_positive_observers_replayed=0)
# Serialize in memory before touching the original partial descriptor.
outputs=[(name+'.json',manifest),('CI_CHECKOUT_SCOPE07_MERGE_RECEIPT_V1.json',receipt),('CI_CHECKOUT_SCOPE07_DESCRIPTOR_RECOVERY_V1.json',recovery)]
serialized=[(file,json.dumps(value,indent=2)+'\n') for file,value in outputs]
for file,text in serialized:
    if file!=name+'.json':assert not (P/file).exists()
    (P/file).write_text(text,encoding='utf8',newline='\n')
shutil.copyfile(Path(__file__),P/'CI_CHECKOUT_SCOPE07_ADMISSION_DESCRIPTOR_RECOVERY_V1.py')
with (E/'CI_CHECKOUT_SCOPE07_DESCRIPTOR_RECOVERY_V1.json').open('x',encoding='utf8') as f:json.dump(recovery,f,indent=2);f.write('\n')
assert (E/(name+'.zip')).read_bytes()==archive==(P/(name+'.zip')).read_bytes()
print(manifest['status'],len(archive),digest,len(members),flush=True)
