"""Compare current postimages and native dependencies with sealed parent bytes."""
from contextlib import ExitStack
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile

from groundwater_snow_archive_storage import materialize
from ordinary_pond_evidence import read,digest,require,rows,physical
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
from implicit_conductivity_forensics import output_records,output_continuation

ALLOWED={'experimental_input_adapter','implicit_conductivity.source_sha256',
    'implicit_groundwater_trial.source_sha256','implicit_groundwater_trial.original_projection_owner_sha256',
    'ordinary_implicit_pond_switch.source_sha256','restart_publisher.library_sha256',
    'original_output.source_sha256','original_output.predecessor_owner_sha256',
    'original_output.groundwater_trial_provider_sha256','original_output.groundwater_snow_composition_sha256'}


class Parent:
    def __init__(self,proof,scratch,stack):
        self.archives=[]
        for label in ['WINDOWS_'+o+'_'+r for o in ('O0','O2') for r in ('SCIENCE','CONTROLS')]+['WINDOWS_SUPPORT']:
            record=read(Path(proof)/('GROUNDWATER_SNOW_CDE_'+label+'_RAW_ARCHIVE.json'))
            path=materialize(proof,record,scratch)
            require(path.stat().st_size==record['bytes'] and digest(path)==record['sha256'],'Inherited original Snow archive changed')
            z=stack.enter_context(zipfile.ZipFile(path));require(set(z.namelist())==set(record['members']),'Inherited member inventory differs')
            self.archives.append((z,record))
        self.projection=json.loads(self.get('COMPILED_PROJECTION_V1.json'))

    def get(self,name):
        found=[(z,r) for z,r in self.archives if name in r['members']];require(len(found)==1,'Missing/ambiguous inherited original member: '+name)
        z,r=found[0];raw=z.read(name);item=r['members'][name]
        require(len(raw)==item['bytes'] and hashlib.sha256(raw).hexdigest()==item['sha256'],'Inherited actual member changed')
        return raw

    def profile(self,path):return 'profiles/'+str(path).replace('\\','/').split('/evidence/',1)[1]

    def build(self,path):
        entry=self.projection[str(path)];raw=self.get(entry['prefix']+'/BUILD.json')
        require(hashlib.sha256(raw).hexdigest()==entry['actual_BUILD_sha256'],'Inherited actual BUILD changed')
        return entry['prefix'],json.loads(raw)

    def fortran(self,prefix):
        names={n for z,r in self.archives for n in r['members'] if n.startswith(prefix+'/') and n.endswith('.f90')}
        return {Path(n).name:self.get(n) for n in names}


def native_dependency(old,current):
    providers=('groundwater_history_native_state.f90','original_cde_output_state.f90',
        'thermal_output_snow_calendar_state.f90','original_output_thermal_domain.f90')
    out={}
    for n in providers:
        raw=(current/n).read_bytes();require(old[n]==raw,'Inherited actual groundwater native provider changed: '+n)
        out[n]=hashlib.sha256(raw).hexdigest()
    pattern=r'(?ims)^    subroutine hybrid_macro_checkpoint\(.*?^    end subroutine hybrid_macro_checkpoint'
    a=re.findall(pattern,old['macropore.f90'].decode().replace('\r\n','\n'))
    b=re.findall(pattern,(current/'macropore.f90').read_text())
    require(len(a)==len(b)==1,'Ambiguous native checkpoint procedure')
    first='      use hybrid_implicit_pond_event_state,only:assert_no_implicit_pond_event\n'
    second='      use hybrid_groundwater_history_native_state,only:groundwater_history_native_checkpoint\n'
    require(a[0].count(first+second)==1 and b[0].count(second+first)==1 and
        b[0].replace(second+first,first+second,1)==a[0],'Inherited native checkpoint changed beyond adjacent USE order')
    out['complete_checkpoint_procedure_sha256']=hashlib.sha256(a[0].encode()).hexdigest()
    return out


