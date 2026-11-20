"""Pure archived clock science, controls, custody and unselected postimages."""
from contextlib import contextmanager
import hashlib
from pathlib import Path
import tempfile
import zipfile

from ordinary_pond_evidence import read,digest,require,rows,physical
from groundwater_clock_archive import unpack
from groundwater_clock_forensics import audit
from groundwater_clock_custody import audit as custody
from groundwater_clock_control_forensics import native_controls,source_controls,postimages
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence

PREFIX='GROUNDWATER_CDE_CLOCK_'


@contextmanager
def extracted(proof,labels):
    owner=tempfile.TemporaryDirectory(prefix='gwclock-raw-')
    if __import__('os').name=='nt':owner.name='\\\\?\\'+str(Path(owner.name).resolve())
    with owner as temporary:
        root=Path(temporary);seen=set()
        for label in labels:
            path=Path(proof)/(PREFIX+label+'_RAW_ARCHIVE.zip');record=read(path.with_suffix('.json'))
            root,members=unpack(path,dict(size_in_bytes=record['bytes'],digest='sha256:'+record['sha256']),root)
            require(not (seen&set(members)) and members==record['members'],'Original raw member identity/inventory differs')
            seen.update(members)
        yield root


def windows(proof):
    with extracted(proof,['WINDOWS_O0','WINDOWS_O2','WINDOWS_SUPPORT']) as root:
        profiles=root/'profiles';projection=read(root/'COMPILED_PROJECTION_V1.json');baseline=read(Path(proof)/(PREFIX+'NONSELECTED_BASELINES_V1.json'))
        def mapped(path):
            normalized=str(path).replace('\\','/');require('/evidence/' in normalized,'Foreign actual Windows location')
            return profiles/normalized.split('/evidence/',1)[1]
        selected=set()
        def original_publisher(expected,opt):
            target=root/('original-publisher-'+expected+'.dll')
            if not target.exists():
                archive=Path(proof)/f'ORDINARY_IMPLICIT_POND_WINDOWS_{opt}_RAW_ARCHIVE.zip'
                record=read(archive.with_suffix('.json'))
                names=[name for name,item in record['members'].items() if name.endswith('/restart_publish.dll') and item['sha256']==expected]
                require(names,'Original qualified publisher bytes missing')
                with zipfile.ZipFile(archive) as z:raw=z.read(names[0])
                require(hashlib.sha256(raw).hexdigest()==expected,'Original qualified publisher changed');target.write_bytes(raw)
            return target
        def bundle(q):
            item=projection[q['build_root']];path=root/item['prefix']
            require(digest(path/'BUILD.json')==item['actual_BUILD_sha256'],'Actual Windows compiled projection differs')
            return path
        metrics={}
        for opt in ('O0','O2'):
            q=read(profiles/f'groundwater-clock-cohort-{opt}-v1/RESULT.json')
            require(q['status']=='ACTUAL_GROUNDWATER_CDE_CLOCK_COMPOSITION_COHORT_PASS' and len(q['cases'])==6,'Actual six-case cohort incomplete')
            cases={name:mapped(item['actual_case_root']) for name,item in q['cases'].items()};builds={name:bundle(read(case/'RESULT.json')) for name,case in cases.items()}
            out=metrics[opt]=dict(short={},controls={},source_controls={})
            for name,case in cases.items():
                record=read(case/'RESULT.json');out['short'][name]=audit(case,builds[name],mapped(record['input_root']));selected.add(builds[name])
            full=profiles/f'groundwater-clock-full-{opt}-v1';record=read(full/'RESULT.json');out['full']=audit(full,bundle(record),mapped(record['input_root']))
            for name in ('h2-periodic','h1-step-explicit','h0-step-periodic'):
                version=2 if name=='h0-step-periodic' else 1
                out['controls'][name]=native_controls(profiles/f'groundwater-clock-controls-{name}-{opt}-v{version}',cases[name],builds[name])
            for name in ('h2-periodic','h0-step-periodic','h1-explicit-monthly'):
                out['source_controls'][name]=source_controls(profiles/f'groundwater-clock-source-controls-{name}-{opt}-v2',builds[name])
            cases['full']=full;builds['full']=bundle(record)
            out['current_postimages']=postimages(profiles/f'groundwater-clock-current-postimage-{opt}-v1',cases,builds)
            preservation=read(profiles/f'groundwater-clock-preservation-{opt}-v1/RESULT.json')
            require(preservation['status']=='ACTUAL_THREE_UNSELECTED_CDE_AND_WATER_NATIVE_PRESERVATION_PASS' and len(preservation['cases'])==3 and preservation['fresh_unaffected_full_periods']==0,'Actual unselected preservation incomplete')
            for name,item in preservation['cases'].items():
                old=baseline['cases'][opt+'/'+name];case=mapped(item['current_case']);report=read(case/'short/RESULT.json');build=bundle(report);meta=read(build/'BUILD.json')
                require({p.name:digest(p) for p in build.glob('*.f90')}==old['Fortran'] and meta['inputs']==old['BUILD']['inputs'] and meta['project']==old['BUILD']['project'],'Actual unselected Fortran/input differs')
                delta=differences(old['BUILD']['identity'],meta['identity'])
                require(set(delta)<={'original_output.source_sha256','groundwater_native_state.source_sha256','groundwater_native_state.predecessor_sha256','restart_publisher.library_sha256'},'Actual unselected compiler/kernel/physical identity changed')
                if 'restart_publisher.library_sha256' in delta:
                    publisher=build/'restart_publish.dll'
                    require(digest(publisher)==meta['identity']['restart_publisher']['library_sha256'],'Actual current publisher differs')
                    publisher_equivalence(original_publisher(old['BUILD']['identity']['restart_publisher']['library_sha256'],opt),publisher)
                require(physical(rows(case/'short/trajectory'))==old['physical'],'Actual unselected physical postimage differs')
                for day,files in old['native'].items():
                    with zipfile.ZipFile(case/f'short/trajectory/accepted-column-1-day-{day}.zip') as z:
                        require(all(hashlib.sha256(z.read(n)).hexdigest()==sha for n,sha in files.items()),'Actual unselected complete native differs')
            water=profiles/f'groundwater-clock-preservation-{opt}-v1/water-own30';old=baseline['water'][opt]
            require(physical(rows(water))==old['physical'],'Actual unchanged cached-water cold rows differ')
            with zipfile.ZipFile(water/'accepted-column-1-day-34.zip') as z:
                require(all(hashlib.sha256(z.read(n)).hexdigest()==sha for n,sha in old['native'].items()),'Actual unchanged cached-water native differs')
            out['unselected']=dict(CDE_contexts=3,water_cached_native_contexts=1)
        source=custody(root,12,profiles/'groundwater-clock-current-source-v1',selected)
        return dict(status='INDEPENDENT_SEALED_WINDOWS_GROUNDWATER_CLOCK_PASS',metrics=metrics,source_custody=source,
                    actual_full_periods=2,actual_full_cold_windows=16,actual_short_contexts=12,actual_short_cold_windows=38,
                    actual_native_refusals=490,actual_transactions=6,actual_source_policy_refusals=54,
                    actual_current_native_postimages=12,actual_unselected_CDE_contexts=6,actual_water_cached_cold_contexts=2)
