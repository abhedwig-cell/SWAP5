"""Read sealed original water Snow groundwater science and preserved dependencies."""
from contextlib import contextmanager,ExitStack
import json
from pathlib import Path
import tempfile
import zipfile

from ordinary_pond_evidence import read,digest,require,rows,physical
from groundwater_snow_archive_storage import materialize
from groundwater_clock_archive import unpack
from water_snow_groundwater_forensics import audit,original
from water_snow_groundwater_custody import audit as custody
from water_snow_groundwater_control_forensics import audit as native_controls,source_controls,transactions
from water_snow_groundwater_portable_forensics import audit_root as portable
from implicit_snow_postimage_forensics import Parent
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence

PREFIX='WATER_SNOW_GROUNDWATER_'


@contextmanager
def extracted(proof,labels):
    with tempfile.TemporaryDirectory(prefix='water-snow-raw-') as scratch:
        base=Path(scratch);seen=set()
        for label in labels:
            record=read(Path(proof)/(PREFIX+label+'_RAW_ARCHIVE.json'));path=materialize(proof,record,base/'archives')
            root,members=unpack(path,dict(size_in_bytes=record['bytes'],digest='sha256:'+record['sha256']),base/'raw')
            require(members==record['members'] and not seen.intersection(members),'Original water Snow archive inventory differs')
            seen.update(members)
        yield root


class AdmittedParent(Parent):
    def __init__(self,proof,scratch,stack):
        self.archives=[]
        for label in ['WINDOWS_'+o+'_'+r for o in ('O0','O2') for r in ('SCIENCE','CONTROLS')]+['WINDOWS_SUPPORT']:
            record=read(Path(proof)/('IMPLICIT_SNOW_COMPOSITION_'+label+'_RAW_ARCHIVE.json'));path=materialize(proof,record,scratch)
            require(path.stat().st_size==record['bytes'] and digest(path)==record['sha256'],'Inherited actual implicit Snow archive changed')
            z=stack.enter_context(zipfile.ZipFile(path));require(set(z.namelist())==set(record['members']),'Inherited implicit Snow member inventory differs')
            self.archives.append((z,record))
        self.projection=json.loads(self.get('COMPILED_PROJECTION_V1.json'))


