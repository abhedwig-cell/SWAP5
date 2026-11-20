"""Independent actual compiler/provider and literal root/partition custody."""
import ast
import hashlib
from pathlib import Path
import subprocess
import zipfile

from ordinary_pond_evidence import read,digest,require

ROOT=Path(__file__).resolve().parents[2]
PARENT='b546801eaf24a01ee4dc457eb857ef46e6b61c30'
OLD_BUILD='53fca12f508800d5c57b9727b05d7fbeab71b229d4b5cb0d6b1fc082abedb0d1'
OLD_DOMAIN='73525f3852d99a383bfa12c8cd3f50e2ee9e54a1a863de353757fbbd76480a9e'
PRE_POSITIVE_BUILD='410d179b577c2499447bfd98bd3b305617733178a989137156e65604dcfac861'
PRE_POSITIVE_DOMAIN='72830a2b4332b8e5c42e5f668e9c68245db45bdf192e411d0a1da93d184a4dfa'
POSITIVE_OLD="        path=output/'solute.f90';path.write_text(bridge.source(path.read_text(encoding='cp1252')),encoding='cp1252')\n"
POSITIVE_NEW="        from snow_undrained_cde_positive import source as preserve_positive\n        path=output/'solute.f90';path.write_text(preserve_positive(bridge.source(path.read_text(encoding='cp1252'))),encoding='cp1252')\n"
POSITIVE_METADATA="    if project.solute:providers.append('snow_undrained_cde_positive.py')\n"
PARTITION_BLOCK="""        from implicit_interception_partition import source as exact_partition
        meteo=output/'MOD_meteo.f90'
        parent=(meteo if meteo.exists() else originals/'MOD_meteo.f90').read_text(encoding='cp1252')
        meteo.write_text(exact_partition(parent),encoding='cp1252')
        patched=['MOD_meteo',*(name for name in patched if name!='MOD_meteo')]
"""
PARTITION_METADATA="    if not selected['swkimpl']:providers.append('implicit_interception_partition.py')\n"
NEW_PROBE="    (output/'age_output_calendar_probe.f90').write_text(probe(project,selected),encoding='cp1252')\n"
OLD_PROBE="""    if project.solute:
        import cde_clock_output as cclock
        import cde_interval_output as interval
        probe=(cclock if selected['flprintdt'] or selected['nprintday']>1 else interval).probe_source(project,selected)
    else:probe=clock.probe_source(project)
    (output/'age_output_calendar_probe.f90').write_text(probe,encoding='cp1252')
"""


def inherited_provider(name,text,actual,selected):
    if POSITIVE_METADATA in text or POSITIVE_NEW in text:
        if selected['kind']!='water':return False
        if name=='snow_undrained.py':
            if text.count(POSITIVE_METADATA)!=1:return False
            text=text.replace(POSITIVE_METADATA,'',1)
            if actual==PRE_POSITIVE_DOMAIN:return hashlib.sha256(text.encode()).hexdigest()==actual
        elif name=='snow_undrained_build.py':
            if text.count(POSITIVE_NEW)!=1:return False
            text=text.replace(POSITIVE_NEW,POSITIVE_OLD,1)
            if actual==PRE_POSITIVE_BUILD:return hashlib.sha256(text.encode()).hexdigest()==actual
        else:return False
    if not selected['swkimpl']:return False
    if name=='snow_undrained.py':
        return actual==OLD_DOMAIN and text.count(PARTITION_METADATA)==1 and hashlib.sha256(
            text.replace(PARTITION_METADATA,'',1).encode()).hexdigest()==OLD_DOMAIN
    if name!='snow_undrained_build.py' or actual!=OLD_BUILD:return False
    if selected['kind']=='cde' and not selected['flprintdt'] and selected['nprintday']==1:return False
    if text.count(PARTITION_BLOCK)!=1:return False
    text=text.replace(PARTITION_BLOCK,'',1);tree=ast.parse(text);last=tree.body[-1]
    if not isinstance(last,ast.FunctionDef) or last.name!='probe' or last.decorator_list:return False
    lines=text.splitlines(keepends=True)
    if lines[last.lineno-1]!='def probe(project,selected):\n':return False
    prefix=''.join(lines[:last.lineno-1])
    return prefix.endswith('\n\n') and prefix.count(NEW_PROBE)==1 and hashlib.sha256(
        prefix[:-2].replace(NEW_PROBE,OLD_PROBE,1).encode()).hexdigest()==OLD_BUILD


