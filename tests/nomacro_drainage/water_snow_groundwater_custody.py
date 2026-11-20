"""Bind actual source, immutable original providers and both new native variants."""
import hashlib
import ast
from pathlib import Path
import subprocess
import zipfile

from ordinary_pond_evidence import read,digest,require

ROOT=Path(__file__).resolve().parents[2]
PARENT='9c447f419d11743efe7464d3c8542ac1bc8fea4a'
LEGACY_BUILD_SHA='43d7c069e8564f37f790b409aed1797d3fd8df6e43c0bfac005a3ff8e20dee0b'


def unchanged_clock_parent(source,selected,actual_sha):
    if actual_sha!=LEGACY_BUILD_SHA or not (selected['flprintdt'] or selected['nprintday']>1):return False
    tree=ast.parse(source);last=tree.body[-1];lines=source.splitlines(keepends=True)
    if not isinstance(last,ast.FunctionDef) or last.name!='complete_day' or last.decorator_list or lines[last.lineno-1]!='def complete_day(source):\n':return False
    prefix=''.join(lines[:last.lineno-1]);call="    if kind=='interval':\n        result=complete_day(result)\n"
    if not prefix.endswith('\n\n') or prefix.count(call)!=1:return False
    parent=prefix[:-2].replace(call,'',1)
    return hashlib.sha256(parent.encode('utf-8')).hexdigest()==LEGACY_BUILD_SHA


