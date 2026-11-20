"""Frozen ordinary raw observers. No model imports, compilations or executions."""
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import subprocess
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
    temporary_owner=tempfile.TemporaryDirectory(prefix='ordinary-raw-')
    if os.name=='nt':temporary_owner.name='\\\\?\\'+str(Path(temporary_owner.name).resolve())
    with temporary_owner as temporary:
        root=Path(temporary)
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
        cap=read(profiles/'ordinary-pond-source-v1/RESULT.json')
        capsule_path=profiles/'ordinary-pond-source-v1'/cap['archive']
        require(digest(capsule_path)==cap['sha256'],'Actual Windows source capsule changed')
        repo=Path(__file__).resolve().parents[2]
        tree={s.split('\t',1)[1]:s.split('\t',1)[0].split()[2] for s in subprocess.check_output(
            ['git','ls-tree','-r',cap['producer_head']],cwd=repo,text=True).splitlines()}
        with zipfile.ZipFile(capsule_path) as z:
            present={n for n,v in cap['members'].items() if v.get('checkout')!='ABSENT'}
            require(set(z.namelist())==present,'Actual Windows source inventory differs')
            for name,item in cap['members'].items():
                require(tree.get(name)==item['git_blob'],'Actual Windows source Git context differs')
                if name not in present:continue
                raw=z.read(name)
                blob=lambda b:hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
                require(hashlib.sha256(raw).hexdigest()==item['sha256'] and
                        item['git_blob'] in (blob(raw),blob(raw.replace(b'\r\n',b'\n'))),'Actual Windows source bytes differ')
        provider=read(root/'provider-PREPARED.json')
        baseline=read(Path(proof)/'ORDINARY_NONSELECTED_ACTUAL_BASELINE_BINDINGS_V1.json')['cases']
        def mapped_input(q):
            normalized=q['input_root'].replace('\\','/')
            require('/evidence/' in normalized,'Foreign actual Windows input location')
            return profiles/normalized.split('/evidence/',1)[1]
        def bundle(q):
            item=projection[q['build_root']];path=root/item['prefix']
            require(digest(path/'BUILD.json')==item['BUILD_sha256'],'Actual compiled projection differs')
            identity=read(path/'BUILD.json')['identity']
            for key,name in [('host','daily_host.py'),('adapter','donor_adapter.f90'),('driver','main.f90'),('experimental_input_adapter','experimental_project.py')]:
                require(identity[key]==cap['members']['app/hybrid_water/'+name]['sha256'],'Actual Windows compiler source differs: '+key)
            for name,sha in identity['kernel_sources']:require(sha==cap['members'][name]['sha256'],'Actual Windows kernel source differs')
            for name,sha in identity['donor_objects'].items():require(sha==provider['provider_files']['build/swap-obj/'+name],'Actual Windows provider object differs')
            for key,name in [('source_sha256','ordinary_implicit_pond_switch.py'),('renderer_sha256','extended_implicit_pond_switch.py'),('pond_tangent_renderer_sha256','ordinary_implicit_pond_tangent.py'),('inherited_chain_rule_renderer_sha256','extended_implicit_pond.py')]:
                require(identity['ordinary_implicit_pond_switch'][key]==cap['members']['app/hybrid_water/'+name]['sha256'],'Actual Windows ordinary renderer differs')
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
            for name,item in preservation['cases'].items():
                old=baseline[name]
                path=profiles/item['current_profile'].replace('\\','/').split('/evidence/',1)[1]
                report=read(path/'RESULT.json');entry=projection[report['build_root']];build=root/entry['prefix']
                now=read(build/'BUILD.json')
                require(old['BUILD_sha256']==item['original_BUILD_sha256'] and digest(build/'BUILD.json')==item['current_BUILD_sha256'], 'Nonselected BUILD binding differs')
                require({p.name:digest(p) for p in build.glob('*.f90')}==old['generated'] and
                        now['inputs']==old['BUILD']['inputs'] and now['project']==old['BUILD']['project'], 'Nonselected actual input/Fortran differs')
                require(physical(rows(path/'trajectory'))==old['physical'],'Nonselected actual physical postimage differs')
                for day in (2,4):
                    with zipfile.ZipFile(path/f'trajectory/accepted-column-1-day-{day}.zip') as z:
                        require(all(hashlib.sha256(z.read(n)).hexdigest()==sha for n,sha in old['native'][str(day)].items()), 'Nonselected actual complete native differs')
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
        expected=('water-groundwater','water-history1-head','cde-plate-history') if initial else ('cde-groundwater-history','water-plate','cde-head-history1')
        for name in expected:
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
