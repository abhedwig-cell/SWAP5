"""Independently audit retained physical receipts and immutable source/build data."""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import tarfile
import tempfile
import zipfile

p=argparse.ArgumentParser(description=__doc__);p.add_argument('--archive',type=Path,required=True);p.add_argument('--sha256',required=True)
a=p.parse_args();sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
assert sha(a.archive)==a.sha256
with tempfile.TemporaryDirectory(prefix='s5-generic-water-raw-audit-') as temp:
    root=Path(temp)
    with tarfile.open(a.archive) as archive:archive.extractall(root,filter='data')
    load=lambda name:json.loads((root/name).read_text())
    for name,h in load('MEMBER_SHA256.json').items():assert sha(root/name)==h,name
    index=load('PROOF_INDEX.json');cases=index['cases'];checked=0;summary={}
    rows=lambda folder:[json.loads(line) for line in (root/folder/'daily.jsonl').read_text().splitlines()]
    physical=lambda row:{k:v for k,v in row.items() if k not in ('column','revision')}
    csv_lines=lambda folder:[s for s in (root/folder/'original/result_output.csv').read_text().splitlines() if s.strip() and not s.startswith('*')]
    baseline=rows(index['canonical']+'/cut')
    if index['platform']=='windows':
        with zipfile.ZipFile(root/'canonical-build/accepted-column-1-day-20.zip') as z:
            old= json.loads(z.read('checkpoint.json'))['binding']['build']
        old_generated='canonical-build'
    else:
        old=load(index['canonical']+'/build/BUILD.json')['identity']
        old_generated=index['canonical']+'/build'
    for field,member in index['canonical_sources'].items():assert sha(root/member)==old[field];checked+=1
    for name,h in old['kernel_sources']:assert sha(root/index['sources'][name])==h;checked+=1
    for name,h in old['donor_generated'].items():assert sha(root/old_generated/name)==h;checked+=1
    for label,case in cases.items():
        report=load(case['report']+'/RESULT.json');meta=load(case['report']+'/BUILD.json')
        assert report['status']=='GENERIC_HYBRID_ORIGINAL_PREFIX_RESTART_ISOLATION_REFUSAL_PASS'
        assert sha(root/case['report']/'BUILD.json')==report['build_sha256']
        assert sha(root/case['report']/'EVENTS.json')==report['events_sha256']
        for original,h in report['source_sha256'].items():
            name='app/hybrid_water/'+original.replace('\\','/').split('/app/hybrid_water/')[-1]
            assert sha(root/index['sources'][name])==h;checked+=1
        identity=meta['identity']
        for name,h in identity['kernel_sources']:
            assert sha(root/index['sources'][name])==h;checked+=1
        for key,name in [('host','daily_host.py'),('adapter','donor_adapter.f90'),('driver','main.f90')]:
            assert sha(root/index['sources']['app/hybrid_water/'+name])==identity[key];checked+=1
        for name,h in identity['donor_generated'].items():assert sha(root/case['build']/name)==h;checked+=1
        for name,h in identity['donor_objects'].items():assert sha(root/index['reference']/'build/swap-obj'/name)==h;checked+=1
        assert sha(root/index['reference']/'build/ttutil-obj/libttutil.a')==identity['ttutil_library'];checked+=1
        suffix='.exe' if index['platform']=='windows' else ''
        for role,filename in [('donor','day_donor'),('kernel','day_kernel')]:
            assert sha(root/case['build']/(filename+suffix))==meta['executable_sha256'][role];checked+=1
        for name,h in meta['inputs'].items():
            assert sha(root/index['reference']/'distribution/SWAP_4.3.1/cases'/meta['project']['case']/name)==h;checked+=1
        continuous=rows(case['continuous']);terminal=rows(case['terminal']);resumed=rows(case['resumed'])
        assert [r['day'] for r in continuous]==[1,2,3,4] and terminal==continuous
        assert list(map(physical,resumed))==list(map(physical,continuous[2:]))
        assert csv_lines(case['terminal'])==csv_lines(case['continuous'])
        assert csv_lines(case['resumed'])[-2:]==csv_lines(case['continuous'])[-2:]
        tol=1e-10 if label.startswith('grass') else 1e-6;nodes=113 if label.startswith('grass') else 112
        for row in continuous+resumed:
            assert row['committed'] and len(row['pressure_head_cm'])==nodes
            values=[*row['stock_end_cm'],*row['stock_start_cm'],*row['external_flux_cm'],*row['pressure_head_cm']]
            assert all(math.isfinite(x) for x in values)
            f=row['external_flux_cm'];residual=math.fsum([*f[:7],*(-x for x in f[7:]),*row['stock_start_cm'],*(-x for x in row['stock_end_cm'])])
            assert residual==row['independent_residual_cm'] and abs(residual)<=tol
            assert abs(row['kernel_residual_cm'])<=tol
        for name in ['result.end','macro.bin']:
            cold=(root/case['terminal']/'original'/name).read_bytes();warm=(root/case['resumed']/'original'/name).read_bytes()
            if label.startswith('grass') or name=='result.end':assert cold==warm
            if label.startswith('andelst'):
                assert cold==(root/index['canonical']/'terminal/original'/name).read_bytes()
                assert warm==(root/index['canonical']/'resumed/original'/name).read_bytes()
        if label.startswith('andelst'):assert continuous==baseline
        directory=case['report']
        mixed=rows(directory+'/mixed');plain=rows(directory+'/plain');shifted=rows(directory+'/shifted')
        for col,control in [(1,plain),(2,shifted)]:
            assert [physical(r) for r in mixed if r['column']==col]==list(map(physical,control))
        assert list(map(physical,plain))!=list(map(physical,shifted))
        fault=(root/directory/'refusal/kernel.stdout').read_text()
        assert 'DAILY_REFUSED 1 1 0' in fault and 'DAILY_ACCEPTED 2 1 1' in fault
        assert 'DAILY_ACCEPTED 1' not in fault
        summary[label]=dict(days=4,maximum_water_residual_cm=max(abs(r['independent_residual_cm']) for r in continuous),
                            exact_own_physical_suffix=True,distinct_instance_and_refusal=True)
    public=load(index['public']+'/RESULT.json');resumed=load(index['public_resume']+'/RESULT.json')
    assert public['model']==resumed['model']=='HYBRID_GRASSGROWTH_WATER'
    assert public['committed_days']==4 and resumed['committed_days']==2
    for folder,end in [(index['public'],2),(index['public_resume'],4)]:
        with zipfile.ZipFile(root/folder/f'accepted-column-1-day-{end}.zip') as z:
            m=json.loads(z.read('checkpoint.json'));assert m['receipt']['committed'] and m['receipt']['day']==end
            for name,h in m['files'].items():assert hashlib.sha256(z.read(name)).hexdigest()==h
    ref=cases['grass-O2']
    assert rows(index['public'])==rows(ref['continuous'])
    assert list(map(physical,rows(index['public_resume'])))==list(map(physical,rows(ref['resumed'])))
    for name in ['result.end','macro.bin']:
        assert (root/index['public_resume']/'original'/name).read_bytes()==(root/ref['terminal']/'original'/name).read_bytes()
    print(json.dumps({'status':'INDEPENDENT_GENERIC_SOURCE_BUILD_INPUT_BALANCE_RESTART_INSTANCE_PUBLIC_AUDIT_PASS',
                      'platform':index['platform'],'retained_files':len(load('MEMBER_SHA256.json')),
                      'source_build_input_identity_checks':checked,'cases':summary}))
