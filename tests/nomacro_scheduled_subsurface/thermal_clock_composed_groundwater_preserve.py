"""Actual admitted CDE history and ordinary groundwater across the new water dispatch."""
import argparse,hashlib,json,subprocess,sys,zipfile
from pathlib import Path,PurePosixPath
import thermal_clock_runtime as current

m=current.m;ROOT=current.ROOT

def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','prior-history-root','prior-ordinary-root','evidence-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--platform',choices=('Windows','Ubuntu'),default='Windows')
    a=p.parse_args();a.output.mkdir();q=dict(status='RUNNING',optimization=a.optimization,platform=a.platform,profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    sources={}
    for family,root,authority,first in [('history',a.prior_history_root,'GROUNDWATER_HISTORY','hys1-snow0-original'),
        ('ordinary',a.prior_ordinary_root,'GROUNDWATER_CHEMICAL','within-csv3')]:
        path=ROOT/'integration/f-ci/nomacro-complete01'/str(authority+'_QUALIFICATION.json');qualification=json.loads(path.read_text(encoding='utf8'))
        members=qualification['archives'][authority+'_'+a.platform.upper()+'_'+a.optimization+'_RAW_ARCHIVE.json']['members']
        run=json.loads((root/'RESULT.json').read_text());sources[family]=(root,run,members,first,m.sha(path))
    save()
    try:
        for name,family,key,script,options,days,endpoints in [
            ('cde-hys2-snow','history','hys2-snow1-original','groundwater_history_runtime.py',('--hysteresis',2,'--snow',1,'--format',3,'--kind','crossing'),35,(4,8,23,34,35)),
            ('cde-heat0-default','history','hys1-heat0-drain0-et1-default','groundwater_history_runtime.py',('--hysteresis',1,'--snow',0,'--format',1,'--kind','crossing','--heat',0,'--drainage',0,'--et',1,'--oxygen',1,'--compatibility-output'),35,(4,8,23,34,35)),
            ('ordinary-cde-default','ordinary','crossing-default','groundwater_chemical_runtime.py',('--kind','crossing','--format',1,'--compatibility-output'),10,(2,4,7,9,10))]:
            root,run,members,first,authority_sha=sources[family];item=run['cases'][key]
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
            subprocess.run(list(map(str,command)),cwd=ROOT,check=True,timeout=300)
            project=m.e.load(inputs,original_output='--compatibility-output' not in options)
            meta,_=m.validate_bundle(out/'build',a.reference_work,project);previous=json.loads((build/'BUILD.json').read_text())
            current_project=dict(meta['project'])
            assert project.water_polish_policy==m.h.ALWAYS_WATER_POLISH
            assert 'water_polish_policy' not in previous['project'] and 'water_polish_policy' not in previous['identity']
            assert meta['identity']['water_polish_policy']==m.h.ALWAYS_WATER_POLISH
            assert current_project==previous['project'] and meta['inputs']==previous['inputs']
            for field in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library',
                'kernel_sources','original_output','lower_boundary_receipt','groundwater_native_state','cde_native_receipt'):
                assert meta['identity'].get(field)==previous['identity'].get(field),(name,field)
            assert m.physical(m.rows(out/'trajectory'))==m.physical(m.rows(short/'trajectory')) and len(m.rows(out/'trajectory'))==days
            for day in endpoints:
                source=short/f'trajectory/accepted-column-1-day-{day}.zip';qualified(source)
                with zipfile.ZipFile(source) as old,zipfile.ZipFile(out/f'trajectory/accepted-column-1-day-{day}.zip') as new:
                    for member in ('result.end','macro.bin'):assert old.read(member)==new.read(member),(name,day,member)
            report=json.loads((out/'RESULT.json').read_text());assert 'PASS' in report['status']
            q['profiles'][name]=dict(actual_build=meta,prior_build_sha256=m.sha(build/'BUILD.json'),authority_sha256=authority_sha,
                actual_immutable_prior_member_hashes=True,all_emitted_sources_exact=True,all_physical_exact=True,
                five_complete_native_payloads_exact=True,prior_native_metadata_literal=True,trajectory=report['trajectory'],cold=report['cold'])
            save();print(name,a.optimization,'LITERAL_CURRENT_GROUNDWATER_CDE_SOURCE_NATIVE_EXACT',flush=True)
        q['status']='THREE_ACTUAL_ADMITTED_GROUNDWATER_CDE_CONTEXTS_SOURCE_NATIVE_EXACT_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
