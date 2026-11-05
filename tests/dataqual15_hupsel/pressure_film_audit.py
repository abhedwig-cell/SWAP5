"""Source/object coherent composition plus actual full runtime adjudication."""
import argparse,json
from pathlib import Path,PurePosixPath
import pressure_film as runner
import film_rotation_audit as rotation
from film_runtime_profiles import profile4

ROOT=runner.ROOT;BASE=runner.BASE;sha=runner.sha


def paths(build,opt):
    original=list(build['baseline']['source_sha256'])[-1].replace('\\','/');root=original.removesuffix('/app/solute_project/main.f90');assert original!=root
    first=list(build['object_sha256'])[0].replace('\\','/');suffix='/'+opt+'/build/0.o';assert first.endswith(suffix)
    workspace=first[:-len(suffix)];baseline=build['baseline']['ttutil_archive'].replace('\\','/').rsplit('/',1)[0]
    return root,workspace,baseline


def key(name,context,opt):
    root,workspace,baseline=context;value=name.replace('\\','/')
    for prefix,target in ((root,'source-snapshot'),(baseline,'baseline-'+opt),(workspace,'')):
        if value.startswith(prefix+'/'):return(target+'/'if target else'')+value[len(prefix)+1:]
    raise AssertionError('unbound provider: '+value)


