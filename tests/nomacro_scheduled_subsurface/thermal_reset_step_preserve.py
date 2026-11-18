"""Actual admitted Snow subdaily clocks across the new FLPRINTDT dispatch."""
import argparse,hashlib,json,subprocess,sys,zipfile
from pathlib import Path,PurePosixPath
import thermal_reset_runtime as current

m=current.m;ROOT=current.ROOT

def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','prior-calendar-root','evidence-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--platform',choices=('Windows','Ubuntu'),default='Windows')
    p.add_argument('--resume',action='store_true')
    a=p.parse_args();a.output.mkdir(exist_ok=a.resume);q=dict(status='RUNNING',optimization=a.optimization,platform=a.platform,profiles={})
    if a.resume:q['retained_previous_report']=json.loads((a.output/'RESULT.json').read_text())
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    authority=ROOT/'integration/f-ci/nomacro-complete01/THERMAL_STEP_QUALIFICATION.json'
    qualification=json.loads(authority.read_text(encoding='utf8'))
    members=qualification['archives']['THERMAL_STEP_'+a.platform.upper()+'_'+a.optimization+'_RAW_ARCHIVE.json']['members']
    root=a.prior_calendar_root;run=json.loads((root/'RESULT.json').read_text());first='monthly-hys2-binary';authority_sha=m.sha(authority)
    save()
    try:
        for key in ('monthly-hys2-binary','explicit-hys1-vector','periodic-hys0-ascii','terminal-hys2-ascii'):
            item=run['cases'][key];old=item['short'];name=key;script='thermal_step_runtime.py';days=35;endpoints=(4,8,23,34,35)
            options=('--mode',old['mode'],'--hysteresis',old['hysteresis'],'--format',old['format'],'--reset',old['reset'],'--et',old['et'],'--nprintday',old['nprintday'])
            def actual(path):
                if a.platform=='Windows':return Path(path)
                base=PurePosixPath(run['cases'][first]['short_root']).parent
                return root/PurePosixPath(path).relative_to(base)
            build=actual(item['build_root']);short=actual(item['short_root']);inputs=actual(item['input_root'])
            def qualified(path):
                relative=path.relative_to(a.evidence_root if a.platform=='Windows' else root).as_posix()
                assert hashlib.sha256(path.read_bytes()).hexdigest()==members[relative],relative
            for path in (build/'BUILD.json',short/'RESULT.json',short/'trajectory/daily.jsonl'):qualified(path)
            out=a.output/name;command=[sys.executable,'-B',str(Path(__file__).with_name(script)),'--reference-work',a.reference_work,
                '--existing-input',inputs,'--output',out,'--optimization',a.optimization,*options]
            if not out.exists():subprocess.run(list(map(str,command)),cwd=ROOT,check=True,timeout=300)
            else:assert a.resume and 'PASS' in json.loads((out/'RESULT.json').read_text())['status']
            project=m.e.load(inputs,original_output='--compatibility-output' not in options)
            meta,_=m.validate_bundle(out/'build',a.reference_work,project);previous=json.loads((build/'BUILD.json').read_text())
            assert meta['project']==previous['project'] and meta['inputs']==previous['inputs']
            for field in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library',
                'kernel_sources','original_output','lower_boundary_receipt','groundwater_native_state','cde_native_receipt'):
                assert meta['identity'].get(field)==previous['identity'].get(field),(name,field)
            assert m.physical(m.rows(out/'trajectory'))==m.physical(m.rows(short/'trajectory')) and len(m.rows(out/'trajectory'))==days
            for day in endpoints:
                source=short/f'trajectory/accepted-column-1-day-{day}.zip';qualified(source)
                with zipfile.ZipFile(source) as old,zipfile.ZipFile(out/f'trajectory/accepted-column-1-day-{day}.zip') as new:
                    for member in ('result.end','macro.bin'):assert old.read(member)==new.read(member),(name,day,member)
            for filename in ('result_output.csv','result_output.bin'):
                left=short/'trajectory/original'/filename;right=out/'trajectory/original'/filename
                if left.exists():
                    from original_output_files import records
                    qualified(left)
                    # Original headers contain the actual execution timestamp.
                    assert records(left)==records(right),(name,filename)
            report=json.loads((out/'RESULT.json').read_text());assert 'PASS' in report['status']
            q['profiles'][name]=dict(actual_build=meta,prior_build_sha256=m.sha(build/'BUILD.json'),authority_sha256=authority_sha,
                actual_immutable_prior_member_hashes=True,all_emitted_sources_exact=True,all_physical_exact=True,
                five_complete_native_payloads_exact=True,prior_native_metadata_literal=True,trajectory=report['trajectory'],cold=report['cold'])
            save();print(name,a.optimization,'LITERAL_PRIOR_SNOW_FLPRINTDT_SOURCE_NATIVE_EXACT',flush=True)
        q['status']='FOUR_ACTUAL_ADMITTED_SNOW_FLPRINTDT_CONTEXTS_SOURCE_NATIVE_USER_EXACT_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
