from pathlib import Path
import hashlib,json,subprocess,io,zipfile,shutil,sys,os,time,difflib
sys.dont_write_bytecode=True
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-cause66';B=R.parent/'swap431-macro-b1-reject64'
ROOT=Path('C:/Users/Veldh012/SWAP5-work/01a1f3ce-667e-7091-82ae-a62485d14eca-8c08570e');W=ROOT/'follow67-data'
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(p,q):p.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
def generate():
    with zipfile.ZipFile(P/'SOURCE_BYTES.zip') as z:
        source={n:z.read(n).decode().replace('\r\n','\n') for n in ['head_observer66.f90','swap_repair66.f90']}
    for name,key in [('head_follow67.f90','head_observer66.f90'),('swap_follow67.f90','swap_repair66.f90')]:
        old=source[key];s=old.replace('abs(t1900-35797.290431125148d0)>1d-10.or.', '(abs(t1900-35797.290431125148d0)>1d-10.and.abs(t1900-35797.290441125151d0)>1d-10).or.')
        assert s!=old
        (R/name).write_text(s);(R/(name+'.patch')).write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='CAUSE66/'+key,tofile='FOLLOW67/'+name)))
    old=(B/'soilwater_native.f90').read_text();s=old.replace('   contains','   logical,save::cut_done67=.false.\n   character(24),save::run_mode67\n   contains',1)
    s=s.replace(' use variables,only:dt,dtmin,fldtmin',' use variables,only:dt,dtmin,fldtmin,t1900',1)
    start=s.index(' original_dt64=dt');end=s.index(" open(newunit=u64,file='input_control64.txt'",start)
    s=s[:start]+''' call get_environment_variable('FOLLOW67_MODE',run_mode67)
 if(trim(run_mode67)/='CONT'.and.trim(run_mode67)/='RESTART') error stop 'FOLLOW67 missing mode'
 if(trim(run_mode67)=='CONT'.and.abs(t1900-35797.290431125148d0)>1d-10) error stop 'FOLLOW67 CONT origin'
 if(trim(run_mode67)=='RESTART'.and.abs(t1900-35797.290441125151d0)>1d-10) error stop 'FOLLOW67 RESTART origin'
 original_dt64=dt;proposal64=dt
 if(dt<=0d0) error stop 'FOLLOW67 invalid saved proposal'
'''+s[end:]
    key="   call write55('follow')\n   if(resume55) call finish33('NATIVE55_RESTART_ONE_FULL_STEP')\n   call finish33('NATIVE55_CONTINUOUS_ONE_FULL_STEP')"
    assert key in s
    s=s.replace(key,"""   if(trim(run_mode67)=='CONT'.and..not.cut_done67) then
    call inventory_dump('cut67');call native09_dump('context_cut67');call ledger12_dump('ledger_cut67')
    call write55('cut67')
    call inventory_dump('cut67_after_io');call native09_dump('context_cut67_after_io');call ledger12_dump('ledger_cut67_after_io')
    if(abs(t1900-35797.290441125151d0)>1d-10) call finish33('FOLLOW67_WRONG_ACCEPTED_CUT')
    cut_done67=.true.;reject26_pending=.false.
    if(done35) call finish33('FOLLOW67_INTERNAL16_BEFORE_NEXT_STEP')
    return
   end if
   call write55('follow67')
   if(resume55) call finish33('FOLLOW67_ONE_NEXT_STEP_ACCEPTED')
   call finish33('FOLLOW67_ONE_NEXT_STEP_ACCEPTED')""")
    (R/'soilwater_follow67.f90').write_text(s);(R/'HARNESS.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='REJECT64/soilwater_native.f90',tofile='FOLLOW67/soilwater_follow67.f90')))
def prepare(opt):
    out=ROOT/('follow67-'+opt);assert not (out/'obj').exists()
    raw=subprocess.check_output(['git','show','95a61203:research/swap431-macro-b1-reject64/REJECT64_EVIDENCE.zip'],cwd=R)
    assert hashlib.sha256(raw).hexdigest()=='f8931da9a481e3f29b0918282bb761ca9a4701c762f92a2c6cfd50243dccafb3'
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        for x in json.loads(z.read('manifest.json')):
            prefix='native/'+opt+'/'
            if x['path'].startswith(prefix):
                p=out/x['path'][len(prefix):];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(z.read(x['path']));assert sha(p)==x['sha256']
    src=W/'cause66/build_delta'/opt/'obj'
    for p in src.iterdir():shutil.copy2(p,out/'obj'/p.name)
    old_identity=json.loads((P/(opt+'_REPAIR_IDENTITY.json')).read_text())
    for n,h in old_identity['objects'].items():assert sha(out/'obj'/n)==h
    save(R/(opt+'_RESTORED.json'),dict(objects={p.name:sha(p) for p in (out/'obj').iterdir() if p.is_file()},parent_cause66=old_identity))
    obj=out/'obj';commands=[]
    for name,dest in [('soilwater_follow67.f90','soilwater.o'),('head_follow67.f90','headcalc.o'),('swap_follow67.f90','swap.o')]:
        commands.append(['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch','-cpp','-Dlinux','-ffree-line-length-none','-I',str(obj),'-c',str(R/name),'-o',str(obj/dest)])
    commands.append(['gfortran','-o',str(out/'follow67.exe'),*map(str,sorted(obj.glob('*.o'))),str(out/'libttutil.a')])
    logs=[]
    for cmd in commands:
        t=time.perf_counter();p=subprocess.run(cmd,cwd=obj,capture_output=True,text=True,timeout=60)
        logs.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=p.returncode,output=p.stdout+p.stderr));save(R/(opt+'_BUILD.json'),logs);assert p.returncode==0,p.stderr
    save(R/(opt+'_IDENTITY.json'),dict(exe_sha256=sha(out/'follow67.exe'),sources={p.name:sha(p) for p in R.glob('*.f90')},compiler=subprocess.check_output(['gfortran','--version'],text=True),objects={p.name:sha(p) for p in obj.glob('*.o')}))