def postimages(root,proof,bundle):
    root=Path(root);profiles=root/'profiles';out={}
    with ExitStack() as stack:
        old=AdmittedParent(proof,root/'inherited-original-archives',stack)
        for opt,version in (('O0','v2'),('O2','v1')):
            baseline=root/'observations'/f'WATER_SNOW_GROUNDWATER_UNSELECTED_BASELINES_{opt}_V1.json'
            manifest=read(baseline)['cases'];parent=profiles/f'water-snow-groundwater-postimages-{opt}-{version}';r=read(parent/'RESULT.json')
            require(r['status']=='ACTUAL_FIVE_UNCHANGED_WATER_SNOW_GROUNDWATER_POSTIMAGES_PASS' and
                len(r['cases'])==5 and r['baseline_sha256']==digest(baseline) and r['fresh_unaffected_full_periods']==0,
                'Actual unchanged dependency postimages incomplete')
            result=out[opt]={}
            for label,item in r['cases'].items():
                b=manifest[label];require(item['baseline']==b,'Original postimage baseline rebound')
                require(__import__('hashlib').sha256(old.get(old.profile(b['receipt']))).hexdigest()==b['receipt_sha256'],
                    'Actual inherited baseline producer changed')
                prefix,oldmeta=old.build(b['build_root'])
                if item['build_root']==b['build_root']:
                    meta=oldmeta;require(item['fresh_compilations']==0 and item['actual_BUILD_sha256']==old.projection[b['build_root']]['actual_BUILD_sha256'],
                        'Actual unchanged original build rebound')
                else:
                    current=bundle(item['build_root']);meta=read(current/'BUILD.json')
                    require(item['fresh_compilations']==1 and old.fortran(prefix)=={p.name:p.read_bytes() for p in current.glob('*.f90')},
                        'Actual unchanged complete Fortran differs')
                    delta=differences(oldmeta['identity'],meta['identity'])
                    require(set(delta)<={'implicit_groundwater_trial.source_sha256','restart_publisher.library_sha256'} and delta==item['identity_changes'],
                        'Unselected dependency changed beyond exact metadata context')
                    if 'restart_publisher.library_sha256' in delta:
                        publisher=root/f'original-publisher-{opt}-{label}.dll';publisher.write_bytes(old.get(prefix+'/restart_publish.dll'))
                        require(digest(publisher)==oldmeta['identity']['restart_publisher']['library_sha256'],'Inherited actual publisher differs')
                        publisher_equivalence(publisher,current/'restart_publish.dll')
                require(meta['inputs']==oldmeta['inputs'] and meta['project']==oldmeta['project'],'Actual unchanged project/input identity differs')
                def mapped(path):return profiles/str(path).replace('\\','/').split('/evidence/',1)[1]
                warm=mapped(item['trajectory_root']);cold=mapped(item['cold_actual_root']);data=rows(warm);own=rows(cold)
                original_rows=[json.loads(line) for line in old.get(old.profile(b['trajectory_root'])+'/daily.jsonl').decode().splitlines()]
                require(len(data)==35 and physical(data)==physical(original_rows) and physical(own)==physical(data[30:34]),
                    'Actual unchanged dependency physical postimage differs')
                require(read(warm/'BUILD.json')==meta,'Actual observed postimage BUILD changed')
                for day in (2,4,7,9,30,34,35):
                    name=f'accepted-column-1-day-{day}.zip';raw=old.get(old.profile(b['trajectory_root'])+'/'+name)
                    with zipfile.ZipFile(__import__('io').BytesIO(raw)) as a,zipfile.ZipFile(warm/name) as c:
                        require(all(a.read(n)==c.read(n) for n in ('macro.bin','result.end')),'Actual unchanged complete native differs')
                        if day==34:
                            with zipfile.ZipFile(cold/name) as d:require(all(c.read(n)==d.read(n) for n in ('macro.bin','result.end')),'Actual postimage cold native differs')
                outputs={};coldoutputs={}
                for name in ('result_output.csv','result_output.bin'):
                    if (warm/'original'/name).exists():
                        outputs[name]=original.output_records((warm/'original'/name).read_bytes(),name)
                        require(outputs[name]==original.output_records(old.get(old.profile(b['trajectory_root'])+'/original/'+name),name),'Actual unchanged user records differ')
                    if (cold/'original'/name).exists():coldoutputs[name]=original.output_records((cold/'original'/name).read_bytes(),name)
                require(original.output_continuation(outputs,coldoutputs,meta['identity']['original_output'],30,34,meta['project']['start_date'])==item['cold']['exact_original_output'],
                    'Actual unchanged cold user records differ')
                result[label]=dict(status='INDEPENDENT_UNCHANGED_SOURCE_PHYSICAL_NATIVE_OUTPUT_POSTIMAGE_PASS',actual_BUILD_sha256=item['actual_BUILD_sha256'])
    return dict(status='INDEPENDENT_TEN_UNCHANGED_WATER_SNOW_POSTIMAGES_PASS',metrics=out,
        actual_unselected_contexts=10,actual_unselected_cold_windows=10,fresh_unaffected_full_periods=0)


