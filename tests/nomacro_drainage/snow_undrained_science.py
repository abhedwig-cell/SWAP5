"""Read sealed actual Snow science, original defects and unchanged parent bytes."""
from contextlib import contextmanager,ExitStack
import hashlib
import io
import json
from pathlib import Path
import tempfile
import zipfile

from ordinary_pond_evidence import read,digest,require,rows,physical
from groundwater_snow_archive_storage import materialize
from groundwater_clock_archive import unpack
from snow_undrained_forensics import audit,original
from snow_undrained_custody import audit as custody
from snow_undrained_component_forensics import audit as component
from snow_undrained_control_forensics import audit as native_controls,source_controls,transactions
from snow_undrained_portable_forensics import audit_root as portable
from water_snow_groundwater_science import AdmittedParent
from implicit_snow_postimage_forensics import Parent
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence

PREFIX='SNOW_UNDRAINED_'


@contextmanager
def extracted(proof,labels):
    with tempfile.TemporaryDirectory(prefix='snow-undrained-raw-') as scratch:
        base=Path(scratch);seen=set()
        for label in labels:
            record=read(Path(proof)/(PREFIX+label+'_RAW_ARCHIVE.json'));path=materialize(proof,record,base/'archives')
            root,members=unpack(path,dict(size_in_bytes=record['bytes'],digest='sha256:'+record['sha256']),base/'raw')
            require(members==record['members'] and not seen.intersection(members),'Original undrained Snow archive inventory differs')
            seen.update(members)
        yield root


class WaterParent(Parent):
    def __init__(self,proof,scratch,stack):
        self.archives=[]
        for label in ['WINDOWS_'+o+'_'+r for o in ('O0','O2') for r in ('SCIENCE','CONTROLS')]+['WINDOWS_SUPPORT']:
            record=read(Path(proof)/('WATER_SNOW_GROUNDWATER_'+label+'_RAW_ARCHIVE.json'));path=materialize(proof,record,scratch)
            require(path.stat().st_size==record['bytes'] and digest(path)==record['sha256'],'Inherited actual water Snow archive changed')
            z=stack.enter_context(zipfile.ZipFile(path));require(set(z.namelist())==set(record['members']),'Inherited water Snow inventory differs')
            self.archives.append((z,record))
        self.projection=json.loads(self.get('COMPILED_PROJECTION_V1.json'))


