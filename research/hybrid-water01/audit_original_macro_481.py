"""Verify an actual source-identical chained481 trajectory and retained own restarts."""
import argparse
import csv
from datetime import date,timedelta
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]


def digest(raw):return hashlib.sha256(raw).hexdigest()


def opened(path):
    meta=json.loads(path.with_name('ARTIFACT.json').read_text())
    assert 'sha256:'+digest(path.read_bytes())==meta['digest']
    return zipfile.ZipFile(path),meta


def physical(row):return {k:v for k,v in row.items() if k!='revision'}


def package(raw,day,binding):
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        assert sorted(z.namelist())==['checkpoint.json','macro.bin','result.end']
        manifest=json.loads(z.read('checkpoint.json'))
        native={n:z.read(n) for n in ('result.end','macro.bin')}
    assert manifest['schema']=='swap5-hybrid-water-checkpoint-3'
    assert manifest['binding']==binding and manifest['receipt']['day']==day
    assert manifest['receipt']['committed']
    assert manifest['files']=={n:digest(v) for n,v in native.items()}
    assert len(native['macro.bin'])==16122624
    magic,nodes,domains,clock=struct.unpack_from('<8siid',native['macro.bin'])
    assert (magic,nodes,domains,clock)==(b'S5MAC006',112,5,35795+day)
    return manifest,native


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--qualified',type=Path,required=True)
    p.add_argument('--segments',type=Path,nargs='+',required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
    capsule,cm=opened(a.qualified)
    qualification=json.loads(capsule.read('RESULT.json'))
    assert qualification['status']=='ORIGINAL_MACRO_COMPLETE_SHORT_RESTART_PASS'
    build=json.loads(capsule.read('O2/build/BUILD.json'));binding=build['binding']
    for role,name in [('donor','day_donor'),('kernel','day_kernel')]:
        assert digest(capsule.read('O2/build/'+name))==build['executable_sha256'][role]
    for name,sha in build['identity']['donor_generated'].items():
        assert digest(capsule.read('O2/build/'+name))==sha
    helper=subprocess.check_output(['git','show','HEAD:app/hybrid_water/original_macro_policy.py'],cwd=ROOT)
    assert digest(helper)==build['identity']['macro_policy']['generator_sha256']
    graph={'app/hybrid_water/original_macro_policy.py':digest(helper)}
    for key,name in [('host','daily_host.py'),('adapter','donor_adapter.f90'),('driver','main.f90'),('budget_source','hybrid_step_budget.f90')]:
        path='app/hybrid_water/'+name
        value=digest(subprocess.check_output(['git','show','HEAD:'+path],cwd=ROOT))
        assert value==build['identity'][key];graph[path]=value
    for path,sha in build['identity']['kernel_sources']:
        assert digest(subprocess.check_output(['git','show','HEAD:'+path],cwd=ROOT))==sha
        graph[path]=sha
    for path in ['app/hybrid_water/donor_sources.py','app/support/restart_publish.c']:
        value=digest(subprocess.check_output(['git','show','HEAD:'+path],cwd=ROOT))
        assert value==digest(subprocess.check_output(['git','show','3affe302984bbafc2108fb5b52d7ea91d44d5b80:'+path],cwd=ROOT))
        graph[path]=value
    rows=json.loads(capsule.read('O2/fresh/RESULT.json'))['rows']
    days={v['day']:v for v in rows};native_by_day={};segments=[];opened_segments=[]
    first_origin=capsule.read('O2/fresh/accepted-column-1-day-4.zip')
    package(first_origin,4,binding)
    package_hash_by_day={4:digest(first_origin)}
    for path in a.segments:
        z,meta=opened(path);opened_segments.append(z)
        candidates=[n for n in z.namelist() if len(n.split('/'))==2 and n.endswith('/RESULT.json') and n.split('/')[0].startswith(('full','resume-'))]
        assert len(candidates)==1
        name=candidates[0];prefix=name.rsplit('/',1)[0];result=json.loads(z.read(name))
        assert result['build']==build
        assert result['origin_checkpoint_sha256']==package_hash_by_day[result['origin_day']]
        current=list(map(json.loads,z.read(prefix+'/daily.jsonl').decode().splitlines()))
        assert [v['day'] for v in current]==list(range(result['origin_day']+1,result['last_accepted_day']+1))
        overlap=[]
        for row in current:
            day=row['day']
            if day in days:
                assert physical(row)==physical(days[day]),('Changed accepted overlap',day)
                overlap.append(day)
            else:days[day]=row
        assert result.get('overlap_days_exact',[])==overlap
        for n in z.namelist():
            if n.startswith(prefix+'/accepted-column-1-day-') and n.endswith('.zip'):
                day=int(n.rsplit('-',1)[1][:-4]);manifest,native=package(z.read(n),day,binding)
                assert physical(manifest['receipt'])==physical(days[day])
                native_hashes={n:digest(v) for n,v in native.items()}
                if day in native_by_day:assert native_by_day[day]==native_hashes
                native_by_day[day]=native_hashes
                package_hash_by_day[day]=digest(z.read(n))
        segments.append({'artifact_id':meta['id'],'artifact_digest':meta['digest'],
            'run':meta['workflow_run'],'origin_day':result['origin_day'],
            'accepted_through':result['last_accepted_day'],'durable_through':result['last_durable_day'],
            'status':result['status'],'seconds':result['model_and_controller_wall_seconds'],
            'overlap_days_exact':overlap})
    assert sorted(days)==list(range(1,482)),'Original481 period not yet complete'
    ordered=[days[d] for d in range(1,482)]
    for i,row in enumerate(ordered):
        assert row['committed'] and abs(row['independent_residual_cm'])<=1e-6
        assert len(row['pressure_head_cm'])==112 and len(row['stock_end_cm'])==6
        assert all(math.isfinite(x) for x in row['pressure_head_cm']+row['stock_end_cm'])
        if i:assert row['stock_start_cm']==ordered[i-1]['stock_end_cm']
    assert 481 in native_by_day
    restarts=[]
    for z in opened_segments:
        for name in z.namelist():
            if not name.startswith('restart-') or len(name.split('/'))!=2 or not name.endswith('/RESULT.json'):continue
            prefix=name.rsplit('/',1)[0];r=json.loads(z.read(name))
            assert r['status']=='OWN_RESTART_WINDOW_COMPLETE' and r['initial_state_exact']
            assert r['origin_sha256']==package_hash_by_day[r['origin_day']]
            for row in r['rows']:assert physical(row)==physical(days[row['day']])
            compared=[]
            for row in r['rows']:
                day=row['day'];_,native=package(z.read(prefix+f'/accepted-column-1-day-{day}.zip'),day,binding)
                if day in native_by_day:
                    assert {n:digest(v) for n,v in native.items()}==native_by_day[day],('Complete native restart differs',prefix,day)
                    compared.append(day)
            assert r['end_day'] in compared,'No complete native endpoint control'
            restarts.append({'window':[r['origin_day'],r['end_day']],
                'physical_days_exact':[v['day'] for v in r['rows']],
                'complete_native_days_exact':compared,'seconds':r['elapsed_seconds']})
    assert {tuple(r['window']) for r in restarts}>={(365,368),(453,459)}
    ref=ROOT/'research/hybrid-water01/whole-period-andelst-groundwater-20261112.csv'
    lineage=json.loads(ref.with_name('whole-period-andelst-reference-lineage-20261112.json').read_text())
    assert digest(ref.read_bytes().replace(b'\r\n',b'\n'))==lineage['canonical_lf_csv_sha256']
    assert build['inputs']==lineage['original_inputs_sha256']
    reference=list(csv.DictReader(ref.read_text().splitlines()));assert len(reference)==481
    comparisons=[]
    for row,old in zip(ordered,reference):
        day=row['day'];assert int(old['day'])==day
        assert old['date']==(date(1998,1,1)+timedelta(days=day-1)).isoformat()
        comparisons.append({'day':day,'date':old['date'],'new_gwl_cm':row['groundwater_cm'],
            'original_printed_cm':float(old['original_gwl_cm']),
            'corrected_printed_cm':float(old['refreshed_gwl_cm']),
            'new_minus_original_cm':row['groundwater_cm']-float(old['original_gwl_cm']),
            'new_minus_corrected_cm':row['groundwater_cm']-float(old['refreshed_gwl_cm'])})
    worst=max(comparisons,key=lambda v:abs(v['new_minus_original_cm']))
    old_archive=ROOT/'research/hybrid-water01/andelst-481-application-evidence.zip'
    assert digest(old_archive.read_bytes())=='02570c194df9c712a61bbb2c678d4ed5cc216f2c4def9259885e48a5a3fe83f9'
    with zipfile.ZipFile(old_archive) as z:
        corrected=list(map(json.loads,z.read('full/daily.jsonl').decode().splitlines()))
    new=days[worst['day']];old=corrected[worst['day']-1]
    pressure_support={'day':worst['day'],'source_archive_sha256':digest(old_archive.read_bytes()),
        'maximum_node_pressure_difference_cm':max(abs(x-y) for x,y in zip(new['pressure_head_cm'],old['pressure_head_cm'])),
        'matrix_stock_difference_cm':new['stock_end_cm'][0]-old['stock_end_cm'][0],
        'scope':'Descriptive comparison with retained corrected Windows profile; numerical policy and platform both differ. Not unrounded original spatial reference or a causal attribution.',
        'decision':'Large pressure-field difference cannot be waived as printed-GWL rounding or accepted from mass closure alone'}
    report={'status':'ORIGINAL_MACRO481_AND_COMPLETE_OWN_RESTART_VERIFIED',
        'analysis_source_canonical_lf_sha256':digest(Path(__file__).read_bytes().replace(b'\r\n',b'\n')),
        'unchanged_model_source_graph':graph,
        'model_execution_days':481,'new_model_runs_by_auditor':0,'qualified_capsule':cm,
        'build':build,'segments':segments,'own_restarts':restarts,
        'maximum_daily_residual_cm':max(abs(x['independent_residual_cm']) for x in ordered),
        'signed_water_residual_cm':math.fsum(x['independent_residual_cm'] for x in ordered),
        'mass_step_retries':sum(x['budget_step_retries'] for x in ordered),
        'summed_continuation_wall_seconds':math.fsum(x['seconds'] for x in segments),
        'terminal_native_sha256':native_by_day[481],
        'reference_lf_csv_sha256':lineage['canonical_lf_csv_sha256'],
        'largest_original_gwl_difference':worst,
        'largest_corrected_gwl_difference':max(comparisons,key=lambda v:abs(v['new_minus_corrected_cm'])),
        'pressure_support_at_worst_gwl':pressure_support,
        'sentinels':[v for v in comparisons if v['day'] in [256,257,365,453,456,457,458,459,481]],
        'science':'NOT_QUALIFIED: comparison uses retained five-decimal groundwater support, not a new oracle or relaxed acceptance; functional completeness and native state do not establish scientific equivalence or runtime parity'}
    (a.output/'daily.jsonl').write_text(''.join(json.dumps(v)+'\n' for v in ordered))
    (a.output/'GROUNDWATER.json').write_text(json.dumps(comparisons,indent=2)+'\n')
    (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['status','maximum_daily_residual_cm','mass_step_retries','summed_continuation_wall_seconds','largest_original_gwl_difference']}))
    return 0


if __name__=='__main__':raise SystemExit(main())
