"""Independently read sealed implicit Snow observations; never run a model."""
from contextlib import contextmanager
import json
import hashlib
from pathlib import Path
import tempfile
import zipfile

from groundwater_snow_archive_storage import materialize
from groundwater_clock_archive import unpack
from ordinary_pond_evidence import read,digest,require
from implicit_snow_forensics import audit
from implicit_snow_custody import audit as custody
from implicit_snow_recovery_forensics import audit as recovery
from implicit_snow_recovery_forensics import transaction_payloads
from implicit_snow_control_forensics import native_controls,source_controls

PREFIX='IMPLICIT_SNOW_COMPOSITION_'


@contextmanager
def extracted(proof,labels):
    with tempfile.TemporaryDirectory(prefix='implicit-snow-raw-') as scratch:
        base=Path(scratch);seen=set()
        for label in labels:
            record=read(Path(proof)/(PREFIX+label+'_RAW_ARCHIVE.json'))
            archive=materialize(proof,record,base/'archives')
            root,members=unpack(archive,dict(size_in_bytes=record['bytes'],digest='sha256:'+record['sha256']),base/'raw')
            require(members==record['members'] and not seen.intersection(members),'Original implicit Snow inventory differs')
            seen.update(members)
        yield root


def ubuntu(proof,opt):
    require(opt in ('O0','O2'),'Foreign implicit Snow optimization')
    with extracted(proof,['UBUNTU_'+opt+'_INITIAL']) as original,extracted(proof,['UBUNTU_'+opt+'_FIRST_RECOVERY']) as first,extracted(proof,['UBUNTU_'+opt+'_FINAL_RECOVERY']) as final:
        cohort=original/'implicit-snow';projection=read(original/'COMPILED_PROJECTION_V1.json')
        def locations(profile):
            p=read(profile/'RESULT.json');entry=projection[p['build_root']];bundle=original/entry['archive_prefix']
            require(digest(bundle/'BUILD.json')==entry['actual_BUILD_sha256'],'Actual portable build projection differs')
            return bundle,original/p['input_root'].split('/proof/',1)[1]
        shorts={};builds=[]
        cases=read(cohort/'source-forms/RESULT.json')['cases'];require(len(cases)==9,'Portable implicit Snow context denominator differs')
        for label in cases:
            profile=cohort/'short'/label;b,i=locations(profile);builds.append(b);shorts[label]=audit(profile,b,i)
        full={}
        for label in ('water-head','cde-groundwater-clock','cde-head-step'):
            profile=cohort/('full-'+label);b,i=locations(profile);full[label]=audit(profile,b,i)
        controls=recovery(original,first,final);source=custody(original,builds)
        require(sum(r['actual_cold_windows'] for r in shorts.values())==27 and
            all(r['actual_days']==35 for r in shorts.values()) and all(r['actual_days']==1096 and
            r['actual_cold_windows']==9 for r in full.values()),'Actual portable science denominator differs')
        return dict(status='INDEPENDENT_SEALED_PORTABLE_IMPLICIT_SNOW_PASS',short=shorts,full=full,
            controls=controls,source_custody=source,actual_short_contexts=9,actual_short_cold_windows=27,
            actual_full_periods=3,actual_full_cold_windows=27,actual_fresh_compiled_refusals=50,
            actual_fresh_source_refusals=48,actual_transaction_contexts=4,models=0,compilations=0)


