#!/usr/bin/env python3
"""Replay sealed research assertions and corruption controls without compiling."""
import base64, copy, hashlib, io, json, pathlib, runpy, tarfile

UNIT = pathlib.Path(__file__).resolve().parent
ROOT = UNIT.parents[2]
sha = lambda b: hashlib.sha256(b).hexdigest()
validate = runpy.run_path(str(UNIT/'run_organic_constraint.py'))['validate']

def verify(record=None, files=None):
    record = record or json.loads((UNIT/'ORGANIC_CONSTRAINT_RESULT.json').read_bytes())
    capsule = (UNIT/'ORGANIC_CONSTRAINT_EVIDENCE.tar.xz.b64').read_bytes()
    assert sha(capsule) == record['evidence_sha256']
    assert not record['production_changed'] and not record['production_admitted']
    for name, expected in record['input_sha256'].items(): assert sha((ROOT/name).read_bytes()) == expected, name
    if files is None:
        with tarfile.open(fileobj=io.BytesIO(base64.b64decode(capsule))) as t:
            files = {m.name:t.extractfile(m).read() for m in t.getmembers() if m.isfile()}
    members = json.loads(files['MEMBERS.json'])
    assert set(files) == set(members) | {'MEMBERS.json'}
    for name, expected in members.items(): assert sha(files[name]) == expected, name
    assert json.loads(files['result.json']) == {k:v for k,v in record.items() if k!='evidence_sha256'}
    events = json.loads(files['events.json'])
    assert all(e['returncode']==0 for e in events)
    assert sum(e['category']=='compile' for e in events)==24
    assert sum(e['category']=='link' for e in events)==2
    assert sum(e['category']=='native' for e in events)==2
    for event in events:
        for stream in ['stdout','stderr']: assert sha(files[event[stream]])==event[stream+'_sha256']
    native = [e for e in events if e['category']=='native']
    for opt,event in zip(['O0','O2'],native):
        assert files[opt+'.txt']==files[event['stdout']]
        assert validate(files[opt+'.txt'])==record['results'][opt]
    return record, files

def rejected(fn):
    try: fn()
    except (AssertionError, ValueError, KeyError, IndexError): return
    raise AssertionError('corruption accepted')

if __name__=='__main__':
    record, files = verify()
    controls = []
    for name in ['src/process/mod_b111_soil_n_daily_candidate.f90',
                 'integration/mc-nut01/competing_sinks/test_organic_constraint.f90']:
        bad=copy.deepcopy(record);bad['input_sha256'][name]='0'*64
        rejected(lambda:verify(bad));controls.append('input:'+name)
    bad=copy.deepcopy(record);bad['evidence_sha256']='0'*64
    rejected(lambda:verify(bad));controls.append('capsule identity')
    for name in ['O0.txt','O2.txt','events.json','result.json']:
        bad=dict(files);bad[name]+=b'!'
        rejected(lambda:verify(files=bad));controls.append('raw:'+name)
    # Recheck the scientific assertion independently of container hashes.
    raw=files['O0.txt'].decode().splitlines()
    for prefix,index,value in [('SWEEP',3,'9.0'),('ROOT',5,'9.0'),('CLIPPED',1,'0'),('CANDIDATE',3,'0')]:
        bad=list(raw);line=next(i for i,s in enumerate(bad) if s.startswith(prefix))
        fields=bad[line].split();fields[index]=value;bad[line]=' '.join(fields)
        rejected(lambda:validate(('\n'.join(bad)+'\n').encode()));controls.append('assertion:'+prefix)
    print(json.dumps(dict(status='RESEARCH_REPLAY_PASS',corruption_controls=len(controls),controls=controls),indent=2))