def audit(root,proof,cases_by_opt,bundle,mapped):
    root=Path(root);profiles=root/'profiles';out={}
    with ExitStack() as stack:
        old=Parent(proof,root/'inherited-original-archives',stack)
        for opt,cases in cases_by_opt.items():
            result=out[opt]=dict(postimages={},native_dependencies={})
            manifest=read(root/'observations'/f'IMPLICIT_SNOW_UNSELECTED_BASELINES_{opt}_V1.json')
            report=read(profiles/f'implicit-snow-unselected-postimages-{opt}-v2/RESULT.json')
            require(report['status']=='ACTUAL_UNSELECTED_IMPLICIT_SNOW_DEPENDENCY_POSTIMAGES_PASS' and len(report['cases'])==6 and
                report['fresh_unaffected_full_periods']==0 and report['baseline_sha256']==digest(root/'observations'/f'IMPLICIT_SNOW_UNSELECTED_BASELINES_{opt}_V1.json'),
                'Actual postimage denominator or baseline differs')
            for label,item in report['cases'].items():
                base=manifest['profiles'][label];require(item['baseline']==base,'Postimage original baseline rebound')
                require(hashlib.sha256(old.get(old.profile(base['receipt']))).hexdigest()==base['receipt_sha256'],
                    'Inherited original postimage producer changed')
                oldprefix,oldbuild=old.build(base['build_root']);current=bundle(item['build_root']);build=read(current/'BUILD.json')
                require(digest(current/'BUILD.json')==item['actual_BUILD_sha256'] and old.fortran(oldprefix)==
                    {p.name:p.read_bytes() for p in current.glob('*.f90')},'Unselected emitted Fortran changed')
                require(oldbuild['inputs']==build['inputs'] and oldbuild['project']==build['project'],'Unselected project/input identity changed')
                delta=differences(oldbuild['identity'],build['identity']);require(set(delta)<=ALLOWED and delta==item['identity_changes'],
                    'Unselected numerical dependency changed')
                if 'restart_publisher.library_sha256' in delta:
                    publisher=root/f'parent-publisher-{opt}-{label}.dll';publisher.write_bytes(old.get(oldprefix+'/restart_publish.dll'))
                    require(digest(publisher)==oldbuild['identity']['restart_publisher']['library_sha256'] and
                        digest(current/'restart_publish.dll')==build['identity']['restart_publisher']['library_sha256'],'Postimage publisher identity differs')
                    publisher_equivalence(publisher,current/'restart_publish.dll')
                case=profiles/f'implicit-snow-unselected-postimages-{opt}-v2'/label
                require(all(digest(case/'input'/n)==v for n,v in build['inputs'].items()),'Actual unselected inputs changed')
                warm=rows(case/'trajectory');cold=rows(case/'own-30');oldtrajectory=old.profile(base['trajectory_root'])
                original=[json.loads(line) for line in old.get(oldtrajectory+'/daily.jsonl').decode().splitlines()]
                require(len(warm)==35 and physical(warm)==physical(original) and physical(cold)==physical(warm[30:34]),
                    'Actual unchanged physical postimage differs')
                for day in (2,4,7,9,30,34,35):
                    name=f'accepted-column-1-day-{day}.zip'
                    with zipfile.ZipFile(io.BytesIO(old.get(oldtrajectory+'/'+name))) as a,zipfile.ZipFile(case/'trajectory'/name) as b:
                        require(all(a.read(n)==b.read(n) for n in ('macro.bin','result.end')),'Actual complete native postimage changed')
                        if day==34:
                            with zipfile.ZipFile(case/'own-30'/name) as c:require(all(b.read(n)==c.read(n) for n in ('macro.bin','result.end')),'Actual postimage cold native differs')
                outputs={};coldoutputs={}
                for name in ('result_output.csv','result_output.bin'):
                    path=case/'trajectory/original'/name
                    if path.exists():
                        outputs[name]=output_records(path.read_bytes(),name)
                        require(outputs[name]==output_records(old.get(oldtrajectory+'/original/'+name),name),'Actual unchanged user records differ')
                    coldpath=case/'own-30/original'/name
                    if coldpath.exists():coldoutputs[name]=output_records(coldpath.read_bytes(),name)
                require(output_continuation(outputs,coldoutputs,build['identity']['original_output'],30,34,build['project']['start_date'])==item['cold']['exact_original_output'],
                    'Actual postimage cold output differs')
                result['postimages'][label]=dict(status='INDEPENDENT_UNCHANGED_SOURCE_PHYSICAL_NATIVE_OUTPUT_POSTIMAGE_PASS',actual_BUILD_sha256=digest(current/'BUILD.json'))
            for label,parentcase,version in (('cde-groundwater-clock','h2-snow-clock-periodic','v4'),
                ('cde-groundwater-interval','h0-snow-interval-monthly','v5'),('cde-groundwater-step-off','h1-snow-step-explicit','v5')):
                current=cases[label][1]
                candidates=[k for k in old.projection if f'groundwater-snow-cohort-{opt}-'+(version if opt=='O0' else 'v3') in k and parentcase in k]
                require(len(candidates)==1,'Missing exact original native dependency context')
                prefix,meta=old.build(candidates[0]);result['native_dependencies'][label]=native_dependency(old.fortran(prefix),current)
    return dict(status='INDEPENDENT_SEALED_UNSELECTED_AND_NATIVE_DEPENDENCIES_PASS',metrics=out,
        actual_unselected_contexts=12,actual_unselected_cold_windows=12,fresh_unaffected_full_periods=0,
        inherited_native_observations_role='Parent1720 observations retained as inherited evidence, never counted fresh; exact provider/procedure comparisons above',
        models=0,compilations=0)
