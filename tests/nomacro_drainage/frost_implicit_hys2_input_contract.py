"""Actual public implicit HYS2 boundary input domain, complete source inverse and hard refusals."""
import argparse,hashlib,json,shutil,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from frost_implicit_hys2_metadata import read
from frost_implicit_hys2_inputs import prepare
from original_output_baseline import assignment
import experimental_project as public
import frost_boundary_composition as boundary
import frost_boundary_state_calendar as calendar
from frost_boundary_terminal_trial import enabled
BASE='47124f4de18a752fc466d50e2752e843548e5fea'
SHA=lambda b:hashlib.sha256(b).hexdigest()


def source():
    git=lambda *a:subprocess.check_output(['git',*a],cwd=R)
    contract=read('FROST_IMPLICIT_HYS2_YEAR06_CONTRACT_V1.json')
    assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','tests','.github')
    assert set(git('diff','--name-only',BASE,'HEAD','--','app','src','tools','reference').decode().splitlines())==set(contract['files'])
    for name,item in contract['files'].items():
        actual=(R/name).read_bytes().replace(b'\r\n',b'\n');assert actual==git('show','HEAD:'+name) and SHA(actual)==item['proposed_lf_sha256']
        if item.get('added'):
            assert subprocess.run(['git','cat-file','-e',BASE+':'+name],cwd=R,capture_output=True).returncode!=0
            continue
        parent=git('show',BASE+':'+name);assert SHA(parent)==item['before_lf_sha256'];text=parent.decode();pieces=[];cursor=0
        for edit in item['ordered_literal_edits']:
            assert cursor<=edit['base_start']<=edit['base_end'] and text[edit['base_start']:edit['base_end']]==edit['before']
            pieces.extend((text[cursor:edit['base_start']],edit['after']));cursor=edit['base_end']
        pieces.append(text[cursor:]);assert ''.join(pieces).encode()==actual
    return git('rev-parse','HEAD').decode().strip(),contract


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();head,contract=source();a.output.mkdir()
    cases=[];declines=[]
    for case in contract['representative_cases']:
        folder=a.output/case['name'];prepare(case,folder)
        project=public.load(folder,original_output=True,time_step_policy='original-adaptive-event-closure-v1')
        selected=boundary.selection(folder,True);assert enabled(project) and selected['bottom']==case['bottom'] and selected['implicit']==1
        assert selected['hysteresis']==case['hysteresis'] and selected['initial']==case['initial'] and selected['kind']==case['kind']
        assert boundary.codec(selected).decode() in contract['native_codecs']
        assert bool(selected.get('boundary_state_calendar'))==(case['calendar']!='parent-dense')
        cases.append(dict(case=case,selected=selected,codec=boundary.codec(selected).decode(),inputs={p.relative_to(folder).as_posix():SHA(p.read_bytes()) for p in folder.rglob('*') if p.is_file()}))
    donor=a.output/contract['representative_cases'][2]['name']
    for key,value in dict(SWMACRO=1,SWHYST=3,SWINCO=3,SWHEA=0,SWCALT=1,SWDRA=0,NPRINTDAY=2,SWSOLU=2,SWMETDETAIL=1,SWBR=1,SWKIMPL=2).items():
        folder=a.output/('outside-'+key);shutil.copytree(donor,folder);p=folder/'swap.swp';p.write_text(assignment(p.read_text(encoding='cp1252'),key,value),encoding='cp1252')
        assert boundary.selection(folder,True) is None
        try:public.load(folder,original_output=True,time_step_policy='original-adaptive-event-closure-v1')
        except ValueError as error:declines.append(dict(selector=key,value=value,refusal=str(error)))
        else:raise AssertionError('Unsupported actual implicit plate route: '+key)
    assert source()[0]==head
    q=dict(status='ACTUAL_IMPLICIT_HYS2_BOUNDARY_PUBLIC_DOMAIN_AND_COMPLETE_SOURCE_INVERSE_PASS_NOT_SCIENTIFICALLY_QUALIFIED',source=head,cases=cases,refusals=declines,compiler_executions=0,model_executions=0)
    (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'],len(cases),len(declines),flush=True)


if __name__=='__main__':main()
