"""Literal actual-source inverse for an explicit additional Newton polishing rule."""
from pathlib import Path
import hashlib,json,subprocess
R=Path(__file__).resolve().parents[2]
BASE='1874c63ee359df7bbcfaead42af69bd9312a9065'
ADMITTED='e252e995eeece63d8f05531a10b746674c070685'
git=lambda *a:subprocess.check_output(['git',*a],cwd=R)
SHA=lambda b:hashlib.sha256(b).hexdigest()

def complete_inverse():
    path='integration/f-ci/nomacro-complete01/RIA12_WATER_POLISH_DOMAIN_CONTRACT_V1.json'
    raw=(R/path).read_bytes().replace(b'\r\n',b'\n');assert raw==git('show','HEAD:'+path);q=json.loads(raw)
    assert q['source_dependency']==BASE and git('rev-parse',BASE+'^{tree}')==git('rev-parse',ADMITTED+'^{tree}')
    subprocess.run(['git','merge-base','--is-ancestor',ADMITTED,'HEAD'],cwd=R,check=True)
    assert q['invariants']['original_scientific_water_limit_cm']=='1e-10' and q['invariants']['original_Newton_mass_guard_literal_unchanged']
    assert all(q['invariants'][key] is False for key in ('physical_equations_changed','old_default_generated_source_changed','inventory_or_flux_fixup','epsilon_water_added','age_moment_disposed','automatic_fallback','new_persistent_state','native_layout_changed','production_authority_changed'))
    domains=('app','src','tools','reference')
    assert set(git('diff','--name-only',BASE,'HEAD','--',*domains).decode().splitlines())==set(q['files'])|set(q['added_files'])
    assert not git('status','--porcelain=v1','--untracked-files=all','--',*domains,'tests','.github')
    for path,item in q['files'].items():
        before=git('show',BASE+':'+path);actual=(R/path).read_bytes().replace(b'\r\n',b'\n')
        assert SHA(before)==item['before_lf_sha256'] and SHA(actual)==item['proposed_lf_sha256'] and actual==git('show','HEAD:'+path)
        source=before.decode();parts=[];cursor=0
        for edit in item['ordered_literal_edits']:
            low,high=edit['base_start'],edit['base_end'];assert cursor<=low<=high<=len(source) and source[low:high]==edit['before'];parts.extend((source[cursor:low],edit['after']));cursor=high
        parts.append(source[cursor:]);assert ''.join(parts).encode()==actual
    for path,item in q['added_files'].items():
        assert not git('ls-tree',BASE,'--',path);actual=(R/path).read_bytes().replace(b'\r\n',b'\n');assert SHA(actual)==item['proposed_lf_sha256'] and actual==git('show','HEAD:'+path)
    return dict(status='ACTUAL_ADDITIONAL_RIA_NEWTON_PRECISION_LITERAL_INVERSE_PASS_NOT_ADMITTED',actual_head=git('rev-parse','HEAD').decode().strip(),actual_admitted_parent=ADMITTED)
