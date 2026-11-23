"""Actual active-vapor9 coupling/native periods; independent science still required."""
import argparse, hashlib, json, struct, subprocess, sys, time, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT/'app/hybrid_water'), str(ROOT/'tests/nomacro_drainage'),
                str(ROOT/'tests/nomacro_scheduled_subsurface')]
from explicit_bottom9_runtime import m, own
from prescribed_vapor_boundary import enabled

BASE = '13bd0b011c40fbe7b37574d2472c05335cd03559'
SHA = lambda raw: hashlib.sha256(raw).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    for key in ('input','reference-work','build-root','output'):
        parser.add_argument('--'+key, type=Path, required=True)
    parser.add_argument('--optimization', choices=('O0','O2'), required=True)
    parser.add_argument('--days', type=int, choices=(2,35), default=2)
    parser.add_argument('--reuse-profile', type=Path)
    args = parser.parse_args()
    git = lambda *a: subprocess.check_output(['git',*a], cwd=ROOT, text=True).strip()
    assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','tests','reference')
    head = git('rev-parse','HEAD')
    proposed = json.loads((ROOT/'integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_PAIRED_VAPOR_PROPOSED_V1.json').read_text())
    paths = proposed['files']
    assert set(git('diff','--name-only',BASE,'HEAD','--','app','src','tools','reference').splitlines()) == set(paths)
    for path, item in paths.items():
        assert SHA((ROOT/path).read_bytes().replace(b'\r\n',b'\n')) == item['proposed_lf_sha256']
    args.output.mkdir()
    build = args.build_root/'bundle'
    previous = None
    if args.reuse_profile:
        previous = json.loads((args.reuse_profile/'RESULT.json').read_text())
        assert previous['status'] == 'ACTUAL_TWO_DAY_ACTIVE_VAPOR_PAIRED9_BUILD_NATIVE_AND_EXACT_COLD_PREFLIGHT_PASS_NOT_QUALIFIED'
        assert previous['optimization'] == args.optimization
        assert previous['input_inventory'] == json.loads(json.dumps(m.e.inventory(args.input)))
        assert not git('diff',previous['source'],'HEAD','--','app','src','tools','reference')
        build = Path(previous['build_root'])
        assert build == args.build_root/'bundle'
        assert SHA((build/'BUILD.json').read_bytes()) == previous['trajectory']['build_sha256']
    record = dict(status='RUNNING', source=head, optimization=args.optimization,
                  days=args.days, purpose='Essential uncovered paired9 active-vapor thermal/boundary and complete native carry risk; independent full scientific qualification remains pending',
                  expected_total_seconds=240, input_root=str(args.input),
                  input_inventory=m.e.inventory(args.input), build_root=str(build),
                  actual_changed_APP=sorted(paths), canonical_admission=False,
                  full_period_qualification=False)
    record['actual_build_producer'] = previous['source'] if previous else head
    record['existing_build_reused'] = bool(previous)
    save = lambda: (args.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
    started = time.perf_counter()
    save()
    try:
        project = m.e.load(args.input, original_output=True, time_step_policy='original-adaptive-day-seed-v1')
        assert enabled(project) and not project.age and not project.macro
        record['kind'] = 'cde' if project.solute else 'water'
        record['native_codec'] = m.e.auxiliary_magic(project).decode()
        command = [sys.executable,'-B','tools/solute/run_water.py','--model',project.model,
                   '--experimental-project',str(args.input),'--original-output',
                   '--experimental-time-step-policy',project.time_step_policy,
                   '--reference-work',str(args.reference_work),'--build-only',
                   '--donor-opt',args.optimization,'--kernel-opt',args.optimization,
                   '--output',str(build)]
        if previous is None:
            with (args.output/'build.stdout.txt').open('xb') as out, (args.output/'build.stderr.txt').open('xb') as err:
                response = subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=300)
            record['build'] = dict(command=command,returncode=response.returncode,
                                   actual_completion_head=git('rev-parse','HEAD'),
                                   seconds=time.perf_counter()-started)
            save()
            response.check_returncode()
        else:
            record['build'] = dict(status='ACTUAL_EXISTING_BUILD_REUSED_UNCHANGED_NO_COMPILATION',
                                   original_build_receipt=str(args.reuse_profile/'RESULT.json'),
                                   actual_completion_head=git('rev-parse','HEAD'))
        save()
        assert record['build']['actual_completion_head'] == head
        meta, _ = m.validate_bundle(build,args.reference_work,project)
        identity = meta['identity']
        vapor = identity['hydraulic_vapor']
        assert vapor['paired_boundary_composition']['native_domain_version'] == 7
        assert not identity.get('model7_terminal_water')
        from prescribed_head_flux_boundary import render_budget
        assert (build/'hybrid_step_budget.f90').read_text(encoding='cp1252') == render_budget((ROOT/'app/hybrid_water/hybrid_step_budget.f90').read_text(encoding='cp1252'),9)
        assert SHA((build/'headcalc.f90').read_text(encoding='cp1252').encode()) == '155dd85c118026439cd837e5b7f2178c9cae99a536b3c5e27b9e751912ebe80c'
        windows = ((1,2),) if args.days == 2 else ((2,4),(19,23),(30,34))
        cuts = {args.days,*(day for pair in windows for day in pair)}
        record['trajectory'], data = m.trajectory(build,args.reference_work,project,args.output/'trajectory',args.days,cuts,300)
        record['actual_native_domains'] = []
        for day in sorted(cuts):
            with zipfile.ZipFile(args.output/'trajectory'/('accepted-column-1-day-'+str(day)+'.zip')) as archive:
                raw = archive.read('macro.bin')
                header = struct.unpack_from('<14i',raw,48)
                layers = header[2]
                count = 14+2*layers
                first = struct.unpack_from('<'+str(count)+'i',raw,48)
                witness = struct.unpack_from('<'+str(count)+'i',raw,48+4*count)
                assert first == witness and raw[:8] == m.e.auxiliary_magic(project)
                assert header[:12] == (7,project.nodes,layers,0,int(project.solute),0,0,0,0,0,1,2)
                assert header[12] in (0,1) and header[13] == 9
                assert first[14:14+layers] == tuple(vapor['models'])
                assert first[14+layers:] == tuple(f if model>=8 else 0 for model,f in zip(vapor['models'],vapor['SWVAPOR']))
                record['actual_native_domains'].append(dict(day=day,header=list(first),duplicated_witness_exact=True,
                                                            macro_bytes=len(raw),macro_sha256=SHA(raw)))
        record['cold'] = [own(build,args.reference_work,project,args.output/'trajectory',data,start,end,args.output/('own-'+str(start))) for start,end in windows]
        record['status'] = ('ACTUAL_TWO_DAY_ACTIVE_VAPOR_PAIRED9_BUILD_NATIVE_AND_EXACT_COLD_PREFLIGHT_PASS_NOT_QUALIFIED'
                            if args.days == 2 else 'ACTUAL35_DAY_ACTIVE_VAPOR_PAIRED9_RUNTIME_NATIVE_AND_THREE_EXACT_COLD_WINDOWS_PASS_INDEPENDENT_SCIENCE_PENDING')
    except Exception as error:
        record.update(status='FAILED_ACTUAL_ACTIVE_VAPOR9_PREFLIGHT_NOT_QUALIFIED',error=repr(error))
        raise
    finally:
        record.update(seconds=time.perf_counter()-started,actual_completion_head=git('rev-parse','HEAD'))
        save()
    assert record['actual_completion_head'] == head
    print(record['status'],record['kind'],record['seconds'],flush=True)


if __name__ == '__main__':
    main()
