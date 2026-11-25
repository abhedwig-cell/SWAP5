"""Independent original-byte implicit HYS2 boundary budgets, state and physical source."""
import json,re
from pathlib import Path
from analytical_hydraulic_archives import SHA
from explicit_bottom9_archive_science import ReadView
from frost_boundary_state_calendar_archive_science import checkpoint,controls,physical
from frost_boundary_archive_science import budgets as dense_budgets,checkpoint as dense_checkpoint,compiled_controls as dense_controls
from frost_calendar_state_probe import budgets
from original_output_files import compare
from frost_boundary_convergence import require_convergence


def source_and_build(store,build,provider,case,opt):
    meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity']
    assert meta['project']['water_tolerance']==1e-10 and meta['project']['nodes']==34
    assert all('-'+opt in identity[k] and '-ffp-contract=off' in identity[k] for k in ['donor_flags','kernel_flags'])
    for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
    for key,folder in [('donor_objects','swap-obj'),('donor_modules','swap-obj'),('ttutil_modules','ttutil-obj')]:
        for name,digest in identity[key].items():assert SHA(provider.get('original-provider-build/'+folder+'/'+name))==digest
    assert SHA(provider.get('original-provider-build/ttutil-obj/libttutil.a'))==identity['ttutil_library']
    suffix='.exe' if (build/'day_donor.exe').is_file() else ''
    for role,digest in meta['executable_sha256'].items():assert SHA((build/('day_'+role+suffix)).read_bytes())==digest
    publisher='restart_publish.dll' if suffix else 'restart_publish.so'
    assert SHA((build/publisher).read_bytes())==identity['restart_publisher']['library_sha256']
    from frost_boundary_terminal_trial import receipt_source,original_head_source
    from frost_calendar_terminal_water import source as calendar_receipt
    from implicit_frost_surface_conductivity import restore
    from implicit_frost_source_guard import TERMINAL_PARTS,qualified_water_headcalc
    source=restore(original_head_source((build/'headcalc.f90').read_text(encoding='cp1252'),case['bottom']))
    for part in TERMINAL_PARTS:assert source.count(part)==1;source=source.replace(part,'',1)
    qualified_water_headcalc(source,case['bottom'])
    parent=(Path(__file__).resolve().parents[2]/'app/hybrid_water/terminal_water_receipt.f90').read_text(encoding='cp1252')
    expected=parent if case['calendar']=='parent-dense' else calendar_receipt()
    assert (build/'terminal_water_receipt.f90').read_text(encoding='cp1252')==receipt_source(expected)
    from time_event_closure import source as event_time
    from implicit_conductivity_retry import time_source as retry_time
    from implicit_pond_event import time_source as pond_time
    expected=pond_time(retry_time(event_time(provider.get('original-provider-build/swap-selected/timecontrol.f90')).decode('cp1252').replace('\r\n','\n')))
    assert (build/'timecontrol.f90').read_text(encoding='cp1252')==expected
    if case['kind']=='water' and case['calendar']!='parent-dense':
        from original_output_thermal import render_integral
        from frost_implicit_plate_calendar import source as pending_date_source,original_source
        original=provider.get('original-provider-build/swap-selected/integral.f90').decode('cp1252').replace('\r\n','\n')
        expected=pending_date_source(render_integral(original,None,identity['original_output']))
        actual=(build/'integral.f90').read_text(encoding='cp1252')
        assert actual==expected and original_source(actual)==render_integral(original,None,identity['original_output'])
    return meta


