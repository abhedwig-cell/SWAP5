"""Continue qualified DATAQUAL07 checkpoints without rebinding or rerunning prefixes."""
import argparse, concurrent.futures, hashlib, json, math, runpy, subprocess, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sha = lambda b: hashlib.sha256(b).hexdigest()

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--target', type=float, default=5.)
    p.add_argument('--seconds', type=float, default=60.)
    p.add_argument('--jobs', type=int, default=4)
    a = p.parse_args()
    assert math.isfinite(a.target) and a.target > 0
    assert 0 < a.seconds <= 120 and 1 <= a.jobs <= 8
    owner = runpy.run_path(str(ROOT/'integration/audits/verify_dataqual07_current.py'))
    owner['source']()
    files = owner['capsule']()
    owner['validate'](files)
    assess = runpy.run_path(str(ROOT/'tools/solute/run_dataqual_batch.py'))['assess']
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    exe = out/'native-O2'
    exe.write_bytes(files['recovery/native-O2'])
    exe.chmod(0o755)
    selected = [dict(batch=b, **r) for b in ['stock24', 'wet13']
                for r in json.loads(files[b+'/results.json']) if r['status']=='PASS']
    (out/'selection.json').write_text(json.dumps(dict(
        source_tree=subprocess.check_output(['git','rev-parse','HEAD^{tree}'],cwd=ROOT,text=True).strip(),
        executable_sha256=sha(exe.read_bytes()), target=a.target, seconds=a.seconds,
        cases=[dict(batch=r['batch'],id=r['id'],origin=r['completed_days']) for r in selected],
        invariants='same executable/input binding, own checkpoint, unchanged physical options and tolerances',
        counting='configuration extension only; never count numerical policy as a new configuration'),indent=2)+'\n')

    def execute(r):
        pre=r['batch']+'/'+r['id']+'/run/'
        case=out/(r['batch']+'-'+r['id'])
        case.mkdir()
        manifest=json.loads(files[pre+'manifest.json'])
        cmd=next(e['command'] for e in manifest['events'] if e['label']=='native').copy()
        assert cmd[2]=='-' and cmd[6]==manifest['binding_sha256']
        assert a.target > r['completed_days']
        for name in ['input.nml','input.swp','macro.nml']:
            raw=files[pre+name]
            assert sha(raw)==manifest['files'][name]
            (case/name).write_bytes(raw)
        raw=files[pre+'restart.bin']
        assert sha(raw)==manifest['files']['restart.bin']
        (case/'origin.bin').write_bytes(raw)
        # Only executable location, own restart location and requested endpoint change.
        cmd[0]=str(exe);cmd[2]='origin.bin';cmd[3]=str(math.ceil(a.target));cmd[7]=repr(a.target)
        started=time.monotonic();code=None;censored=False
        with (case/'native.stdout').open('wb') as so,(case/'native.stderr').open('wb') as se:
            try:
                code=subprocess.run(cmd,cwd=case,stdout=so,stderr=se,timeout=a.seconds).returncode
            except subprocess.TimeoutExpired:
                censored=True
        result=dict(id=r['id'],batch=r['batch'],configuration=r['configuration'],
                    origin_days=r['completed_days'],origin_sha256=sha(raw),command=cmd,
                    seconds=time.monotonic()-started,returncode=code,censored=censored,
                    **assess(case,a.target))
        result['status']='PASS' if code==0 and result['physical_complete'] else 'CENSORED' if censored else 'FAILED'
        assert (case/'origin.bin').read_bytes()==raw
        rejection=case/'diagnostic-rejected.bin'
        result['rollback_exact_to_origin']=rejection.read_bytes()==raw if rejection.exists() else None
        result['files']={f.name:sha(f.read_bytes()) for f in case.iterdir() if f.is_file()}
        (case/'result.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
        return result

    results=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as pool:
        futures=[pool.submit(execute,r) for r in selected]
        for future in concurrent.futures.as_completed(futures):
            r=future.result();results.append(r)
            (out/'results.json').write_text(json.dumps(sorted(results,key=lambda x:(x['batch'],x['id'])),indent=2,allow_nan=False)+'\n')
            print(json.dumps({k:r[k] for k in ['id','status','completed_days','seconds']}),flush=True)

if __name__=='__main__':
    main()
