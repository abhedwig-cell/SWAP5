"""Read-only original capsule/Git/provider/compiler custody for ordinary proofs."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import zipfile

from ordinary_pond_evidence import read, digest, require

ROOT=Path(__file__).resolve().parents[2]


def audit(root):
    root=Path(root);cap=read(root/'source/RESULT.json')
    require(digest(root/'source'/cap['archive'])==cap['sha256'], 'Actual source ZIP changed')
    tree={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in subprocess.check_output(
        ['git','ls-tree','-r',cap['producer_head']],cwd=ROOT,text=True).splitlines()}
    def sha(b):return hashlib.sha256(b).hexdigest()
    def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
    with zipfile.ZipFile(root/'source'/cap['archive']) as z:
        present={n for n,v in cap['members'].items() if v.get('checkout')!='ABSENT'}
        require(set(z.namelist())==present,'Actual source member inventory differs')
        for name,item in cap['members'].items():
            require(tree.get(name)==item['git_blob'],'Actual source Git producer differs')
            if name not in present:continue
            raw=z.read(name);lf=raw.replace(b'\r\n',b'\n')
            require(len(raw)==item['bytes'] and sha(raw)==item['sha256'] and
                    item['git_blob'] in (blob(raw),blob(lf)), 'Actual source bytes differ: '+name)
            if 'lf_normalized_sha256' in item:require(sha(lf)==item['lf_normalized_sha256'],'Source LF hash differs')
    provider=read(root/'provider-PREPARED.json')
    require(provider['source_archives']['SWAP.ZIP']=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151','Original SWAP provider differs')
    builds=[]
    for path in (root/'compiled').rglob('BUILD.json'):
        build=read(path);identity=build['identity']
        for field,name in [('host','daily_host.py'),('adapter','donor_adapter.f90'),('driver','main.f90'),
                           ('experimental_input_adapter','experimental_project.py')]:
            require(identity[field]==cap['members']['app/hybrid_water/'+name]['sha256'],'Actual compiled source identity differs: '+field)
        budget=path.parent/'hybrid_step_budget.f90'
        require(identity['budget_source']==(digest(budget) if budget.is_file() else
                cap['members']['app/hybrid_water/hybrid_step_budget.f90']['sha256']), 'Actual rendered budget identity differs')
        for name,expected in identity['kernel_sources']:
            require(expected==cap['members'][name]['sha256'],'Actual compiled kernel source differs')
        policy=identity['ordinary_implicit_pond_switch']
        for field,name in [('source_sha256','ordinary_implicit_pond_switch.py'),
                           ('renderer_sha256','extended_implicit_pond_switch.py'),
                           ('pond_tangent_renderer_sha256','ordinary_implicit_pond_tangent.py'),
                           ('inherited_chain_rule_renderer_sha256','extended_implicit_pond.py')]:
            require(policy[field]==cap['members']['app/hybrid_water/'+name]['sha256'],'Actual ordinary renderer source differs')
        for name,expected in identity['donor_objects'].items():
            require(expected==provider['provider_files']['build/swap-obj/'+name],'Actual original object custody differs')
        require(identity['ttutil_library']==provider['provider_files']['build/ttutil-obj/libttutil.a'],'Actual original TTUTIL differs')
        builds.append(path.relative_to(root).as_posix())
    require(builds,'No actual compiled source custody')
    return dict(status='ACTUAL_ORIGINAL_ORDINARY_GIT_SOURCE_PROVIDER_COMPILER_CUSTODY_PASS',
                producer_source=cap['producer_head'],actual_source_members=len(present),actual_builds=builds,
                source_archive_sha256=cap['sha256'],provider_sha256=digest(root/'provider-PREPARED.json'))
