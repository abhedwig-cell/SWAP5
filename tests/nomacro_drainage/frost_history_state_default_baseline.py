"""Build real canonical/current hys2 at one actual checkout; never project HEAD."""
import argparse,hashlib,json,re,shutil,subprocess,sys,zipfile
from pathlib import Path
R=Path.cwd()
BASE='e0461f005b95b9f68bc70d4d4698eff903bc04ed'
CLEANUP=Path('C:/Users/Veldh012/OneDrive - Wageningen University & Research/Documents/ChatGPT/SWAP5-finaliseren/tools/storage/cleanup.py')
TASK='01a1e8b4-228b-75f1-8ac4-b07ca1e15713'


def main():
    p=argparse.ArgumentParser()
    for name in ('evidence','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();git=lambda *args:subprocess.check_output(['git',*args],cwd=R).decode().strip()
    head=git('rev-parse','HEAD');branch=git('symbolic-ref','--short','HEAD');tree=git('rev-parse','HEAD^{tree}')
    assert not git('status','--porcelain=v1','--untracked-files=all','--ignored')
    sparse=Path(git('rev-parse','--git-path','info/sparse-checkout'));sparse=sparse if sparse.is_absolute() else R/sparse;patterns=sparse.read_bytes();assert len(patterns.splitlines())==14
    contract=json.loads((R/'integration/f-ci/nomacro-complete01/FROST_HYSTERESIS_STATE01_CONTRACT_V1.json').read_text());paths=list(contract['files'])+[contract['added_file']['path']];working={path:(R/path).read_bytes() for path in paths};proof=R/'integration/f-ci/nomacro-complete01';proofs={p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in proof.iterdir() if p.is_file() and (p.name.endswith('.zip') or '.zip.part' in p.name)}
    with zipfile.ZipFile(a.output/'actual-before-source-bytes.zip','x',compression=zipfile.ZIP_DEFLATED) as z:
        for path,raw in working.items():z.writestr(path,raw)
    fixtures=lambda:{p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (R/'reference/swap-4.3.1/projects').rglob('*') if p.is_file()}
    original_fixtures=fixtures();assert len(original_fixtures)==56
    q=dict(status='RUNNING_ACTUAL_SAME_R_DEFAULT_BASELINES_NO_MODEL_PERIODS',orchestrator_source=head,actual_checkout=str(R),current_branch=branch,current_tree=tree,baseline=BASE,working_source_raw_sha256={p:hashlib.sha256(b).hexdigest() for p,b in working.items()},materialized_proof_paths=proofs,original_fixture_hashes=original_fixtures,builds=[],model_periods_executed=0)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def storage(*args):return json.loads(subprocess.check_output([sys.executable,'-B',str(CLEANUP),*args],cwd=CLEANUP.parents[2]))
    save();cases=[]
    for implicit,kind,opt in [(0,'water','O0'),(0,'cde','O2'),(1,'water','O0'),(1,'cde','O2')]:
        hys=0 if kind=='water' else 1;initial=1 if kind=='water' else 2;stem=('implicit' if implicit else 'explicit')+'-'+kind
        original=a.evidence/('frost-history-state01-'+stem+'-hys'+str(hys)+'-initial'+str(initial)+'-'+opt+'-v1');profile=json.loads((original/'RESULT.json').read_text());inputs=a.output/'inputs'/stem;shutil.copytree(profile['input_root'],inputs);path=inputs/'swap.swp';text=path.read_text(encoding='cp1252');text,count=re.subn(r'(?mi)^([ \t]*SWHYST[ \t]*=[ \t]*)[^!\r\n]*',lambda m:m[1]+'2',text);assert count==1;path.write_text(text,encoding='cp1252')
        command=profile['build']['command'];model=command[command.index('--model')+1];cases.append(dict(implicit=implicit,kind=kind,optimization=opt,stem=stem,inputs=str(inputs),model=model))
    try:
        q['space_preflight']=storage('check-space','--large-job');save()
        for phase,source in [('current',head),('canonical',BASE)]:
            if phase=='canonical':subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false','switch','--detach',BASE],cwd=R,check=True,capture_output=True)
            assert git('rev-parse','HEAD')==source
            for case in cases:
                label='frost-history-state01-default-'+phase+'-'+case['stem']+'-'+case['optimization']+'-v1';allocated=storage('allocate','--task',TASK,'--kind','build','--name',label,'--variant',case['optimization'],'--source-ref',source,'--recipe','ActualsameR '+source+' unchangedoldhys2 '+case['stem']+' buildonly; no modelperiod; exactgenerated/compiled baseline comparison');build=Path(allocated['path'])/'bundle';out=a.output/(phase+'-'+case['stem']);out.mkdir()
                command=[sys.executable,'-B','tools/solute/run_water.py','--model',case['model'],'--experimental-project',case['inputs'],'--original-output','--experimental-time-step-policy','original-adaptive-event-closure-v1','--reference-work',str(a.reference_work),'--build-only','--donor-opt',case['optimization'],'--kernel-opt',case['optimization'],'--output',str(build)]
                with (out/'build.stdout').open('xb') as stdout,(out/'build.stderr').open('xb') as stderr:r=subprocess.run(command,cwd=R,stdout=stdout,stderr=stderr,timeout=240)
                item=dict(**case,phase=phase,actual_compiler_source=git('rev-parse','HEAD'),build_root=str(build),command=command,returncode=r.returncode);q['builds'].append(item);save();assert item['actual_compiler_source']==source;r.check_returncode()
                validator="import sys;from pathlib import Path;sys.path[:0]=['tests/nomacro_scheduled_subsurface','tests/nomacro_drainage','app/hybrid_water'];from original_output_matrix import m;p=m.e.load(Path(sys.argv[1]),original_output=True,time_step_policy='original-adaptive-event-closure-v1');m.validate_bundle(Path(sys.argv[2]),Path(sys.argv[3]),p);print('ACTUAL_PHASE_BUNDLE_VALIDATED')"
                with (out/'validate.stdout').open('xb') as stdout,(out/'validate.stderr').open('xb') as stderr:r=subprocess.run([sys.executable,'-B','-c',validator,case['inputs'],str(build),str(a.reference_work)],cwd=R,stdout=stdout,stderr=stderr,timeout=90)
                item['actual_phase_bundle_validation_returncode']=r.returncode;save();r.check_returncode();print('BUILT',phase,case['stem'],source,flush=True)
    except Exception as error:q.update(status='FAILED_ACTUAL_SAME_R_DEFAULT_BASELINES',error=repr(error));raise
    finally:
        if git('rev-parse','HEAD')!=head:subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false','switch',branch],cwd=R,check=True,capture_output=True)
        assert git('rev-parse','HEAD')==head and git('rev-parse','HEAD^{tree}')==tree and sparse.read_bytes()==patterns
        restored=[]
        for path,raw in working.items():
            target=R/path;assert not target.is_symlink();actual=target.read_bytes();assert actual.replace(b'\r\n',b'\n')==raw.replace(b'\r\n',b'\n')
            if actual!=raw:target.write_bytes(raw);restored.append(path)
            assert target.read_bytes()==raw
        if restored:
            subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false','add','--',*restored],cwd=R,check=True,capture_output=True)
            assert git('write-tree')==tree
        missing=[path for path in proofs if not (R/path).is_file()]
        for at in range(0,len(missing),20):subprocess.run(['git','restore','--source=HEAD','--worktree','--ignore-skip-worktree-bits','--',*missing[at:at+20]],cwd=R,check=True,capture_output=True)
        for path,digest in proofs.items():assert hashlib.sha256((R/path).read_bytes()).hexdigest()==digest
        assert not git('status','--porcelain=v1','--untracked-files=all','--ignored') and fixtures()==original_fixtures
        q.update(actual_current_head_restored=head,actual_current_tree_restored=tree,exact_actual_source_EOL_restored_paths=restored,exact_missing_proof_paths_restored=missing,sparse_patterns_unchanged=14);save()
    # Import current observers only after genuine current HEAD and bytes return.
    sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'app/hybrid_water')]
    from snow58_compiled_postimage import compare
    q['comparisons']=[]
    for case in cases:
        pair={item['phase']:Path(item['build_root']) for item in q['builds'] if item['stem']==case['stem']};a_root,b_root=pair['canonical'],pair['current'];files=lambda root:{p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in ('.f90','.f','.for','.inc')};aa,bb=files(a_root),files(b_root);assert aa and aa.keys()==bb.keys();generated=[]
        for name,path in aa.items():
            left,right=path.read_bytes(),bb[name].read_bytes();assert left.replace(b'\r\n',b'\n')==right.replace(b'\r\n',b'\n');generated.append(dict(file=name,actual_canonical_raw_sha256=hashlib.sha256(left).hexdigest(),actual_current_raw_sha256=hashlib.sha256(right).hexdigest()))
        q['comparisons'].append(dict(stem=case['stem'],optimization=case['optimization'],generated=generated,compiled=compare(a_root,b_root)));save()
    assert len(q['comparisons'])==4 and git('rev-parse','HEAD')==head
    q['status']='FOUR_ACTUAL_SAME_R_CANONICAL_AND_CURRENT_OLD_HYS2_WHOLE_GENERATED_COMPILED_POSTIMAGES_PASS_ZERO_MODEL_PERIODS';save();print(q['status'],flush=True)


if __name__=='__main__':main()