def windows(proof):
    labels=['WINDOWS_'+o+'_'+r for o in ('O0','O2') for r in ('SCIENCE','CONTROLS')]+['WINDOWS_SUPPORT']
    with extracted(proof,labels) as root:
        profiles=root/'profiles';projection=read(root/'COMPILED_PROJECTION_V1.json');out={}
        def mapped(path):
            normalized=str(path).replace('\\','/');require('/evidence/' in normalized,'Foreign original Windows location')
            return profiles/normalized.split('/evidence/',1)[1]
        def bundle(path):
            entry=projection[str(path)];result=root/entry['prefix']
            require(digest(result/'BUILD.json')==entry['actual_BUILD_sha256'],'Actual Windows compiled projection differs')
            return result
        cases_by_opt={}
        for opt in ('O0','O2'):
            cohort=read(root/'observations'/f'IMPLICIT_SNOW_WINDOWS_CURRENT_COHORT_{opt}_V1.json')
            require(len(cohort['cases'])==9,'Actual Windows context denominator differs')
            q=out[opt]=dict(short={},full={},native={},source={},transactions={});builds=[];cases={};cases_by_opt[opt]=cases
            for label,item in cohort['cases'].items():
                profile=mapped(item['actual_case_root']);p=read(profile/'RESULT.json');b=bundle(p['build_root'])
                require(digest(profile/'RESULT.json')==item['actual_original_receipt_sha256'] and
                    digest(b/'BUILD.json')==item['actual_BUILD_sha256'],'Original selected Windows producer changed')
                q['short'][label]=audit(profile,b,mapped(p['input_root']));builds.append(b);cases[label]=(profile,b,mapped(p['input_root']))
            for label,name in (('water-head',f'implicit-snow-root-full-water-{opt}-v1'),
                ('cde-groundwater-clock',f'implicit-snow-full-cde-{opt}-v1'),('cde-head-step',f'implicit-snow-cde-root-full-head-{opt}-v2')):
                profile=profiles/name;p=read(profile/'RESULT.json')
                q['full'][label]=audit(profile,bundle(p['build_root']),mapped(p['input_root']))
            native_labels=(('water-head',f'implicit-snow-root-native-{opt}-v1'),
                           ('cde-head-step' if opt=='O0' else 'cde-flux-interval',f'implicit-snow-cde-root-native-{opt}-v1'))
            if opt=='O2':native_labels=(('water-flux-step',f'implicit-snow-root-native-{opt}-v1'),native_labels[1])
            for label,name in native_labels:
                profile,b,i=cases[label];q['native'][label]=native_controls(profiles/name,profile,b,i)
            if opt=='O0':
                for role,label in (('water','water-head'),('cde','cde-head-step'),('groundwater','cde-groundwater-clock'),('interval','cde-groundwater-interval')):
                    q['source'][label]=source_controls(profiles/f'implicit-snow-source-refusals-{role}-O0-v1',cases[label][1])
            q['source_custody']=custody(root,builds,profiles/'implicit-snow-current-source-v1')
            with zipfile.ZipFile(profiles/'implicit-snow-current-source-v1/actual-producer-source.zip') as z:
                external_source=hashlib.sha256(z.read('app/hybrid_water/daily_coupling.py')).hexdigest()
            transaction_root=profiles/f'implicit-snow-transactions-{opt}-v1';record=read(transaction_root/'RESULT.json')
            require(set(record)=={'water','cde-head','cde-groundwater','cde-interval'},'Actual Windows transaction denominator differs')
            for role,label in (('water','water-head'),('cde-head','cde-head-step'),('cde-groundwater','cde-groundwater-clock'),('cde-interval','cde-groundwater-interval')):
                require(record[role]['status']=='ACTUAL_TRANSACTION_PASS' and record[role]['checks']==dict.fromkeys(
                    ('discard_no_day_advance','replay_exact','accept_exact','recovered_next_day_exact','origin_unchanged'),True),
                    'Actual Windows transaction checks differ')
                profile,b,i=cases[label];q['transactions'][label]=transaction_payloads(transaction_root/role,profile,b,i,external_source)
        require(sum(v['actual_cold_windows'] for q in out.values() for v in q['short'].values())==54 and
            all(v['actual_days']==35 for q in out.values() for v in q['short'].values()) and
            all(v['actual_days']==1096 and v['actual_cold_windows']==9 for q in out.values() for v in q['full'].values()),
            'Actual Windows science denominator differs')
        from implicit_snow_postimage_forensics import audit as postimages
        preservation=postimages(root,proof,cases_by_opt,bundle,mapped)
        return dict(status='INDEPENDENT_SEALED_WINDOWS_IMPLICIT_SNOW_SCIENCE_CONTROLS_PASS',metrics=out,
            actual_short_contexts=18,actual_short_cold_windows=54,actual_full_periods=6,actual_full_cold_windows=54,
            actual_fresh_compiled_refusals=100,actual_fresh_source_refusals=48,models=0,compilations=0,
            actual_transaction_contexts=8,preservation=preservation,actual_unselected_contexts=12,actual_unselected_cold_windows=12)
