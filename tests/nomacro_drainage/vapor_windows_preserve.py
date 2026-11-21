"""Preserve the actual Windows vapor cohort, compiled bytes and failed research."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
import zipfile
from groundwater_snow_archive_storage import store_original
from vapor_hydraulic_portable import CASES

ROOT=Path(__file__).resolve().parents[2]
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def profile_name(label,kind,opt):
    return f'vapor-native3-{label}-{kind}-full-{opt}-v1' if label in ('8','11') else f'vapor-native3-{label}-{kind}-{opt}-v1-full'


def main():
    parser=argparse.ArgumentParser()
    for name in ('evidence','work','reference-work'):parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--kind',choices=('water','cde','research','postimages'),required=True);a=parser.parse_args()
    proof=ROOT/'integration/f-ci/nomacro-complete01';stem='HYDRAULIC_VAPOR_WINDOWS_'+a.kind.upper()+'_RAW_V1'
    record=proof/(stem+'.json');assert not record.exists();archive=a.evidence/(stem+'.zip');assert not archive.exists()
    files={};projection={};roles=[]
    producer=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    def add(path,name):
        assert path.is_file() and not path.is_symlink()
        if name in files:assert files[name]==path
        else:files[name]=path
    def tree(path,name):
        assert path.is_dir()
        for file in sorted(path.rglob('*')):
            if file.is_file():add(file,name+'/'+file.relative_to(path).as_posix())
    def profile(path):tree(path,'profiles/'+path.relative_to(a.evidence).as_posix())
    def build(path):
        prefix='compiled/'+path.relative_to(a.work).as_posix()
        meta=path/'BUILD.json';assert meta.is_file()
        for file in sorted(path.iterdir()):
            if file.is_file() and (file.name in ('BUILD.json','day_donor','day_kernel') or file.suffix.lower() in ('.f90','.exe','.dll','.so')):add(file,prefix+'/'+file.name)
        projection[str(path)]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA(meta.read_bytes()))
    if a.kind in ('water','cde'):
        for opt in ('O0','O2'):
            for label,models,flags in CASES:
                path=a.evidence/profile_name(label,a.kind,opt);q=json.loads((path/'RESULT.json').read_text())
                assert q['kind']==a.kind and q['optimization']==opt and q['layer_models']==models and q['vapor_flags']==flags
                assert q['trajectory']['days']==1096 and q['trajectory']['status']=='FULL_PASS'
                item=dict(case=label,optimization=opt,profile='profiles/'+path.name)
                if q['status']=='FAILED':
                    assert a.kind=='cde' and label=='mixed-11-8'
                    continued=a.evidence/(path.name[:-len('-full')]+'-cold-continuation')
                    completed=json.loads((continued/'RESULT.json').read_text());assert completed['status'].endswith('_PASS_NOT_ADMITTED') and len(completed['own'])==7
                    assert SHA((path/'RESULT.json').read_bytes())==completed['retained_original_RESULT_sha256']
                    profile(continued);item['continuation']='profiles/'+continued.name
                else:assert q['status'].endswith('_PASS_NOT_ADMITTED') and len(q['own'])==7
                profile(path);build(Path(q['build_root']));roles.append(item)
                if label in ('8','mixed-7-8'):
                    if label=='8':name=f'vapor-native3-8-{a.kind}-controls-{opt}-'+('v1' if a.kind=='water' and opt=='O0' else 'v2')
                    else:name=f'vapor-native3-{label}-{a.kind}-{opt}-v1-controls'
                    controls=a.evidence/name;c=json.loads((controls/'RESULT.json').read_text())
                    assert c['status']=='ACTUAL_COMPILED_VAPOR_NATIVE3_REFUSALS_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
                    assert len(c['refusals'])==57 and len(c['inherited_output_native_refusals'])==(29 if a.kind=='cde' else 24)
                    assert all(value is True for value in c['transactions'].values())
                    profile(controls);item['controls']='profiles/'+controls.name
        if a.kind=='water':
            tree(a.reference_work/'build','original-provider-build');add(a.reference_work/'PREPARED.json','provider-PREPARED.json')
    elif a.kind=='postimages':
        for opt in ('O0','O2'):
            for version in (1,2):
                path=a.evidence/f'vapor-unselected-model7-postimages-{opt}-v{version}';profile(path)
                q=json.loads((path/'RESULT.json').read_text())
                if version==2:
                    assert q['status']=='ACTUAL_VAPOR_UNSELECTED_MODEL7_COMPLETE_COMPILED_NATIVE_SHORT_POSTIMAGES_EXACT_OLD_FULL_CONTROLS_REUSABLE'
                    for item in q['contexts']:
                        child=Path(item['profile_root']);observed=json.loads((child/'RESULT.json').read_text());build(Path(observed['build_root']))
    else:
        for path in sorted(a.evidence.iterdir()):
            name=path.name
            selected=(name.startswith(('hydraulic-vapor-','hydraulic_vapor_','HYDRAULIC_VAPOR_','vapor-trial-','vapor-frontend-','vapor_frontend_','vapor-prior-','VAPOR_')) or name.startswith('vapor-native2-') or name=='vapor-native3-8-water-prefix-O0-v1' or (name.startswith(('vapor-8-','vapor-11-')) and 'native3' not in name))
            if not selected or name.startswith('HYDRAULIC_VAPOR_WINDOWS_'):continue
            if path.is_dir():
                profile(path)
                result=path/'RESULT.json'
                if result.is_file():
                    q=json.loads(result.read_text())
                    if q.get('build_root') and 'vapor-native3-' not in q['build_root'] and Path(q['build_root'],'BUILD.json').is_file():build(Path(q['build_root']))
            elif path.is_file():add(path,'profiles/'+name)
        correction=a.evidence/'WC_K_models_04_11.KELVIN_SIGN01.f90'
        if correction.is_file():add(correction,'profiles/'+correction.name)
        # Native1/2 failed bundle bytes are unique evidence of their actual
        # source epochs; preserve before the registered builds are released.
        for name in ('vapor-8-daily-water-O0-v1','vapor-8-daily-water-O2-v1','vapor-11-daily-water-O0-v1','vapor-11-daily-water-O2-v1','vapor-native2-8-water-O0-v1'):
            build(a.work/name/'bundle')
    add(Path(__file__),'controllers/vapor_windows_preserve.py')
    assert files
    inventories={}
    with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as output:
        for name,path in sorted(files.items()):
            raw=path.read_bytes();output.writestr(name,raw);inventories[name]=dict(bytes=len(raw),sha256=SHA(raw))
        raw=(json.dumps(projection,indent=2)+'\n').encode();output.writestr('COMPILED_PROJECTION_V1.json',raw);inventories['COMPILED_PROJECTION_V1.json']=dict(bytes=len(raw),sha256=SHA(raw))
    stored=store_original(archive,proof,archive.name)
    q=dict(status='ACTUAL_WINDOWS_VAPOR_'+a.kind.upper()+'_SOURCE_BOUND_RAW_PRESERVED_NOT_ADMITTED',**stored,members=inventories,roles=roles,
        archiver_source=producer,actual_archiver_sha256=SHA(Path(__file__).read_bytes()),
        actual_original_paths_rewritten=False,original_failed_roles_preserved=True,public_admission=False,
        native3_prefix_compiled_dependency='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1' if a.kind=='research' else None)
    record.open('x',encoding='utf8').write(json.dumps(q,indent=2)+'\n');print(q['status'],q['bytes'],q['sha256'],len(files),flush=True)


if __name__=='__main__':main()
