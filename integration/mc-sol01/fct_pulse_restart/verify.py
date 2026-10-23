"""Source-bound analytic pulse, fresh native restart and process-kill proof."""
import argparse,base64,hashlib,io,json,runpy,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def assess(files):
    labels=json.loads(files['ROUNDS.json']);latest=labels[-1]
    for label in labels:
        r=json.loads(files[label+'/execution.json']);raw=files[label+'/checkpoint.raw']
        assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==r['baseline']
        for p,h in r['inputs'].items():
            assert sha(files[label+'/source/'+p])==h
            if label==latest:assert sha((ROOT/p).read_bytes())==h,('current source',p)
        for p,h in r['generated'].items():assert sha(files[label+'/'+p])==h
        for e in r['events']:
            for s in ['stdout','stderr']:assert sha(files[label+'/'+e[s]])==e[s+'_sha256']
        for p,h in r['artifacts'].items():assert sha(files[label+'/'+p])==h
    r=json.loads(files[latest+'/execution.json']);assert r['status']=='EXECUTED' and all(e['returncode']==e['expected'] for e in r['events'])
    generated=runpy.run_path(str(HERE/'generate.py'))['sources']()
    for p,b in generated.items():assert files[latest+'/'+p]==b
    assert len(r['closures']['pulse'])==10 and len(r['closures']['disk'])==181
    assert r['policy']==sha(json.dumps(dict(inputs=r['inputs'],generated=r['generated']),sort_keys=True).encode())
    builds=[e for e in r['events'] if '-fcheck=all' in e['command']];assert len(builds)==4
    for e in builds:
        cmd=e['command'];assert '-ffpe-trap=invalid,zero,overflow' in cmd and '-fopenmp' in cmd
        category='pulse' if Path(cmd[-1]).parent.name.startswith('pulse-') else 'disk'
        sources=[p for p in cmd if p.endswith('.f90')];assert sources==r['closures'][category] and len(sources)==len(set(sources))
        for p in sources:
            path=Path(p)
            if path.is_relative_to(ROOT):assert str(path.relative_to(ROOT)) in r['inputs']
            else:assert path.name in generated
    assert b'GNU Fortran' in files[latest+'/'+r['events'][0]['stdout']]
    accuracy=runpy.run_path(str(HERE/'accuracy.py'))['compare'](r['pulse_cases'],lambda p:files[latest+'/'+p])
    cp=runpy.run_path(str(HERE/'checkpoint.py'));seen=set();crashes=0
    def stream(e):
        assert e in r['events'];return files[latest+'/'+e['stdout']]
    def ledger(raw):return [l for l in raw.splitlines() if l.startswith(b'WINDOW ')]
    for c in r['disk_cases']:
        key=(c['optimization'],c['n'],c['factor'],c['exponent']);assert key not in seen;seen.add(key)
        full=files[latest+'/'+c['full']];split=files[latest+'/'+c['split']];resumed=files[latest+'/'+c['resumed']]
        assert full==resumed and full!=split
        events=c['events'];fl=ledger(stream(events['full']));rl=ledger(stream(events['resumed']))
        assert len(fl)==4 and [int(l.split()[1]) for l in fl]==[1,2,3,4]
        assert len(ledger(stream(events['split'])))==2 and rl==fl[2:]
        for line in fl:
            vals=list(map(float,line.split()[3:]));assert len(vals)==5
            import math
            assert all(math.isfinite(x) for x in vals) and vals[0]>=0 and vals[1]>=vals[4]>0 and 0<=vals[2]<1e-10 and abs(vals[3])<1e-10
        assert b'DISK_RUN_PASS' in stream(events['full']) and b'DISK_RUN_PASS' in stream(events['resumed'])
        assert set(c['negative_controls'])=={'damaged','truncated','policy','context','native_parameters','native_crc','native_equilibrium_valid_crc'}
        for name in ['wrong-parameters','crc-reject','equilibrium-reject']:
            assert stream(events[name]).strip()==b'RESTORE_REJECTED_BOTH_TARGETS_EMPTY'
            assert not any(p.endswith('/'+name+'/payload.bin') for p in r['artifacts'])
        context={k:c[k] for k in ['n','factor','exponent']};context['n']=int(context['n'])
        raw=cp['encode'](split,r['policy'],context)
        assert cp['decode'](raw,r['policy'],context)==split
        for bad,policy,ctx in [(raw[:-1],r['policy'],context),(raw[:-1]+bytes([raw[-1]^1]),r['policy'],context),
            (raw,'0'*64,context),(raw,r['policy'],{**context,'factor':context['factor']+.1})]:
            try:cp['decode'](bad,policy,ctx)
            except(AssertionError,KeyError,ValueError):pass
            else:raise AssertionError('accepted invalid envelope')
        for crash in c['crashes']:
            e=crash['event'];assert e in r['events'] and e['returncode']==-9 and e['expected']==-9
            assert e['command'][-2:]==['--crash',crash['point']]
            authority=files[latest+'/'+crash['authority']]
            point=crash['point'];expected=split if point=='before' else files[latest+'/'+str(Path(c['full']).parent.parent/'third/payload.bin')]
            assert cp['decode'](authority,r['policy'],context)==expected
            assert files[latest+'/'+crash['continued']]==full
            assert ledger(stream(events['continued-'+point]))==fl[2 if point=='before' else 3:]
            crashes+=1
    from itertools import product
    assert seen==set(product(['O0','O2'],[40,80],[.8,1.2],[.5,1.,2.])) and crashes==4
    prior=json.loads(files['PRESERVATION.json']);assert prior['qualified'] and prior['controls']>=156 and prior['reactive_controls']==8
    assert not r['production_activated']
    return dict(status='PULSE_AND_FRESH_PROCESS_JOINT_RESTART_O0_O2_QUALIFIED',pulse=accuracy,
        disk_cases=24,separate_native_runs=sum(len(c['events']) for c in r['disk_cases']),fresh_process_endpoints_byte_exact=24,
        envelope_rejections=96,native_corruption_parameter_rejections=72,publisher_process_kills=4,crash_recoveries_exact=4,
        disk_restart_qualified=True,fresh_process_restart_qualified=True,bounded_POSIX_process_crash_publication_qualified=True,
        production_activated=False,full_mc_sol01_closed=False)
