"""Validate literal checkout-only changes and the real Git path selection."""
import argparse,fnmatch,hashlib,json,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[2]
P=R/'integration/f-ci/nomacro-complete01'
SHA=lambda b:hashlib.sha256(b).hexdigest()
git=lambda *a,**kw:subprocess.check_output(['git',*a],cwd=R,**kw)


def historical_workflow(path,text):
    """Invert only a complete exact current checkout file for a legacy assertion."""
    contract=json.loads(git('show','HEAD:integration/f-ci/nomacro-complete01/CI_CHECKOUT_SCOPE07_CONTRACT_V1.json'))
    item=contract['files'].get(path)
    if item is None or SHA(text.encode())!=item['proposed_lf_sha256']:
        raise ValueError('Foreign complete current checkout workflow: '+path)
    original=git('show',contract['actual_canonical_dependency']+':'+path)
    if SHA(original)!=item['before_lf_sha256']:
        raise ValueError('Foreign original checkout workflow: '+path)
    before=original.decode();parts=[];cursor=0
    for edit in item['ordered_literal_edits']:
        if edit['before']!='' or edit['base_start']!=edit['base_end'] or edit['base_start']<cursor:
            raise ValueError('Foreign checkout-only literal inverse: '+path)
        parts.extend((before[cursor:edit['base_start']],edit['after']));cursor=edit['base_end']
    parts.append(before[cursor:])
    if ''.join(parts)!=text:
        raise ValueError('Changed current workflow command or checkout body: '+path)
    return before


def audit():
    head=git('rev-parse','HEAD').decode().strip();contract=json.loads((P/'CI_CHECKOUT_SCOPE07_CONTRACT_V1.json').read_text())
    base=contract.get('actual_canonical_dependency',contract['qualified_dependency_candidate'])
    assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','tests','.github','reference')
    assert not git('diff',base,'HEAD','--','app','src','tools','reference')
    changes=set(git('diff','--name-only',base,'HEAD','--','.github/workflows').decode().splitlines())
    assert changes==set(contract['files']) and len(changes)==13
    observations=[];steps=0
    for path,item in sorted(contract['files'].items()):
        before=git('show',base+':'+path);actual=(R/path).read_bytes().replace(b'\r\n',b'\n')
        assert actual==git('show','HEAD:'+path) and SHA(actual)==item['proposed_lf_sha256']
        assert SHA(before)==item['before_lf_sha256'];text=before.decode();cursor=0;parts=[]
        for edit in item['ordered_literal_edits']:
            assert edit['before']=='' and edit['base_start']==edit['base_end']>=cursor
            addition=edit['after'];assert addition.count('filter: blob:none\n')==1 and addition.count('sparse-checkout-cone-mode: false\n')==1 and addition.count('sparse-checkout: |\n')==1
            assert 'run:' not in addition and 'timeout' not in addition and 'permissions' not in addition and 'ref:' not in addition
            parts.extend((text[cursor:edit['base_start']],addition));cursor=edit['base_end']
        parts.append(text[cursor:]);assert ''.join(parts).encode()==actual
        assert item['all_non_checkout_yaml_values_identical'] and len(item['ordered_literal_edits'])==len(item['checkout_steps'])
        expected_profile='complete_evidence' if path=='.github/workflows/fci-canonical.yml' else 'source_and_metadata'
        assert all(x['profile']==expected_profile for x in item['checkout_steps'])
        steps+=len(item['checkout_steps']);observations.append(dict(path=path,before_sha256=SHA(before),actual_sha256=SHA(actual),checkout_steps=len(item['checkout_steps'])))
    assert steps==43
    names_raw=git('ls-tree','-r','--name-only','-z','HEAD');names=set(names_raw.decode().rstrip('\0').split('\0'))
    rules=Path(__file__).with_suffix('.rules');raw=rules.read_bytes();normal=raw.replace(b'\r\n',b'\n')
    assert normal.decode()==contract['rules'] and normal==git('show','HEAD:'+rules.relative_to(R).as_posix())
    selected=git('sparse-checkout','check-rules','--no-cone','--rules-file',str(rules),'-z',input=names_raw)
    included=set(selected.decode().rstrip('\0').split('\0'));prefix='integration/f-ci/nomacro-complete01/'
    excluded={name for name in names if name.startswith(prefix) and '/' not in name[len(prefix):] and (fnmatch.fnmatchcase(name[len(prefix):],'*.zip') or fnmatch.fnmatchcase(name[len(prefix):],'*.zip.part[0-9][0-9][0-9]'))}
    assert excluded and included==names-excluded
    assert all(name in included for name in names if name.startswith(('app/','src/','tools/','tests/','reference/','docs/')))
    assert all(name in included for name in names if name.startswith(prefix) and name.endswith('.json'))
    full_rules=Path(__file__).with_name('ci_checkout_scope07_evidence.rules');full_raw=full_rules.read_bytes().replace(b'\r\n',b'\n')
    assert full_raw.decode()==contract['profiles']['complete_evidence']=='/*\n'
    assert full_raw==git('show','HEAD:'+full_rules.relative_to(R).as_posix())
    full_selected=git('sparse-checkout','check-rules','--no-cone','--rules-file',str(full_rules),'-z',input=names_raw)
    assert set(full_selected.decode().rstrip('\0').split('\0'))==names
    # These are genuine immutable Git objects, not fabricated files in a projected
    # working directory. Actual qualification readers use that explicit interface.
    references={}
    for row in git('ls-tree','-r','-z','HEAD','--',prefix).split(b'\0'):
        if not row:continue
        meta,name=row.split(b'\t',1);mode,kind,digest=meta.decode().split();references[name.decode()]=(kind,digest)
    assert all(references[name][0]=='blob' and len(references[name][1])==40 for name in excluded)
    assert git('rev-parse','HEAD').decode().strip()==head
    return dict(status='ACTUAL_LITERAL43_CHECKOUT_ONLY_INVERSES_AND_REAL_GIT_COMPLETE_SOURCE_SELECTION_PASS_NOT_CANONICALLY_ADMITTED',actual_head=head,actual_base=base,workflow_files=observations,checkout_steps=43,complete_evidence_checkout_steps=sum(x['profile']=='complete_evidence' for v in contract['files'].values() for x in v['checkout_steps']),fci_canonical_keeps_complete_versioned_evidence=True,real_Git_complete_evidence_selection_sha256=SHA(full_selected),tracked_paths=len(names),included_paths=len(included),excluded_archive_paths=sorted(excluded),real_Git_rules_input_sha256=SHA(names_raw),real_Git_rules_output_sha256=SHA(selected),engine_source_changed=False,scientific_model_periods_replayed=0,compiler_executions=0,model_executions=0,performance_speedup_claimed=False,canonical_admission=False)


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit()
    with a.output.open('x',encoding='utf8') as f:json.dump(q,f,indent=2);f.write('\n')
    print(q['status'],q['checkout_steps'],len(q['excluded_archive_paths']),flush=True)


if __name__=='__main__':main()