def postimages(root,proof,bundle,mapped):
    out={}
    with ExitStack() as stack:
        parents=[AdmittedParent(proof,root/'inherited-implicit',stack),WaterParent(proof,root/'inherited-water',stack)]
        for opt in ('O0','O2'):
            manifest=read(root/'observations'/f'SNOW_UNDRAINED_UNSELECTED_BASELINES_{opt}_V1.json')
            path=root/'profiles'/f'snow-undrained-unselected-postimages-{opt}-v5';r=read(path/'RESULT.json')
            require(r['status']=='ACTUAL_SIX_UNSELECTED_SNOW_UNDRAINED_DEPENDENCY_POSTIMAGES_PASS' and
                r['baseline_sha256']==digest(root/'observations'/f'SNOW_UNDRAINED_UNSELECTED_BASELINES_{opt}_V1.json') and
                len(r['cases'])==6 and r['fresh_unaffected_full_periods']==0,'Actual unselected postimage denominator differs')
            results=out[opt]={}
            for label,item in r['cases'].items():
                base=manifest['cases'][label];require(item['baseline']==base,'Original postimage baseline rebound')
                member=parents[0].profile(base['receipt'])
                matches=[p for p in parents if any(member in record['members'] for z,record in p.archives)]
                require(len(matches)==1,'Missing/ambiguous admitted original postimage receipt')
                parent=matches[0];raw=parent.get(member);require(hashlib.sha256(raw).hexdigest()==base['receipt_sha256'],'Admitted original receipt changed')
                before=json.loads(raw);prefix,oldmeta=parent.build(before['build_root']);current=bundle(item['build_root']);meta=read(current/'BUILD.json')
                require(parent.fortran(prefix)=={p.name:p.read_bytes() for p in current.glob('*.f90')},'Unselected complete actual Fortran changed')
                delta=differences(oldmeta['identity'],meta['identity'])
                require(delta==item['identity_changes'] and set(delta)<={'experimental_input_adapter',
                    'implicit_conductivity.implicit_snow_composition_source_sha256','original_output.implicit_snow_composition_source_sha256',
                    'implicit_groundwater_trial.source_sha256','implicit_groundwater_trial.original_projection_owner_sha256',
                    'lower_boundary_receipt.composition_sha256','original_output.composition_build_sha256','restart_publisher.library_sha256'},
                    'Actual unchanged compiler dependency changed')
                require(oldmeta['inputs']==meta['inputs'] and set(differences(oldmeta['project'],meta['project']))<={'case'},
                    'Actual unchanged scientific inputs/project differ')
                if 'restart_publisher.library_sha256' in delta:
                    dll=root/f'old-publisher-{opt}-{label}.dll';dll.write_bytes(parent.get(prefix+'/restart_publish.dll'))
                    require(digest(dll)==oldmeta['identity']['restart_publisher']['library_sha256'],'Original actual publisher changed')
                    publisher_equivalence(dll,current/'restart_publish.dll')
                warm=mapped(item['trajectory_root']);cold=mapped(item['cold_actual_root']);data=rows(warm);own=rows(cold)
                oldwarm=parent.profile(before.get('trajectory_root',str(base['receipt']).replace('\\','/').rsplit('/',1)[0]+'/trajectory'))
                original_rows=[json.loads(line) for line in parent.get(oldwarm+'/daily.jsonl').decode().splitlines()]
                require(len(data)==35 and physical(data)==physical(original_rows) and physical(own)==physical(data[30:34]),
                    'Actual unchanged physical postimage differs')
                require(read(warm/'BUILD.json')==meta,'Observed current postimage BUILD differs')
                for day in (2,4,7,9,30,34,35):
                    name=f'accepted-column-1-day-{day}.zip'
                    with zipfile.ZipFile(io.BytesIO(parent.get(oldwarm+'/'+name))) as a,zipfile.ZipFile(warm/name) as b:
                        require(all(a.read(n)==b.read(n) for n in ('macro.bin','result.end')),'Unchanged complete native postimage differs')
                        if day==34:
                            with zipfile.ZipFile(cold/name) as c:require(all(b.read(n)==c.read(n) for n in ('macro.bin','result.end')),'Actual postimage cold native differs')
                outputs={};coldoutputs={}
                for name in ('result_output.csv','result_output.bin'):
                    if (warm/'original'/name).exists():
                        outputs[name]=original.output_records((warm/'original'/name).read_bytes(),name)
                        require(outputs[name]==original.output_records(parent.get(oldwarm+'/original/'+name),name),'Unchanged user output differs')
                    if (cold/'original'/name).exists():coldoutputs[name]=original.output_records((cold/'original'/name).read_bytes(),name)
                require(original.output_continuation(outputs,coldoutputs,meta['identity']['original_output'],30,34,meta['project']['start_date'])==item['cold']['exact_original_output'],
                    'Actual postimage cold output differs')
                results[label]=dict(status='INDEPENDENT_UNCHANGED_SOURCE_PHYSICAL_NATIVE_OUTPUT_POSTIMAGE_PASS',actual_BUILD_sha256=digest(current/'BUILD.json'))
    return dict(status='INDEPENDENT_TWELVE_UNCHANGED_SNOW_UNDRAINED_DEPENDENCY_POSTIMAGES_PASS',metrics=out,
        actual_unselected_contexts=12,actual_unselected_cold_windows=12,fresh_unaffected_full_periods=0)


