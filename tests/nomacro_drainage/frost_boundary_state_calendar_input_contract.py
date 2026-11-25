"""Actual new public compositions, hard exclusions and preserved old owners."""
import argparse,hashlib,json,shutil,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from frost_boundary_state_calendar_inputs import prepare
from original_output_baseline import assignment
import experimental_project as public
import frost_boundary_state_calendar as composed
import frost_boundary_composition as boundary
import implicit_frost_root_state as root
BASE='74ecc55765df548e758605f3566bc93558a6fefb'
git=lambda *a:subprocess.check_output(['git',*a],cwd=R)
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def source():
    contract=json.loads((R/'integration/f-ci/nomacro-complete01/FROST_BOUNDARY_STATE_CALENDAR04_CONTRACT_V1.json').read_text())
    assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','tests','.github')
    assert set(git('diff','--name-only',BASE,'HEAD','--','app','src','tools','reference').decode().splitlines())==set(contract['files'])
    for path,item in contract['files'].items():
        raw=(R/path).read_bytes().replace(b'\r\n',b'\n');assert raw==git('show','HEAD:'+path) and SHA(raw)==item['proposed_lf_sha256']
        if item['added']:continue
        old=git('show',BASE+':'+path);assert SHA(old)==item['before_lf_sha256'];text=old.decode();parts=[];cursor=0
        for edit in item['ordered_literal_edits']:
            assert text[edit['base_start']:edit['base_end']]==edit['before'];parts.extend((text[cursor:edit['base_start']],edit['after']));cursor=edit['base_end']
        parts.append(text[cursor:]);assert ''.join(parts).encode()==raw
    for name in ('implicit_frost_root_state.py','implicit_snow_root_state.f90','implicit_frost_surface_conductivity.py','frost_divdra_overlap.py','frost_reference.py'):
        path='app/hybrid_water/'+name;assert (R/path).read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':'+path)
    return git('rev-parse','HEAD').decode().strip(),contract


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    head,contract=source();args.output.mkdir();cases=[];declines=[];old=[]
    from frost_calendar_output import codec,metadata
    for case in contract['representative_cases']:
        folder=args.output/case['name'];prepare(case,folder)
        project=public.load(folder,original_output=True,time_step_policy='original-adaptive-event-closure-v1')
        selected=composed.selection(folder,True);assert selected and selected['frost_calendar'] and selected['bottom']==case['bottom'] and selected['hysteresis']==case['hysteresis'] and selected['initial']==case['initial']
        code=codec(project);assert code.decode() in contract['native_codecs'] and metadata(project)['policy']==composed.POLICY
        if case['implicit']:
            assert root.boundary(project)==case['bottom'] and root.hysteresis(project)==case['hysteresis']
            assert '(swbotb/='+str(case['bottom'])+'.or.swfrost/=1.or.swdra/=1.or.swhyst/='+str(case['hysteresis'])+')' in root.source(project.solute,root.hysteresis(project),root.boundary(project))
            from implicit_snow_root_carry import enabled as generic_water
            from implicit_snow_cde_root_carry import enabled as generic_cde
            assert not generic_water(project) and not generic_cde(project)
        cases.append(dict(case=case,selected=selected,codec=code.decode(),original_inputs={p.relative_to(folder).as_posix():dict(bytes=p.stat().st_size,sha256=SHA(p.read_bytes())) for p in folder.rglob('*') if p.is_file()}))
    for case in contract.get('known_numerically_blocked_cases',[]):
        folder=args.output/('known-numerical-'+case['name']);prepare(case,folder)
        assert composed.selection(folder,True) is None
        try:public.load(folder,original_output=True,time_step_policy='original-adaptive-event-closure-v1')
        except ValueError as error:declines.append(dict(selector='KNOWN_IMPLICIT_HYS2_CALENDAR_CLOCK_FAILURE',case=case['name'],actual_public_refusal=str(error)))
        else:raise AssertionError('Known numerical failure entered public composition')
    from frost_boundary_inputs import prepare as prior
    for bottom in (5,8):
        for kind in ('water','cde'):
            for implicit in (0,1):
                if bottom==8 and implicit:continue
                folder=args.output/f'parent-{kind}-b{bottom}-i{implicit}';prior(kind,implicit,bottom,folder)
                assert composed.selection(folder,True) is None
                project=public.load(folder,original_output=True,time_step_policy='original-adaptive-event-closure-v1');selected=boundary.selection(folder,True)
                assert selected['policy']=='original-frost-boundary58-dense-state-composition-v1' and selected['hysteresis']==selected['initial']==2
                assert boundary.codec(selected)=={('water',0):b'S5FBW001',('cde',0):b'S5FBC001',('water',1):b'S5FBW002',('cde',1):b'S5FBC002'}[(kind,implicit)]
                old.append(dict(kind=kind,bottom=bottom,implicit=implicit,unchanged_old_selection_and_codec=True))
    donor=args.output/contract['representative_cases'][0]['name']
    for key,value in dict(SWMACRO=1,SWHYST=3,SWINCO=3,SWHEA=0,SWCALT=1,SWDRA=0,NPRINTDAY=2,SWSOLU=2,SWMETDETAIL=1,SWBR=1,SWKIMPL=2).items():
        folder=args.output/('outside-'+key);shutil.copytree(donor,folder);path=folder/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),key,value),encoding='cp1252')
        assert composed.selection(folder,True) is None
        try:public.load(folder,original_output=True,time_step_policy='original-adaptive-event-closure-v1')
        except ValueError as error:declines.append(dict(selector=key,value=value,actual_public_refusal=str(error)))
        else:raise AssertionError('Unsupported public composition admitted '+key)
    for kind in ('water','cde'):
        case=dict(contract['representative_cases'][0],kind=kind,implicit=1,bottom=5);folder=args.output/('outside-implicit8-'+kind);prepare(case,folder);path=folder/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),'SWBOTB',8),encoding='cp1252');assert composed.selection(folder,True) is None
        try:public.load(folder,original_output=True,time_step_policy='original-adaptive-event-closure-v1')
        except ValueError as error:declines.append(dict(selector='IMPLICIT8',kind=kind,actual_public_refusal=str(error)))
        else:raise AssertionError('Retained implicit8 failure admitted')
    assert source()[0]==head
    result=dict(status='CURRENT_PUBLIC_COMPOSITIONS_HARD_REFUSALS_PARENT_SELECTIONS_AND_UNCHANGED_ROOT_PROVIDER_SOURCE_PASS_NOT_SCIENTIFICALLY_QUALIFIED',source=head,cases=cases,declines=declines,parent=old,unchanged_default_bottom6_root_forms={str((solute,mode)):SHA(root.source(solute,mode).encode('cp1252')) for solute in (False,True) for mode in (0,1,2)},compiler_executions=0,model_executions=0,canonical_admission=False)
    (args.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],flush=True)


if __name__=='__main__':main()
