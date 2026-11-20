"""Read sealed interval/drainage science and unchanged integrated postimages."""
from contextlib import contextmanager
import hashlib
import os
from pathlib import Path
import tempfile
import zipfile

from ordinary_pond_evidence import read,digest,require,rows,physical
from groundwater_clock_archive import unpack
from groundwater_interval_forensics import audit
from groundwater_interval_custody import audit as custody
from groundwater_interval_control_forensics import native_controls,source_controls
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence

PREFIX='GROUNDWATER_CDE_INTERVAL_'


@contextmanager
def extracted(proof,labels):
    owner=tempfile.TemporaryDirectory(prefix='gwinterval-raw-')
    if os.name=='nt':owner.name='\\\\?\\'+str(Path(owner.name).resolve())
    with owner as directory:
        root=Path(directory);seen=set()
        for label in labels:
            path=Path(proof)/(PREFIX+label+'_RAW_ARCHIVE.zip');record=read(path.with_suffix('.json'))
            root,members=unpack(path,dict(size_in_bytes=record['bytes'],digest='sha256:'+record['sha256']),root)
            require(members==record['members'] and not (seen&set(members)),'Original interval member inventory differs')
            seen.update(members)
        yield root


def windows(proof):
    labels=['WINDOWS_'+opt+'_'+role for opt in ('O0','O2') for role in ('SCIENCE','CONTROLS')]+['WINDOWS_SUPPORT']
    with extracted(proof,labels) as root:
        profiles=root/'profiles';projection=read(root/'COMPILED_PROJECTION_V1.json')
        baseline=read(Path(proof)/(PREFIX+'NONSELECTED_BASELINES_V1.json'));selected=set();verified=set()
        def mapped(path):
            normalized=str(path).replace('\\','/');require('/evidence/' in normalized,'Foreign actual Windows interval location')
            return profiles/normalized.split('/evidence/',1)[1]
        def bundle(record):
            entry=projection[record['build_root']];path=root/entry['prefix']
            require(digest(path/'BUILD.json')==entry['actual_BUILD_sha256'],'Actual Windows interval compiled projection differs')
            return path
        def publisher(expected,opt):
            target=root/('original-publisher-'+expected+'.dll')
            if target.exists():return target
            for prefix in ('GROUNDWATER_CDE_CLOCK','ORDINARY_IMPLICIT_POND'):
                path=Path(proof)/f'{prefix}_WINDOWS_{opt}_RAW_ARCHIVE.zip';manifest=read(path.with_suffix('.json'))
                names=[n for n,item in manifest['members'].items() if n.endswith('/restart_publish.dll') and item['sha256']==expected]
                if not names:continue
                if path not in verified:
                    require(path.stat().st_size==manifest['bytes'] and digest(path)==manifest['sha256'],'Original postimage publisher archive differs')
                    verified.add(path)
                with zipfile.ZipFile(path) as z:raw=z.read(names[0])
                require(hashlib.sha256(raw).hexdigest()==expected,'Original postimage publisher bytes differ')
                with target.open('xb') as f:f.write(raw)
                return target
            raise AssertionError('Original postimage publisher missing from preserved original raw')
        metrics={}
        for opt in ('O0','O2'):
            cohort=profiles/f'groundwater-interval-cohort-{opt}-v1';report=read(cohort/'RESULT.json')
            require(report['status']=='ACTUAL_GROUNDWATER_CDE_INTERVAL_DRAINAGE_COMPOSITION_COHORT_PASS' and len(report['cases'])==8,
                    'Actual eight-case Windows interval cohort incomplete')
            out=metrics[opt]=dict(short={},native={},source_controls={});cases={};builds={}
            for name,item in report['cases'].items():
                case=mapped(item['actual_case_root']);record=read(case/'RESULT.json');path=bundle(record)
                out['short'][name]=audit(case,path,mapped(record['input_root']))
                selected.add(path);cases[name]=case;builds[name]=path
            full=profiles/f'groundwater-interval-full-{opt}-v1';record=read(full/'RESULT.json')
            out['full']=audit(full,bundle(record),mapped(record['input_root']))
            control=read(profiles/f'groundwater-interval-control-cohort-{opt}-v2/RESULT.json')
            require(control['status']=='ACTUAL_FOUR_NATIVE_THREE_SOURCE_COMPOSITION_CONTEXTS_PASS' and
                    len(control['native'])==4 and len(control['source_controls'])==3,'Actual Windows interval control cohort incomplete')
            for name,item in control['native'].items():
                out['native'][name]=native_controls(mapped(item['actual_root']),cases[name],builds[name])
            for name,item in control['source_controls'].items():
                out['source_controls'][name]=source_controls(mapped(item['actual_root']),builds[name])
            preservation=profiles/f'groundwater-interval-preservation-{opt}-v1';retained=read(preservation/'RESULT.json')
            require(retained['status']=='ACTUAL_THREE_UNCHANGED_CDE_POSTIMAGES_PASS' and len(retained['cases'])==3 and
                    retained['fresh_unaffected_full_periods']==0,'Actual unchanged interval dependency postimages incomplete')
            for name,item in retained['cases'].items():
                old=baseline['cases'][opt+'/'+name];case=preservation/name;path=bundle(dict(build_root=item['current_build']));meta=read(path/'BUILD.json')
                require(item['original_receipt_sha256']==old['original_receipt_sha256'] and
                        item['original_BUILD_sha256']==old['original_BUILD_sha256'],'Original postimage baseline receipt rebound')
                require({p.name:digest(p) for p in path.glob('*.f90')}==old['Fortran'] and
                        meta['inputs']==old['BUILD']['inputs'] and meta['project']==old['BUILD']['project'],
                        'Actual unselected interval dependency Fortran/input changed')
                delta=differences(old['BUILD']['identity'],meta['identity'])
                require(set(delta)<={'original_output.source_sha256','original_output.predecessor_owner_sha256',
                                    'groundwater_native_state.source_sha256','groundwater_native_state.predecessor_sha256',
                                    'restart_publisher.library_sha256'},'Actual unselected numerical/provider identity changed')
                if 'restart_publisher.library_sha256' in delta:
                    current=path/'restart_publish.dll';require(digest(current)==meta['identity']['restart_publisher']['library_sha256'],'Current publisher differs')
                    publisher_equivalence(publisher(old['BUILD']['identity']['restart_publisher']['library_sha256'],opt),current)
                warm=rows(case/'trajectory');cold=rows(case/'own-30')
                require(physical(warm)==old['physical'] and physical(cold)==physical(warm[30:34]),'Actual unchanged physical postimage differs')
                for day,inventory in old['native'].items():
                    with zipfile.ZipFile(case/f'trajectory/accepted-column-1-day-{day}.zip') as z:
                        require(all(hashlib.sha256(z.read(n)).hexdigest()==sha for n,sha in inventory.items()),'Actual unchanged complete native postimage differs')
                with zipfile.ZipFile(case/'own-30/accepted-column-1-day-34.zip') as z:
                    require(all(hashlib.sha256(z.read(n)).hexdigest()==sha for n,sha in old['native']['34'].items()),'Actual unchanged cold complete native differs')
            out['actual_unselected_contexts']=3
        origins=custody(root,16,profiles/'groundwater-interval-current-source-v1',selected)
        native=[v for o in metrics.values() for v in o['native'].values()]
        source=[v for o in metrics.values() for v in o['source_controls'].values()]
        require(sum(v['actual_refusals'] for v in native)==642 and sum(v['actual_refusals'] for v in source)==56,
                'Actual Windows interval controls denominator differs')
        return dict(status='INDEPENDENT_SEALED_WINDOWS_INTERVAL_DRAINAGE_SCIENCE_PASS',metrics=metrics,source_custody=origins,
                    actual_short_contexts=16,actual_short_cold_windows=50,actual_full_periods=2,actual_full_cold_windows=16,
                    actual_native_refusals=642,actual_compiled_refusals=640,actual_accepted_receipt_refusals=2,
                    actual_source_policy_refusals=56,actual_transaction_contexts=8,
                    actual_unselected_CDE_contexts=6,actual_unselected_CDE_cold_windows=6)


def ubuntu(proof,opt):
    from groundwater_interval_portable_archive import audit_root
    require(opt in ('O0','O2'),'Foreign portable interval optimization')
    with extracted(proof,['UBUNTU_'+opt]) as root:
        return audit_root(root)
