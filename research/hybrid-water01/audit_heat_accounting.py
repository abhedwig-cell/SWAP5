"""Independent original-source, actual-object, physical-state and energy witness audit."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import tarfile
import tempfile
import zipfile

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--archive',type=Path,required=True);p.add_argument('--sha256',required=True)
p.add_argument('--base-archive',type=Path,required=True)
a=p.parse_args();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(a.archive)==a.sha256
with tempfile.TemporaryDirectory(prefix='s5-heat-independent-audit-') as temp:
    root=Path(temp)/'observed';base=Path(temp)/'base'
    with tarfile.open(a.archive) as t:t.extractall(root,filter='data')
    load=lambda p:json.loads(p.read_text())
    index=load(root/'PROOF_INDEX.json');assert sha(a.base_archive)==index['base_archive_sha256']
    with tarfile.open(a.base_archive) as t:t.extractall(base,filter='data')
    for name,digest in load(root/'MEMBER_SHA256.json').items():assert sha(root/name)==digest,name
    for patch in root.rglob('bad-heat-face.txt.patch.json'):
        witness=load(patch);source=root/witness['source'];assert sha(source)==witness['source_sha256']
        lines=source.read_bytes().splitlines(keepends=True)
        assert len(witness['changes'])==1
        for change in witness['changes']:lines[change['line']]=bytes.fromhex(change['replacement_hex'])
        assert hashlib.sha256(b''.join(lines)).hexdigest()==witness['reconstructed_bad_sha256']
        del lines
    original_index=load(base/'PROOF_INDEX.json');original_members=load(base/'MEMBER_SHA256.json')
    original_objects={digest for name,digest in original_members.items() if name.endswith('.o')}
    original=base/original_index['reference']/'build/swap-selected/temperature.f90'
    original_text=original.read_text(encoding='cp1252')
    physical=lambda r:{k:v for k,v in r.items() if k not in ('column','revision')}
    totals={};all_steps=0
    for label,case in index['cases'].items():
        directory=root/case['directory'];meta=load(directory/'BUILD.json');binding=meta['binding']
        assert binding['original_temperature_sha256']==sha(original)
        observed=(directory/'temperature.f90').read_text(encoding='cp1252')
        assert re.sub(r'! BEGIN HEAT OBSERVATION\n.*?! END HEAT OBSERVATION\n','',observed,flags=re.S)==original_text
        assert sha(directory/'temperature.f90')==binding['observed_temperature_sha256']
        assert sha(directory/('observed-donor.exe' if index['platform']=='windows' else 'observed-donor'))==binding['observed_donor_sha256']
        for name,digest in binding['heat_observation_sources'].items():assert sha(root/index['sources'][name])==digest
        for path,digest in meta['linked_objects'].items():
            name=path.replace('\\','/').split('/')[-1]
            assert digest in original_objects or sha(directory/name)==digest
        cut,end=case['cut'],case['end'];window=directory/f'window-{cut}-to-{end}'
        native_case=original_index['cases'][label]
        if label.startswith('hupsel'):
            full=original_index['hupsel_full'];origin=base/full/'full'/f'accepted-column-1-day-{cut}.zip'
            expected=base/full/f'own-{cut}-to-{end}'
        else:
            origin=base/native_case['continuous']/f'accepted-column-1-day-{cut}.zip'
            expected=base/native_case['resumed']
        assert sha(origin)==binding['adopted_original_origin_sha256']==case['origin_sha256']
        actual=[json.loads(l) for l in (window/'daily.jsonl').read_text().splitlines()]
        wanted=[json.loads(l) for l in (expected/'daily.jsonl').read_text().splitlines()]
        assert list(map(physical,actual))==list(map(physical,wanted))
        with zipfile.ZipFile(window/f'accepted-column-1-day-{end}.zip') as z:
            manifest=json.loads(z.read('checkpoint.json'));assert manifest['binding']==binding
            assert manifest['receipt']==actual[-1] and manifest['receipt']['committed']
            for name,digest in manifest['files'].items():
                assert hashlib.sha256(z.read(name)).hexdigest()==digest
                assert z.read(name)==(expected/'original'/name).read_bytes()
        # Recompute sensible storage independently from exported original material
        # coefficients. This is verification, never another model execution.
        lines=iter((window/'original/original-heat-accounting.txt').read_text().splitlines())
        count=0;maximum_cell=0.;maximum_global=0.;maximum_missing=0.;composition=0.;statuses=Counter()
        while True:
            line=next(lines,None)
            if line is None:break
            head=line.split();assert head[0]=='HEAT_STEP' and len(head)==17
            data=list(map(float,head[1:14]));n=int(head[3]);assert all(map(math.isfinite,data))
            rows=[]
            for i in range(1,n+1):
                row=next(lines).split();assert row[:2]==['HEAT_NODE',str(i)] and len(row)==12
                rows.append(list(map(float,row[2:])))
            cell=[v[0]*v[6]*(v[5]-v[4])-(v[8]-v[9]) for v in rows]
            frozen=math.fsum(v[0]*v[6]*(v[5]-v[4]) for v in rows);boundary=rows[0][8]-rows[-1][9]
            assert max(map(abs,cell))<=1e-9 and abs(frozen-boundary)<=1e-9
            maximum_cell=max(maximum_cell,max(map(abs,cell)));maximum_global=max(maximum_global,abs(frozen-boundary))
            assert head[-2:]==['F','F'];statuses[head[4]]+=1
            if head[-3]=='T':
                assert head[4:6]==['3','0']
                u0=[];u1=[];comp=[]
                for dz,sat,w0,w1,t0,t1,cavg,solid,up,down in rows:
                    assert 0<=w0<=sat and 0<=w1<=sat
                    c0=solid+w0*4.18+(sat-w0)*.001212
                    c1=solid+w1*4.18+(sat-w1)*.001212
                    u0.append(dz*c0*t0);u1.append(dz*c1*t1)
                    comp.append(dz*(4.18-.001212)*.5*(t0+t1)*(w1-w0))
                change=math.fsum(b-a for a,b in zip(u0,u1));composed=math.fsum(comp)
                # Existing storage owner's stock-scaled representation bound;
                # this is NOT a relaxation of the physical1e-9 energy budget.
                gamma=(4*n+4)*sys.float_info.epsilon
                bound=gamma/(1-gamma)*math.fsum(abs(x)+abs(y) for x,y in zip(u0,u1))
                assert abs(change-data[8])<=bound and abs(composed-data[10])<=bound
                assert abs((change-boundary)-data[12])<=bound
                maximum_missing=max(maximum_missing,abs(data[12]));composition+=data[10]
            count+=1
        assert maximum_missing>1e-9,'Missing-energy counterfactual unexpectedly qualified'
        all_steps+=count
        totals[label]={'steps':count,'original_source_outside_observation_exact':True,
            'physical_and_both_native_payloads_exact':True,'maximum_cell_residual_j_cm2':maximum_cell,
            'maximum_global_residual_j_cm2':maximum_global,'storage_status_counts':dict(statuses),
            'zero_missing_energy_counterfactual':'FAIL','maximum_counterfactual_residual_j_cm2':maximum_missing,
            'composition_change_sum_j_cm2':composition,'full_energy_balance_complete':False}
    assert len(totals)==6
    print(json.dumps({'status':'INDEPENDENT_ORIGINAL_HEAT_SOURCE_OBJECT_STATE_CONDUCTION_AND_STORAGE_AUDIT_PASS',
                      'platform':index['platform'],'raw_files':len(load(root/'MEMBER_SHA256.json')),
                      'cases':totals,'total_heat_steps':all_steps,'full_energy_balance_complete':False}))
