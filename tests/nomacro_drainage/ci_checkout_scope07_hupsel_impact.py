"""Compare real Hupsel scientific dependencies before selecting old model periods."""
from pathlib import Path
import hashlib,json,os,re,subprocess
R=Path(__file__).resolve().parents[2]
DEPENDENCIES=('app','src','tools','reference','examples','CMakeLists.txt','Makefile',
              'pyproject.toml','requirements.txt','integration/f-ci/hupsel51-water-balance',
              'integration/nomacro-coverage01')
WORKFLOW='.github/workflows/hupsel51-water-balance.yml'
SELECTION="    needs: dependency-impact\n    if: needs.dependency-impact.outputs.run_models == 'true'\n"


def main():
    git=lambda *a:subprocess.check_output(['git',*a],cwd=R)
    base=os.environ['BASE'];assert re.fullmatch('[0-9a-f]{40}',base)
    head=git('rev-parse','HEAD').decode().strip()
    assert not git('status','--porcelain=v1','--untracked-files=all','--',*DEPENDENCIES,WORKFLOW)
    before=git('ls-tree','-r',base,'--',*DEPENDENCIES)
    after=git('ls-tree','-r','HEAD','--',*DEPENDENCIES)
    assert before and after
    def qualification(ref):
        text=git('show',ref+':'+WORKFLOW).decode()
        assert text.count('  qualification:\n')==1
        body=text.split('  qualification:\n',1)[1]
        if body.startswith(SELECTION):body=body[len(SELECTION):]
        return body
    prior_body=qualification(base);current_body=qualification('HEAD')
    changed=before!=after or prior_body!=current_body
    q=dict(status='ACTUAL_HUPSEL_SCIENTIFIC_DEPENDENCY_SELECTION',actual_base=base,
           actual_checkout=head,dependency_paths=list(DEPENDENCIES),
           previous_Git_tree_bytes_sha256=hashlib.sha256(before).hexdigest(),
           current_Git_tree_bytes_sha256=hashlib.sha256(after).hexdigest(),
           unchanged_scientific_tracked_files=len(before.splitlines()) if before==after else None,
           original_model_job_body_identical=prior_body==current_body,
           original_model_job_sha256=hashlib.sha256(current_body.encode()).hexdigest(),
           run_models=changed,current_scientific_PASS_claimed=False,
           reason='SCIENTIFIC_SOURCE_INPUT_BUILD_OR_ORIGINAL_JOB_CHANGED' if changed else 'EXACT_SCIENTIFIC_DEPENDENCIES_AND_ORIGINAL_MODEL_JOB_UNCHANGED_INHERIT_PRIOR_EVIDENCE',
           compiler_executions=0,model_executions=0)
    assert git('rev-parse','HEAD').decode().strip()==head
    Path(os.environ['GITHUB_OUTPUT']).open('a',encoding='utf8').write('run_models='+str(changed).lower()+'\n')
    print(json.dumps(q,indent=2),flush=True)


if __name__=='__main__':main()
