"""Retain the exact bounded generic-waterhost proof; never run a model."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--platform',choices=['windows','linux'],required=True)
p.add_argument('--temp',type=Path,required=True)
p.add_argument('--linux-extracted',type=Path)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--hupsel',action='store_true',help='Retain complete Hupsel successor and six bounded controls')
p.add_argument('--closure-full',action='store_true',help='Retain complete successor and repeated-publication proof')
p.add_argument('--source-head',default='91ef5ff08a49d6e874d5b54b878339cd268ccdb6')
a=p.parse_args();files={};cases={}
def add(root,prefix):
    for path in sorted(root.rglob('*')):
        if path.is_file():files[prefix+'/'+path.relative_to(root).as_posix()]=path
def case(report,build,continuous=None,resumed=None):
    return dict(report=report,build=build,continuous=continuous or build+'/continuous',
                terminal=build+'/terminal-control',resumed=resumed or build+'/resumed')
if a.platform=='windows':
    roots={
      'grass-O2-build':'s5-hybrid-generic-grass-O2-20261111',
      'grass-O2-resume':'s5-hybrid-generic-grass-O2-resume-20261111',
      'grass-O2-report':'s5-hybrid-generic-grass-O2-qualified-20261111',
      'grass-O0':'s5-hybrid-generic-grass-O0-qualified-20261111',
      'andelst-O0-build':'s5-hybrid-generic-andelst-O0-qualified-20261111',
      'andelst-O2-build':'s5-hybrid-generic-andelst-O2-qualified-20261111',
      'andelst-O0-report':'s5-hybrid-generic-andelst-O0-final2-20261111',
      'andelst-O2-report':'s5-hybrid-generic-andelst-O2-final2-20261111',
      'canonical':'s5-hybrid-generic-old-andelst-macro-control-20261111',
      'public':'s5-hybrid-generic-grass-public-20261111',
      'public-resume':'s5-hybrid-generic-grass-public-resume-20261111'}
    if a.closure_full:
        roots={name:'s5-hybrid-full-'+name+'-20261111' for name in
               ['grass-O0','grass-O2','andelst-O0','andelst-O2']}
        roots.update({'canonical':'s5-hybrid-generic-old-andelst-macro-control-20261111',
                      'public':'s5-hybrid-full-public-20261111',
                      'public-resume':'s5-hybrid-full-public-resume-20261111',
                      'full-trajectory':'s5-hybrid-grass-full-20261111',
                      'reproduced-staging-failure':'s5-repeat-checkpoint-native-before-20261111',
                      'initial-fixture-failure':'s5-repeat-checkpoint-before-20261111'})
    if a.hupsel:
        roots={name:'s5-hybrid-hupsel-release-'+name+'-20261111' for name in
               ['hupsel-O0','grass-O0','grass-O2','andelst-O0','andelst-O2']}
        roots.update({'hupsel-O2':'s5-hybrid-hupsel-O2-season-20261111',
          'canonical':'s5-hybrid-generic-old-andelst-macro-control-20261111',
          'public':'s5-hybrid-hupsel-preserved-grass-public-20261111',
          'public-resume':'s5-hybrid-hupsel-preserved-grass-public-resume-20261111',
          'hupsel-full':'s5-hybrid-hupsel-full-season-20261111',
          'hupsel-public-late':'s5-hybrid-hupsel-public-late-20261111'})
    for prefix,name in roots.items():add(a.temp/name,prefix)
    for path in sorted(a.temp.glob('s5-hybrid-generic-*-20261111.log')):files['logs/'+path.name]=path
    for opt in ['O0','O2']:
        cases['andelst-'+opt]=case('andelst-'+opt+'-report','andelst-'+opt+'-build')
    cases['grass-O0']=case('grass-O0','grass-O0')
    cases['grass-O2']=case('grass-O2-report','grass-O2-build','grass-O2-build','grass-O2-resume')
    cases['grass-O2']['terminal']='grass-O2-report/terminal-control'
    if a.closure_full:
        cases={name:case(name,name) for name in ['grass-O0','grass-O2','andelst-O0','andelst-O2']}
        for path in sorted(a.temp.glob('s5-hybrid-full-*-20261111.log')):files['logs/'+path.name]=path
        files['logs/full.log']=a.temp/'s5-hybrid-grass-full-20261111.log'
    if a.hupsel:
        cases={name:case(name,name) for name in ['hupsel-O0','hupsel-O2','grass-O0','grass-O2','andelst-O0','andelst-O2']}
    old=a.temp/'s5-andelst-a4da56a0-prefix'
    for path in sorted(old.iterdir()):
        if path.is_file() and (path.suffix.lower() in ['.f90','.o','.mod','.exe'] or path.name=='accepted-column-1-day-20.zip'):
            files['canonical-build/'+path.name]=path
    for relative in ['build/swap-obj','build/ttutil-obj','build/swap-selected',
                     'distribution/SWAP_4.3.1/tools/SWAP/source',
                     'distribution/SWAP_4.3.1/cases/1.hupselbrook','distribution/SWAP_4.3.1/cases/2.grassgrowth','distribution/SWAP_4.3.1/cases/3.macroporeflow']:
        add(a.temp/'s5-water-integrated-reference'/relative,'reference/'+relative)
    reference='reference';canonical='canonical';public='public';public_resume='public-resume'
else:
    assert a.linux_extracted
    add(a.linux_extracted,'')
    files={name.lstrip('/'):path for name,path in files.items()}
    for project in (['hupsel','grass','andelst'] if a.hupsel else ['grass','andelst']):
        for opt in ['O0','O2']:
            name='generic-'+project+'-'+opt;cases[project+'-'+opt]=case(name,name)
    reference='generic-reference';canonical='generic-baseline';public='generic-public';public_resume='generic-public-resume'

first=json.loads(files[cases['grass-O0']['report']+'/BUILD.json'].read_text())
source_names=[name for name,digest in first['identity']['kernel_sources']]
source_names+=['app/hybrid_water/'+name for name in ['daily_host.py','donor_sources.py','donor_adapter.f90','main.f90','hybrid_step_budget.f90']]
source_names+=['app/support/restart_publish.c','tools/solute/run_water.py',
 'research/hybrid-water01/qualify_generic_hybrid_waterhost.py',
 'research/hybrid-water01/run_hybrid_grass_full.py',
 'research/hybrid-water01/check_hybrid_budget_protocol.py',
 'research/hybrid-water01/test_generic_hybrid_state.f90',
 'research/hybrid-water01/prepare_generic_hybrid_reference.py',
 'research/hybrid-water01/prepare_generic_hybrid_baseline.py','tools/vq/b0_source_runner.py']
staging=a.temp/('s5-generic-source-'+a.platform+'-20261111');staging.mkdir(exist_ok=True)
sources={}
for i,name in enumerate(source_names):
    path=staging/str(i)
    if a.platform=='windows':path.write_bytes((ROOT/name).read_bytes())
    else:path.write_bytes(subprocess.check_output(['git','cat-file','blob',a.source_head+':'+name],cwd=ROOT))
    member='source/current/'+name;files[member]=path;sources[name]=member
if a.platform=='windows':
    with __import__('zipfile').ZipFile(old/'accepted-column-1-day-20.zip') as archive:
        old_build=json.loads(archive.read('checkpoint.json'))['binding']['build']
    old_sources={}
    for field,name in [('host','daily_host.py'),('adapter','donor_adapter.f90'),('driver','main.f90')]:
        raw=subprocess.check_output(['git','cat-file','blob','01a9d29c380645dec880257f360174b5cb5ea5c0:app/hybrid_water/'+name],cwd=ROOT)
        lf=raw.replace(b'\r\n',b'\n')
        match=next(x for x in [raw,lf,lf.replace(b'\n',b'\r\n')] if hashlib.sha256(x).hexdigest()==old_build[field])
        path=staging/('old-'+name);path.write_bytes(match);member='source/canonical/'+name
        files[member]=path;old_sources[field]=member
else:
    old_sources={field:'generic-baseline-root/app/hybrid_water/'+name for field,name in
                 [('host','daily_host.py'),('adapter','donor_adapter.f90'),('driver','main.f90')]}
index=dict(platform=a.platform,source_head=a.source_head,
           canonical_source='01a9d29c380645dec880257f360174b5cb5ea5c0',cases=cases,reference=reference,
           canonical=canonical,public=public,public_resume=public_resume,sources=sources,canonical_sources=old_sources,
           scope='Bounded original water prototype and exact same-platform canonical preservation. DonorO2/kernelO0/O2; no full project/native1e-5C heat/whole science.')
if a.closure_full:
    index['repeated_publication']=True
    index['full_trajectory']='full-trajectory' if a.platform=='windows' else None
    index['scope']='Repeated durable publication and preserved bounded O0/O2 controls; Windows full original1827 water and own seasonal restarts. No native1e-5C or whole science.'
if a.hupsel:
    index.update(repeated_publication=True,hupsel_full='hupsel-full' if a.platform=='windows' else 'generic-hupsel-full',
                 hupsel_public_late='hupsel-public-late' if a.platform=='windows' else None,
                 scope='Corrected original Hupsel1096, exact nine own windows, six bounded controls. Original heat; whole scientific equivalence unqualified.')
hashes={name:hashlib.sha256(path.read_bytes()).hexdigest() for name,path in files.items()}
assert not a.output.exists()
with tarfile.open(a.output,'x:xz',preset=3) as archive:
    for name,path in sorted(files.items()):archive.add(path,arcname=name,recursive=False)
    for name,value in [('MEMBER_SHA256.json',hashes),('PROOF_INDEX.json',index)]:
        data=(json.dumps(value,indent=2)+'\n').encode();info=tarfile.TarInfo(name);info.size=len(data);archive.addfile(info,io.BytesIO(data))
print(json.dumps(dict(archive=str(a.output),bytes=a.output.stat().st_size,
                     sha256=hashlib.sha256(a.output.read_bytes()).hexdigest(),retained_files=len(files))))