def audit(root,build_paths=None,source_root=None):
    root=Path(root);source=Path(source_root or root/'source');cap=read(source/'RESULT.json')
    archive=source/cap['archive'];require(digest(archive)==cap['sha256'],'Actual water Snow source capsule changed')
    tree={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in
        subprocess.check_output(['git','ls-tree','-r',cap['producer_head']],cwd=ROOT,text=True).splitlines()}
    sha=lambda raw:hashlib.sha256(raw).hexdigest()
    gitblob=lambda raw:hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
    with zipfile.ZipFile(archive) as z:
        present={name for name,item in cap['members'].items() if item.get('checkout')!='ABSENT'}
        require(set(z.namelist())==present,'Actual water Snow source capsule inventory differs')
        for name,item in cap['members'].items():
            require(tree.get(name)==item['git_blob'],'Actual water Snow source Git identity differs')
            if name not in present:continue
            raw=z.read(name);lf=raw.replace(b'\r\n',b'\n')
            require(len(raw)==item['bytes'] and sha(raw)==item['sha256'] and item['git_blob'] in (gitblob(raw),gitblob(lf)),
                'Actual original source bytes differ: '+name)
            if 'lf_normalized_sha256' in item:require(sha(lf)==item['lf_normalized_sha256'],'Actual source LF observation differs')
        parents={name:z.read('app/hybrid_water/'+name).replace(b'\r\n',b'\n').decode('cp1252') for name in
            ('groundwater_history_native_state.f90','implicit_snow_root_state.f90')}
        build_source=z.read('app/hybrid_water/snow_water_groundwater_build.py').replace(b'\r\n',b'\n').decode('utf-8')
    for name,text in parents.items():
        qualified=subprocess.check_output(['git','show',PARENT+':app/hybrid_water/'+name],cwd=ROOT).decode('cp1252')
        require(text==qualified,'Original admitted native parent provider changed')
    def render(parent,replacements):
        text=parents[parent]
        for old,new,count in replacements:
            require(text.count(old)==count,'Actual literal native clone seam differs');text=text.replace(old,new)
        return text.encode('cp1252')
    provider=read(root/'provider-PREPARED.json');out=[]
    paths=[Path(p)/'BUILD.json' for p in build_paths] if build_paths is not None else sorted((root/'compiled').rglob('BUILD.json'))
    for path in paths:
        b=read(path);i=b['identity'];o=i['original_output'];implicit=o['swkimpl']
        require(o['groundwater_snow_water_output'] is True and o['kind']=='water' and o['swsnow']==o['swbotb']==1 and implicit in (0,1),
            'Wrong actual water Snow groundwater source context')
        for field,name in (('host','daily_host.py'),('adapter','donor_adapter.f90'),('driver','main.f90'),('experimental_input_adapter','experimental_project.py')):
            require(i[field]==cap['members']['app/hybrid_water/'+name]['sha256'],'Actual compiler source differs: '+name)
        for name,value in i['kernel_sources']:require(value==cap['members'][name]['sha256'],'Actual compiled kernel differs')
        for name,value in i['donor_objects'].items():require(value==provider['provider_files']['build/swap-obj/'+name],'Original immutable object provider differs')
        require(i['ttutil_library']==provider['provider_files']['build/ttutil-obj/libttutil.a'],'Original immutable TTUTIL provider differs')
        for name,value in i['donor_generated'].items():require(digest(path.parent/name)==value,'Actual emitted water Snow source changed: '+name)
        for field,name in (('source_sha256','snow_water_groundwater.py'),('composition_build_sha256','snow_water_groundwater_build.py')):
            require(o[field]==cap['members']['app/hybrid_water/'+name]['lf_normalized_sha256'] or
                field=='composition_build_sha256' and unchanged_clock_parent(build_source,o,o[field]),'Actual new water Snow compiler owner differs')
        state=i['groundwater_native_state'];require(state['source_sha256']==cap['members']['app/hybrid_water/snow_water_groundwater_state.py']['lf_normalized_sha256'],
            'Actual new water Snow native source owner differs')
        hyd=render('groundwater_history_native_state.f90',[
            ('hybrid_groundwater_history_native_state','hybrid_snow_water_groundwater_native_state',1),
            ('groundwater_history_native_checkpoint','snow_water_groundwater_native_checkpoint',2),
            ('only: swbotb,swcfbs,','only: swkimpl,swbotb,swcfbs,',1),('swsolu/=1','swsolu/=0.or.swkimpl/='+str(implicit),1),
            ('swsnow<0.or.swsnow>1','swsnow/=1',1),('(swhyst==0.and.swsnow==0)','(swhea/=1.or.swcalt/=2)',1),
            ('expected=[2,n,','expected=['+str(14+implicit)+',n,',1),('swcfbs,1]','swcfbs,swkimpl]',1)])
        rates=render('implicit_snow_root_state.f90',[
            ('hybrid_implicit_snow_root_state','hybrid_snow_water_groundwater_root_state',1),
            ('implicit_snow_root_checkpoint','snow_water_groundwater_root_checkpoint',2),('swkimpl/=1','swkimpl/='+str(implicit),1),
            ('(swbotb/=5.and.swbotb/=8)','swbotb/=1',1),('expected=[1,numnod,','expected=[2,numnod,',1),
            ('HYBRID_SNOW_ROOT_NATIVE','HYBRID_SNOW_GROUNDWATER_ROOT_NATIVE',1)])
        for name,expected,field in (('snow_water_groundwater_native_state.f90',hyd,'provider_sha256'),
            ('snow_water_groundwater_root_state.f90',rates,'root_provider_sha256')):
            require((path.parent/name).read_bytes().replace(b'\r\n',b'\n')==expected and state[field]==sha(expected) and
                o['native_composition'][field]==sha(expected),'Actual literal water Snow native clone differs')
        require((path.parent/'macropore.f90').read_bytes().replace(b'\r\n',b'\n').startswith(hyd+b'\n'+rates+b'\n'),
            'Actual typed native source absent from compiled module unit')
        for role,stem in (('donor','day_donor'),('kernel','day_kernel')):
            exe=next((path.parent/(stem+s) for s in ('','.exe') if (path.parent/(stem+s)).exists()),None)
            require(exe and digest(exe)==b['executable_sha256'][role],'Actual water Snow compiled executable differs')
        out.append(dict(actual_BUILD_sha256=digest(path),native_codec=o['native_codec'],actual_compiler=i['compiler']))
    require(len(out)==9,'Actual water Snow compiler context denominator differs')
    return dict(status='ACTUAL_WATER_SNOW_GROUNDWATER_SOURCE_PROVIDER_COMPILER_CUSTODY_PASS',
        producer_source=cap['producer_head'],source_archive_sha256=cap['sha256'],actual_builds=out)