def case_audit(store,name,case,provider,producer,opt,folder_prefix=None):
    prefix=folder_prefix or 'current/'+name;folder=ReadView(store,prefix);profile=folder/'science';q=json.loads((profile/'RESULT.json').read_text());warm=profile/'trajectory'
    projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));entry=projection[q['build_root']];build=ReadView(store,entry['archive_prefix'])
    meta=source_and_build(store,build,provider,case,opt)
    assert SHA((build/'BUILD.json').read_bytes())==entry['actual_BUILD_sha256']==q['trajectory']['build_sha256']
    assert q['source']==producer and q['kind']==case['kind'] and meta['project']['start_date']==(case['start'] or '2002-01-01')
    for n,digest in meta['inputs'].items():assert SHA((folder/'inputs'/n).read_bytes())==digest
    convergence=require_convergence(profile)
    if case['calendar']=='parent-dense':
        assert q['status']=='CANDIDATE_ACTUAL_FROST_SWDIVD1_'+case['kind'].upper()+'_SHORT_PASS_NOT_ADMITTED' and q['optimization']==opt
        inventory={p.relative_to(folder/'inputs').as_posix():SHA(p.read_bytes()) for p in (folder/'inputs').rglob('*') if p.is_file()}
        assert inventory==q['inventory']
        text=(folder/'inputs/swap.swp').read_text(encoding='cp1252')
        for key,value in dict(SWMACRO=0,SWBOTB=case['bottom'],SWKIMPL=1,SWSOLU=int(case['kind']=='cde'),SWHYST=2,SWINCO=2,SWFROST=1,SWSNOW=1,SWDRA=1,NPRINTDAY=1,PERIOD=1,SWMONTH=0,SWODAT=0,SWRES=1).items():
            found=re.findall(r'(?mi)^\s*'+key+r'\s*=\s*([+-]?\d+)\s*(?:!.*)?$',text);assert len(found)==1 and int(found[0])==value
        scientific=dense_budgets(warm,case['kind']);data=[json.loads(line) for line in (warm/'daily.jsonl').read_text().splitlines()]
        windows=[(2,4),(19,23),(30,34)];cuts={35}|{d for pair in windows for d in pair}
        assert {int(p.stem.rsplit('-',1)[1]) for p in warm.glob('accepted-column-1-day-*.zip')}==cuts
        assert [(x['start'],x['end']) for x in q['own']]==windows
        for day in cuts:dense_checkpoint(warm/f'accepted-column-1-day-{day}.zip',meta,case,data[day-1])
        for start,end in windows:
            cold=profile/('own-'+str(start));rows=[json.loads(line) for line in (cold/'daily.jsonl').read_text().splitlines()]
            assert [physical(row,case['kind']) for row in rows]==[physical(row,case['kind']) for row in data[start:end]]
            assert dense_checkpoint(cold/f'accepted-column-1-day-{end}.zip',meta,case,rows[-1])==dense_checkpoint(warm/f'accepted-column-1-day-{end}.zip',meta,case,data[end-1])
            compare(warm/'original',cold/'original',meta['identity']['original_output'],start,end,meta['project']['start_date'])
        result=dict(case=case,actual_compiler_source=producer,optimization=opt,compiler=meta['identity']['compiler'],science=scientific,native_samples=len(cuts),exact_cold_windows=len(windows),controls=dense_controls(folder/'controls',warm,data,meta,case),convergence=convergence,BUILD_sha256=SHA((build/'BUILD.json').read_bytes()))
        return result
    assert q['status']=='ACTUAL_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED' and q['duration_days']==case['days']
    selected=q['selection'];assert all(selected[k]==case[k] for k in ('kind','bottom','implicit','hysteresis','initial'))
    from experimental_project import switches
    values=switches((folder/'inputs/swap.swp').read_text(encoding='cp1252'))
    assert all(values[k]==v for k,v in dict(SWMACRO=0,SWBOTB=case['bottom'],SWKIMPL=1,SWHYST=case['hysteresis'],SWINCO=case['initial'],SWSOLU=int(case['kind']=='cde')).items())
    scientific=budgets(warm,case['kind'],case['days']);assert scientific==q['independent_original_budgets']
    data=[json.loads(line) for line in (warm/'daily.jsonl').read_text().splitlines()]
    windows=[(2,4),(19,23),(30,34)] if case['days']==35 else [(2,case['days'])]
    assert [(x['start'],x['end']) for x in q['own']]==windows
    cuts={case['days']}|{d for pair in windows for d in pair}
    assert {int(p.stem.rsplit('-',1)[1]) for p in warm.glob('accepted-column-1-day-*.zip')}==cuts
    for day in cuts:checkpoint(warm/f'accepted-column-1-day-{day}.zip',meta,case,data[day-1])
    for start,end in windows:
        cold=profile/('own-'+str(start));rows=[json.loads(line) for line in (cold/'daily.jsonl').read_text().splitlines()]
        assert [physical(row,case['kind']) for row in rows]==[physical(row,case['kind']) for row in data[start:end]]
        assert checkpoint(cold/f'accepted-column-1-day-{end}.zip',meta,case,rows[-1])==checkpoint(warm/f'accepted-column-1-day-{end}.zip',meta,case,data[end-1])
        compare(warm/'original',cold/'original',meta['identity']['original_output'],start,end,meta['project']['start_date'])
    result=dict(case=case,actual_compiler_source=producer,actual_controller_source=q['actual_controller_source'],compiler=meta['identity']['compiler'],optimization=opt,science=scientific,native_samples=len(cuts),exact_cold_windows=len(windows),convergence=convergence,BUILD_sha256=SHA((build/'BUILD.json').read_bytes()))
    if case['days']==35:result['controls']=controls(folder/'controls',warm,data,meta,case)
    return result