def windows(proof):
    labels=['WINDOWS_'+o+'_'+r for o in ('O0','O2') for r in ('SCIENCE','CONTROLS')]+['WINDOWS_SUPPORT']
    with extracted(proof,labels) as root:
        profiles=root/'profiles';projection=read(root/'COMPILED_PROJECTION_V1.json');out={};cases={}
        def mapped(path):
            normalized=str(path).replace('\\','/');require('/evidence/' in normalized,'Foreign actual Windows water Snow location')
            return profiles/normalized.split('/evidence/',1)[1]
        def bundle(path):
            item=projection[str(path)];b=root/item['prefix'];require(digest(b/'BUILD.json')==item['actual_BUILD_sha256'],'Actual Windows compiler projection differs');return b
        def locations(profile):
            r=read(profile/'RESULT.json');b=bundle(r['build_root']);i=mapped(r['input_root'])
            warm=mapped(r['trajectory_root']) if r.get('trajectory_root') else profile/'trajectory'
            cold=[mapped(v) for v in r['cold_actual_roots']] if r.get('cold_actual_roots') else [profile/f"own-{x['start']}" for x in r['cold']]
            return b,i,warm,cold
        for opt in ('O0','O2'):
            manifest=read(root/'observations'/f'WATER_SNOW_GROUNDWATER_WINDOWS_CURRENT_COHORT_{opt}_V2.json')
            require(len(manifest['cases'])==9,'Actual selected Windows context denominator differs')
            q=out[opt]=dict(short={},full={});builds=[]
            for label,item in manifest['cases'].items():
                profile=mapped(item['actual_case_root']);b,i,w,c=locations(profile)
                require(digest(profile/'RESULT.json')==item['actual_original_receipt_sha256'] and digest(b/'BUILD.json')==item['actual_BUILD_sha256'],
                    'Actual selected original Windows receipt/BUILD changed')
                q['short'][label]=audit(profile,b,i,w,c);builds.append(b);cases[opt+'/'+label]=(profile,b,i,w)
            for label,name in (('explicit-h2-clock',f'water-snow-groundwater-full-{opt}-v1-explicit-h2-clock'),
                ('implicit-h1-step-reset',f'water-snow-groundwater-full-{opt}-v1-implicit-h1-step-reset'),
                ('explicit-h0-daily',f'water-snow-groundwater-day-closure-full-{opt}-v1')):
                profile=profiles/name;b,i,w,c=locations(profile);q['full'][label]=audit(profile,b,i,w,c)
            q['source_custody']=custody(root,builds,profiles/'water-snow-groundwater-current-source-v2')
        controls={};sdk=read(profiles/'water-snow-groundwater-current-source-v2/RESULT.json')['members']['app/hybrid_water/daily_coupling.py']['sha256']
        for opt,label,native_name,oldprofile_name,source_name in (
            ('O0','explicit-h0-daily','water-snow-groundwater-native-O0-v2','water-snow-groundwater-first-short-O0-v1','water-snow-groundwater-source-refusals-O0-v2'),
            ('O2','implicit-h1-step-reset','water-snow-groundwater-native-O2-v1','water-snow-groundwater-short-O2-v1-implicit-h1-step-reset','water-snow-groundwater-source-refusals-O2-v1')):
            profile,b,i,w=cases[opt+'/'+label];oldprofile=profiles/oldprofile_name;ob,oi,ow,oc=locations(oldprofile)
            oldmeta=read(ob/'BUILD.json');meta=read(b/'BUILD.json')
            require(oldmeta['project']==meta['project'] and oldmeta['inputs']==meta['inputs'] and
                all(oldmeta['identity'][k]==meta['identity'][k] for k in ('compiler_sha256','donor_flags','donor_objects')) and
                '-flto' not in meta['identity']['donor_flags'],'Actual retained native compiler dependency changed')
            for name in ('macropore.f90','integral.f90','snow_water_groundwater_native_state.f90','snow_water_groundwater_root_state.f90',
                'original_output_thermal_domain.f90','thermal_output_snow_calendar_state.f90'):
                require((ob/name).read_bytes()==(b/name).read_bytes(),'Actual retained compiled native/private reader changed')
            controls[opt]=dict(native=native_controls(profiles/native_name,oldprofile,ob,oi,ow),
                source=source_controls(profiles/source_name,b),transactions=transactions(profiles/f'water-snow-groundwater-transactions-{opt}-v2',profile,b,i,sdk,w),
                native_dependency_reuse='Exact complete native/private sources, compiler,flags,objects,input; original controls counted once')
        retained=postimages(root,proof,bundle)
        require(all(v['actual_days']==35 and v['actual_cold_windows']==3 for q in out.values() for v in q['short'].values()) and
            all(v['actual_days']==1096 and v['actual_cold_windows']==9 for q in out.values() for v in q['full'].values()),
            'Actual Windows water Snow science denominator differs')
        return dict(status='INDEPENDENT_SEALED_WINDOWS_WATER_SNOW_GROUNDWATER_PASS',metrics=out,controls=controls,postimages=retained,
            actual_short_contexts=18,actual_short_cold_windows=54,actual_full_periods=6,actual_full_cold_windows=54,
            actual_compiled_refusals=130,actual_source_refusals=32,actual_transaction_contexts=2,
            actual_unselected_contexts=10,actual_unselected_cold_windows=10,model_executions=0)


def ubuntu(proof,opt):
    require(opt in ('O0','O2'),'Foreign portable water Snow optimization')
    with extracted(proof,['UBUNTU_'+opt+'_INITIAL']) as original_root,extracted(proof,['UBUNTU_'+opt+'_RECOVERY']) as current:
        return portable(original_root,current)