def windows(proof):
    labels=['WINDOWS_'+o+'_'+r for o in ('O0','O2') for r in ('SCIENCE','CONTROLS')]+['WINDOWS_SUPPORT']
    with extracted(proof,labels) as root:
        profiles=root/'profiles';projection=read(root/'COMPILED_PROJECTION_V1.json');out={};cases={}
        def mapped(path):
            normalized=str(path).replace('\\','/');require('/evidence/' in normalized,'Foreign actual Windows evidence location')
            return profiles/normalized.split('/evidence/',1)[1]
        def bundle(path):
            item=projection[str(path)];b=root/item['prefix'];require(digest(b/'BUILD.json')==item['actual_BUILD_sha256'],'Actual compiled projection differs');return b
        def locations(profile):
            r=read(profile/'RESULT.json');b=bundle(r['build_root']);i=mapped(r['input_root'])
            warm=mapped(r['trajectory_root']) if r.get('trajectory_root') else profile/'trajectory'
            cold=[mapped(v) for v in r['cold_actual_roots']] if r.get('cold_actual_roots') else [profile/f"own-{x['start']}" for x in r['cold']]
            return b,i,warm,cold
        for opt in ('O0','O2'):
            manifest=read(root/'observations'/f'SNOW_UNDRAINED_WINDOWS_CURRENT_COHORT_{opt}_V3.json');require(len(manifest['cases'])==9,'Actual Windows case denominator differs')
            q=out[opt]=dict(short={},full={});builds=[]
            for label,item in manifest['cases'].items():
                profile=mapped(item['actual_case_root']);b,i,w,c=locations(profile)
                require(digest(profile/'RESULT.json')==item['actual_original_receipt_sha256'] and digest(b/'BUILD.json')==item['actual_BUILD_sha256'],
                    'Actual original selected producer/BUILD changed')
                q['short'][label]=audit(profile,b,i,w,c);builds.append(b);cases[opt+'/'+label]=(profile,b,i,w)
            full=read(root/'observations'/f'SNOW_UNDRAINED_WINDOWS_CURRENT_FULLS_{opt}_V1.json');require(len(full['cases'])==4,'Actual Windows full denominator differs')
            for label,item in full['cases'].items():
                profile=mapped(item['actual_case_root']);require(digest(profile/'RESULT.json')==item['actual_original_receipt_sha256'],'Actual full producer changed')
                b,i,w,c=locations(profile);q['full'][label]=audit(profile,b,i,w,c)
            q['source_custody']=custody(root,builds,profiles/'snow-undrained-current-source-v2')
            q['cde_component']=component(profiles/f'snow-undrained-cde-positive-{opt}-v1',read(root/'provider-PREPARED.json'))
        defects={}
        for opt in ('O0','O2'):
            bad=profiles/f'snow-undrained-exact-partition-full-{opt}-v1-cde-explicit-flux-interval'
            b,i,w,c=locations(bad)
            try:audit(bad,b,i,w,c)
            except ValueError as error:
                require(str(error)=='integrated actual CDE flow mass guard exceeded','Original CDE refusal differs')
            else:raise ValueError('Original positive-tail CDE full period unexpectedly passes')
            current=cases[opt+'/cde-explicit-flux-interval'][1]
            old=b'               if (cmsy(i) < vsmall) then';new=b'               if (cmsy(i) <= 0d0) then'
            before=(b/'solute.f90').read_bytes();after=(current/'solute.f90').read_bytes()
            require(before.count(old)==1 and before.replace(old,new,1)==after,
                'Actual integrated CDE correction changed more than the positive cutoff')
            failed=rows(profiles/f'snow-undrained-full-{opt}-v1-water-explicit-flux-daily/trajectory')
            require(len(failed)==1066 and all(v['committed'] for v in failed[:1065]) and not failed[-1]['committed'] and
                abs(failed[-1]['kernel_residual_cm'])>1e-10 and abs(failed[-1]['independent_residual_cm'])>1e-10,
                'Original day1066 interception defect not retained')
            full=read(root/'observations'/f'SNOW_UNDRAINED_WINDOWS_CURRENT_FULLS_{opt}_V1.json')
            repaired=rows(mapped(full['cases']['water-explicit-flux-daily']['actual_case_root'])/'trajectory')[1065]
            require(repaired['committed'] and abs(repaired['kernel_residual_cm'])<=1e-10 and abs(repaired['independent_residual_cm'])<=1e-10,
                'Actual day1066 water conservation not repaired')
            defects[opt]=dict(original_CDE_integrated_refusal_retained=True,complete_CDE_source_single_predicate=True,
                original_day1066_water_refusal_retained=True,repaired_day1066_independent_residual_cm=repaired['independent_residual_cm'])
        controls={};external=read(profiles/'snow-undrained-current-source-v2/RESULT.json')['members']['app/hybrid_water/daily_coupling.py']['sha256']
        for opt in ('O0','O2'):
            for label,control,native_name,trans_name in (
                ('water-explicit-flux-daily',f'snow-undrained-current-source-{opt}-v1-water',f'snow-undrained-exact-partition-native-{opt}-v1',f'snow-undrained-current-transactions-{opt}-v1-water'),
                ('cde-implicit-head-clock-positive',f'snow-undrained-positive-tail-source-controls-{opt}-v1',f'snow-undrained-positive-tail-native-controls-{opt}-v1',f'snow-undrained-positive-tail-transactions-controls-{opt}-v1')):
                profile,b,i,w=cases[opt+'/'+label]
                controls[opt+'/'+label]=dict(source=source_controls(profiles/control,b),native=native_controls(profiles/native_name,profile,b,i,w),
                    transactions=transactions(profiles/trans_name,profile,b,i,external,w))
        preserved=postimages(root,proof,bundle,mapped)
        require(all(v['actual_days']==35 and v['actual_cold_windows']==3 for q in out.values() for v in q['short'].values()) and
            all(v['actual_days']==1096 and v['actual_cold_windows']==9 for q in out.values() for v in q['full'].values()),'Actual Windows period denominator differs')
        return dict(status='INDEPENDENT_SEALED_WINDOWS_SNOW_UNDRAINED_PASS',metrics=out,controls=controls,postimages=preserved,original_defects=defects,
            actual_short_contexts=18,actual_short_cold_windows=54,actual_full_periods=8,actual_full_cold_windows=72,
            actual_compiled_refusals=100,actual_source_refusals=72,actual_transaction_contexts=4,
            actual_unselected_contexts=12,actual_unselected_cold_windows=12,model_executions=0)


def ubuntu(proof,opt):
    require(opt in ('O0','O2'),'Foreign portable Snow optimization')
    with extracted(proof,['UBUNTU_'+opt]) as root:return portable(root)
