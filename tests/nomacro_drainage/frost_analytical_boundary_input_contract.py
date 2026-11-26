"""Bound the real complete current undrained composition before public builds."""
from pathlib import Path
import hashlib,json,subprocess
R=Path(__file__).resolve().parents[2]
BASE='9af88c3de6198ddec40c2674dd1542a89fa9c0d7'
P='integration/f-ci/nomacro-complete01/'
SHA=lambda b:hashlib.sha256(b).hexdigest()


def source():
    git=lambda *a:subprocess.check_output(['git',*a],cwd=R)
    head=git('rev-parse','HEAD').decode().strip()
    assert not git('for-each-ref','--format=%(refname)','refs/replace')
    assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','tests','reference','.github')
    assert not git('diff',BASE,'HEAD','--','src','tools','reference')
    raw=git('show','HEAD:'+P+'FROST_ANALYTICAL_BOUNDARY10_SOURCE_PROPOSAL_V4.json')
    contract=json.loads(raw)
    assert (R/P/'FROST_ANALYTICAL_BOUNDARY10_SOURCE_PROPOSAL_V4.json').read_bytes().replace(b'\r\n',b'\n')==raw
    assert contract['actual_before_source']==BASE
    assert set(git('diff','--name-only',BASE,'HEAD','--','app').decode().splitlines())==set(contract['files'])
    for path,item in contract['files'].items():
        actual=(R/path).read_bytes().replace(b'\r\n',b'\n')
        assert actual==git('show','HEAD:'+path) and SHA(actual)==item['proposed_lf_sha256']
        if item.get('added'):continue
        before=git('show',BASE+':'+path);assert SHA(before)==item['before_lf_sha256']
        text=before.decode();parts=[];cursor=0
        for edit in item['ordered_literal_edits']:
            assert cursor<=edit['base_start']<=edit['base_end'] and text[edit['base_start']:edit['base_end']]==edit['before']
            parts.extend((text[cursor:edit['base_start']],edit['after']));cursor=edit['base_end']
        parts.append(text[cursor:]);assert ''.join(parts).encode()==actual
    raw=git('show','HEAD:'+P+'FROST_ANALYTICAL_BOUNDARY10_INPUT_CONTRACT_PROPOSED_V1.json');cases=json.loads(raw)
    assert (R/P/'FROST_ANALYTICAL_BOUNDARY10_INPUT_CONTRACT_PROPOSED_V1.json').read_bytes().replace(b'\r\n',b'\n')==raw
    assert len(cases['representative_cases'])==16 and len({c['name'] for c in cases['representative_cases']})==16
    assert all(((c['drainage']==0 and c['bottom']==6) or (c['drainage']==1 and c['bottom'] in (5,6,8))) and c['days'] in (12,35) for c in cases['representative_cases'])
    assert git('rev-parse','HEAD').decode().strip()==head
    return head,cases


if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    head,contract=source();q=dict(status='ACTUAL_COMPLETE_ANALYTICAL_BOUNDARY_FROST_SOURCE_LITERAL_INVERSES_AND16_CASE_CONTRACT_PASS_NOT_ADMITTED',actual_source=head,actual_parent_candidate=BASE,representative_cases=len(contract['representative_cases']),compiler_executions=0,model_executions=0)
    with a.output.open('x',encoding='utf8') as f:json.dump(q,f,indent=2);f.write('\n')
    print(q['status'],head,flush=True)