def controls(files):
    latest=json.loads(files['ROUNDS.json'])[-1];r=json.loads(files[latest+'/execution.json']);passed=[]
    def reject(name,fn):
        f=dict(files);fn(f)
        try:assess(f)
        except(AssertionError,KeyError,ValueError):passed.append(name);return
        raise AssertionError('accepted '+name)
    case=r['disk_cases'][0]
    reject('missing original full endpoint',lambda f:f.pop(latest+'/'+case['full']))
    reject('missing fresh process endpoint',lambda f:f.pop(latest+'/'+case['resumed']))
    reject('changed actual CRC-valid rejection artifact',lambda f:f.__setitem__(latest+'/'+str(Path(case['full']).parent.parent/'equilibrium-corrupt.bin'),b'!'))
    reject('changed production codec source',lambda f:f.__setitem__(latest+'/source/src/adapter/mod_matrix_joint_restart_file.f90',b'!'))
    reject('missing current preservation owner',lambda f:f.pop('PRESERVATION.json'))
    pulse=next(c for c in r['pulse_cases'] if c['optimization']=='O2' and c['flag']==1)
    def falsify_profile(f):
        p=latest+'/'+pulse['stdout'];lines=f[p].decode().splitlines();v=lines[2].split();v[3]='-1.0';lines[2]=' '.join(v);f[p]=('\n'.join(lines)+'\n').encode()
        rr=json.loads(f[latest+'/execution.json'])
        for e in [*rr['events'],*rr['pulse_cases']]:
            if e['stdout']==pulse['stdout']:e['stdout_sha256']=sha(f[p])
        f[latest+'/execution.json']=json.dumps(rr).encode()
    reject('negative pulse profile with consistent raw hashes',falsify_profile)
    def foreign_source(f):
        rr=json.loads(f[latest+'/execution.json']);e=next(e for e in rr['events'] if '-fcheck=all' in e['command'])
        old=next(p for p in e['command'] if p.endswith('/pulse_driver.f90'));new='/tmp/unbound_pulse.f90'
        for event in rr['events']:
            event['command']=[new if p==old else p for p in event['command']]
        rr['closures']['pulse']=[new if p==old else p for p in rr['closures']['pulse']]
        f[latest+'/execution.json']=json.dumps(rr).encode()
    reject('unbound compiled source with consistent closure declaration',foreign_source)
    crash=next(c for c in r['disk_cases'] if c['crashes'])['crashes'][0]
    reject('missing killed-publication authority',lambda f:f.pop(latest+'/'+crash['authority']))
    return passed
def unpack(path,expected):
    raw=base64.b64decode(path.read_bytes());assert sha(raw)==expected
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:
        ms=t.getmembers();assert len(ms)==len({m.name for m in ms}) and all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in ms)
        f={m.name:t.extractfile(m).read() for m in ms}
    manifest=json.loads(f.pop('MANIFEST.json'));assert manifest=={p:sha(b) for p,b in f.items()};return f
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');a=ap.parse_args();i=json.loads((HERE/'EVIDENCE_INDEX.json').read_text())
    f=unpack(HERE/'EVIDENCE.tar.xz.b64',i['decoded_sha256']);result=assess(f);assert result==json.loads(f['VERIFICATION.json'])
    if a.self_test:result['controls']=controls(f)
    print(json.dumps(result,indent=2))
