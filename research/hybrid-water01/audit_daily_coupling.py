"""Independently read retained bytes, lineage, balances and accepted namespaces."""
import argparse
from datetime import date
import hashlib
import json
import math
from pathlib import Path
import tarfile
import tempfile
import zipfile

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--archive',type=Path,required=True);p.add_argument('--sha256',required=True)
p.add_argument('--base-archive',type=Path,required=True)
p.add_argument('--current-only',action='store_true',help='Audit new default preservation without repeating prior performance control')
a=p.parse_args();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(a.archive)==a.sha256
with tempfile.TemporaryDirectory(prefix='s5-external-daily-audit-') as directory:
    root=Path(directory);base=root/'base';root=root/'proof'
    with tarfile.open(a.archive) as t:t.extractall(root,filter='data')
    load=lambda p:json.loads(p.read_text())
    index=load(root/'PROOF_INDEX.json')
    assert sha(a.base_archive)==index['base_sha256']
    with tarfile.open(a.base_archive) as t:t.extractall(base,filter='data')
    for name,digest in load(root/'MEMBER_SHA256.json').items():assert sha(root/name)==digest,name
    base_index=load(base/'PROOF_INDEX.json')
    assert base_index['platform']==index['platform']
    prefixes=['current'] if a.current_only else ['current','before']
    for prefix in prefixes:
        report=load(root/prefix/'RESULT.json')
        assert report['status']=='EXTERNAL_DAILY_THREE_PROJECTS_O0_O2_ACCEPT_DISCARD_RECOVERY_PASS'
        assert len(report['cases'])==6 and len(report['events'])==6
        for name,digest in report['source_sha256'].items():assert sha(root/index['sources'][prefix][name])==digest
    corruption=load(root/'corruption/RESULT.json')
    assert corruption['status']=='MUTATED_NATIVE_ORIGIN_OWNER_NATIVE_ADOPTION_AND_TERMINAL_GUARDS_PASS'
    for name,digest in corruption['source_sha256'].items():assert sha(root/index['sources']['current'][name])==digest

    def read_package(path,binding):
        with zipfile.ZipFile(path) as z:
            assert sorted(z.namelist())==['checkpoint.json','macro.bin','result.end']
            manifest=json.loads(z.read('checkpoint.json'))
            data={name:z.read(name) for name in ['result.end','macro.bin']}
        assert manifest['schema']=='swap5-hybrid-water-checkpoint-3'
        assert manifest['binding']==binding
        assert manifest['files']=={n:hashlib.sha256(raw).hexdigest() for n,raw in data.items()}
        assert manifest['receipt']['committed'] is True
        return manifest['receipt'],data

    physical=lambda r:{k:v for k,v in r.items() if k not in ('column','revision','coupling')}
    checked=0
    for key in ['grass','hupsel','andelst']:
        for opt in ['O0','O2']:
            label=key+'-'+opt;case=base_index['cases'][label]
            meta=load(base/case['report']/'BUILD.json');binding=meta['binding']
            origin=base/case['continuous']/'accepted-column-1-day-2.zip'
            original,_=read_package(origin,binding)
            expected=[json.loads(l) for l in (base/case['continuous']/'daily.jsonl').read_text().splitlines()]
            epoch=(date.fromisoformat(meta['project']['start_date'])-date(1900,1,1)).days+1
            for prefix in prefixes:
                report=load(root/prefix/'RESULT.json')
                entry=next(c for c in report['cases'] if c['project']==key and c['optimization']==opt)
                assert entry['bundle_build_sha256']==sha(base/case['report']/'BUILD.json')
                assert entry['native_origin_sha256']==sha(origin)
                owner=root/prefix/label
                source_hash=sha(root/index['sources'][prefix]['app/hybrid_water/daily_coupling.py'])
                external={**binding,'external_daily':{'version':1,'source_sha256':source_hash,
                          'coupling_id':'column-A','forcing':'original-project'}}
                first,p1=read_package(owner/'external/trial-1/accepted-column-1-day-3.zip',binding)
                second,p2=read_package(owner/'external/trial-2/accepted-column-1-day-3.zip',binding)
                assert first==second and p1==p2
                accepted_path=owner/'external/accepted-column-1-day-3.zip'
                accepted,pa=read_package(accepted_path,external)
                assert pa==p1 and physical(accepted)==physical(expected[2])
                assert accepted['coupling']=={'id':'column-A','revision':1,'origin_revision':0,
                       'origin_sha256':sha(origin),'origin_day':2,'window_day1900':[epoch+2,epoch+3],
                       'forcing':'original-project'}
                assert not (owner/'external/accepted-column-1-day-4.zip').exists()
                assert not list((owner/'peer').glob('accepted-*.zip'))
                _,uninterrupted=read_package(owner/'external/trial-3/accepted-column-1-day-4.zip',binding)
                final_path=owner/'restored/accepted-column-1-day-4.zip'
                final,pf=read_package(final_path,external)
                assert sha(final_path)==entry['external_day4_sha256']
                assert uninterrupted==pf and physical(final)==physical(expected[3])
                c=final['coupling']
                assert c['origin_sha256']==sha(accepted_path) and c['origin_revision']==1 and c['revision']==2
                assert c['origin_day']==3 and c['window_day1900']==[epoch+3,epoch+4]
                recovered,pfail=read_package(owner/'sync-failure/accepted-column-1-day-4.zip',external)
                assert pfail==pf and recovered==final
                for r in [first,second,accepted,final]:
                    assert all(math.isfinite(v) for v in [*r['stock_start_cm'],*r['stock_end_cm'],*r['external_flux_cm'],*r['pressure_head_cm']])
                    f=r['external_flux_cm']
                    residual=math.fsum([*f[:7],*(-v for v in f[7:]),*r['stock_start_cm'],*(-v for v in r['stock_end_cm'])])
                    assert residual==r['independent_residual_cm'] and abs(residual)<=meta['project']['water_tolerance']
                    assert abs(r['kernel_residual_cm'])<=meta['project']['water_tolerance']
                checked+=1
            # Publisher reuse changes no native state or physical computation.
            for relative in ([] if a.current_only else ['external/accepted-column-1-day-3.zip','restored/accepted-column-1-day-4.zip']):
                with zipfile.ZipFile(root/'current'/label/relative) as now, zipfile.ZipFile(root/'before'/label/relative) as old:
                    for name in ['result.end','macro.bin']:assert now.read(name)==old.read(name)
    before=load(root/'before/RESULT.json') if not a.current_only else None
    current=load(root/'current/RESULT.json')
    assert len(current['compiler_events'])==24
    if before is not None:assert len(before['compiler_events'])==66
    print(json.dumps({'status':'INDEPENDENT_DAILY_COUPLING_SOURCE_LINEAGE_PHYSICAL_PAYLOAD_PUBLICATION_AUDIT_PASS',
                      'platform':index['platform'],'raw_files':len(load(root/'MEMBER_SHA256.json')),
                      'current_cases':6,'current_and_previous_cases':checked,'C_compiles_before':66 if before else None,'C_compiles_after':24,
                      'seconds_before':math.fsum(e['seconds'] for e in before['events']) if before else None,
                      'seconds_after':math.fsum(e['seconds'] for e in current['events']),
                      'publisher_reuse_native_payloads_exact':True if before else 'NOT_SELECTED_PRIOR_PERFORMANCE'}))
