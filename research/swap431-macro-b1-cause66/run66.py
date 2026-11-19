from pathlib import Path
import json,hashlib,os,shutil,subprocess,sys,time
sys.dont_write_bytecode=True
R=Path(__file__).resolve().parent
ROOT=Path('C:/Users/Veldh012/SWAP5-work/01a1f3ce-667e-7091-82ae-a62485d14eca-8c08570e')
W=ROOT/'cause66-data'
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def run(opt,stage,mode,intervention='NONE'):
    assert (stage=='OBS' and opt=='O0' and (mode,intervention) in [('CHAIN','NONE'),('DIRECT','NONE'),('CHAIN','SMALL'),('DIRECT','LARGE')]) or (stage=='REPAIR' and intervention=='NONE')
    label='_'.join([opt,stage,mode,intervention]);c=W/'runs'/label;out=W/'evidence/data'/label
    assert not c.exists() and not out.exists(),'immutable route already exists'
    c.mkdir(parents=True);out.mkdir(parents=True)
    baseline=W/'coupled65'/(opt+'_'+mode)
    inp=json.loads((baseline/'INPUT.json').read_text())
    for x in inp['original_case_manifest']:
        p=baseline/x['path'];assert sha(p)==x['sha256'] or x['path']=='swap.swp'
        dst=c/x['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst)
    # Use the exact already modified COUPLED65 control deck and start packet.
    for name in ['swap.swp','own.end','calibration_base.bin']:shutil.copy2(baseline/name,c/name)
    env=os.environ.copy();env.update(inp['environment']);env['CAUSE66_ENDPOINT']=intervention;env['CAUSE66_REPAIR']='1' if stage=='REPAIR' else '0'
    exe=ROOT/('cause66-'+opt)/(stage+'.exe');identity=json.loads((R/(opt+'_'+stage+'_IDENTITY.json')).read_text());assert sha(exe)==identity['exe_sha256']
    (out/'INPUT.json').write_text(json.dumps(dict(baseline=inp,exe_sha256=sha(exe),identity=identity,environment={k:env[k] for k in [*inp['environment'],'CAUSE66_ENDPOINT','CAUSE66_REPAIR']}),indent=2)+'\n')
    t=time.perf_counter()
    try:
        p=subprocess.run([str(exe),'./swap.swp'],cwd=c,env=env,capture_output=True,text=True,timeout=20)
        q=dict(returncode=p.returncode,censored=False,seconds=time.perf_counter()-t,stdout=p.stdout,stderr=p.stderr)
    except subprocess.TimeoutExpired as e:q=dict(censored=True,seconds=time.perf_counter()-t,stdout=str(e.stdout),stderr=str(e.stderr))
    (out/'RUN.json').write_text(json.dumps(q,indent=2)+'\n')
    for p in c.rglob('*'):
        if p.is_file():
            dst=out/p.relative_to(c);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst)
    print(label,json.dumps(q));assert not q['censored'] and q['returncode']==0
    assert 'NATIVE55_RESTART_ONE_FULL_STEP' in (out/'outcome.txt').read_text()
if __name__=='__main__':run(*sys.argv[1:])
