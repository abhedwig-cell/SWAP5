"""Read actual Git/source/provider/compiler custody without model execution."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

from ordinary_pond_evidence import read,digest,require

ROOT=Path(__file__).resolve().parents[2]


def audit(root,build_paths=None):
    root=Path(root);source=root/'source';cap=read(source/'RESULT.json');archive=source/cap['archive']
    require(digest(archive)==cap['sha256'],'Actual implicit Snow source archive changed')
    tree={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in
        subprocess.check_output(['git','ls-tree','-r',cap['producer_head']],cwd=ROOT,text=True).splitlines()}
    sha=lambda raw:hashlib.sha256(raw).hexdigest()
    def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
    with zipfile.ZipFile(archive) as z:
        present={name for name,v in cap['members'].items() if v.get('checkout')!='ABSENT'}
        require(set(z.namelist())==present,'Actual implicit Snow source capsule denominator differs')
        for name,item in cap['members'].items():
            require(tree.get(name)==item['git_blob'],'Actual implicit Snow source Git context differs')
            if name not in present:continue
            raw=z.read(name);lf=raw.replace(b'\r\n',b'\n')
            require(len(raw)==item['bytes'] and sha(raw)==item['sha256'] and item['git_blob'] in (blob(raw),blob(lf)),
                'Actual implicit Snow producer source bytes differ: '+name)
            if 'lf_normalized_sha256' in item:require(sha(lf)==item['lf_normalized_sha256'],'Actual source LF identity differs')
        root_parent=z.read('app/hybrid_water/implicit_snow_root_state.f90').replace(b'\r\n',b'\n')
    provider=read(root/'provider-PREPARED.json');observations=[]
    paths=([Path(p)/'BUILD.json' for p in build_paths] if build_paths is not None else sorted((root/'compiled').rglob('BUILD.json')))
    for file in paths:
        build=read(file);i=build['identity'];o=i['original_output']
        require(i.get('implicit_conductivity',{}).get('implicit_snow_composition') is True and o['swsnow']==1,
                'Wrong actual implicit Snow source context')
        for field,name in (('host','daily_host.py'),('adapter','donor_adapter.f90'),('driver','main.f90'),('experimental_input_adapter','experimental_project.py')):
            require(i[field]==cap['members']['app/hybrid_water/'+name]['sha256'],'Actual compiler core source differs: '+name)
        for name,value in i['kernel_sources']:require(value==cap['members'][name]['sha256'],'Actual compiled kernel source differs')
        for name,value in i['donor_objects'].items():require(value==provider['provider_files']['build/swap-obj/'+name],'Actual original object provider differs')
        require(i['ttutil_library']==provider['provider_files']['build/ttutil-obj/libttutil.a'],'Actual original TTUTIL provider differs')
        for name,value in i['donor_generated'].items():require(digest(file.parent/name)==value,'Actual emitted implicit Snow source changed: '+name)
        for name,policy in i.items():
            key='app/hybrid_water/'+name+'.py'
            if isinstance(policy,dict) and 'source_sha256' in policy and key in cap['members']:
                require(policy['source_sha256']==cap['members'][key]['sha256'],'Actual numerical source policy differs: '+name)
        require(i['implicit_conductivity']['implicit_snow_composition_source_sha256']==
            cap['members']['app/hybrid_water/implicit_snow_composition.py']['lf_normalized_sha256'],
            'Actual implicit Snow selector composition differs')
        if 'implicit_snow_root_carry' in o:
            policy=o['implicit_snow_root_carry'];chemical=o['kind']=='cde'
            owner='implicit_snow_cde_root_carry.py' if chemical else 'implicit_snow_root_carry.py'
            require(policy['source_sha256']==cap['members']['app/hybrid_water/'+owner]['lf_normalized_sha256'],
                'Actual original root carry compiler owner differs')
            expected=root_parent
            if chemical:
                require(expected.count(b'swsolu/=0')==1,'Original root carry parent domain changed')
                require(policy['parent_provider_sha256']==sha(expected),'Actual CDE root parent provider differs')
                expected=expected.replace(b'swsolu/=0',b'swsolu/=1',1)
            require(sha(expected)==policy['provider_sha256'] and
                (file.parent/'implicit_snow_root_state.f90').read_bytes().replace(b'\r\n',b'\n')==expected,
                'Actual compiled original root rates differ')
            actual=(file.parent/'macropore.f90').read_bytes().replace(b'\r\n',b'\n')
            require(actual.startswith(expected+b'\n'),'Actual root module is absent from native compiler unit')
        for role,stem in (('donor','day_donor'),('kernel','day_kernel')):
            exe=next((file.parent/(stem+s) for s in ('','.exe') if (file.parent/(stem+s)).exists()),None)
            require(exe and digest(exe)==build['executable_sha256'][role],'Actual compiled executable differs')
        observations.append(dict(actual_BUILD=str(file),actual_BUILD_sha256=digest(file),codec=o['native_codec']))
    require(len(observations)==9,'Actual coherent implicit Snow build denominator differs')
    return dict(status='ACTUAL_IMPLICIT_SNOW_GIT_SOURCE_PROVIDER_COMPILED_CUSTODY_PASS',
        actual_source_commit=cap['producer_head'],source_members=len(present),source_archive_sha256=cap['sha256'],actual_builds=observations)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('root',type=Path);p.add_argument('--builds',nargs='+',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    result=audit(a.root,a.builds)
    with a.output.open('x',encoding='utf-8') as f:json.dump(result,f,indent=2);f.write('\n')
    print(result['status'],len(result['actual_builds']))