def source_binding(files,opt):
    prefix=opt+'/build/';build=json.loads(files[prefix+'BUILD.json']);old=build['baseline'];context=paths(build,opt)
    clean=lambda values:[v for v in values if not v.startswith(('-I','-J'))]
    assert old['status']=='BUILT'and old['build_mode']=='clean-source'and old['reuse_candidate']is None
    assert clean(build['flags'])==clean(old['flags'])==['-'+opt,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
    assert build['status']=='BUILT'and build['complete_module_closure_rebuilt']and build['production_admission']is False and build['whole_scientific_admission']is False
    assert set(build['interventions'])==set(runner.candidate_sources())and len(build['source_sha256'])==len(build['object_sha256'])==len(old['source_sha256'])==236
    events=build['events'];assert events==json.loads(files[prefix+'EVENTS.json'])and len(events)==237 and all(e['returncode']==0 for e in events)
    sources=list(build['source_sha256'].items());objects=list(build['object_sha256'].items());candidates=runner.candidate_sources();external=0
    for i,(before,pin)in enumerate(old['source_sha256'].items()):
        name=key(before,context,opt);original=files[name];assert sha(original)==pin
        relative=name.removeprefix('source-snapshot/')if name.startswith('source-snapshot/')else None
        if relative:assert original.replace(b'\r\n',b'\n')==(ROOT/relative).read_bytes().replace(b'\r\n',b'\n')
        else:external+=1;assert PurePosixPath(name).name=='legacy_swp_original.f90'
        actual,digest=sources[i];raw=files[key(actual,context,opt)];assert sha(raw)==digest
        if relative in candidates:assert raw.decode().replace('\r\n','\n')==candidates[relative]
        else:assert raw==original
        obj,pin=objects[i];assert sha(files[key(obj,context,opt)])==pin and obj.replace('\\','/').endswith('/'+str(i)+'.o')
        command=events[i]['command'];assert clean(command[1:command.index('-c')])==clean(build['flags'])and command[command.index('-c')+1]==actual and command[-2:]==['-o',obj]
    assert external==1
    pub=build['publication_provider'];assert pub==old['publication_provider']
    for field in ('source','object'):assert sha(files[key(pub[field],context,opt)])==pub[field+'_sha256']
    assert files[key(pub['source'],context,opt)].replace(b'\r\n',b'\n')==(ROOT/'app/support/restart_publish.c').read_bytes().replace(b'\r\n',b'\n')
    assert sha(files[key(build['ttutil_archive'],context,opt)])==build['archive_sha256']==old['archive_sha256']
    names=[n for n in (prefix+'swap5_hupsel_germination.exe',prefix+'swap5_hupsel_germination')if n in files];assert len(names)==1 and sha(files[names[0]])==build['executable_sha256']
    args=[s.strip('"')for s in files[prefix+'link.args'].decode().splitlines()];offset=2 if'-Wl,--stack,16777216'in args else 1
    assert args[:offset]==(['-fopenmp','-Wl,--stack,16777216']if offset==2 else['-fopenmp'])
    assert args[offset:offset+236]==[p.replace('\\','/')for p,_ in objects]
    assert args[offset+236:]==[pub['object'].replace('\\','/'),build['ttutil_archive'].replace('\\','/'),'-o',events[-1]['command'][1][1:].replace('\\','/').removesuffix('/link.args')+'/'+PurePosixPath(names[0]).name]
    assert events[-1]['command'][1].startswith('@');return build


def audit(folder,opt):
    registration=json.loads((folder/'REGISTRATION.json').read_text());assert registration==json.loads((BASE/runner.REG).read_text())
    assert registration['production_admission']is False and registration['whole_scientific_admission']is False
    previous=json.loads((BASE/rotation.runner.REG).read_text());assert registration['profile_days']==previous['profile_days']and registration['wet_cuts']==previous['wet_cuts']
    assert sorted(registration['capture_days'])==sorted(set(previous['profile_days']+previous['additional_capture_days']))
    case=folder/'full1096';build=json.loads((folder/'build/BUILD.json').read_text());run=rotation.run_record(case)
    assert run['scope']=='ORIGINAL_INPUT_INITIALIZATION'and run['returncode']==0 and run['restart_sha256']is None and not run['diagnostic_override']and run['executable_sha256']==build['executable_sha256']
    inputs=json.loads((BASE/'PRESSURE_DIAGNOSTIC_INPUTS_20261104.json').read_text())['files_sha256'];assert run['inputs']==inputs and all(sha((case/n).read_bytes())==pin for n,pin in inputs.items())
    windows,daily,interval=rotation.daily_data(case);crop=rotation.rows(case/'crop.csv');points={d:profile4((case/f'checkpoint-{d}.bin').read_bytes())for d in registration['capture_days']}
    assert(case/'checkpoint-1096.bin').read_bytes()==(case/'checkpoint.bin').read_bytes()
    proof=rotation.ledger(daily,crop,{d:p for d,p in points.items()if d>=495},1096);rotation.profile_checks(points,daily,rotation.rows(case/'state.csv'))
    pairs=[p for cut in registration['wet_cuts']for p in ((cut-1,cut),(cut,cut+1))]+[(1095,1096)]
    for first,last in pairs:
        strict=folder/'restarts'/f'{first}-to-{last}';record=rotation.run_record(strict)
        assert record['scope']=='STRICT_OWN_BUILD_RESTART'and record['returncode']==0 and record['executable_sha256']==run['executable_sha256']and record['restart_sha256']==sha((case/f'checkpoint-{first}.bin').read_bytes())and record['inputs']==inputs and not record['diagnostic_override']
        assert all(sha((strict/n).read_bytes())==pin for n,pin in inputs.items());runner.rotation.exact_window(case,strict,last)
    env=json.loads((folder/'CONTROL_ENVIRONMENT.json').read_text());assert env['OMP_NUM_THREADS']=='1'and env['predecessor_override']is False
    owner=json.loads((folder/'owner-controls/RESULT.json').read_text());app=json.loads((folder/'app-refusals/RESULT.json').read_text());writer=json.loads((folder/'writer-qualification/RESULT.json').read_text())
    assert owner['executable_sha256']==run['executable_sha256']and owner['checkpoint_sha256']==sha((case/'checkpoint.bin').read_bytes())and owner['clock']==1096
    assert len(owner['events'])==37 and all(e['status']=='PASS'and e['returncode']==1 for e in owner['events'])and len(app['events'])==11 and all(e['returncode']==1 for e in app['events'])
    assert writer['executable_sha256']==run['executable_sha256']and writer['finite_writer_refusals']==6 and writer['each_failed_write_preserves_prior_target_bytes']and writer['strict_restart_exact']
    result=dict(status='ACTUAL_COHERENT_PRESSURE_FILM_FULL1096_LEDGER_CUT_RESTART_AND_NATIVE_CONTROLS_PASS',optimization=opt,days=1096,intervals=len(windows),interval_ledger=interval,proof=proof,selected_profiles=registration['capture_days'],strict_windows=len(pairs),science=rotation.science(daily,crop,points),production_admission=False,whole_scientific_admission=False,migration_complete=False)
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runtime',type=Path,required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);a=p.parse_args()
    result=audit(a.runtime.resolve(),a.optimization);(a.runtime/'AUDIT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status']);print(json.dumps(result['science']))