def audit(root,build_paths=None,source_root=None):
    root=Path(root);source=Path(source_root or root/'source');cap=read(source/'RESULT.json')
    require(digest(source/cap['archive'])==cap['sha256'],'Actual undrained Snow source capsule changed')
    tree={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in
        subprocess.check_output(['git','ls-tree','-r',cap['producer_head']],cwd=ROOT,text=True).splitlines()}
    sha=lambda raw:hashlib.sha256(raw).hexdigest()
    blob=lambda raw:hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
    with zipfile.ZipFile(source/cap['archive']) as z:
        present={n for n,v in cap['members'].items() if v.get('checkout')!='ABSENT'}
        require(set(z.namelist())==present,'Actual source capsule inventory differs')
        for name,item in cap['members'].items():
            require(tree.get(name)==item['git_blob'],'Actual source Git identity differs')
            if name not in present:continue
            raw=z.read(name);lf=raw.replace(b'\r\n',b'\n')
            require(len(raw)==item['bytes'] and sha(raw)==item['sha256'] and item['git_blob'] in (blob(raw),blob(lf)),
                'Actual producer source bytes differ: '+name)
            if 'lf_normalized_sha256' in item:require(sha(lf)==item['lf_normalized_sha256'],'Actual LF source observation differs')
        texts={n:z.read('app/hybrid_water/'+n).replace(b'\r\n',b'\n').decode('cp1252') for n in
            ('implicit_snow_root_state.f90','snow_undrained.py','snow_undrained_build.py')}
    require(texts['implicit_snow_root_state.f90'].encode('cp1252')==subprocess.check_output(
        ['git','show',PARENT+':app/hybrid_water/implicit_snow_root_state.f90'],cwd=ROOT),'Admitted root parent changed')
    provider=read(root/'provider-PREPARED.json');meteo=(root/'provider-MOD_meteo.f90').read_bytes()
    require(sha(meteo)==provider['provider_files']['build/swap-selected/MOD_meteo.f90'],'Original meteo provider changed')
    corrected=meteo.replace(b'\r\n',b'\n').decode('cp1252')
    for old,new in [('      if (aintcdt < small) then','      if (aintcdt == 0d0) then'),
        ('         if (graidt + gird > small) then','         if (graidt + gird > 0d0) then')]:
        require(corrected.count(old)==1,'Original qualified partition seam differs');corrected=corrected.replace(old,new,1)
    require(sha(corrected.encode('cp1252'))=='f1c338398d437ad47f516749f32b5ff527131734df661b1b17af1cc0f99cdb0c',
        'Whole existing qualified exact interception module differs')
    paths=[Path(p)/'BUILD.json' for p in build_paths] if build_paths is not None else sorted((root/'compiled').rglob('BUILD.json'))
    out=[]
    for path in paths:
        b=read(path);i=b['identity'];o=i['original_output'];implicit=o['swkimpl'];chemical=int(o['kind']=='cde')
        require(o['ordinary_snow_undrained_output'] is True and o['kind'] in ('water','cde') and o['swsnow']==1 and
            o['swdra']==0 and o['swbotb'] in (5,8) and implicit in (0,1),'Foreign actual compiler context')
        for field,name in (('host','daily_host.py'),('adapter','donor_adapter.f90'),('driver','main.f90'),('experimental_input_adapter','experimental_project.py')):
            require(i[field]==cap['members']['app/hybrid_water/'+name]['sha256'],'Actual compiler source differs: '+name)
        for name,value in i['kernel_sources']:require(value==cap['members'][name]['sha256'],'Actual compiled kernel source differs')
        for name,value in i['donor_objects'].items():require(value==provider['provider_files']['build/swap-obj/'+name],'Immutable original object differs')
        require(i['ttutil_library']==provider['provider_files']['build/ttutil-obj/libttutil.a'],'Immutable original TTUTIL differs')
        for name,value in i['donor_generated'].items():require(digest(path.parent/name)==value,'Actual emitted source changed: '+name)
        expected={'snow_undrained.py','snow_undrained_build.py','snow_undrained_state.py','thermal_output_clock.py',
            'thermal_output_step.py','thermal_output_reset.py','implicit_snow_root_state.f90',
            'original_output_thermal_domain.f90','thermal_output_snow_calendar_state.f90'}
        if chemical:expected|={'cde_clock_output.py','cde_interval_output.py','cde_interval_source.py',
            'cde_interval_output_state.f90','cde_interval_snow_state.f90','cde_interval_receipt.f90','cde_clock_events.f90',
            'snow_undrained_cde_positive.py'}
        if not implicit:expected.add('implicit_interception_partition.py')
        require(set(o['providers'])==expected,'Actual compiler provider inventory differs')
        for name,value in o['providers'].items():
            item=cap['members']['app/hybrid_water/'+name]
            require(value==item['lf_normalized_sha256'] or name in texts and inherited_provider(name,texts[name],value,o),
                'Actual compiler provider source differs: '+name)
        rates=texts['implicit_snow_root_state.f90']
        for old,new,count in [('hybrid_implicit_snow_root_state','hybrid_snow_undrained_root_state',1),
            ('implicit_snow_root_checkpoint','snow_undrained_root_checkpoint',2),
            ('swsolu/=0','swsolu/='+str(chemical),1),('swkimpl/=1','swkimpl/='+str(implicit),1),
            ('expected=[1,numnod','expected=[3,numnod',1),('HYBRID_SNOW_ROOT_NATIVE','HYBRID_UNDRAINED_SNOW_ROOT_NATIVE',1)]:
            require(rates.count(old)==count,'Literal root clone seam differs');rates=rates.replace(old,new)
        actual=(path.parent/'snow_undrained_root_state.f90').read_bytes().replace(b'\r\n',b'\n')
        require(actual==rates.encode('cp1252') and (path.parent/'macropore.f90').read_bytes().replace(b'\r\n',b'\n').startswith(actual+b'\n'),
            'Actual compiled literal root provider differs')
        require((path.parent/'MOD_meteo.f90').read_bytes().replace(b'\r\n',b'\n')==corrected.encode('cp1252'),
            'Actual whole corrected original meteo module differs')
        for role,stem in (('donor','day_donor'),('kernel','day_kernel')):
            exe=next((path.parent/(stem+s) for s in ('','.exe') if (path.parent/(stem+s)).exists()),None)
            require(exe and digest(exe)==b['executable_sha256'][role],'Actual compiled executable differs')
        out.append(dict(actual_BUILD_sha256=digest(path),native_codec=o['native_codec'],actual_compiler=i['compiler']))
    require(len(out)==9,'Actual compiler context denominator differs')
    return dict(status='ACTUAL_SNOW_UNDRAINED_SOURCE_PROVIDER_COMPILER_CUSTODY_PASS',
        producer_source=cap['producer_head'],source_archive_sha256=cap['sha256'],actual_builds=out)
