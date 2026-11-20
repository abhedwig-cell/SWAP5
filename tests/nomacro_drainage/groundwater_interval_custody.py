"""Actual Git/provider/compiled source custody including explicit clock cases."""
import hashlib
from pathlib import Path
import subprocess
import zipfile

from ordinary_pond_evidence import read,digest,require

ROOT=Path(__file__).resolve().parents[2]


def audit(root,expected_builds=8,source_root=None,build_paths=None):
    root=Path(root);source=Path(source_root or root/'source');cap=read(source/'RESULT.json');archive=source/cap['archive']
    require(digest(archive)==cap['sha256'],'Actual clock source capsule changed')
    tree={s.split('\t',1)[1]:s.split('\t',1)[0].split()[2] for s in subprocess.check_output(['git','ls-tree','-r',cap['producer_head']],cwd=ROOT,text=True).splitlines()}
    def sha(b):return hashlib.sha256(b).hexdigest()
    def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
    with zipfile.ZipFile(archive) as z:
        present={name for name,v in cap['members'].items() if v.get('checkout')!='ABSENT'}
        require(set(z.namelist())==present,'Actual clock capsule inventory differs')
        for name,item in cap['members'].items():
            require(tree.get(name)==item['git_blob'],'Actual clock capsule Git context differs')
            if name not in present:continue
            raw=z.read(name);lf=raw.replace(b'\r\n',b'\n')
            require(len(raw)==item['bytes'] and sha(raw)==item['sha256'] and item['git_blob'] in (blob(raw),blob(lf)), 'Actual clock source bytes differ')
            if 'lf_normalized_sha256' in item:require(sha(lf)==item['lf_normalized_sha256'],'Actual clock LF source differs')
    provider=read(root/'provider-PREPARED.json');builds=[]
    paths=sorted(Path(p)/'BUILD.json' for p in build_paths) if build_paths is not None else sorted((root/'compiled').rglob('BUILD.json'))
    for file in paths:
        build=read(file);i=build['identity'];output=i['original_output']
        for field,name in [('host','daily_host.py'),('adapter','donor_adapter.f90'),('driver','main.f90'),('experimental_input_adapter','experimental_project.py')]:
            require(i[field]==cap['members']['app/hybrid_water/'+name]['sha256'],'Actual clock compiler source differs')
        for name,expected in i['kernel_sources']:require(expected==cap['members'][name]['sha256'],'Actual clock kernel source differs')
        for name,expected in i['donor_objects'].items():require(expected==provider['provider_files']['build/swap-obj/'+name],'Actual clock original object provider differs')
        require(i['ttutil_library']==provider['provider_files']['build/ttutil-obj/libttutil.a'],'Actual clock TTUTIL provider differs')
        fields=([('source_sha256','cde_interval_output.py'),('groundwater_interval_composition_sha256','groundwater_cde_interval.py')]
                if output.get('groundwater_cde_interval') else
                [('source_sha256','cde_clock_output.py'),('groundwater_clock_composition_sha256','groundwater_cde_clock.py'),('groundwater_trial_provider_sha256','age_groundwater_output.py')])
        for field,name in fields:
            require(output[field]==cap['members']['app/hybrid_water/'+name]['lf_normalized_sha256'],'Actual composed clock renderer source differs')
        actual_private=(file.parent/'original_cde_output_state.f90').read_bytes().replace(b'\r\n',b'\n')
        require(sha(actual_private)==output['cde_output_state_sha256']==cap['members']['app/hybrid_water/cde_interval_output_state.f90']['lf_normalized_sha256'],'Actual compiled private-state template differs')
        native=i['groundwater_native_state'];history=bool(output['swhyst'])
        for field,name in [('source_sha256','groundwater_history_native.py' if history else 'groundwater_native.py'),('provider_sha256','groundwater_history_native_state.f90' if history else 'groundwater_native_state.f90')]:
            require(native[field]==cap['members']['app/hybrid_water/'+name]['sha256'],'Actual composed native source differs')
        if i.get('ordinary_implicit_pond_switch'):
            policy=i['ordinary_implicit_pond_switch']
            for field,name in [('source_sha256','ordinary_implicit_pond_switch.py'),('renderer_sha256','extended_implicit_pond_switch.py'),('pond_tangent_renderer_sha256','ordinary_implicit_pond_tangent.py'),('inherited_chain_rule_renderer_sha256','extended_implicit_pond.py')]:
                require(policy[field]==cap['members']['app/hybrid_water/'+name]['sha256'],'Actual composed ordinary numerical source differs')
        builds.append(file.relative_to(root).as_posix())
    require(len(builds)==expected_builds,'Actual original portable compiled denominator differs')
    return dict(status='ACTUAL_GROUNDWATER_INTERVAL_DRAINAGE_GIT_SOURCE_PROVIDER_COMPILED_CUSTODY_PASS',
                producer_source=cap['producer_head'],source_members=len(present),actual_builds=builds,
                source_archive_sha256=cap['sha256'])
