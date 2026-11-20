"""Frozen ordinary raw observers. No model imports, compilations or executions."""
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import tempfile
import zipfile

from ordinary_pond_evidence import audit_root, audit_short, read, digest, require, rows, physical
from ordinary_chain_forensics import component
from ordinary_control_forensics import audit as controls
from ordinary_source_custody import audit as custody
from ordinary_pond_forensics import component as zero_component

PREFIX='ORDINARY_IMPLICIT_POND_'


@contextmanager
def extracted(proof, labels):
    with tempfile.TemporaryDirectory(prefix='ordinary-raw-') as temporary:
        root=Path(temporary)
        if os.name=='nt':root=Path('\\\\?\\'+str(root.resolve()))
        seen=set()
        for label in labels:
            path=Path(proof)/(PREFIX+label+'_RAW_ARCHIVE.zip');q=read(path.with_suffix('.json'))
            require(path.stat().st_size==q['bytes'] and digest(path)==q['sha256'],'Changed actual ordinary raw archive: '+label)
            with zipfile.ZipFile(path) as z:
                require(len(z.namelist())==len(set(z.namelist())) and set(z.namelist())==set(q['members']), 'Actual raw inventory differs')
                for name in z.namelist():
                    parts=PurePosixPath(name)
                    require(not parts.is_absolute() and '..' not in parts.parts and ':' not in name and '\\' not in name and
                            not stat.S_ISLNK(z.getinfo(name).external_attr>>16) and name not in seen,'Unsafe/duplicate original raw member')
                    seen.add(name);raw=z.read(name);item=q['members'][name]
                    require(len(raw)==item['bytes'] and hashlib.sha256(raw).hexdigest()==item['sha256'],'Changed actual raw member: '+name)
                    target=root.joinpath(*parts.parts);target.parent.mkdir(parents=True,exist_ok=True)
                    target.write_bytes(raw)
        yield root


