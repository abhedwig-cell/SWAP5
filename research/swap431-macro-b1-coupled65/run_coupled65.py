"""Four preregistered processes; no compilation, solver edits or state search."""
from pathlib import Path
import hashlib, json, os, re, shutil, subprocess, sys, time
sys.dont_write_bytecode = True
R = Path(__file__).resolve().parent
BASE = '15d14a7b5679b6e11a97414e29a09738e09b9a29'
WORK = Path('C:/Users/Veldh012/SWAP5-work/01a1f3ce-667e-7091-82ae-a62485d14eca-8c08570e/coupled65-cases')
CASE = Path('C:/Users/Veldh012/swap431-state02-work/phase/O2/V1/case')
def blob(path):
    return subprocess.check_output(['git','show',BASE+':'+path], cwd=R)
def sha(p):
    with p.open('rb') as f: return hashlib.file_digest(f,'sha256').hexdigest()
def save(p,q): p.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
def run(opt,mode):
    profile=opt+'_'+mode
    out=WORK/'evidence/data'/profile
    c=WORK/profile
    assert not out.exists() and not c.exists(), 'immutable route already exists'
    c.mkdir(parents=True)
    manifest=json.loads(blob('research/swap431-macro-b1-native09/CASE_IDENTITY.json'))
    for x in manifest:
        src=CASE/x['path']; assert sha(src)==x['sha256'],x['path']
        dst=c/x['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
    own=blob('research/swap431-macro-b1-native55/data/'+opt+'/CONT_D2/candidate.end')
    (c/'own.end').write_bytes(own)
    assert sha(c/'own.end')=='59988fe0728bc51006085bbc957afc16ddf50b23a5cbb644228716dff743748e'
    (c/'calibration_base.bin').write_bytes(blob('research/swap431-macro-b1-sense23/data/'+opt+'/RESUME_IEEE/trial23_base.bin'))
    assert sha(c/'calibration_base.bin')=='aec5d4383614499853fe809018b53844d54d852a205a77f45c28ea28378f62c3'
    s=(c/'swap.swp').read_text(encoding='cp1252')
    s=re.sub(r'(?mi)^(\s*SWINCO\s*=\s*)2\b',r'\g<1>3',s,count=1)
    s=re.sub(r'(?mi)^\s*TEND\s*=.*$',' TEND = 1998-01-03',s,count=1)
    s+="\n INIFIL = 'own.end'\n SWINITYPE = 2\n SWENDTYPE = 2\n"
    for key in ['SWBAL','SWBLC','SWBMA']:
        s=re.sub(r'(?mi)^(\s*'+key+r'\s*=\s*)0\b',r'\g<1>1',s,count=1)
    s=re.sub(r'(?mi)^\s*DATEFIX\s*=.*$',' DATEFIX = 2 1',s,count=1)
    s=re.sub(r'(?mi)^(\s*SWYRVAR\s*=\s*)0\b',r'\g<1>1',s,count=1)
    s+='\n OUTDAT = 1998-01-02 1998-01-03\n'
    (c/'swap.swp').write_text(s,encoding='cp1252')
    resources=json.loads(blob('research/swap431-macro-b1-reject64/RESOURCE_PATHS.json'))
    exe=Path(resources[opt]['path'])/'native09.exe'
    identity=json.loads(blob('research/swap431-macro-b1-reject64/'+opt+'_IDENTITY.json'))
    assert sha(exe)==identity['exe_sha256']
    env=os.environ.copy()
    overrides=dict(PYTHONDONTWRITEBYTECODE='1',NATIVE55_MODE='RESTART',DAY10_MODE='RESTART',PROBE35_ENABLE='0',LEDGER12_REQUIRE='1',PERIOD34_ORIGINAL_POLICY='0',SELECT50_T=format(35797.29042064949,'.17g'),SELECT50_DT=format(0.000282842712474619,'.17g'),REJECT64_DT=format(2.0951312035156963e-5 if mode=='CHAIN' else 1e-5,'.17g'))
    env.update(overrides)
    out.mkdir(parents=True)
    save(out/'INPUT.json',dict(baseline=BASE,exe=str(exe),identity=identity,environment=overrides,original_case_manifest=manifest,own_end_sha256=sha(c/'own.end')))
    t=time.perf_counter()
    try:
        p=subprocess.run([str(exe),'./swap.swp'],cwd=c,env=env,capture_output=True,text=True,timeout=20)
        q=dict(returncode=p.returncode,censored=False,seconds=time.perf_counter()-t,stdout=p.stdout,stderr=p.stderr)
    except subprocess.TimeoutExpired as e:
        q=dict(censored=True,seconds=time.perf_counter()-t,stdout=str(e.stdout),stderr=str(e.stderr))
    save(out/'RUN.json',q)
    for p in c.rglob('*'):
        if p.is_file():
            dst=out/p.relative_to(c);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst)
    print(profile,json.dumps(q))
    assert not q['censored'] and q['returncode']==0 and 'NATIVE55_RESTART_ONE_FULL_STEP' in (out/'outcome.txt').read_text()
    if mode=='CHAIN':
        a=[list(map(float,x.split())) for x in (out/'attempt_trace.txt').read_text().splitlines() if x.strip()]
        assert len(a)==2 and a[0][8]==4 and a[1][8]==0 and a[1][3]==1e-5
if __name__=='__main__': run(*sys.argv[1:3])