def run(opt,mode):
    assert opt in ['O0','O2'] and mode in ['CONT','RESTART']
    label=opt+'_'+mode;c=W/'runs'/label;out=W/'evidence/data'/label
    assert not c.exists() and not out.exists();c.mkdir(parents=True);out.mkdir(parents=True)
    base=W/'cause66/data'/(opt+'_REPAIR_CHAIN_NONE');inp=json.loads((base/'INPUT.json').read_text());old=inp['baseline']
    for x in old['original_case_manifest']:
        p=base/x['path'];assert sha(p)==x['sha256'] or x['path']=='swap.swp'
        dst=c/x['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst)
    for name in ['swap.swp','calibration_base.bin']:shutil.copy2(base/name,c/name)
    native=base/'own.end' if mode=='CONT' else W/'evidence/data'/(opt+'_CONT')/'cut67.end'
    if mode=='RESTART':assert sha(native)=='d5ee169f99cebe1a8dd849b39bfe51d06bdbcf5f226e127d2d70246807a373d7'
    shutil.copy2(native,c/'own.end')
    env=os.environ.copy();env.update(inp['environment']);env['FOLLOW67_MODE']=mode;env['CAUSE66_ENDPOINT']='NONE';env['CAUSE66_REPAIR']='1';env.pop('REJECT64_DT',None)
    exe=ROOT/('follow67-'+opt)/'follow67.exe';identity=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert sha(exe)==identity['exe_sha256']
    save(out/'INPUT.json',dict(identity=identity,baseline_case=old,environment={k:env[k] for k in [*inp['environment'],'FOLLOW67_MODE'] if k in env},native_source=str(native),native_sha256=sha(native),native_dt_preserved=True,mode=mode))
    t=time.perf_counter()
    try:
        p=subprocess.run([str(exe),'./swap.swp'],cwd=c,env=env,capture_output=True,text=True,timeout=20)
        q=dict(returncode=p.returncode,censored=False,seconds=time.perf_counter()-t,stdout=p.stdout,stderr=p.stderr)
    except subprocess.TimeoutExpired as e:q=dict(censored=True,seconds=time.perf_counter()-t,stdout=str(e.stdout),stderr=str(e.stderr))
    save(out/'RUN.json',q)
    for p in c.rglob('*'):
        if p.is_file():
            dst=out/p.relative_to(c);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst)
    print(label,json.dumps(q));assert not q['censored'] and q['returncode']==0
    if mode=='CONT':assert sha(out/'cut67.end')=='d5ee169f99cebe1a8dd849b39bfe51d06bdbcf5f226e127d2d70246807a373d7'
if __name__=='__main__':
    if sys.argv[1]=='prepare':generate();prepare('O0');prepare('O2')
    else:run(*sys.argv[1:3])