def windows(proof):
    with extracted(proof,['WINDOWS_O0','WINDOWS_O2','WINDOWS_SUPPORT']) as root:
        projection=read(root/'COMPILED_PROJECTION_V1.json')
        profiles=root/'profiles'
        def mapped_input(q):
            normalized=q['input_root'].replace('\\','/')
            require('/evidence/' in normalized,'Foreign actual Windows input location')
            return profiles/normalized.split('/evidence/',1)[1]
        def bundle(q):
            item=projection[q['build_root']];path=root/item['prefix']
            require(digest(path/'BUILD.json')==item['BUILD_sha256'],'Actual compiled projection differs')
            return path
        result={};full_data={}
        for opt in ('O0','O2'):
            out=result[opt]=dict(full={},short={},components={},controls={})
            for label,profile in [('water',f'ordinary-pond-chain-weighted-water-{opt}-qualified-budget-v1'),
                                  ('cde',f'ordinary-pond-cde-groundwater-full-{opt}-v1')]:
                path=profiles/profile;q=read(path/'RESULT.json')
                out['full'][label]=audit_root(path,bundle(q),mapped_input(q))
                full_data[opt,label]=physical(rows(path/'full/trajectory'))
            cohort=read(profiles/f'ordinary-pond-matrix-recovered-{opt}-v1/RESULT.json')
            for name,item in cohort['cases'].items():
                case=(profiles/item['actual_case_root'].replace('\\','/').split('/evidence/',1)[1]
                      if 'actual_case_root' in item else profiles/f'ordinary-pond-matrix-recovered-{opt}-v1'/name)
                q=read(case/'short/RESULT.json');out['short'][name]=audit_short(case,bundle(q),mapped_input(q))
            water=read(profiles/f'ordinary-pond-chain-weighted-water-{opt}-qualified-budget-v1/RESULT.json')
            for label,folder in [('chain','current-tangent'),('limits','limits-component')]:
                out['components'][label]=component(profiles/f'ordinary-pond-{folder}-{opt}-v1',bundle(water))
            for case in ('groundwater','water-step','cde','water','cde-step'):
                out['controls'][case]=controls(profiles/f'ordinary-pond-source-controls-{case}-{opt}-v1')
            post=read(profiles/f'ordinary-current-postimage-{opt}-v1/RESULT.json')
            require(post['status']=='ACTUAL_CURRENT_ORDINARY_GUARD_NINE_NATIVE_POSTIMAGES_PASS' and
                    post['fresh_compilations']==post['repeated_full_periods']==0 and len(post['cases'])==7,
                    'Actual current read-only postimage incomplete')
            count=0
            for case,item in post['cases'].items():
                source=profiles/item['actual_original_receipt'].replace('\\','/').split('/evidence/',1)[1]
                require(digest(source)==item['receipt_sha256'] and
                        item['original_receipt_and_BUILD_unchanged'] is True,'Actual source postimage rebound')
                origin=source.parent/('full/trajectory' if case.endswith('-full') else 'trajectory')
                warm=rows(origin)
                for window in item['cold']:
                    start,end=window['start'],window['end'];cold=profiles/f'ordinary-current-postimage-{opt}-v1'/case/f'own-{start}'
                    require(physical(rows(cold))==physical(warm[start:end]),'Current postimage physical rows differ')
                    with zipfile.ZipFile(origin/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(cold/f'accepted-column-1-day-{end}.zip') as b:
                        require(all(a.read(n)==b.read(n) for n in ('result.end','macro.bin')),'Current complete native postimage differs')
                    require(window['exact_physical'] is window['exact_complete_native'] is window['origin_unchanged'] is True,'Current source guard continuation failed')
                    count+=1
            require(count==9,'Current native postimage denominator differs')
            tx=read(profiles/f'ordinary-transactions-{opt}-v1/RESULT.json')
            require(tx['status']=='ACTUAL_CURRENT_ORDINARY_WATER_CDE_TRANSACTION_PASS' and
                    set(tx['cases'])=={'water','cde'} and all(v is True for case in tx['cases'].values() for v in case.values()),'Actual transactions incomplete')
            preservation=read(profiles/f'ordinary-nonselected-{opt}-v1/RESULT.json')
            require(preservation['status']=='ACTUAL_THREE_NONSELECTED_OWNERS_POSTIMAGE_PASS' and
                    len(preservation['cases'])==3 and preservation['fresh_full_periods']==0,'Nonselected preservation incomplete')
            out.update(current_native_postimages=count,transactions=tx['cases'],nonselected=preservation['cases'])
        require(full_data['O0','water']==full_data['O2','water'] and
                full_data['O0','cde']==full_data['O2','cde'],'Actual cross optimization physical rows differ')
        result['original_zero_switch']=zero_component(profiles/'ordinary-pond-component-O0-v1')
        return dict(status='INDEPENDENT_WINDOWS_ORDINARY_RAW_SCIENCE_PASS',metrics=result,
                    actual_full_periods=4,actual_full_cold_windows=32,short_contexts=12,
                    source_policy_refusals=200,current_native_postimages=18,transactions=4,nonselected_contexts=6)


def ubuntu(proof,opt,initial):
    label='UBUNTU_'+('INITIAL_' if initial else 'FOLLOWUP_')+opt
    with extracted(proof,[label]) as root:
        projection=read(root/'COMPILED_PROJECTION_V1.json')
        def bundle(q):
            entry=projection[q['build_root']];result=root/entry['archive_prefix']
            require(digest(result/'BUILD.json')==entry['actual_BUILD_sha256'],'Ubuntu compiled projection differs')
            return result
        matrix=root/'ordinary-matrix';short={}
        for name in read(matrix/'RESULT.json')['cases']:
            case=matrix/name;q=read(case/'short/RESULT.json');short[name]=audit_short(case,bundle(q),case/'input')
        require(len(short)==3,'Ubuntu selected short denominator differs')
        name='ordinary-water' if initial else 'ordinary-cde';path=root/name;q=read(path/'RESULT.json')
        full=audit_root(path,bundle(q),path/'input' if initial else matrix/'cde-groundwater-history/input')
        component_result=component(root/('ordinary-components' if initial else 'ordinary-limits'),bundle(q))
        refusals={} if initial else {name:controls(matrix/name/'source-controls') for name in short}
        sources=custody(root)
        return dict(status='INDEPENDENT_UBUNTU_ORDINARY_RAW_SCIENCE_PASS',full=full,short=short,
                    component=component_result,source_policy_refusals=refusals,source_custody=sources,
                    original_job_conclusion='failure' if initial else 'success',
                    initial_failure='Unsupported subdaily CDE groundwater fixture after these successful observations' if initial else None)
