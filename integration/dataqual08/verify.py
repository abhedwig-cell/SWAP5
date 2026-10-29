"""Verify DATAQUAL08 retained prefixes and censored work without executing a model."""
import base64,csv,hashlib,io,json,math,runpy,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
def verify():
    status=json.loads((ROOT/'integration/dataqual08/STATUS.json').read_bytes())
    for p,h in status['postimages'].items():assert sha((ROOT/p).read_bytes())==h,p
    owner=runpy.run_path(str(ROOT/'integration/audits/verify_dataqual07_current.py'))
    owner['source']();old=owner['capsule']();owner['validate'](old)
    meta=json.loads((ROOT/'integration/dataqual08/CAPSULE.json').read_bytes())
    raw=base64.b64decode(b''.join((ROOT/p).read_bytes() for p in meta['parts']),validate=True)
    assert len(raw)==meta['bytes'] and sha(raw)==meta['sha256']
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
        ms=t.getmembers();assert len(ms)==meta['members']==len({m.name for m in ms})
        assert all(m.isfile() and not Path(m.name).is_absolute() and '..'not in Path(m.name).parts for m in ms)
        f={m.name:t.extractfile(m).read() for m in ms}
    manifest=json.loads(f.pop('MANIFEST.json'));assert manifest=={p:sha(b)for p,b in f.items()}
    assert sha(old['recovery/native-O2'])==meta['executable_sha256']
    js=lambda p:json.loads(f[p])
    rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
    results=js('five/results.json');retained=js('five/RETAINED.json');summary=json.loads((ROOT/'integration/dataqual08/RESULT.json').read_bytes())
    assert len(results)==15 and all(r['status']=='CENSORED' and r['returncode']is None and r['censored'] for r in results)
    for r in results:
        pre='five/'+r['batch']+'-'+r['id']+'/'
        oldpre=r['batch']+'/'+r['id']+'/run/'
        for p,h in r['files'].items():assert sha(f[pre+p])==h
        for p in ['input.nml','input.swp','macro.nml']:assert f[pre+p]==old[oldpre+p]
        assert f[pre+'origin.bin']==old[oldpre+'restart.bin']
        original=next(e['command'] for e in json.loads(old[oldpre+'manifest.json'])['events'] if e['label']=='native')
        assert r['command'][1:]==original[1:2]+['origin.bin','5']+original[4:7]+['5.0']+original[8:]
    assert len(retained['retained'])==1
    r=retained['retained'][0];pre='five/'+r['batch']+'-'+r['id']+'/'
    assert sha(f[pre+'restart.bin'])==r['checkpoint_sha256']
    assert f[pre+'checkpoint-view/origin.bin']==f[pre+'restart.bin']
    assert all(not rows(pre+'checkpoint-view/'+p) for p in ['budget.csv','progress.csv','cost.csv','diagnostics.csv'])
    assert b'NATIVE_SWSOLU0_MACRO_RUTTER_HEAT_PROJECT_PASS'in f[pre+'checkpoint-view/stdout']
    for p,key in [('state.csv','state_sha256'),('temperature.csv','temperature_sha256')]:
        assert sha(f[pre+'checkpoint-view/'+p])==r[key]
        rr=rows(pre+'checkpoint-view/'+p);assert len(rr)==112
        assert all(math.isfinite(float(v))for row in rr for v in row.values())
        if p=='state.csv':assert all(0<=float(row['theta'])<=1 for row in rr)
    b=rows(pre+'budget.csv');assert float(b[0]['t0'])==r['origin_days'] and float(b[-1]['t1'])==r['completed_days']==2.
    keys=['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']
    assert all(abs(float(row[k]))<=1e-10 for row in b for k in keys)
    assert max(abs(float(row[k]))for row in b for k in keys)==r['max_water_cm']
    progress=[x for x in rows(pre+'progress.csv')if float(x['t1'])<=2.]
    assert progress and all(int(x['mass_rejections'])==0 for x in progress)
    e=js('three/execution.json');assert e['censored'] and e['returncode']is None
    assert f['three/origin.bin']==f[pre+'restart.bin']
    assert summary['native_processes']==16 and summary['five_day_completions']==0
    assert abs(summary['native_seconds']-sum(x['seconds']for x in results)-e['seconds'])<1e-9
    assert summary['configuration_days']==retained['after_days']
    assert summary['water_qualified']==83 and summary['started']==151
    return dict(qualified_daily_prefixes=1,new_water_configurations=0,configuration_days=summary['configuration_days'],native_processes=16,censored=16,full_historical_closure=False)
if __name__=='__main__':print(json.dumps(verify(),indent=2))
